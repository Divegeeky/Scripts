#Define Bitmap location
$bmps = 'C$\IDMS\Bitmaps'

#Define CDF location
$cdfs = 'C$\IDMS\CDF'

#Define Server CDF Locations
$bmpsserver = '\\fso\core\ApplicationData\IDMS\Bitmaps'
$cdfserver = '\\fso\core\ApplicationData\IDMS\CDF'

#Define the arrays for the filenames to be deleted
$bmptodelete = gci '\\FSO0157\C$\IDMS\Old bitmaps' | Select -ExpandProperty Name
$cdftodelete = gci '\\FSO0157\C$\IDMS\Old CDFS' | Select -ExpandProperty Name

#Get all FSO AD Computer objects
#$computers = Get-ADComputer -Filter * -Properties name, description | select name, description

#Filter to all Catcard machines
#$targets2 = $computers.Where({$_.description -like "FSO - CatCard*"}) | select -ExpandProperty name

#Add Matt's machine too...
#$targets2 += "FSO0157" 
$targets = get-adgroupmember GPO_CatCard_Computers | select -ExpandProperty name
$offlinecomputers=@()
#For each Catcard machine, delete the BMPs and CDFs, using verbose switch.
$targets.ForEach({if(Test-Connection -ComputerName $_ -Count 1 -TimeToLive 200 -Quiet -ErrorAction Continue){
    #Write-Host ("{0} is online and able to be reached." -f $_)
}
Else{
      $offlinecomputers+= $_
}
})
if ($offlinecomputers){
Write-Warning "We are exiting because there were offline computers" 
$offlinecomputers.ForEach({Write-Warning ("{0} was offline when we tried to run this script" -f $_)})
exit
}
Else{
    $targets.ForEach({
       $tempcpuname = $_
       $bmptodelete.ForEach({Remove-Item "\\$tempcpuname\$bmps\$_" })
       $cdftodelete.ForEach({Remove-Item "\\$tempcpuname\$cdfs\$_" })
       # Remove-Item -Path "\\$_\$bmps1" -Include $bmptodelete -Verbose
       # Remove-Item -Path "\\$_\$cdfs" -Include $cdftodelete -Verbose
    })
    $bmptodelete.ForEach({Remove-Item "$bmpsserver\$_"})
    $cdftodelete.ForEach({Remove-Item "$cdfserver\$_"})
}