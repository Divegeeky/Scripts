#region include
Import-Module \\FSO\Core\Scripts\Include\Get_Functions.psm1
Import-Module \\FSO\Core\Scripts\include\Utility_Functions.psm1
#endregion include

#region variables
$Computers = Get-AllClients | Select Name
$Trubardor = @()
$Falsado = @()
#endregion variable

#region functions
function Get-JAVACPL {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)]
    [Alias('Names')]
    [string]$Name
    )

    process{
        if (Test-Connection $Name -Quiet -Count 2){
            try {$User = Invoke-Command -ComputerName $Name -ScriptBlock {$User = Get-WmiObject Win32_ComputerSystem | Select UserName 
                                                                         Return $User }
                 if($User.UserName){ Write-Host $User.UserName "Is Logged onto this System"}
                 else { Invoke-Command -ComputerName $Name -ScriptBlock {GPupdate /force /boot}
                       $Jabba = (Invoke-Command -ComputerName $Name -ScriptBlock {Test-Path -Path "C:\Program Files\Java\jre7\bin\javacpl.exe"}) 
                    if($Jabba -eq $False){ Write-Host $Name,"FALSE"
                                           uninstall-software -ComputerName $Name -AppGUID '{26A24AE4-039D-4CA4-87B4-2F86417045FF}'
                                           Invoke-Command -ComputerName $Name -ScriptBlock {Remove-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\AppMgmt\{7748c09b-dea9-4736-a1ed-070cce7ae0d5}'}
                                          }
                    if($Jabba -eq $True) { Write-Host $Name,"True"
                                #Invoke-Command -ComputerName $Name -ScriptBlock {GPupdate /force /boot}  
                                }
        
                       }
                }            
            catch{
                 } 
                 
                               
                                                    }
               }
}

function Get-InstalledSoftware {
[cmdletbinding()]            
param(            
 [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]            
 [string[]]$ComputerName = $env:computername            

)            

begin {            
 $UninstallRegKey="SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"             
}            

process {            
 foreach($Computer in $ComputerName) {            
  Write-Verbose "Working on $Computer"            
  if(Test-Connection -ComputerName $Computer -Count 1 -ea 0) {            
   $HKLM   = [microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',$computer)            
   $UninstallRef  = $HKLM.OpenSubKey($UninstallRegKey)            
   $Applications = $UninstallRef.GetSubKeyNames()            

   foreach ($App in $Applications) {            
    $AppRegistryKey  = $UninstallRegKey + "\\" + $App            
    $AppDetails   = $HKLM.OpenSubKey($AppRegistryKey)            
    $AppGUID   = $App            
    $AppDisplayName  = $($AppDetails.GetValue("DisplayName"))            
    $AppVersion   = $($AppDetails.GetValue("DisplayVersion"))            
    $AppPublisher  = $($AppDetails.GetValue("Publisher"))            
    $AppInstalledDate = $($AppDetails.GetValue("InstallDate"))            
    $AppUninstall  = $($AppDetails.GetValue("UninstallString"))            
    if(!$AppDisplayName) { continue }            
    $OutputObj = New-Object -TypeName PSobject             
    $OutputObj | Add-Member -MemberType NoteProperty -Name ComputerName -Value $Computer.ToUpper()            
    $OutputObj | Add-Member -MemberType NoteProperty -Name AppName -Value $AppDisplayName            
    $OutputObj | Add-Member -MemberType NoteProperty -Name AppVersion -Value $AppVersion            
    $OutputObj | Add-Member -MemberType NoteProperty -Name AppVendor -Value $AppPublisher            
    $OutputObj | Add-Member -MemberType NoteProperty -Name InstalledDate -Value $AppInstalledDate            
    $OutputObj | Add-Member -MemberType NoteProperty -Name UninstallKey -Value $AppUninstall            
    $OutputObj | Add-Member -MemberType NoteProperty -Name AppGUID -Value $AppGUID            
    $OutputObj# | Select ComputerName, DriveName            
   }            
  }            
 }            
}            
}
function uninstall-software {
[cmdletbinding()]            

param (            

 [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
 [string]$ComputerName = $env:computername,
 [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
 [string]$AppGUID
)            

 try {
  $returnval = ([WMICLASS]"\\$computerName\ROOT\CIMV2:win32_process").Create("msiexec `/x$AppGUID `/norestart `/qn")
 } catch {
  write-error "Failed to trigger the uninstallation. Review the error message"
  $_
  exit
 }
 switch ($($returnval.returnvalue)){
  0 { "Uninstallation command triggered successfully" }
  2 { "You don't have sufficient permissions to trigger the command on $Computer" }
  3 { "You don't have sufficient permissions to trigger the command on $Computer" }
  8 { "An unknown error has occurred" }
  9 { "Path Not Found" }
  9 { "Invalid Parameter"}
 }
}



#endregion functions

#region main
#$Computers | Get-JAVACPL
$Software = $Computers | Foreach-Object {Get-InstalledSoftware -ComputerName $Name}
#endregion main