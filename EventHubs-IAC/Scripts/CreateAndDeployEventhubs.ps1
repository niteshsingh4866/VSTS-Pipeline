#--------------------------------------------------------------------------------- 
#The sample scripts are not supported under any Microsoft standard support 
#program or service. The sample scripts are provided AS IS without warranty  
#of any kind. Microsoft further disclaims all implied warranties including,  
#without limitation, any implied warranties of merchantability or of fitness for 
#a particular purpose. The entire risk arising out of the use or performance of  
#the sample scripts and documentation remains with you. In no event shall 
#Microsoft, its authors, or anyone else involved in the creation, production, or 
#delivery of the scripts be liable for any damages whatsoever (including, 
#without limitation, damages for loss of business profits, business interruption, 
#loss of business information, or other pecuniary loss) arising out of the use 
#of or inability to use the sample scripts or documentation, even if Microsoft 
#has been advised of the possibility of such damages  
#--------------------------------------------------------------------------------- 

<#
.SYNOPSIS

.DESCRIPTION
#>

#Requires -Version 3.0

Param(

    [string] $settingsFileName = '\Settings\EventHubsSettings.json',
    [string] $armDeploymentTemplateFile = '\Templates\EventHubsArmTemplate.json',
    [string] $armDeploymentTemplateFile1 = '\Templates\EventHubsArmTemplate1.json',
    [boolean] $unitTestMode = $false
)

# Define FUNCTIONS

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
			if ($null -eq $vault.resourceGroupName) {throw "Missing resourceGroupName in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.namespaceName) {throw "Missing namespaceName in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.eventHubName) {throw "Missing eventHubName in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.location) {throw "Missing location in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.retentionInDays) {throw "Missing retentionInDays in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.partitionCount) {throw "Missing partitionCount in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.CaptureEnable) {throw "Missing CaptureEnable in settings file for $($subscription.subscriptionId)"}
            if ($vault.CaptureEnable -eq 'true')
            {
                if ($null -eq $vault.captureTimeInSeconds) {throw "Missing captureTimeInSeconds in settings file for $($subscription.subscriptionId)"}
                if ($null -eq $vault.encoding) {throw "Missing encoding in settings file for $($subscription.subscriptionId)"}
                if ($null -eq $vault.captureSize) {throw "Missing captureSize in settings file for $($subscription.subscriptionId)"}
                if ($null -eq $vault.StorageAccountName) {throw "Missing StorageAccountName in settings file for $($subscription.subscriptionId)"}
                if ($null -eq $vault.blobContainerName) {throw "Missing blobContainerName in settings file for $($subscription.subscriptionId)"}
                if ($null -eq $vault.StorageAccountResourceGroup) {throw "Missing StorageAccountResourceGroup in settings file for $($subscription.subscriptionId)"}
            }

        } # EventHubs
    } # Subscription
    return $true
} # Function

#Deploy EventHubs 
function Publish-EventHubs
{
    [OutputType([String])]
    param
    (
        [parameter(Mandatory = $true)][string]$armDeploymentTemplateFile,
        [parameter(Mandatory = $true)][string]$armDeploymentTemplateFile1,
        [parameter(Mandatory = $true)][string]$resourceGroupName,
        [parameter(Mandatory = $true)][string]$namespaceName,
        [parameter(Mandatory = $true)][string]$eventHubName,
        [parameter(Mandatory = $true)][string]$location,
		[parameter(Mandatory = $true)][int]$retentionInDays,
        [parameter(Mandatory = $true)][int]$partitionCount,
		[parameter(Mandatory = $true)][string]$CaptureEnable,
        [parameter(Mandatory = $false)][int]$captureTimeInSeconds,
        [parameter(Mandatory = $false)][string]$encoding,
        [parameter(Mandatory = $false)][int]$captureSize,
        [parameter(Mandatory = $false)][string]$StorageAccountName,
        [parameter(Mandatory = $false)][string]$blobContainerName,
        [parameter(Mandatory = $false)][string]$StorageAccountResourceGroup
    )

    #Check resource group exist
    try {
        $resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction Stop   
    }
    catch {
        $resourceGroup = $null
    }
    if ($null -eq $resourceGroup)
    {
        $message = "Resource group $resourceGroupName not found, deployment stop"
        Write-Verbose $message
        return $message
    }
    else 
    {
        # Prepare deployment variables
		Write-Verbose "Deployment Started on rg $($armDeployment.ResourceGroupName)"
        $deploymentParameters =  @{}
        $deploymentParameters.Add('namespaceName',$namespaceName)
        $deploymentParameters.Add('eventHubName',$eventHubName)
        $deploymentParameters.Add('location',$location)
        $deploymentParameters.Add('retentionInDays',$retentionInDays)
        $deploymentParameters.Add('partitionCount',$partitionCount)
        $deploymentParameters.Add('CaptureEnable',$CaptureEnable)
        if($CaptureEnable -eq 'true')
        { 
            $deploymentParameters.Add('captureTimeInSeconds',$captureTimeInSeconds) 
            $deploymentParameters.Add('encoding',$encoding) 
            $deploymentParameters.Add('captureSize',$captureSize) 
            $deploymentParameters.Add('StorageAccountName',$StorageAccountName) 
            $deploymentParameters.Add('blobContainerName',$blobContainerName) 
            $deploymentParameters.Add('StorageAccountResourceGroup',$StorageAccountResourceGroup)

            #EventHub Template
            $Var = $armDeploymentTemplateFile
        }
        else
        {
            $Var = $armDeploymentTemplateFile1
        }
                
        # Unlock ResourceGroup
		Unlock-ResourceGroup $resourceGroupName
        write-verbose "ResourceGroup Unlocked"
        
        #Deploy the infrastructure
        Write-Verbose "VPN Template: $Var"    
       $armDeployment = New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $Var).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('yyyyMMdd-HHmm')) `
                                            -ResourceGroupName $resourceGroupName `
                                            -TemplateFile $Var `
                                            -TemplateParameterObject $deploymentParameters `
                                            -Force -Verbose
        Lock-ResourceGroup $resourceGroupName
        Write-Verbose "ResourceGroup Locked"
        Write-Verbose "Deployment on rg $($armDeployment.ResourceGroupName) $($armDeployment.ProvisioningState) $($armDeployment.Timestamp)"
        return $armDeployment.ProvisioningState	
		
    }
}

function Publish-Infrastructure
{
param(
        [parameter(Mandatory = $true)][string]$settingsFileName,
        [parameter(Mandatory = $true)][string]$armDeploymentTemplateFile,
        [parameter(Mandatory = $true)][string]$armDeploymentTemplateFile1
  
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
			
                $applicationFile = "..\SettingsByWorkload\" + "nv_" + $applicationName + ".workload.json"
                $applicationFile = Get-FileFullPath -fileName $applicationFile  -rootPath $PSScriptRoot
                $applicationFileJson = Get-JsonParameterSet -settingsFileName $applicationFile
                $null = Test-ParameterSet -settings $settings
               #$organizationName = $applicationFileJson.organizationName
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
                            foreach ($param in $settings.WorkLoads)
                            {
                                $resourceGroupName = $param.resourceGroupName
                                $namespaceName = $param.namespaceName
                                $eventHubName = $param.eventHubName
								$location = $param.location
                                $retentionInDays = $param.retentionInDays 
                                $partitionCount = $param.partitionCount
                                $CaptureEnable = $param.CaptureEnable
                                if($CaptureEnable -eq 'true')
                                {
                                    $captureTimeInSeconds = $param.captureTimeInSeconds
                                    $encoding = $param.encoding
                                    $captureSize = $param.captureSize
                                    $StorageAccountName = $param.StorageAccountName
                                    $blobContainerName = $param.blobContainerName
                                    $StorageAccountResourceGroup = $param.StorageAccountResourceGroup
                                }
                                else
                                {
                                    $captureTimeInSeconds = $null
                                    $encoding = $null
                                    $captureSize = $null
                                    $StorageAccountName = $null
                                    $blobContainerName = $null
                                    $StorageAccountResourceGroup = $null
                                }
                                Write-Verbose ""
                                Write-Verbose "Ready to start deployment on environment $EnvironmentName of a VirtualNetwork in subscription $subscriptionId for resource group: $resourceGroupName, virtualNetworkName $virtualNetworkName, location $location"
                                

                                $result = Publish-EventHubs `
                                -armDeploymentTemplateFile $armDeploymentTemplateFile `
                                -armDeploymentTemplateFile1 $armDeploymentTemplateFile1 `
                                -resourceGroupName $resourceGroupName `
                                -namespaceName $namespaceName `
                                -eventHubName $eventHubName `
                                -location $location `
								-retentionInDays $retentionInDays `
                                -partitionCount $partitionCount `
                                -CaptureEnable $CaptureEnable `
                                -captureTimeInSeconds $captureTimeInSeconds `
                                -encoding $encoding `
                                -captureSize $captureSize `
                                -StorageAccountName $StorageAccountName `
                                -blobContainerName $blobContainerName `
                                -StorageAccountResourceGroup $StorageAccountResourceGroup  
                                if ($result -ne 'Succeeded') {$deploymentIsSucceeded = $false}

                            }
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

#END OF FUNCTIONS, START OF SCRIPT
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

    # Get required templates and setting files. Throw if not found
    $scriptsPath = $PSScriptRoot
	for ($i=1; $i -lt 2 ; $i++) 
    {
        $scriptsPath = Split-Path -Path $scriptsPath -Parent
    }
    $SettingsPath = Join-Path $scriptsPath $settingsFileName
    $settingsFileName = $SettingsPath
    $ARMTemplatePath = Join-Path $scriptsPath $armDeploymentTemplateFile
    $armDeploymentTemplateFile = $ARMTemplatePath
    $ARMTemplatePath1 = Join-Path $scriptsPath $armDeploymentTemplateFile1
    $armDeploymentTemplateFile1 = $ARMTemplatePath1
	
    # Deploy infrastructure
    return Publish-Infrastructure `
        -settingsFileName $settingsFileName `
        -armDeploymentTemplateFile $armDeploymentTemplateFile `
        -armDeploymentTemplateFile1 $armDeploymentTemplateFile1 
}
# END of script
