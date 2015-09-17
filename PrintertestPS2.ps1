#region import
Import-Module \\fso\core\Scripts\include\Alert_Functions.psm1
Import-Module \\fso\core\Scripts\include\Log_functions.psm1
Import-Module \\fso\core\Scripts\include\Get_Functions.psm1
#endregion import

#region global variables
$start = Get-Date
$errors = @()
$events = @()
$client = Get-WMIObject Win32_ComputerSystem | Select Name
$currentprinter
$currentrenamedprinter
#endregion global variables

#region main
$msg= "Registering a log source"
$events+=$msg
New-PSLogSource

$msg = "Starting work on {0} with the user of {1}" -f $client.Name,$env:USERNAME
$events+=$msg

$printers = get-Wmiobject -Class Win32_printer | Where-Object {$_.SystemName -like '\\SVR0210'}
if($printers){
    $printers| %{
        $msg = "Beginning work on {0} with user {1} and printer {2}"-f $client.Name,$env:USERNAME,$_.Name
        $events+=$msg
        $tempprinter = $_
        $currentprinter= $_
        $class = [wmiclass]"Win32_Printer"
        $tempprintername = $_ | Select -ExpandProperty Name
        $tempprintername = $tempprintername.ToUpper()
        $printername = $tempprintername.replace("\\SVR0210\", "\\SVR0213\")
        $currentrenamedprinter = $printername
        #Remove-Printer -Name $tempprintername
        
        try{
            $tempprinter.PSBase.Delete()
        }
        catch{
            $msg = "There was an error deleting the printer {0} on System {1} and User {2}"-f $currentprinter.Name, $client.Name, $env:USERNAME
            $errors += New-Object PSObject -Property @{
                Error = $msg
                ComputerName = $Client.Name
                User = $env:USERNAME
                Printer = $currentprinter.Name
                Function = $MyInvocation.MyCommand.Name
            }
        }

        #Add-Printer -ConnectionName $printername
        try{
            $class.AddPrinterConnection($printername)
        }
        catch{
            $msg = "There was an error adding the printer {0} on System {1} and User {2}"-f $currentrenamedprinter, $client.Name, $env:USERNAME
            $errors += New-Object PSObject -Property @{
                Error = $msg
                ComputerName = $Client.Name
                User = $env:USERNAME
                Printer = $currentrenamedprinter
                Function = $MyInvocation.MyCommand.Name
            }

        }

    }
}
Else{
    $msg= "There appears to be no printers that are connected to SVR0210 on {0} for the user {1}"-f $client.Name,$env:USERNAME
    $events+=$msg
}
$end = Get-Date
$total = New-TimeSpan $start $end
$msg = "Start: $start`nEnd: $end`nTotal: $total`n`nThe script ran!`n"

if($events) {
    $msg += "`nEvents:`n"
    $script:events | %{
        $msg += "$_`n"
    }
}

if($errors) {
    $msg += "`nThe following errors occured:`n"
    $i = 1
    $errors | %{
        $msg += "`n{0}. Function: {1}`nError: {2}`n" -f $i++, $_.Function, $_.Error
    }

    Log-Error $msg

    $subject = "The {0} script encountered one or more errors" -f $MyInvocation.MyCommand.Name
    $body = "<h3>Printer Migration Errors:</h3>"
    $errors | select Function, Error, ComputerName, User, Printer |
    Send-Alert -Subject $subject -Body $body -To 'Jpototsk@email.arizona.edu'
} else {
    Log-Info $msg
}



#endregion main
