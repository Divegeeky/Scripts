#region include
Import-module C:\Users\Jpototsk\scripts\include\Get_Functions.psm1
#endregion include

#region variables
$Clients = Get-AllClients
$BiosData = @()
$errors = @()
$Credential = Get-Credential
#endregion variable

#region functions
function Get-BiosInfo {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)]
    [Alias('Names')]
    [string]$Name
    )

    process{
        if (Test-Connection $Name -Quiet -Count 2){
            try {
                $BiosInfo = Get-WmiObject -Credential $Credential -ComputerName $Name Win32_VideoController
            }
            catch{
            }
            if ($BiosInfo){
                New-Object PSObject -Property @{
                    Name = $Name
                    SerialNumber = $BiosInfo.PNPDeviceID
                    VideoCardDescripton = $BiosInfo.Description
                }
            }
        }
    }
}
            

#endregion functions

#region main
$BiosData = Get-AllClients | Select -First 5 | Get-BiosInfo
#endregion main