#region Include
Import-Module \\fso\core\scripts\include\get_functions.psm1

#endregion Include
#region variables
$BiosData = @()
$Warrantyinfo = @()
$cMyData = @()
#endregion variables
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

function Get-WebsiteData {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)]
    [Alias('ServiceTag')]
    [string]$sSerial
    )
    process {
            foreach ($i in 0..($cMatches.count -1)) {
        $cRecord = New-Object -TypeName system.Object
            [void] $foreach.MoveNext()
        $cRecord | Add-Member -MemberType noteProperty -Name 'Provider' $cMatches[$foreach.current]
            [void] $foreach.MoveNext()
        $cRecord | Add-Member -MemberType noteProperty -Name 'Start Date' $cMatches[$foreach.current]
            [void] $foreach.MoveNext()
        $cRecord | Add-Member -MemberType noteProperty -Name 'End Date' $cMatches[$foreach.current]
            [void] $foreach.MoveNext()
    if ($cMatches[$foreach.current] -ne "") {
        $cRecord | Add-Member -MemberType noteProperty -Name 'Days Left' $cMatches[$foreach.current]
                                            } 
    else {
        $cRecord | Add-Member -MemberType noteProperty -Name 'Days Left' "0"
         }  
        $cMyData += $cRecord
                                            }
            
            }
                          }

#endregion functions

#region main
$BiosData = Get-AllClients | Select-Object -First 10 | Get-BiosInfo
$sSerial = $BiosData.ServiceTag
$Warrantyinfo = $sSerial | Get-WebsiteData 

#endregion main