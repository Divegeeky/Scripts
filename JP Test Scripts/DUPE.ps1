#region Inlcude
Import-Module \\fso\core\Scripts\include\SQL_functions.psm1 -DisableNameChecking
Import-Module \\fso\core\Scripts\include\Alert_Functions.psm1 -DisableNameChecking
if((Get-PSSnapin -Name SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue) -eq $null) {
    try{Add-PsSnapin SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue}catch{}
}
#endregion Include

#region variables
$serverName = 'SVR0103'
$databaseName = 'IDMS'
$query1 = 
"select ISO, LNAME, FNAME, MNAME, ISSUED, PICTID, UNIVID 
  from [IDMS].[dbo].[arizona] 
  where pictid in ( 
        select pictid 
        from [IDMS].[dbo].[arizona] 
        where pictid <> '' 
        group by pictid 
        having count(*) > 1 
  ) 
  order by pictid"

$query2 = "select ISO, LNAME, FNAME, MNAME, ISSUED, SIGID, UNIVID 
  from [IDMS].[dbo].[arizona] 
  where sigid in ( 
        select sigid 
        from [IDMS].[dbo].[arizona] 
        where sigid <> '' 
        group by sigid 
        having count(*) > 1 
  ) 
  order by sigid"

$subject = "Duplicate IDMS Data Entry"
$body = "<h3>IDMS Duplicate Entry Data</h3><p>The following duplicate information was found in IDMS</p>"

#endregion variables

#region functions



#endregion functions

#region main
$Q1 = Invoke-SQLquery -serverName $serverName -databaseName $databaseName -query $query1 
$Q2 = Invoke-SQLquery -serverName $serverName -databaseName $databaseName -query $query2
#$Q1,$Q2 | Send-Alert -subject $subject -body $body -to "support@fso.arizona.edu"
#$Q1, $Q2

#endregion main


