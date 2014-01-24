Import-module \\FSO\CORE\SCripts\include\Get_Functions.psm1
$computers = Get-AllClients | Select Name

function Stop-ISW {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)]
    [Alias('Names')]
    [string]$Name
    )

    process{
        if (Test-Connection $Name -Quiet -Count 2){
            Invoke-Command -ComputerName $Name -ScriptBlock { Set-Service UI0Detect -status stopped -StartMode Disabled
               
                                                             }                
                               
                                                    }
               }
}

$Computers | Stop-ISW