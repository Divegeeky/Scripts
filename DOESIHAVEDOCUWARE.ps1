$clients = Get-Content C:\users\Jpototsk\Downloads\docuwarenames.csv
$IHAVEDOCUWARE=@()
$IDONTHAVEDOCUWARE=@()
$IWASNOTONLINE=@()

$clients.ForEach({
    if(test-connection -ComputerName $_ -Quiet -count 1){
        if(get-service -ComputerName $_ -Name DWDesktopService -ErrorAction SilentlyContinue){
            $IHAVEDOCUWARE += New-Object PSObject -Property @{
                ComputerName = $_               
            }
        }
        else{
            $IDONTHAVEDOCUWARE += New-Object PSObject -Property @{
                ComputerName = $_               
            }
        }
        
    }
    Else{
        $IWASNOTONLINE += New-Object PSObject -Property @{
                ComputerName = $_               
        }
    }
})
