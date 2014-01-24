#region include
Import-Module \\FSO\CORE\Scripts\include\Get_Functions.psm1


#endregion include

#region variables
$Computers = Get-AllClients | Select Name
$IHAVEPENDING= @()
#endregion variable

#region functions
function Get-Pending {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)]
    [Alias('Names')]
    [string]$Name
    )

    process{
        if (Test-Connection $Name -Quiet -Count 2){
            try {
                 $Brudda = (Invoke-Command -ComputerName $Name -ScriptBlock {
                 $Test = Test-Path -Path "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\InProgress"
                 Return $Test}) }
            catch{
                 } 
         if($Brudda){ New-Object PSObject -Property @{
                    Name = $Name
                    Fromunda = $Brudda
                                                        }
                      }
            
        
      
                                                    }
               }
}




#endregion functions

#region main
$IHAVEPENDING = $Computers | Get-Pending



#endregion main