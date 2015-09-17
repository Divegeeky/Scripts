Import-Module \\fso\core\scripts\include\Get_Functions.psm1

$printers = get-printer | Where-Object ComputerName -like 'SVR0210'
if($printers){
$printers.ForEach({
    $tempprinter = $_
    $tempprintername = $_ | Select -ExpandProperty Name
    $printername = $tempprintername.replace("\\SVR0210\", "\\SVR0213\")
    Remove-Printer -Name $tempprintername
    Add-Printer -ConnectionName $printername
})
}
Else{
Write-Warning -Message "This Machine Appears to have nothing on SVR0210"
}