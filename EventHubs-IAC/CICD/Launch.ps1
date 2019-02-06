param(
    [parameter(Mandatory=$true)]
    [ValidateSet('Build','Deploy')]
    [string]
    $CICDphase,

    [string]
    $targetDeploymentRing = 'dfi'
)
#hastable for sake parameters
$settings = @{
    targetDeploymentRing = $targetDeploymentRing
}

$Error.Clear()
switch ($CICDphase) 
{
    'Build' {Invoke-PSake -buildFile $PSScriptRoot\$CICDphase\$CICDphase.ps1}
    'Deploy' {Invoke-PSake -buildFile $PSScriptRoot\$CICDphase\$CICDphase.ps1 -parameters $settings }
}

if (!$psake.build_success) {Throw 'psake failed'}