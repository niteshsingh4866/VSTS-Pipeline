
Param(

    [string] $settingsFileName = '\Settings\LBPIPInputSettings.json',
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
            if ($null -eq $vault.environmentName) {throw "Missing environmentName in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.LoadBalancerName) {throw "Missing LoadBalancerName in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.LoadBalancerResourceGroupName) {throw "Missing LoadBalancerResourceGroupName in settings file for $($subscription.subscriptionId)"}
			
            foreach($IP in $vault.FrontendIPConfiguration)
            {
                if ($null -eq $IP.name) {throw "Missing name in settings file for $($subscription.subscriptionId)"}
                if ($null -eq $IP.publicIPName) {throw "Missing publicIPName in settings file for $($subscription.subscriptionId)"}
                if ($null -eq $IP.PublicIPResourceGroupName) {throw "Missing PublicIPResourceGroupName in settings file for $($subscription.subscriptionId)"}
            }           		
        } #LBPIP
    } # Subscription
    return $true
} # Function

function Publish-LBPIP
{
    [OutputType([String])]
    param
    (
        [parameter(Mandatory = $true)][string]$LoadBalancerResourceGroupName,
        [parameter(Mandatory = $true)][string]$LoadBalancerName,
        [parameter(Mandatory = $true)][string]$PublicIPResourceGroupName,
        [parameter(Mandatory = $true)][string]$publicIPName,
        [parameter(Mandatory = $true)][string]$name
        
    )

    #Check resource group exist
    try {
        $resourceGroup = Get-AzureRmResourceGroup -Name $LoadBalancerResourceGroupName -ErrorAction Stop   
    }
    catch {
        $resourceGroup = $null
    }
    if ($null -eq $resourceGroup)
    {
        $message = "LoadBalancer Resource Group $LoadBalancerResourceGroupName not found, deployment stop"
        Write-Verbose $message
        return $message
    }
    else 
    {
        
        $lb = Get-AzureRmLoadBalancer -Name $LoadBalancerName -ResourceGroupName $LoadBalancerResourceGroupName 
        $pip=(Get-AzureRmPublicIpAddress -Name $publicIPName -ResourceGroupName $PublicIPResourceGroupName) 
        $LBConfig=New-AzureRmLoadBalancerFrontendIpConfig -Name $publicIPName -PublicIpAddressId $pip.Id 
        if($null -ne $LBConfig)
        {
            Write-Verbose "new FrontendIpConfig created for $($LBConfig.Name)" -Verbose
        }
        $addLBConfig=$lb | Add-AzureRmLoadBalancerFrontendIpConfig -Name $name -PublicIpAddress $pip 
        if($null -ne $LBConfig)
        {
            Write-Verbose "new FrontendIpConfig added for $($addLBConfig.Name)" -Verbose
        }
        $setLB=$lb | Set-AzureRmLoadBalancer -Verbose

         Write-Verbose "$LoadBalancerName ProvisioningState for $publicIPName $($setLB.ProvisioningState)" 		
		 
    }
}

function Publish-Infrastructure
{
param(
        [parameter(Mandatory = $true)][string]$settingsFileName
              
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
               $LoadBalancerResourceGroupName = $settings.WorkLoads[$i].LoadBalancerResourceGroupName
			   $LoadBalancerName =$settings.WorkLoads[$i].LoadBalancerName
                            
              
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
                            						    
                                #Write-Verbose ""
                                Write-Verbose "Ready to start deployment on environment $EnvironmentName in subscription $subscriptionId for resource group: $LoadBalancerResourceGroupName"
                               $unlock=Unlock-ResourceGroup $LoadBalancerResourceGroupName 
                                if($null -ne $unlock)
                                {
                                    Write-Verbose "resource group unlocked" -Verbose
                                } 
                                foreach($IP in $settings.WorkLoads[$i].FrontendIPConfiguration)
                                {
                                    Publish-LBPIP `
                                    -LoadBalancerResourceGroupName $LoadBalancerResourceGroupName `
                                    -LoadBalancerName $LoadBalancerName `
                                    -PublicIPResourceGroupName $IP.PublicIPResourceGroupName `
                                    -publicIPName $IP.publicIPName `
                                    -name $IP.name 
                                }
                              Lock-ResourceGroup $LoadBalancerResourceGroupName		                                
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
   

    # Deploy infrastructure
    return Publish-Infrastructure `
    -settingsFileName $settingsFileName 
    
}