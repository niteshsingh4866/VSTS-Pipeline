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

Param(
    [string] $targetDeploymentRing = 'dfi',
    [string] $deploymentScriptName = 'CreateAndDeploy-Eventhubs.ps1'
)

$scriptsPath = $PSScriptRoot
for ($i=1; $i -le 2 ; $i++) {$scriptsPath = Split-Path -Path $scriptsPath -Parent}
$deploymentScriptName = "$scriptsPath\Scripts\$deploymentScriptName"

Import-Module -Name psake
Import-Module -Name pester

function Invoke-TestFailure
{
    param(
        [parameter(Mandatory=$true)]
        [validateSet('StaticCode','Unit','Integration','Acceptance')]
        [string]$testType,

        [parameter(Mandatory=$true)]
        $pesterResults
    )

    switch ($testType) {
        'StaticCode'    {$errorID = 'StaticCodeTestFailure'}
        'Unit'          {$errorID = 'UnitTestFailure'}
        'Integration'   {$errorID = 'IntegrationTestFailure'}
        'Acceptance'    {$errorID = 'AcceptanceTestFailure'}
    }
    $errorCategory = [System.Management.Automation.ErrorCategory]::LimitsExceeded
    $errorMessage = "$testType Test Failed: $($pesterResults.FailedCount) tests failed out of $($pesterResults.TotalCount) total test."
    $exception = New-Object -TypeName System.SystemException -ArgumentList $errorMessage
    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,$errorID, $errorCategory, $null

    Write-Output "##vso[task.logissue type=error]$errorMessage"
    Throw $errorRecord
}

FormatTaskName "--------------- {0} ---------------"

Properties {
    $TestsPath = "$PSScriptRoot\Tests"
    $TestResultsPath = "$TestsPath\Results"
    $targetDeploymentRing = $targetDeploymentRing
    $deploymentScriptName= $deploymentScriptName
}

Task Default -depends Deploy

Task Deploy -Depends Clean {
    "Starting infrastructure deployment in $targetDeploymentRing environment ..."

    # Exeture the infra as code, config as code script
    $result = Invoke-Expression "$deploymentScriptName -targetDeploymentRing '$targetDeploymentRing' -unitTestMode 0"
    Write-Verbose "Deployment completed $result" -Verbose
}

Task Clean {
    "Starting Cleaning enviroment..."

    write-verbose "Deploy targetDeploymentRing $targetDeploymentRing" -Verbose
    #Remove Test Results from previous runs
    New-Item $TestResultsPath -ItemType Directory -Force
    Remove-Item "$TestResultsPath\*.xml" -Verbose 

    $Error.Clear()
}