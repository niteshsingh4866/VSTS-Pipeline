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

    [string] $settingsFileName = '\Settings\ASEv1InputSettings.json',
    [string] $armDeploymentTemplateFile1 = '\Templates\ASEv1InternalArmTemplate.json',
    [string] $armDeploymentTemplateFile2 = '\Templates\ASEv1ExternalArmTemplate.json',
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
            if ($null -eq $vault.name) {throw "Missing name in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.ASEType) {throw "Missing ASEType in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.location) {throw "Missing location in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.vnetName) {throw "Missing vnetName in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.vnetResourceGroupeName) {throw "Missing vnetResourceGroupeName in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.subnetName) {throw "Missing subnetName in settings file for $($subscription.subscriptionId)"}
            if ($vault.ASEType -eq 'Internal')
            {
                if ($null -eq $vault.dnsSuffix) {throw "Missing dnsSuffix in settings file for $($subscription.subscriptionId)"}
            }

        } # ASEv1
    } # Subscription
    return $true
} # Function

#Deploy ASEv1
function Publish-ASEv1
{
    [OutputType([String])]
    param
    (
        [parameter(Mandatory = $true)][string]$armDeploymentTemplateFile1,
        [parameter(Mandatory = $true)][string]$armDeploymentTemplateFile2,
        [parameter(Mandatory = $true)][string]$resourceGroupName,
        [parameter(Mandatory = $true)][string]$name,
        [parameter(Mandatory = $true)][string]$ASEType,
        [parameter(Mandatory = $true)][string]$location,
		[parameter(Mandatory = $true)][string]$vnetName,
        [parameter(Mandatory = $true)][string]$vnetResourceGroupeName,
		[parameter(Mandatory = $true)][string]$subnetName,
		[parameter(Mandatory = $false)][string]$dnsSuffix
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
        $deploymentParameters.Add('name',$name)
        $deploymentParameters.Add('location',$location)
		$deploymentParameters.Add('vnetName',$vnetName)
        $deploymentParameters.Add('vnetResourceGroupeName',$vnetResourceGroupeName)
        $deploymentParameters.Add('subnetName',$subnetName)
        if($ASEType -eq 'Internal')
        {
            $deploymentParameters.Add('dnsSuffix',$dnsSuffix) 
            #VPN Template
            $Var = $armDeploymentTemplateFile1
        }
        else
        {
            #VPN Template
            $Var = $armDeploymentTemplateFile2
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
        [parameter(Mandatory = $true)][string]$armDeploymentTemplateFile1,
        [parameter(Mandatory = $true)][string]$armDeploymentTemplateFile2
  
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
                                $name = $param.name
                                $location = $param.location
								$ASEType = $param.ASEType
                                $vnetName = $param.vnetName 
                                $vnetResourceGroupeName = $param.vnetResourceGroupeName
                                $subnetName = $param.subnetName
                                if($ASEType -eq 'Internal')
                                {
                                    $dnsSuffix = $param.dnsSuffix
                                }
                                else
                                {
                                    $dnsSuffix = $null
                                }
                                Write-Verbose ""
                                Write-Verbose "Ready to start deployment on environment $EnvironmentName of a VirtualNetwork in subscription $subscriptionId for resource group: $resourceGroupName, virtualNetworkName $virtualNetworkName, location $location"
                                

                                $result = Publish-ASEv1 `
                                -armDeploymentTemplateFile1 $armDeploymentTemplateFile1 `
                                -armDeploymentTemplateFile2 $armDeploymentTemplateFile2 `
                                -resourceGroupName $resourceGroupName `
                                -name $name `
                                -location $location `
								-ASEType $ASEType `
                                -vnetName $vnetName `
                                -vnetResourceGroupeName $vnetResourceGroupeName `
                                -subnetName $subnetName `
                                -dnsSuffix $dnsSuffix 
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
    $ARMTemplatePath1 = Join-Path $scriptsPath $armDeploymentTemplateFile1
    $armDeploymentTemplateFile1 = $ARMTemplatePath1
    $ARMTemplatePath2 = Join-Path $scriptsPath $armDeploymentTemplateFile2
    $armDeploymentTemplateFile2 = $ARMTemplatePath2
	
    # Deploy infrastructure
    return Publish-Infrastructure `
        -settingsFileName $settingsFileName `
        -armDeploymentTemplateFile1 $armDeploymentTemplateFile1 `
        -armDeploymentTemplateFile2 $armDeploymentTemplateFile2 
}
# END of script
