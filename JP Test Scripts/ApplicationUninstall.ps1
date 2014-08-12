$Computers = Get-Content C:\Temp\Test.txt
$Computers | ForEach-Object {$app = Get-WmiObject -Class Win32_Product -ComputerName $_ | Where-Object {$_.IdentifyingNumber -match "26A24AE4-039D-4CA4-87B4-2F86417045FF"}
$app.Uninstall()}