Import-Module \\FSO\CORE\Scripts\include\Get_Functions.psm1

Get-UserTemplates | ?{$_.name -like "Operations*"} | select name, samaccountname | %{"`n`n$($_.Name.ToUpper()):";Get-ADGroupMembership $_.samaccountname} | clip
