
Param(

    [string] $settingsFileName = '\Settings\backupSettings.json',
    [string] $armDeploymentTemplateFile = '\Templates\backupArmTemplate.json',
    [boolean] $unitTestMode = $false
)

#Check no missing setting
function Test-ParameterSet
{
    param
    (
        [parameter(Mandatory = $true)][System.Object]$settings
    )
    # Loop through the $settings and check no missing setting
    if ($null -eq $applicationFileJson.subscriptions) {throw "Missing subscriptions field in settings file"}
    foreach ($subscription in $applicationFileJson.subscriptions)
    {
        if ($null -eq $subscription.subscriptionId) {throw "Missing subscription Id field in settings file"}
        # Loop through the $settings and check no missing setting
        foreach ($vault in $settings.WorkLoads)
        {
		    if ($null -eq $vault.applicationName) {throw "Missing applicationNam in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.environmentName) {throw "Missing virtualNetworkName in settings file for $($subscription.subscriptionId)"}
			if ($null -eq $vault.vaultRG) {throw "Missing vaultRG in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.vaultName) {throw "Missing vaultName in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.policyName) {throw "Missing policyName in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.fabricName) {throw "Missing fabricName in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.backupItem) {throw "Missing backupItem in settings file for $($subscription.subscriptionId)"} 
			          			
        } # Backup
    } # Subscription
    return $true
} # Function

function Publish-Backup
{
    [OutputType([String])]
    param
    (
        [parameter(Mandatory = $true)][string]$armDeploymentTemplateFile,
        [parameter(Mandatory = $true)][string]$vaultRG,
        [parameter(Mandatory = $true)][string]$vaultName,
        [parameter(Mandatory = $true)][string]$policyName,
        [parameter(Mandatory = $true)][string]$fabricName,
        [parameter(Mandatory = $true)][system.object[]]$backupItem
    )

    #Check resource group exist
    try {
        $resourceGroup = Get-AzureRmResourceGroup -Name $vaultRG -ErrorAction Stop   
    }
    catch {
        $resourceGroup = $null
    }
    if ($null -eq $resourceGroup)
    {
        $message = "Resource group $vaultRG not found, deployment stop"
        Write-Verbose $message
        return $message
    }
    else 
    {
        # Prepare deployment variables
		Write-Verbose "ResourceGroup Found"
		$deploymentParameters =@{}
        $deploymentParameters.Add('vaultRG',$vaultRG)
        $deploymentParameters.Add('vaultName',$vaultName)
        $deploymentParameters.Add('policyName',$policyName)
        $deploymentParameters.Add('fabricName',$fabricName)
        $deploymentParameters.Add('backupItem',$backupItem)
        $newdeploymentParameters=$deploymentParameters
       Unlock-ResourceGroup $vaultRG
        write-verbose "ResourceGroup Unlocked"
        #Deploy the infrastructure
        Write-Verbose "Enalbing Backup Creation Template: $armDeploymentTemplateFile"    
       $armDeployment = New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $armDeploymentTemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('yyyyMMdd-HHmm')) `
                                            -ResourceGroupName $vaultRG `
                                            -TemplateFile $armDeploymentTemplateFile `
                                            -TemplateParameterObject $newdeploymentParameters `
                                            -Force -Verbose

        Write-Verbose "Deployment on rg $($armDeployment.ResourceGroupName) $($armDeployment.ProvisioningState) $($armDeployment.Timestamp)"
        return $armDeployment.ProvisioningState
		 Lock-ResourceGroup $vaultRG
        Write-Verbose "ResourceGroup Locked"
    }
}

function Publish-Infrastructure
{
param(
        [parameter(Mandatory = $true)][string]$settingsFileName,
        [parameter(Mandatory = $true)][string]$armDeploymentTemplateFile
        
     )
 
    $settings = Get-JsonParameterSet -settingsFileName $settingsFileName
	$deploymentIsSucceeded = $true
    $workloadCount = $settings.WorkLoads.Count
    Write-Verbose "workloadCounts: $workloadCount"
    if($workloadCount -ge 1)
	{
        for($i = 0;$i -lt $workloadCount; $i++)
            { 
               $applicationName = $settings.WorkLoads[$i].applicationName
               $environmentName = $settings.WorkLoads[$i].environmentName
			   $vaultRG =$settings.WorkLoads[$i].vaultRG
               $vaultName =$settings.WorkLoads[$i].vaultName
               $policyName =$settings.WorkLoads[$i].policyName
               $fabricName =$settings.WorkLoads[$i].fabricName
               $backupItem =@()
               foreach($item in $settings.WorkLoads.backupItem)
               {
                    $hash =@{}
                    $hash.Add('VMRG',$item.VMRG)
                    $hash.Add('VMName',$item.VMName)
                    $backupItem +=$hash
               }

               $applicationFile = "..\SettingsByWorkload\" + "nv_" + $applicationName + ".workload.json"

                $applicationFile = Get-FileFullPath -fileName $applicationFile  -rootPath $PSScriptRoot
                $applicationFileJson = Get-JsonParameterSet -settingsFileName $applicationFile
                $null = Test-ParameterSet -settings $settings
                $policyCount = $applicationFileJson.subscriptions.Count
                if($policyCount -ge 1)
                {  
                    for($i = 0;$i -lt $policyCount; $i++)
                    { 
                        if($applicationFileJson.subscriptions[$i].environmentName -eq $environmentName)
                        {
                            $subscriptionId = $applicationFileJson.subscriptions[$i].subscriptionId 
                            Write-Verbose "Environment Subscription: $($subscriptionId)"
                            Set-ContextIfNeeded -SubscriptionId $subscriptionId
                            						    
                                Write-Verbose ""
                                Write-Verbose "Ready to start deployment on environment $EnvironmentName of Enabling the VM Backup With Recovery Vault in subscription $subscriptionId for resource group: $vaultRG"
                
                                $result = Publish-Backup `
                                -armDeploymentTemplateFile $armDeploymentTemplateFile `
                                -vaultRG $vaultRG `
                                -vaultName $vaultName `
                                -policyName $policyName `
                                -fabricName $fabricName `
                                -backupItem $backupItem 
                                                                

                                if ($result -ne 'Succeeded') {$deploymentIsSucceeded = $false}
                         }
                    }
                }
            }
    }
    if ($deploymentIsSucceeded -eq $false) 
    {
        $errorID = 'Deployment failure'
        $errorCategory = [System.Management.Automation.ErrorCategory]::LimitsExceeded
        $errorMessage = 'Deployment failed'
        $exception = New-Object -TypeName System.SystemException -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,$errorID, $errorCategory, $null
        Throw $errorRecord
    }
    else 
    {
        return $true    
    } # Deploy status
} # function


#end of function and start of script
if ($unitTestMode)
{
    #do nothing
    Write-Verbose 'Unit test mode, no deployment' -Verbose
}
else 
{
    #Log in Azure if not already done
    try 
    {
        $azureRmContext = Get-AzureRmContext -ErrorAction Stop
    }
    catch 
    {
        $result = Add-AzureRmAccount
        $azureRmContext = $result.Context
    }
    Write-Verbose "Subscription name $($azureRmContext.Subscription.Name)" -Verbose
    $VerbosePreference = 'Continue'

    #setting file path
    $scriptsPath = $PSScriptRoot
	for ($i=1; $i -lt 2 ; $i++) 
    {
        $scriptsPath = Split-Path -Path $scriptsPath -Parent
        
    }
    $settingsFileName=Join-Path $scriptsPath $settingsFileName
    $armDeploymentTemplateFile=Join-Path $scriptsPath $armDeploymentTemplateFile
    # Deploy infrastructure
    return Publish-Infrastructure `
    -settingsFileName $settingsFileName `
    -armDeploymentTemplateFile $armDeploymentTemplateFile `
}