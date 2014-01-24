#region include
Import-Module \\FSO\CORE\Scripts\include\Get_Functions.psm1


#endregion include

#region variables
$Computers = Get-AllClients | Select Name


#endregion variable

#region functions
function Get-User {
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
                    User = $Computerinfo.UserName
                }
            }
        }
    }
}


#endregion functions

#region main
$UserData = $Computers | Get-User
$UserData | ForEach-Object {
if ($_.User) { Write-Host $_.Name 'System Has' $_.User 'Logged in' } else { Restart-Computer -ComputerName $_.Name -Force } }

#endregion main