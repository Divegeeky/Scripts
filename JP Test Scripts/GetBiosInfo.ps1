#region include
Import-module \\FSO\CORE\Scripts\include\Get_Functions.psm1
#endregion include

#region variables
$BiosData = @()
$Computers = Get-AllClients | Select Name
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
                $BiosInfo = Get-WmiObject -ComputerName $Name Win32_Bios -ErrorAction SilentlyContinue
            }
            catch{
            }
            if ($BiosInfo){
                New-Object PSObject -Property @{
                    Name = $Name
                    BiosVersion = $BiosInfo.SMBIOSBIOSVersion
                    ServiceTag = $BiosInfo.SerialNumber
                }
            }
        }
    }
}
            

#endregion functions

#region main
$BiosData = $Computers | Get-BiosInfo
$BiosData | Select-Object Name, BiosVersion, ServiceTag | Export-Csv C:\temp\ServiceTags2.CSV
#endregion main