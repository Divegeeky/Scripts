# Prompts for the distinguished group name
# and returns members as display names.
#
# Note:  Un-comment lines below to output account name, or export to CSV
#
$GFile = New-Item -type file -force ".\GroupDetails.csv"
Write-Host "Enter Group Name: ie... CN=inpgrca_Science_ArchaeologyG,OU=GROUPS,OU=GCP,OU=GRCA,OU=IMR,DC=NPS,DC=DOI,DC=NET" -ForegroundColor Red
$GName = Read-Host
$group = [ADSI] "LDAP://$GName"
$group.cn
$group.cn | Out-File $GFile -encoding ASCII -append
foreach ($member in $group.member)
		{
			$Uname = new-object directoryservices.directoryentry("LDAP://$member")
			$Uname.cn
            #$Uname.samaccountname
			#$Uname.cn | Out-File $GFile -encoding ASCII -append
        }