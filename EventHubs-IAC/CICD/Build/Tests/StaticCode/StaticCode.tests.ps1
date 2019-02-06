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
Describe 'StaticCode ' {
    $scriptsPath = $PSScriptRoot
    for ($i=1; $i -le 4 ; $i++) {$scriptsPath = Split-Path -Path $scriptsPath -Parent}
    $scriptsPath = "$scriptsPath\Scripts\*.ps1"

    Context 'Is valid PowerShell Code ' {
        $scripts = Get-ChildItem -Path $scriptsPath
        foreach ($script in $scripts)
        {
            It "$($script.name)" {
                $psFile = Get-Content -Path $script.FullName -ErrorAction Stop
                $errors = $null
                $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
                $errors.Count | Should be 0
            }
        }
    }

    Context 'Script Analyzer Standard Rules' {
        $result = Invoke-ScriptAnalyzer -Path $scriptsPath
        $scriptAnalyzerRules = Get-ScriptAnalyzerRule
        foreach ($rule in $scriptAnalyzerRules)
        {
            It "Should pass $rule" {
                If ($result.RuleName -contains $rule)
                {
                    $result | Where-Object RuleName -EQ $rule -OutVariable failures | Out-Default
                    $failures.Count | Should Be 0
                }
            }
        }
    }
}