$Data = Get-Content 
$symbol = gwmi Win32_USBControllerDevice |%{[wmi]($_.Dependent)} | Where -Property Name -Match "Symbol USB Sync"
