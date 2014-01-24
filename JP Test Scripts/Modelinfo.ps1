#region include
Import-module C:\Users\Jpototsk\scripts\include\Get_Functions.psm1
#endregion include

#region variables
$CompData = @()
$Computers = Get-Content C:\temp\ModelComputers.txt
#endregion variable

#region functions
function Get-ModelInfo {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)]
    [Alias('Names')]
    [string]$Name
    )

    process{
        if (Test-Connection $Name -Quiet -Count 2){
            try {
                $ComputerInfo = Get-WmiObject -ComputerName $Name Win32_ComputerSystem -ErrorAction SilentlyContinue
            }
            catch{
            }
            if ($Computerinfo){
                New-Object PSObject -Property @{
                    Name = $Name
                    #Model = $Computerinfo.Model
                    User = $Computerinfo.UserName
                }
            }
        }
    }
}
            

#endregion functions

#region main
$CompData = $Computers | Get-ModelInfo
$CompData | Select-Object Name, User | Export-Csv C:\temp\Computerinfo.CSV
#endregion main