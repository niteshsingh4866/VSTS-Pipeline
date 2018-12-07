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

    [string] $settingsFileName = '\Settings\NetworkSettings.json',
    [string] $armDeploymentTemplateFile = '\Templates\express-vngw.json',
    [string] $armDeploymentTemplateFile1 = '\Templates\vpn-vngw.json',
    [string] $armDeploymentTemplateFile2 = '\Templates\vpn-vngw1.json',
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
            if ($null -eq $vault.virtualNetworkName) {throw "Missing virtualNetworkName in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.location) {throw "Missing location in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.gatewayPublicIPName) {throw "Missing gatewayPublicIPName in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.gatewayName) {throw "Missing gatewayName in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.gatewayIPconfName) {throw "Missing gatewayIPconfName in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.gatewayType) {throw "Missing gatewayType in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.sku) {throw "Missing sku in settings file for $($subscription.subscriptionId)"}
            if ($null -eq $vault.vpnType) {throw "Missing vpnType in settings file for $($subscription.subscriptionId)"}

        } # Virtual Network
    } # Subscription
    return $true
} # Function

#Deploy network
function Publish-Network
{
    [OutputType([String])]
    param
    (
        [parameter(Mandatory = $true)][string]$armDeploymentTemplateFile,
        [parameter(Mandatory = $true)][string]$armDeploymentTemplateFile1,
        [parameter(Mandatory = $true)][string]$armDeploymentTemplateFile2,
        [parameter(Mandatory = $true)][string]$resourceGroupName,
        [parameter(Mandatory = $true)][string]$virtualNetworkName,
        [parameter(Mandatory = $true)][string]$environmentName,
        [parameter(Mandatory = $true)][string]$location,
		[parameter(Mandatory = $true)][string]$gatewayPublicIPName,
		[parameter(Mandatory = $true)][string]$gatewayName,
		[parameter(Mandatory = $true)][string]$gatewayIPconfName,
		[parameter(Mandatory = $true)][string]$gatewayType,
		[parameter(Mandatory = $true)][string]$sku,
        [parameter(Mandatory = $true)][string]$vpnType,
        [parameter(Mandatory = $false)][string]$activeActive,
        [parameter(Mandatory = $false)][string]$activeActiveGatewayPublicIpName
        
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
        $deploymentParameters.Add('virtualNetworkName',$virtualNetworkName)
        $deploymentParameters.Add('environment',$environmentName)
        $deploymentParameters.Add('location',$location)
		$deploymentParameters.Add('gatewayPublicIPName',$gatewayPublicIPName)
        $deploymentParameters.Add('gatewayName',$gatewayName)
        $deploymentParameters.Add('gatewayIPconfName',$gatewayIPconfName)
        $deploymentParameters.Add('gatewayType',$gatewayType)
        $deploymentParameters.Add('sku',$sku)
        $deploymentParameters.Add('vpnType',$vpnType)
        if($activeActive -eq 'true')
        {
            $deploymentParameters.Add('activeActive',$activeActive)
            $deploymentParameters.Add('activeActiveGatewayPublicIpName',$activeActiveGatewayPublicIpName)   
            $Var1 = $armDeploymentTemplateFile2
        }
        else
        {
            #VPN Template
            $Var1 = $armDeploymentTemplateFile1
        }
        
                
        # Unlock ResourceGroup
		Unlock-ResourceGroup $resourceGroupName
        write-verbose "ResourceGroup Unlocked"
        #Deploy the infrastructure
        
        if($gatewayType -eq "Expressroute")
        {
            #ExpressRoute Template
            $Var1 = $armDeploymentTemplateFile
            Write-Verbose "ExpressRoute Template: $Var1"
            $deploymentParameters =  @{}
            $deploymentParameters.Add('virtualNetworkName',$virtualNetworkName)
            $deploymentParameters.Add('environment',$environmentName)
            $deploymentParameters.Add('location',$location)
            $deploymentParameters.Add('gatewayPublicIPName',$gatewayPublicIPName)
            $deploymentParameters.Add('gatewayName',$gatewayName)
            $deploymentParameters.Add('gatewayIPconfName',$gatewayIPconfName)
            $deploymentParameters.Add('gatewayType',$gatewayType)
            $deploymentParameters.Add('sku',$sku)             
        }  

        Write-Verbose "VPN Template: $Var1"    
       $armDeployment = New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $Var1).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('yyyyMMdd-HHmm')) `
                                            -ResourceGroupName $resourceGroupName `
                                            -TemplateFile $Var1 `
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
                            foreach ($virtualNetwork in $settings.WorkLoads)
                            {
                                $resourceGroupName = $virtualNetwork.resourceGroupName
                                $virtualNetworkName = $virtualNetwork.virtualNetworkName
                                $location = $virtualNetwork.location
								$gatewayPublicIPName = $virtualNetwork.gatewayPublicIPName
                                $gatewayName = $virtualNetwork.gatewayName 
                                $gatewayIPconfName = $virtualNetwork.gatewayIPconfName
                                $gatewayType = $virtualNetwork.gatewayType
                                $sku = $virtualNetwork.sku
                                $vpnType = $virtualNetwork.vpnType
                                $activeActive = $virtualNetwork.activeActive
                                if($activeActive -eq 'true')
                                {
                                    $activeActiveGatewayPublicIpName = $virtualNetwork.activeActiveGatewayPublicIpName
                                }
                                else
                                {
                                    $activeActiveGatewayPublicIpName = $null
                                }
                                Write-Verbose ""
                                Write-Verbose "Ready to start deployment on environment $EnvironmentName of a VirtualNetwork in subscription $subscriptionId for resource group: $resourceGroupName, virtualNetworkName $virtualNetworkName, location $location"
                                

                                $result = Publish-Network `
                                -armDeploymentTemplateFile $armDeploymentTemplateFile `
                                -armDeploymentTemplateFile1 $armDeploymentTemplateFile1 `
                                -armDeploymentTemplateFile2 $armDeploymentTemplateFile2 `
                                -resourceGroupName $resourceGroupName `
                                -virtualNetworkName $virtualNetworkName `
                                -environmentName $EnvironmentName `
                                -location $location `
								-gatewayPublicIPName $gatewayPublicIPName `
                                -gatewayName $gatewayName `
                                -gatewayIPconfName $gatewayIPconfName `
                                -gatewayType $gatewayType `
                                -sku $sku `
                                -vpnType $vpnType `
                                -activeActive $activeActive `
                                -activeActiveGatewayPublicIpName $activeActiveGatewayPublicIpName
								
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
	for ($i=1; $i -lt 2 ; $i++) {$scriptsPath = Split-Path -Path $scriptsPath -Parent}
    $SettingsPath = Join-Path $scriptsPath $settingsFileName
    $settingsFileName = $SettingsPath
    $ARMTemplatePath = Join-Path $scriptsPath $armDeploymentTemplateFile
    $armDeploymentTemplateFile = $ARMTemplatePath
    $ARMTemplatePath1 = Join-Path $scriptsPath $armDeploymentTemplateFile1
    $armDeploymentTemplateFile1 = $ARMTemplatePath1
    $ARMTemplatePath2 = Join-Path $scriptsPath $armDeploymentTemplateFile2
    $armDeploymentTemplateFile2 = $ARMTemplatePath2
	#$SettingsByWorkload = Get-FileFullPath -fileName $SettingsByWorkload -rootPath $PSScriptRoot

    # Deploy infrastructure
    return Publish-Infrastructure `
        -settingsFileName $settingsFileName `
        -armDeploymentTemplateFile $armDeploymentTemplateFile `
        -armDeploymentTemplateFile1 $armDeploymentTemplateFile1 `
        -armDeploymentTemplateFile2 $armDeploymentTemplateFile2 
 #       -targetEnvironment $targetDeploymentRing `
 #      -SettingsByWorkloadParam $SettingsByWorkload
}
# END of script
