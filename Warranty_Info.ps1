#region include
import-module \\fso\Core\Scripts\include\Get_Functions.psm1
ipmo \\fso\core\Scripts\include\Alert_Functions.psm1
ipmo \\fso\core\Scripts\include\Utility_Functions.psm1

#endregion include

#region variables
$clients = Get-AllClients | Where {$_.Name -like "FSO*" -and $_.Name -notlike "SVR*"} | Select Name | Sort
$errors = @()
#endregion variable

#region functions

function Get-Model_Data{
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)]
    [Alias('Names')]
    [string]$Name
    )

    process{
        if (Test-Connection $Name -Quiet -Count 2){
            try {
                $bios = Get-WmiObject -ComputerName $Name -Class Win32_Bios -ErrorAction SilentlyContinue
                $comp = Get-WmiObject -ComputerName $Name -Class Win32_ComputerSystem -ErrorAction SilentlyContinue
                }
            catch{                
                if ($bios.SerialNumber -eq $null){
                    try{
                        $bios.SerialNumber = Get-WmiObject -ComputerName $Name -Class Win32_Baseboard -ErrorAction SilentlyContinue
                        }
                    catch{}
                    }
                }
            }
        if ($bios -and $comp){
            New-Object -TypeName psobject -Property @{
                Name = $Name
                BIOSVersion = [string]$bios.BiosVersion
                SerialNumber = $bios.SerialNumber
                Manufacturer = $bios.Manufacturer
                Model = $comp.Model
                RAMinGB = [math]::round(($comp.TotalPhysicalMemory)/(1GB), 2)
                }
            }
        }
    }
#endregion functions

#region main

#endregion main