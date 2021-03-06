﻿#region include
Import-Module \\FSO\CORE\Scripts\include\Get_Functions.psm1


#endregion include

#region variables
$Computers = Get-AllClients | Select Name
$IHAVEJAVA= @()
#endregion variable

#region functions
function Get-JAVA {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)]
    [Alias('Names')]
    [string]$Name
    )

    process{
        if (Test-Connection $Name -Quiet -Count 2){
            try {
                 $Fromunda = (Invoke-Command -ComputerName $Name -ScriptBlock {
                 $Test = Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\AppMgmt\{a2e07cfd-04c4-4abd-8719-6c990572df01}"
                 Return $Test}) }
            catch{
                 } 
         if($Fromunda){ New-Object PSObject -Property @{
                    Name = $Name
                    Fromunda = $Fromunda
                                                        }
                      }
            
        
      
                                                    }
               }
}
function Remove-JAVA {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)]
    [Alias('Names')]
    [string]$Name
    )

    process{
        if (Test-Connection $Name -Quiet -Count 2){
            try {
                 $Gotcha = (Invoke-Command -ComputerName $Name -ScriptBlock {
                 $Test = Remove-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\AppMgmt\{a2e07cfd-04c4-4abd-8719-6c990572df01}'
                 Return $Test}) }
            catch{
                 } 
         if($Gotcha){ New-Object PSObject -Property @{
                    Name = $Name
                    Fromunda = $Gotcha
                                                        }
                      }
            
        
      
                                                    }
               }
}
#endregion functions

#region main
$IHAVEJAVA = $Computers | Get-Java 
$IHAVEJAVA | Select Name | Remove-JAVA

#endregion main