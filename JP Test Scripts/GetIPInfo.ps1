#region include
Import-module C:\Users\Jpototsk\scripts\include\Get_Functions.psm1
#endregion include

#region variables
$IPData = @()
$ADData = @()
$Computers = Get-Content C:\temp\ADComputers.txt

#endregion variable

#region functions
function Get-IPInfo {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)]
    [Alias('Names')]
    [string]$Name
    )

    process{
           try {
                $IPInfo = Get-WmiObject -ComputerName $Name Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | Where { $_.IPAddress } |  Select -Expand IPAddress
                }
           catch{
            }
            if ($IPInfo){
                New-Object PSObject -Property @{
                    Name = $Name
                    IPAddress = $IPINFO
                         }
            }
        }
    }
 function Get-ADDescription {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)]
    [Alias('Names')]
    [string]$Name
    )

    process{ $ADInfo = Get-ADComputer $Name -Properties Description | Select Name, Description
                If ($ADInfo){  
                    New-Object PSObject -Property @{
                    Name = $ADInfo.Name
                    ADDescription = $ADInfo.Description
                    
                                                    }
                            }
            }       
}
#endregion functions

#region main
#$IPData = $Computers | Get-IPInfo
$ADData = $Computers | Get-ADDescription
#$IPData | Select-Object Name, IPAddress | Export-Csv C:\temp\IP.CSV
$ADData | Select-Object Name, ADDescription | Export-Csv C:\temp\AD.CSV
#endregion main