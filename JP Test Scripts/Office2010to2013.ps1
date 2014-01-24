#region Include
Import-Module \\FSO\Core\Scripts\include\Get_Functions.psm1

#endregion Include

#region Variables
$Clients = Get-AllClients | Select-Object Name -First 20
$64BitMachines = @()
$32BitMachines = @()
# TODO Jason remember to put Admin File Name into Adminfile path
#$32BitOfficeInstallPath = \\FSO\Core\ManagedSoftware\Office2013\x86\setup.exe /Adminfile \\FSO\Core\ManagedSoftware\Office2013\x86\
# TODO Jason remember to put Admin File Name into Adminfile path
#$64BitOfficeInstallPath = \\FSO\Core\ManagedSoftware\Office2013\x64\setup.exe /Adminfile \\FSO\Core\ManagedSoftware\Office2013\x64\ 
# TODO Jason remember to put uninstall path in
#$64BitOfficeUninstallPath = 
# TODO Jason remember to put uninstall path in
#$32BitOfficeUninstallPath = 
# TODO Jason remember to put uninstall path in
#$64BitVisioUninstallPath = 
# TODO Jason remember to put uninstall path in
#$32BitVisioUninstallPath = 
# TODO Jason remember to put uninstall path in
#$64BitProjectUninstallPath = 
# TODO Jason remember to put uninstall path in
#$32BitProjectUninstallPath = 
#endregion Variables


#region Functions
function Get-Architecture 
{
    [CmdletBinding()] 
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)]
        [Alias('Names')]
        [string]$Name
         )
    process{
            if (Test-Connection $Name -Quiet -Count 2)
                {
                try {$wmi = Get-WmiObject Win32_OperatingSystem -ComputerName $Name -ErrorAction SilentlyContinue
                     if ($wmi) { 
                    New-Object PSObject -Property @{
                    Name = $Name
                    OSArchitecture = $wmi.OSArchitecture
                                                     }
                                                                                                       
                                }
                    }                             
                catch{
                     }
               
                }
            }    
}               



#endregion Functions

#region Main
$Allarch = $Clients | Get-Architecture 
$Allarch | Foreach ($_.OSArchitecture){                
        if ( $_.OSArchitecture -notlike "32-bit"){ $64BitMachines += New-Object PSObject -Property @{
                                                    Name = $_.Name
                                                    OSArchitecture = $_.OSArchitecture
                                                                                                    }
                                                 }
        if ($_.OSArchitecture -notlike "64-bit"){ $32BitMachines += New-Object PSObject -Property @{
                                                    Name = $_.Name
                                                    OSArchitecture = $_.OSArchitecture                                               
                                                                                                   }
                                                 }

                                       } 

                               
               

#endregion Main