#Import-Module powershellpack
Import-Module \\fso\core\Scripts\CodeSign\codesign.psm1 -DisableNameChecking
Import-Module \\fso\core\Scripts\include\DocuWare_Functions.psm1 -DisableNameChecking
Import-Module \\fso\core\Scripts\include\EDS_functions.psm1 -DisableNameChecking
Import-Module \\fso\core\Scripts\include\Task_Functions.psm1 -DisableNameChecking
Import-Module \\fso\core\Scripts\include\AdminVault_Functions.psm1 -DisableNameChecking
Import-Module \\fso\core\Scripts\include\Utility_Functions.psm1 -DisableNameChecking
Import-Module \\fso\core\Scripts\Monitor\Maintenance_Functions.psm1 -DisableNameChecking
Import-Module \\fso\core\Scripts\Monitor\Monitor_Functions.psm1 -DisableNameChecking

# The following is for using git with powershell:
# . "C:\Users\damayhewd\Documents\WindowsPowerShell\Modules\posh-git\profile.example.ps1"

$myCred = Get-Credential (whoami)

function rdpme {
    param(
    [parameter(Mandatory=$true,Position=0)][string]$Server,
    [parameter(Mandatory=$false)][switch]$Fullscreen
    )
    if($Fullscreen) {rdp $Server -Credential $myCred -Fullscreen}
    else {rdp $Server -Credential $myCred}
}

# if(Test-Path 'C:\Scripts') {
#    cd 'C:\Scripts'
# }