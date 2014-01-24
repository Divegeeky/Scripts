################################################################################
# PowerShell routine to Install SEP12 
################################################################################

$computerNames = Get-ADComputer -Filter 'Name -like "INPGRCA*"' | Select-Object Name

# 32 Bit Source
$source32 = "C:\tools\SEP12ru1mp1x86_setup.exe"

# 64 Bit Source
$source64 = "C:\tools\SEP12ru1mp1x64_setup.exe"

$destination = "SEP12installer.exe"

foreach ($computer in $computerNames) {
    if ((test-connection -ComputerName $computer -BufferSize 16 -Count 1 -ErrorAction 0 -Quiet) -eq "False") {
        Write-Host "$computer not responding"
        continue
    }
    elseif (Test-Path "\\$computer\c$\$destination") {
        Write-Host "File Exists on $computer"
    }
    elseif ( (Get-WmiObject -ComputerName $computer Win32_OperatingSystem).OSArchitecture -eq "64-bit" ) { 
        
        Write-Host "Copying 64bit Installer to $computer"
        copy $source64 "\\$computer\c$\$destination"
    }
    else {
        Write-Host "Copying 32bit Installer to $computer"
        copy $source32 "\\$computer\c$\$destination"   
    }

    Write-Host "Installing on $computer"
    Invoke-Command -ComputerName $computer -ScriptBlock {& cmd.exe /c c:\SEP12installer.exe }
}

#Invoke-Command -computername (get-content $computerNames) -ScriptBlock {& cmd.exe /c c:\SEP12installer.exe }


Write-Host "Done."