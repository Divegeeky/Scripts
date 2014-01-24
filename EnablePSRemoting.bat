@echo off
echo.
echo Enable PS Remoting on a remote computer
echo Uses psexec to enable PSRemoting through powershell
echo Disables Windows Firewall if computer is on VPN
echo -------------------------------------------------------------------------------
cd c:\pstools
:start
Set /P Computer=Computer Name: 
Set /P VPN=On VPN? (Y/N, defaults to N) 
if /i {%VPN%}=={y} (psexec \\%computer% -u renamed_admin -p sst1701Asst1701A -h powershell.exe "net stop mpssvc")
psexec \\%computer% -u renamed_admin -p sst1701Asst1701A -h -d powershell.exe "enable-psremoting -force"
echo.
echo Press a key to enable on another computer.  Close this window when finished.
pause>nul
echo -------------------------------------------------------------------------------
echo.
set VPN=n
goto :start