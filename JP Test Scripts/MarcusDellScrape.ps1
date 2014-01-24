$sSerial = ""

if ($Args[0] -eq $Null) {
    Write-Warning "Please provide a serial number."
    exit
} else {
    $sSerial = $Args[0]
}

$oWeb = New-Object System.Net.WebClient
$sUrl = "http://www.dell.com/support/troubleshooting/us/en/555/Servicetag/$sSerial"
$sData = $oWeb.DownloadString($sUrl)

$sData = $sData | ForEach-Object { $_ -replace "<i>", "" }
$sData = $sData | ForEach-Object { $_.Split("<") }
$sData = $sData | Select-String "contract"
$sData = $sData | ForEach-Object { $_ -replace $_,"$_`n" }

$oRegEx = [regex]'"contract_.*row">(.*)'
$cMatches = $oRegEx.Matches($sData)
$cMatches = $cMatches | ForEach-Object { $_.Groups[1].value }

$cMyData = @()
foreach ($i in 0..($cMatches.count -1)) {
    $cRecord = New-Object -TypeName system.Object
    [void] $foreach.MoveNext()
    $cRecord | Add-Member -MemberType noteProperty -Name 'Provider' $cMatches[$foreach.current]
    [void] $foreach.MoveNext()
    $cRecord | Add-Member -MemberType noteProperty -Name 'Start Date' $cMatches[$foreach.current]
    [void] $foreach.MoveNext()
    $cRecord | Add-Member -MemberType noteProperty -Name 'End Date' $cMatches[$foreach.current]
    [void] $foreach.MoveNext()
    if ($cMatches[$foreach.current] -ne "") {
        $cRecord | Add-Member -MemberType noteProperty -Name 'Days Left' $cMatches[$foreach.current]
    } else {
        $cRecord | 
        Add-Member -MemberType noteProperty -Name 'Days Left' "0"
    }    
    $cMyData += $cRecord
}

$cMyData