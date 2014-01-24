#region variables

$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
#from http://iia.arizona.edu/eds_attributes_ps_hr
$employeeStatusHash = @{
A = 'Active'
L = 'Leave of Absence'
P = 'Leave With Pay'
R = 'Retired'
S = 'Suspended'
T = 'Terminated'
W = 'Short Work Break'
}

#endregion


#region includes

Import-Module (Join-Path $scriptPath 'Password_Functions.psm1') -DisableNameChecking

#endregion


#region functions

function Get-EDSLogin {
<#
    .Synopsis
        Gets authentication information for EDS.
    .Example
        PS C:\> Get-EDSLogin
    .Notes
        See http://iia.arizona.edu/eds_registration
#>
    $key = 193, 167, 215, 90, 58, 147, 246, 51, 205, 158, 130, 181, 62, 250, 50, 250, 1, 42, 136, 85, 23, 123, 25, 37, 100, 77, 83, 123, 5, 26, 90, 199
    $user = '\fso-eds-ad-sync'
    $file = (Join-Path $scriptPath 'Static_EDS.xml')
    Retrieve-Password -user $user -key $key -file $file | New-Credential -user $user.trimstart('\')
}

function Get-EDS {
<#
    .Synopsis
        Returns all records from EDS. If the NoISONumber switch is used only records that don't have an ISO Number will be returned.
    .Description
        Queries EDS using LDAP for all records. If the NoISONumber switch is used only records that don't have an ISO Number will be returned.
    .Parameter PropertiesToLoad
        EDS properties to load values.  See http://sia.uits.arizona.edu/eds_attributes for more a list of
        acceptable values.
    .Parameter NoISONumber
        Switch parameter. If used only records that do not have an ISO number will be returned.
    .Example
        Get-EDS -NoISONumber
#>
    [CmdletBinding()]
	param(
	[parameter(Mandatory=$false)][string[]][ValidateNotNullOrEmpty()]$PropertiesToLoad = ('emplid','sn','givenname','isoNumber', 'uid'),
    [parameter(Mandatory=$false)][switch]$NoISONumber
    )
    # inner helper function to hide Attempts param from client
    function Get-EDSHelper {
        [CmdletBinding()]
        param(
        [parameter(Mandatory=$true)][string[]]$PropertiesToLoad,
        [parameter(Mandatory=$false)][switch]$NoISONumber,
        [parameter(Mandatory=$false)][int]$Attempts = 0
        )
        try {
            $Attempts++
        	$found = $null
        	$ldaproot = "LDAP://eds.arizona.edu:636/ou=People,dc=eds,dc=arizona,dc=edu"
            $edslogin = Get-EDSlogin
        	$userDN = "uid=$($edslogin.username),ou=App Users,dc=eds,dc=arizona,dc=edu"
        	$auth = [system.DirectoryServices.AuthenticationTypes]::None
        	$DE = New-Object System.DirectoryServices.DirectoryEntry($ldaproot)
        	$DE.psbase.AuthenticationType = $auth
        	$DE.psbase.Username = $userDN
        	$DE.psbase.Password = $edslogin | Get-Password
        	$search = New-Object system.DirectoryServices.DirectorySearcher($DE)
           
            $PropertiesToLoad | % {
                $search.PropertiesToLoad.Add("$_") | Out-Null
            }

            if($NoISONumber) {
                Write-Verbose ("{0}`n`tGetting all EDS info for records that don't have an ISO number. This may take a few minutes. Attempt number {1}." -f $MyInvocation.MyCommand.Name, $Attempts)
                $search.filter = "(&(!isoNumber=*)(!objectclass=arizonaedutestperson))"
            } else {
                Write-Verbose ("{0}`n`tGetting all EDS info. This may take a few minutes. Attempt number {1}." -f $MyInvocation.MyCommand.Name, $Attempts)
                $search.filter = "(&(isoNumber=*)(!objectclass=arizonaedutestperson))"
            }
            
            $found = $search.findall()
            [array]$array = $null
        	foreach ($record in $found) {
        		$prophash = @{}
        		$obj = $null
        		foreach ($prop in $record.Properties.PropertyNames)
        			{ $prophash += @{$prop = $record.Properties.$prop} }
        		$obj = New-Object psobject -Property $prophash
        		$array += $obj
        	}
        	# return the result
            $array
        } catch {
            Write-Verbose ("{0}`n`tA problem occured: {1}" -f $MyInvocation.MyCommand.Name, $_)
            # sometimes EDS just times out, try at least 3 times before throwing exception
            if($Attempts -lt 3) {
                if($NoISONumber) {
                    Get-EDSHelper -PropertiesToLoad $PropertiesToLoad  -Attempts $Attempts -NoISONumber
                } else {
                    Get-EDSHelper -PropertiesToLoad $PropertiesToLoad -Attempts $Attempts
                }
            } else {
                Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $_)
            }
        } 
        $DE.psbase.Dispose()
    }
    
    # properties as string for verbose output
    $props = ''
    $PropertiesToLoad | %{
        $props += "{0}, " -f $_
    }
    Write-Verbose ("{0}`n`tPropertiesToLoad: {1}" -f $MyInvocation.MyCommand.Name, $props)
    # call the helper
    if($NoISONumber) {
        Get-EDSHelper -PropertiesToLoad $PropertiesToLoad -NoISONumber
    } else {
        Get-EDSHelper -PropertiesToLoad $PropertiesToLoad
    }
}

function Get-EDSinfo {
<#
    .Synopsis
        Returns EDS information by searching on NetID or EmplId.
    .Parameter Identity
        The NetID (UID in EDS) or EmplID to use as a target for the search.
    .Parameter Credentials
        The username and password in a credential object used to query EDS.
    .Example
        PS C:\> Get-EDSInfo
    .Notes
        Useful Link: http://iia.arizona.edu/eds_attributes
#>
    [CmdletBinding()]	
    param(
    [parameter(Mandatory=$true,Position=0)][string]$Identity,
    [parameter(Mandatory=$false)]$Credentials = $(Get-EDSlogin)
    )
    Write-Verbose ("{0}`n`tSearching EDS using {1}" -f $MyInvocation.MyCommand.Name, $Identity)
    $EDSurl = "https://eds.arizona.edu/people/"
	$url = $EDSurl + $identity
	$webclient = New-Object System.Net.WebClient
	$webclient.credentials = New-Object System.Net.NetworkCredential -ArgumentList $credentials.username, ($credentials | Get-Password)
	[xml]$xml = $webclient.DownloadString($url)
	$edsxml = $xml.dsml.'directory-entries'.entry.attr
	if ($edsxml) {
        Write-Verbose ("{0}`n`tFound data, formatting output..." -f $MyInvocation.MyCommand.Name)
        $obj = New-Object PSObject
        $edsxml | sort Name | %{Add-Member -InputObject $obj -MemberType NoteProperty -Name $_.Name -Value $_.value}
        $obj
	}
}

function Get-EDSInfoByISO {
<#
    .Synopsis
        Searches EDS based on CatCard number (ISO).
    .Parameter ISO
        The target ISO number used to search EDS.
    .Example
        PS C:\> Get-EDSInfoByISO 6010790201346182
#>
    [CmdletBinding()]
    param (
    [parameter(Mandatory=$true,Position=0)][string]$ISO
    )
    # inner helper function is used to hide the Attempts parameter so calling code won't inadvertently alter the 
    # number of attempts
    function Get-EDSInfoByISOHelper {
        [CmdletBinding()]
        param (
        [parameter(Mandatory=$true,Position=0)][string]$ISO,
        [parameter(Mandatory=$false)][int]$Attempts = 0
        )
        
        try {
            $Attempts++
            Write-Verbose ("{0}`n`tGetting EDS info by ISO <{1}>. Attempt number {2}..." -f $MyInvocation.MyCommand.Name, $ISO, $Attempts)
            $found = $null
        	$ldaproot = "LDAP://eds.arizona.edu:636/ou=People,dc=eds,dc=arizona,dc=edu"
        	$edslogin = get-EDSlogin
        	$userDN = "uid=$($edslogin.username),ou=App Users,dc=eds,dc=arizona,dc=edu"
        	$auth = [system.DirectoryServices.AuthenticationTypes]::None
        	$DE = New-Object System.DirectoryServices.DirectoryEntry($ldaproot)
        	$DE.psbase.AuthenticationType = $auth
        	$DE.psbase.Username = $userDN
        	$DE.psbase.Password = $edslogin | Get-Password
        	$search = New-Object system.DirectoryServices.DirectorySearcher($DE)
        	$search.PropertiesToLoad.Add("cn") | Out-Null
            $search.PropertiesToLoad.Add("dccPrimaryActionDate") | Out-Null
            $search.PropertiesToLoad.Add("dccPrimaryDept") | Out-Null
            $search.PropertiesToLoad.Add("dccPrimaryDeptName") | Out-Null
            $search.PropertiesToLoad.Add("dccPrimaryEndDate") | Out-Null
            $search.PropertiesToLoad.Add("dccPrimaryStatus") | Out-Null
            $search.PropertiesToLoad.Add("dccPrimaryTitle") | Out-Null
            $search.PropertiesToLoad.Add("dccPrimaryType") | Out-Null
            $search.PropertiesToLoad.Add("dccRelation") | Out-Null
            $search.PropertiesToLoad.Add("dsvUAID") | Out-Null
            $search.PropertiesToLoad.Add("givenName") | Out-Null
            $search.PropertiesToLoad.Add("eduPersonAffiliation") | Out-Null
            $search.PropertiesToLoad.Add("eduPersonPrimaryAffiliation") | Out-Null
            $search.PropertiesToLoad.Add("emplid") | Out-Null
            $search.PropertiesToLoad.Add("employeePrimaryDept") | Out-Null
            $search.PropertiesToLoad.Add("employeePrimaryDeptName") | Out-Null
        	$search.PropertiesToLoad.Add("employeeStatus") | Out-Null
            $search.PropertiesToLoad.Add("employeeTitle") | Out-Null
            $search.PropertiesToLoad.Add("employeeType") | Out-Null
            $search.PropertiesToLoad.Add("isonumber") | Out-Null
        	$search.PropertiesToLoad.Add("mail") | Out-Null
            $search.PropertiesToLoad.Add("sn") | Out-Null
            $search.PropertiesToLoad.Add("uaid") | Out-Null
        	$search.PropertiesToLoad.Add("uid") | Out-Null
            $search.filter = "(isonumber=$ISO)"
        	$found = $search.findall()
        	[array]$array = $null
        	foreach ($record in $found) {
        		$prophash = @{}
        		$obj = $null
        		foreach ($prop in $record.Properties.PropertyNames)
        			{ $prophash += @{$prop = $record.Properties.$prop} }
        		$obj = New-Object psobject -Property $prophash
        		$array += $obj
        	}
            
            $array
        	
        	$de.psbase.Dispose()
        } catch {
            Write-Verbose ("{0}`n`tA problem occured: {1}" -f $MyInvocation.MyCommand.Name, $_)
            # sometimes EDS just times out, try at least 3 times before throwing exception
            if($Attempts -lt 3) {
                Get-EDSInfoByISOHelper -ISO $ISO -Attempts $Attempts
            } else {
                Write-Verbose ("{0}`n`tCould not get EDS info" -f $MyInvocation.MyCommand.Name)
            }
        }
        
    }
    # Get-EDSInfoByISO calls Get-EDSInfoByISOHelper
    Get-EDSInfoByISOHelper -ISO $ISO
}

function Get-EDSInfoByName {
<#
    .Synopsis
        Searches EDS based on the specified name.
    .Description
        This function searches EDS based on the specified name. The function attempts to split the name
        into last name and first name if it sees it in 'last name, first name' format. If not it assumes
        that only the last name was passed in.
    .Parameter Name
        The name used to search EDS for. Format should be 'last name, first name' or just 'last name'.
    .Parameter FSO
        Switch parameter. By default this function assumes the person is in FSO. If no results are returned
        try negating this switch by using -FSO:$false
    .Parameter Employee
        Switch parameter. By default this function assumes the person is an employee. If no results are returned
        try negating this switch by using -Employee:$false
    .Example
        PS C:\> Get-EDSInfoByName -Name 'Smith, Jeff'
    .Example
        PS C:\> Get-EDSInfoByName -Name 'Smith'
    .Example
        PS C:\> Get-EDSInfoByName -Name 'Smith, Jeff' -FSO:$false
    .Example
        PS C:\> Get-EDSInfoByName -Name 'Smith, Jeff' -FSO:$false -Employee:$false
#>
    [CmdletBinding()]
    param(
	[parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
	[string]$Name,
	[switch]$FSO = $true,
	[switch]$Employee = $true
	)
	$FSOdepts = 7701, 7702, 7703, 7704, 7706, 7708, 7709, 7710, 7901
	if ($name -match ',') {
		$lastName, $firstName = $name.split(',')
		$firstName = $firstname.Trim()
	} else {
		$lastName = $Name.Trim()
		$firstname = $null
	}
	$found = $null
	$ldaproot = "LDAP://eds.arizona.edu:636/ou=People,dc=eds,dc=arizona,dc=edu"
	$edslogin = get-EDSlogin
	$userDN = "uid=$($edslogin.username),ou=App Users,dc=eds,dc=arizona,dc=edu"
	$auth = [system.DirectoryServices.AuthenticationTypes]::None
	$DE = New-Object System.DirectoryServices.DirectoryEntry($ldaproot)
	$DE.psbase.AuthenticationType = $auth
	$DE.psbase.Username = $userDN
	$DE.psbase.Password = $edslogin | Get-Password
	$search = New-Object system.DirectoryServices.DirectorySearcher($DE)
	$search.PropertiesToLoad.Add("cn") | Out-Null
	$search.PropertiesToLoad.Add("employeeStatus") | Out-Null
	$search.PropertiesToLoad.Add("emplid") | Out-Null
	$search.PropertiesToLoad.Add("employeePrimaryDeptName") | Out-Null
	$search.PropertiesToLoad.Add("employeePrimaryDept") | Out-Null
	$search.PropertiesToLoad.Add("uid") | Out-Null
    $search.PropertiesToLoad.Add("uaid") | Out-Null
    $search.filter = "(&(givenname=$firstName*)(sn=$lastname))"
	$found = $search.findall()
	[array]$array = $null
	foreach ($record in $found) {
		$prophash = @{}
		$obj = $null
		foreach ($prop in $record.Properties.PropertyNames)
			{ $prophash += @{$prop = $record.Properties.$prop} }
		$obj = New-Object psobject -Property $prophash
		$array += $obj
	}
	
    #Test to see if they are an employee -- statuses taken from FAST's isEmployee function in EDS Viewer
	if ($employee) {
        $array = $array | Where-Object {('A','P','M','B','N','F') -contains $($_.employeestatus)}
    } 
      
    #if we only want FSO employees, only return those employees that are in an FSO department.
	if ($fso) {
        $array = $array | Where-Object { $FSOdepts -contains $($_.employeeprimarydept)} 
    }
	
	$array
	
	$de.psbase.Dispose()
}

function Get-EDSInfoByFullName {
<#
    .Synopsis
        Searches EDS based on the specified last name and first name.
    .Description
        Uses the specified first and last names to search EDS. This function assumes that the person
        is in FSO and an employee. This behavior can be modified by negating the FSO and Employee 
        switch parameters. 
    .Parameter LastName
        The surname of the person to search for.
    .Parameter FirstName
        The givenname of the person to search for.
    .Parameter FSO
        Switch parameter. By default this function assumes the person is in FSO. If no results are returned
        try negating this switch by using -FSO:$false
    .Parameter Employee
        Switch parameter. By default this function assumes the person is an employee. If no results are returned
        try negating this switch by using -Employee:$false
    .Example
        PS C:\> Get-EDSInfoByFullName -LastName 'Smith' -FirstName 'Jeff'
    .Example
        PS C:\> Get-EDSInfoByFullName -LastName 'Smith' -FirstName 'Jeff' -FSO:$false
    .Example
        PS C:\> Get-EDSInfoByFullName -LastName 'Smith' -FirstName 'Jeff' -FSO:$false -Employee:$false
#>
    [CmdletBinding()]
	param(
	[parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
	[string]$LastName,
    [string]$FirstName,
	[switch]$FSO = $true,
	[switch]$Employee = $true
	)
	$FSOdepts = 7701, 7702, 7703, 7704, 7706, 7708, 7709, 7710, 7901
	$found = $null
	$ldaproot = "LDAP://eds.arizona.edu:636/ou=People,dc=eds,dc=arizona,dc=edu"
	$edslogin = get-EDSlogin
	$userDN = "uid=$($edslogin.username),ou=App Users,dc=eds,dc=arizona,dc=edu"
	$auth = [system.DirectoryServices.AuthenticationTypes]::None
	$DE = New-Object System.DirectoryServices.DirectoryEntry($ldaproot)
	$DE.psbase.AuthenticationType = $auth
	$DE.psbase.Username = $userDN
	$DE.psbase.Password = $edslogin | Get-Password
	$search = New-Object system.DirectoryServices.DirectorySearcher($DE)
	$search.PropertiesToLoad.Add("cn") | Out-Null
	$search.PropertiesToLoad.Add("employeeStatus") | Out-Null
	$search.PropertiesToLoad.Add("emplid") | Out-Null
	$search.PropertiesToLoad.Add("employeePrimaryDeptName") | Out-Null
	$search.PropertiesToLoad.Add("employeePrimaryDept") | Out-Null
	$search.PropertiesToLoad.Add("uid") | Out-Null
    $search.PropertiesToLoad.Add("uaid") | Out-Null
    $search.filter = "(&(givenname=$firstName*)(sn=$lastname))"
	$found = $search.findall()
	[array]$array = $null
	foreach ($record in $found) {
		$prophash = @{}
		$obj = $null
		foreach ($prop in $record.Properties.PropertyNames)
			{ $prophash += @{$prop = $record.Properties.$prop} }
		$obj = New-Object psobject -Property $prophash
		$array += $obj
	}
	
    #Test to see if they are an employee -- statuses taken from FAST's isEmployee function in EDS Viewer
	if ($employee) {
        $array = $array | Where-Object {('A','P','M','B','N','F') -contains $($_.employeestatus)}
    } 
      
    #if we only want FSO employees, only return those employees that are in an FSO department.
	if ($fso) {
        $array = $array | Where-Object { $FSOdepts -contains $($_.employeeprimarydept)} 
    }
	
	$array
	
	$de.psbase.Dispose()
}

function Get-EDSRecord {
<#
    .Synopsis
        Finds an EDS record based on an ID number or by fullname.
    .Description
        If an ID is passed in the function will attempt to find a corresponding EDS record. If no ID
        is passed in and instead the first and last names are passed in the function will attempt to
        find an EDS record by fullname. A total of 10 attempts to connect to EDS will be made.
    .Parameter Id
        An identifying number that may be used to query EDS for a particular record.
    .Parameter FirstName
        The first name of the person for whom an EDS record is needed.
    .Parameter LastName
        The last name of the person for whom an EDS record is needed.
    .Example
        Get-EDSRecord 12345678
    .Example
        Get-EDSRecord -FirstName 'John' -LastName 'Smith'
#>
    [CmdletBinding()]
	param(
	[parameter(Mandatory=$false,Position=0)][string]$Id = $null,
    [parameter(Mandatory=$false,Position=1)][string]$FirstName = '',
    [parameter(Mandatory=$false,Position=2)][string]$LastName = ''
    )
    # inner helper function is used to hide the Attempts parameter so calling code won't inadvertently alter the 
    # number of attempts
    function Get-EDSRecordHelper {
        [CmdletBinding()]
    	param(
    	[parameter(Mandatory=$false,Position=0)][string]$Id = $null,
        [parameter(Mandatory=$false,Position=1)][string]$FirstName = '',
        [parameter(Mandatory=$false,Position=2)][string]$LastName = '',
        [parameter(Mandatory=$false)][int]$Attempts = 0
    	)
        try {
            $Attempts++
            if($Id) {
                Get-EDSinfo $Id
            } else {
                Get-EDSInfoByFullName -LastName $LastName -FirstName $FirstName -FSO:$false -Employee:$false
            }
        } catch {
            Write-Verbose ("{0}`n`tA problem occured: {1}" -f $MyInvocation.MyCommand.Name, $_)
            # sometimes EDS just times out, try at least 10 times before throwing exception
            if($Attempts -lt 10) {
                if($ByName) {
                    Get-EDSRecordHelper -LastName $LastName -FirstName $FirstName -Attempts $Attempts -ByName
                } else {
                    Get-EDSRecordHelper -Id $Id -Attempts $Attempts
                }
            } else {
                Write-Verbose ("{0}`n`tCould not get EDS info" -f $MyInvocation.MyCommand.Name)
            }
        }
    }
    
    # Get-EDSRecord code calls Get-EDSRecordHelper
    if(-not([string]::IsNullOrEmpty($Id))) {
        Write-Verbose ("{0}`n`tGet by ID number <{1}>..." -f $MyInvocation.MyCommand.Name, $Id)
        Get-EDSRecordHelper -ID $Id
    } elseif((-not([string]::IsNullOrEmpty($FirstName))) -and ((-not([string]::IsNullOrEmpty($LastName)))) ) {
        Write-Verbose ("{0}`n`tGet by full name <{1}>..." -f $MyInvocation.MyCommand.Name, ("$LastName, $FirstName"))
        Get-EDSRecordHelper -FirstName $FirstName -LastName $LastName
    } else {
        Throw "Insufficient data to query EDS with. Either an ID number or a first and last name must be provided." -f $Id, $FirstName, $LastName
    }
    
}

function Get-EdsDccRecords {
<#
    .Synopsis
        Returns all Designated Campus Colleague records from EDS. If the NoISONumber switch is used only records
        that don't have an ISO Number will be returned.
    .Description
        Queries EDS using LDAP for all records where the employeestatus is 'A'. If the
        NoISONumber switch is used only records that don't have an ISO Number will be returned.
    .Parameter PropertiesToLoad
        EDS properties to load values.  See http://sia.uits.arizona.edu/eds_attributes for more a list of
        acceptable values.
    .Parameter NoISONumber
        Switch parameter. If used only records that do not have an ISO number will be returned.
    .Example
        Get-EDSDSVRecords -NoISONumber
#>
    [CmdletBinding()]
	param(
	[parameter(Mandatory=$false)][string[]][ValidateNotNullOrEmpty()]$PropertiesToLoad = ('emplid','sn','givenname','isoNumber','eduPersonPrimaryAffiliation','dccPrimaryDept','dccPrimaryDeptName','dccPrimaryEndDate','dccPrimaryStatus','dccPrimaryTitle','dccPrimaryType','dccRelation','dccPrimaryActionDate','dsvUAID'),
    [parameter(Mandatory=$false)][switch]$NoISONumber
    )
    # inner helper function to hide Attempts param from client
    function Get-EdsDccRecordsHelper {
        [CmdletBinding()]
        param(
        [parameter(Mandatory=$true)][string[]]$PropertiesToLoad,
        [parameter(Mandatory=$false)][switch]$NoISONumber,
        [parameter(Mandatory=$false)][int]$Attempts = 0
        )
        try {
            $Attempts++
        	$found = $null
        	$ldaproot = "LDAP://eds.arizona.edu:636/ou=People,dc=eds,dc=arizona,dc=edu"
            $edslogin = Get-EDSlogin
        	$userDN = "uid=$($edslogin.username),ou=App Users,dc=eds,dc=arizona,dc=edu"
        	$auth = [system.DirectoryServices.AuthenticationTypes]::None
        	$DE = New-Object System.DirectoryServices.DirectoryEntry($ldaproot)
        	$DE.psbase.AuthenticationType = $auth
        	$DE.psbase.Username = $userDN
        	$DE.psbase.Password = $edslogin | Get-Password
        	$search = New-Object system.DirectoryServices.DirectorySearcher($DE)
           
            $PropertiesToLoad | % {
                $search.PropertiesToLoad.Add("$_") | Out-Null
            }

            if($NoISONumber) {
                Write-Verbose ("{0}`n`tGetting EDS info for all DCCs that don't have an ISO number. This may take a few minutes. Attempt number {1}." -f $MyInvocation.MyCommand.Name, $Attempts)
                $search.filter = "(&(eduPersonPrimaryAffiliation=dcc)(!isoNumber=*)(!objectclass=arizonaedutestperson))"
            } else {
                Write-Verbose ("{0}`n`tGetting EDS info for DCCs. This may take a few minutes. Attempt number {1}." -f $MyInvocation.MyCommand.Name, $Attempts)
                #$search.filter = "(&(eduPersonPrimaryAffiliation=affiliate)(objectclass=arizonaeduemployee)(!objectclass=arizonaedutestperson))"
                $search.filter = "(&(eduPersonPrimaryAffiliation=dcc)(!objectclass=arizonaedutestperson))"
            }
            
            $found = $search.findall()
            [array]$array = $null
        	foreach ($record in $found)
        	{
        		$prophash = @{}
        		$obj = $null
        		foreach ($prop in $record.Properties.PropertyNames)
        			{ $prophash += @{$prop = $record.Properties.$prop} }
        		$obj = New-Object psobject -Property $prophash
        		$array += $obj
        	}
        	# return the result
            $array
        } catch {
            Write-Verbose ("{0}`n`tA problem occured: {1}" -f $MyInvocation.MyCommand.Name, $_)
            # sometimes EDS just times out, try at least 3 times before throwing exception
            if($Attempts -lt 3) {
                if($NoISONumber) {
                    Get-EDSDccRecordsHelper -PropertiesToLoad $PropertiesToLoad  -Attempts $Attempts -NoISONumber
                } else {
                    Get-EDSDccRecordsHelper -PropertiesToLoad $PropertiesToLoad -Attempts $Attempts
                }
            } else {
                Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $_)
            }
        } 
        $DE.psbase.Dispose()
    }
    
    # properties as string for verbose output
    $props = ''
    $PropertiesToLoad | %{
        $props += "{0}, " -f $_
    }
    Write-Verbose ("{0}`n`tPropertiesToLoad: {1}" -f $MyInvocation.MyCommand.Name, $props)
    # call the helper
    if($NoISONumber) {
        Get-EdsDccRecordsHelper -PropertiesToLoad $PropertiesToLoad -NoISONumber
    } else {
        Get-EdsDccRecordsHelper -PropertiesToLoad $PropertiesToLoad
    }
}

function Get-EDSDSVRecords {
<#
    .Synopsis
        Returns all Department Sponsered Visitor records from EDS. If the NoISONumber switch is used only records
        that don't have an ISO Number will be returned.
    .Description
        Queries EDS using LDAP for all records where the employeestatus is 'A'. If the
        NoISONumber switch is used only records that don't have an ISO Number will be returned.
    .Parameter PropertiesToLoad
        EDS properties to load values.  See http://sia.uits.arizona.edu/eds_attributes for more a list of
        acceptable values.
    .Parameter NoISONumber
        Switch parameter. If used only records that do not have an ISO number will be returned.
    .Example
        Get-EDSDSVRecords -NoISONumber
#>
    [CmdletBinding()]
	param(
	[parameter(Mandatory=$false)][string[]][ValidateNotNullOrEmpty()]$PropertiesToLoad = ('emplid','sn','givenname','isoNumber','eduPersonPrimaryAffiliation','dsvId','dsvAffiliationType','dsvExpirationDate','dsvSponoringDept'),
    [parameter(Mandatory=$false)][switch]$NoISONumber
    )
    # inner helper function to hide Attempts param from client
    function Get-EDSDSVRecordsHelper {
        [CmdletBinding()]
        param(
        [parameter(Mandatory=$true)][string[]]$PropertiesToLoad,
        [parameter(Mandatory=$false)][switch]$NoISONumber,
        [parameter(Mandatory=$false)][int]$Attempts = 0
        )
        try {
            $Attempts++
        	$found = $null
        	$ldaproot = "LDAP://eds.arizona.edu:636/ou=People,dc=eds,dc=arizona,dc=edu"
            $edslogin = Get-EDSlogin
        	$userDN = "uid=$($edslogin.username),ou=App Users,dc=eds,dc=arizona,dc=edu"
        	$auth = [system.DirectoryServices.AuthenticationTypes]::None
        	$DE = New-Object System.DirectoryServices.DirectoryEntry($ldaproot)
        	$DE.psbase.AuthenticationType = $auth
        	$DE.psbase.Username = $userDN
        	$DE.psbase.Password = $edslogin | Get-Password
        	$search = New-Object system.DirectoryServices.DirectorySearcher($DE)
           
            $PropertiesToLoad | % {
                $search.PropertiesToLoad.Add("$_") | Out-Null
            }

            if($NoISONumber) {
                Write-Verbose ("{0}`n`tGetting EDS info for all DSVs that don't have an ISO number. This may take a few minutes. Attempt number {1}." -f $MyInvocation.MyCommand.Name, $Attempts)
                $search.filter = "(&(eduPersonPrimaryAffiliation=affiliate)(!isoNumber=*)(!objectclass=arizonaedutestperson))"
            } else {
                Write-Verbose ("{0}`n`tGetting EDS info for DSVs. This may take a few minutes. Attempt number {1}." -f $MyInvocation.MyCommand.Name, $Attempts)
                #$search.filter = "(&(eduPersonPrimaryAffiliation=affiliate)(objectclass=arizonaeduemployee)(!objectclass=arizonaedutestperson))"
                $search.filter = "(&(eduPersonPrimaryAffiliation=affiliate)(!objectclass=arizonaedutestperson))"
            }
            
            $found = $search.findall()
            [array]$array = $null
        	foreach ($record in $found)
        	{
        		$prophash = @{}
        		$obj = $null
        		foreach ($prop in $record.Properties.PropertyNames)
        			{ $prophash += @{$prop = $record.Properties.$prop} }
        		$obj = New-Object psobject -Property $prophash
        		$array += $obj
        	}
        	# return the result
            $array
        } catch {
            Write-Verbose ("{0}`n`tA problem occured: {1}" -f $MyInvocation.MyCommand.Name, $_)
            # sometimes EDS just times out, try at least 3 times before throwing exception
            if($Attempts -lt 3) {
                if($NoISONumber) {
                    Get-EDSDSVRecordsHelper -PropertiesToLoad $PropertiesToLoad  -Attempts $Attempts -NoISONumber
                } else {
                    Get-EDSDSVRecordsHelper -PropertiesToLoad $PropertiesToLoad -Attempts $Attempts
                }
            } else {
                Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $_)
            }
        } 
        $DE.psbase.Dispose()
    }
    
    # properties as string for verbose output
    $props = ''
    $PropertiesToLoad | %{
        $props += "{0}, " -f $_
    }
    Write-Verbose ("{0}`n`tPropertiesToLoad: {1}" -f $MyInvocation.MyCommand.Name, $props)
    # call the helper
    if($NoISONumber) {
        Get-EDSDSVRecordsHelper -PropertiesToLoad $PropertiesToLoad -NoISONumber
    } else {
        Get-EDSDSVRecordsHelper -PropertiesToLoad $PropertiesToLoad
    }
}

function Get-EDSEmployeeRecords {
<#
    .Synopsis
        Returns all employee records from EDS. If the NoISONumber switch is used only records
        that don't have an ISO Number will be returned.
    .Description
        Queries EDS using LDAP for all records where the employeestatus is 'A'. If the
        NoISONumber switch is used only records that don't have an ISO Number will be returned.
    .Parameter PropertiesToLoad
        EDS properties to load values.  See http://sia.uits.arizona.edu/eds_attributes for more a list of
        acceptable values.
    .Parameter NoISONumber
        Switch parameter. If used only records that do not have an ISO number will be returned.
    .Example
        Get-EDSEmployeeRecords -NoISONumber
#>
    [CmdletBinding()]
	param(
	[parameter(Mandatory=$false)][string[]][ValidateNotNullOrEmpty()]$PropertiesToLoad = ('emplid','sn','givenname','isoNumber','employeestatus'),
    [parameter(Mandatory=$false)][switch]$NoISONumber
    )
    # inner helper function to hide Attempts param from client
    function Get-EDSEmployeeRecordsHelper {
        [CmdletBinding()]
        param(
        [parameter(Mandatory=$true)][string[]]$PropertiesToLoad,
        [parameter(Mandatory=$false)][switch]$NoISONumber,
        [parameter(Mandatory=$false)][int]$Attempts = 0
        )
        try {
            $Attempts++
        	$found = $null
        	$ldaproot = "LDAP://eds.arizona.edu:636/ou=People,dc=eds,dc=arizona,dc=edu"
            $edslogin = Get-EDSlogin
        	$userDN = "uid=$($edslogin.username),ou=App Users,dc=eds,dc=arizona,dc=edu"
        	$auth = [system.DirectoryServices.AuthenticationTypes]::None
        	$DE = New-Object System.DirectoryServices.DirectoryEntry($ldaproot)
        	$DE.psbase.AuthenticationType = $auth
        	$DE.psbase.Username = $userDN
        	$DE.psbase.Password = $edslogin | Get-Password
        	$search = New-Object system.DirectoryServices.DirectorySearcher($DE)
           
            $PropertiesToLoad | % {
                $search.PropertiesToLoad.Add("$_") | Out-Null
            }

            if($NoISONumber) {
                Write-Verbose ("{0}`n`tGetting EDS info for all active employees that don't have an ISO number. This may take a few minutes. Attempt number {1}." -f $MyInvocation.MyCommand.Name, $Attempts)
                $search.filter = "(&(employeestatus=A)(!isoNumber=*)(objectclass=arizonaeduemployee)(!objectclass=arizonaedutestperson))"
            } else {
                Write-Verbose ("{0}`n`tGetting EDS info for all active employees. This may take a few minutes. Attempt number {1}." -f $MyInvocation.MyCommand.Name, $Attempts)
                $search.filter = "(&(employeestatus=A)(objectclass=arizonaeduemployee)(!objectclass=arizonaedutestperson))"
            }
            
            $found = $search.findall()
            [array]$array = $null
        	foreach ($record in $found)
        	{
        		$prophash = @{}
        		$obj = $null
        		foreach ($prop in $record.Properties.PropertyNames)
        			{ $prophash += @{$prop = $record.Properties.$prop} }
        		$obj = New-Object psobject -Property $prophash
        		$array += $obj
        	}
        	# return the result
            $array
        } catch {
            Write-Verbose ("{0}`n`tA problem occured: {1}" -f $MyInvocation.MyCommand.Name, $_)
            # sometimes EDS just times out, try at least 3 times before throwing exception
            if($Attempts -lt 3) {
                if($NoISONumber) {
                    Get-EDSEmployeeRecordsHelper -PropertiesToLoad $PropertiesToLoad  -Attempts $Attempts -NoISONumber
                } else {
                    Get-EDSEmployeeRecordsHelper -PropertiesToLoad $PropertiesToLoad -Attempts $Attempts
                }
            } else {
                Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $_)
            }
        } 
        $DE.psbase.Dispose()
    }
    
    # properties as string for verbose output
    $props = ''
    $PropertiesToLoad | %{
        $props += "{0}, " -f $_
    }
    Write-Verbose ("{0}`n`tPropertiesToLoad: {1}" -f $MyInvocation.MyCommand.Name, $props)
    # call the helper
    if($NoISONumber) {
        Get-EDSEmployeeRecordsHelper -PropertiesToLoad $PropertiesToLoad -NoISONumber
    } else {
        Get-EDSEmployeeRecordsHelper -PropertiesToLoad $PropertiesToLoad
    }
} 

function Get-EDSPOIRecords {
<#
    .Synopsis
        Returns all Person Of Interest (POI) records from EDS. If the NoISONumber switch is used only records
        that don't have an ISO Number will be returned.
    .Description
        Queries EDS using LDAP for all records where the eduPersonPrimaryAffiliation is POI. If the
        NoISONumber switch is used only records that don't have an ISO Number will be returned.
    .Parameter PropertiesToLoad
        EDS properties to load values.  See http://sia.uits.arizona.edu/eds_attributes for more a list of
        acceptable values.
    .Parameter NoISONumber
        Switch parameter. If used only records that do not have an ISO number will be returned.
    .Example
        Get-EDSPOIRecords -NoISONumber
#>
    [CmdletBinding()]
	param(
	[parameter(Mandatory=$false)][string[]][ValidateNotNullOrEmpty()]$PropertiesToLoad = ('emplid','sn','givenname','isoNumber','employeePoiPrimaryDept','employeePoiStatus','EmployeePoiTitle','employeePoiType'),
    [parameter(Mandatory=$false)][switch]$NoISONumber
    )
    # inner helper function to hide Attempts param from client
    function Get-EDSPOIRecordsHelper {
        [CmdletBinding()]
        param(
        [parameter(Mandatory=$true)][string[]]$PropertiesToLoad,
        [parameter(Mandatory=$false)][switch]$NoISONumber,
        [parameter(Mandatory=$false)][int]$Attempts = 0
        )
        try {
            $Attempts++
        	$found = $null
        	$ldaproot = "LDAP://eds.arizona.edu:636/ou=People,dc=eds,dc=arizona,dc=edu"
            $edslogin = Get-EDSlogin
        	$userDN = "uid=$($edslogin.username),ou=App Users,dc=eds,dc=arizona,dc=edu"
        	$auth = [system.DirectoryServices.AuthenticationTypes]::None
        	$DE = New-Object System.DirectoryServices.DirectoryEntry($ldaproot)
        	$DE.psbase.AuthenticationType = $auth
        	$DE.psbase.Username = $userDN
        	$DE.psbase.Password = $edslogin | Get-Password
        	$search = New-Object system.DirectoryServices.DirectorySearcher($DE)
           
            $PropertiesToLoad | % {
                $search.PropertiesToLoad.Add("$_") | Out-Null
            }

            if($NoISONumber) {
                Write-Verbose ("{0}`n`tGetting EDS info for all active POI that don't have an ISO number. This may take a few minutes. Attempt number {1}." -f $MyInvocation.MyCommand.Name, $Attempts)
                $search.filter = "(&(eduPersonPrimaryAffiliation=POI)(employeePoiStatus=A)(!isoNumber=*)(!objectclass=arizonaedutestperson))"
            } else {
                Write-Verbose ("{0}`n`tGetting EDS info for all active POI. This may take a few minutes. Attempt number {1}." -f $MyInvocation.MyCommand.Name, $Attempts)
                $search.filter = "(&(eduPersonPrimaryAffiliation=POI)(employeePoiStatus=A)(!objectclass=arizonaedutestperson))"
            }
            
            $found = $search.findall()
            [array]$array = $null
        	foreach ($record in $found)
        	{
        		$prophash = @{}
        		$obj = $null
        		foreach ($prop in $record.Properties.PropertyNames)
        			{ $prophash += @{$prop = $record.Properties.$prop} }
        		$obj = New-Object psobject -Property $prophash
        		$array += $obj
        	}
        	# return the result
            $array
        } catch {
            Write-Verbose ("{0}`n`tA problem occured: {1}" -f $MyInvocation.MyCommand.Name, $_)
            # sometimes EDS just times out, try at least 3 times before throwing exception
            if($Attempts -lt 3) {
                if($NoISONumber) {
                    Get-EDSPOIRecordsHelper -PropertiesToLoad $PropertiesToLoad  -Attempts $Attempts -NoISONumber
                } else {
                    Get-EDSPOIRecordsHelper -PropertiesToLoad $PropertiesToLoad -Attempts $Attempts
                }
            } else {
                Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $_)
            }
        } 
        $DE.psbase.Dispose()
    }
    
    # properties as string for verbose output
    $props = ''
    $PropertiesToLoad | %{
        $props += "{0}, " -f $_
    }
    Write-Verbose ("{0}`n`tPropertiesToLoad: {1}" -f $MyInvocation.MyCommand.Name, $props)
    # call the helper
    if($NoISONumber) {
        Get-EDSPOIRecordsHelper -PropertiesToLoad $PropertiesToLoad -NoISONumber
    } else {
        Get-EDSPOIRecordsHelper -PropertiesToLoad $PropertiesToLoad
    }
}

function Get-EDSStudentRecords {
<#
    .Synopsis
        Returns all student records from EDS. If the NoISONumber switch is used only records
        that don't have an ISO Number will be returned.
    .Description
        Queries EDS using LDAP for all records where the eduPersonPrimaryAffiliation is Student or if the
        All switch is used all records where 'Student' is in the eduPersonAffiliation list. If the
        NoISONumber switch is used only records that don't have an ISO Number will be returned.
    .Parameter PropertiesToLoad
        EDS properties to load values.  See http://sia.uits.arizona.edu/eds_attributes for more a list of
        acceptable values.
    .Parameter NoISONumber
        Switch parameter. If used only records that do not have an ISO number will be returned.
    .Parameter All
        Switch parameter. If used all records that have 'Student' in their eduPersonAffiliation list are
        returned. These may included employees.  If not used only records with an eduPersonPrimaryAffiliation
        of 'Student' are returned which excludes employees.
    .Example
        Get-EDSStudentRecords -NoISONumber
#>
    [CmdletBinding()]
	param(
	[parameter(Mandatory=$false)][string[]][ValidateNotNullOrEmpty()]$PropertiesToLoad = ('emplid','sn','givenname','isoNumber','eduPersonPrimaryAffiliation','eduPersonAffiliation','studentstatus'),
    [parameter(Mandatory=$false)][switch]$NoISONumber,
    [parameter(Mandatory=$false)][switch]$All
    )
    # inner helper function to hide Attempts param from client
    function Get-EDSStudentRecordsHelper {
        [CmdletBinding()]
        param(
        [parameter(Mandatory=$true)][string[]]$PropertiesToLoad,
        [parameter(Mandatory=$false)][switch]$NoISONumber,
        [parameter(Mandatory=$false)][switch]$All,
        [parameter(Mandatory=$false)][int]$Attempts = 0
        )
        try {
            $Attempts++
        	$found = $null
        	$ldaproot = "LDAP://eds.arizona.edu:636/ou=People,dc=eds,dc=arizona,dc=edu"
            $edslogin = Get-EDSlogin
        	$userDN = "uid=$($edslogin.username),ou=App Users,dc=eds,dc=arizona,dc=edu"
        	$auth = [system.DirectoryServices.AuthenticationTypes]::None
        	$DE = New-Object System.DirectoryServices.DirectoryEntry($ldaproot)
        	$DE.psbase.AuthenticationType = $auth
        	$DE.psbase.Username = $userDN
        	$DE.psbase.Password = $edslogin | Get-Password
        	$search = New-Object system.DirectoryServices.DirectorySearcher($DE)
           
            $PropertiesToLoad | % {
                $search.PropertiesToLoad.Add("$_") | Out-Null
            }

            if($NoISONumber) {
                if($All) {
                    Write-Verbose ("{0}`n`tGetting EDS info for all students that don't have an ISO number. This may take a few minutes. Attempt number {1}." -f $MyInvocation.MyCommand.Name, $Attempts)
                    $search.filter = "(&(eduPersonAffiliation=Student)(!objectclass=arizonaedutestperson)(!isoNumber=*))"
                } else {
                    Write-Verbose ("{0}`n`tGetting EDS info for only students that don't have an ISO number. This may take a few minutes. Attempt number {1}." -f $MyInvocation.MyCommand.Name, $Attempts)
                    $search.filter = "(&(eduPersonPrimaryAffiliation=Student)(!objectclass=arizonaedutestperson)(!isoNumber=*))"
                }
            } else {
                if($All) {
                    Write-Verbose ("{0}`n`tGetting EDS info for all students. This may take a few minutes. Attempt number {1}." -f $MyInvocation.MyCommand.Name, $Attempts)
                    $search.filter = "(&(eduPersonAffiliation=Student)(!objectclass=arizonaedutestperson))"
                } else {
                    Write-Verbose ("{0}`n`tGetting EDS info for only students. This may take a few minutes. Attempt number {1}." -f $MyInvocation.MyCommand.Name, $Attempts)
                    $search.filter = "(&(eduPersonPrimaryAffiliation=Student)(!objectclass=arizonaedutestperson))"
                }
            }
            
            $found = $search.findall()
            [array]$array = $null
        	foreach ($record in $found)
        	{
        		$prophash = @{}
        		$obj = $null
        		foreach ($prop in $record.Properties.PropertyNames)
        			{ $prophash += @{$prop = $record.Properties.$prop} }
        		$obj = New-Object psobject -Property $prophash
        		$array += $obj
        	}
        	# return the result
            $array
        } catch {
            Write-Verbose ("{0}`n`tA problem occured: {1}" -f $MyInvocation.MyCommand.Name, $_)
            # sometimes EDS just times out, try at least 3 times before throwing exception
            if($Attempts -lt 3) {
                if($NoISONumber) {
                    if($All) {
                        Get-EDSStudentRecordsHelper -PropertiesToLoad $PropertiesToLoad -Attempts $Attempts -NoISONumber -All
                    } else {
                        Get-EDSStudentRecordsHelper -PropertiesToLoad $PropertiesToLoad -Attempts $Attempts -NoISONumber
                    }
                } else {
                    if($All) {
                        Get-EDSStudentRecordsHelper -PropertiesToLoad $PropertiesToLoad -Attempts $Attempts -All
                    } else {
                        Get-EDSStudentRecordsHelper -PropertiesToLoad $PropertiesToLoad -Attempts $Attempts
                    }
                }
            } else {
                Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $_)
            }
        } 
        $DE.psbase.Dispose()
    }
    
    # properties as string for verbose output
    $props = ''
    $PropertiesToLoad | %{
        $props += "{0}, " -f $_
    }
    Write-Verbose ("{0}`n`tPropertiesToLoad: {1}" -f $MyInvocation.MyCommand.Name, $props)
    # call the helper
    if($NoISONumber) {
        if($All) {
            Get-EDSStudentRecordsHelper -PropertiesToLoad $PropertiesToLoad -NoISONumber -All
        } else {
            Get-EDSStudentRecordsHelper -PropertiesToLoad $PropertiesToLoad -NoISONumber
        }
    } else {
        if($All) {
            Get-EDSStudentRecordsHelper -PropertiesToLoad $PropertiesToLoad -All
        } else {
            Get-EDSStudentRecordsHelper -PropertiesToLoad $PropertiesToLoad
        }
    }
}

function Format-StudentStatus {
<#
    .Synopsis
        Converts the studentstatus EDS attribute to a more human friendly format.
    .Parameter StudentStatus
        The studentstatus attribute for an EDS Record.
    .Parameter AsString
        Switch parameter. If used the result is output as a string, otherwise a custom PSObject
        is returned.
    .Example
        $edsStudentRecordContainingStudentStatusAttribute | Format-StudentStatus       
    #>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]$StudentStatus,
    [parameter(Mandatory=$false)][switch]$AsString
    )
    process {
        $career, $level, $load, $residency, $term = $StudentStatus.Split(':')
        Write-Verbose ("{0}`n`t{1}, {2}, {3}, {4}, {5}" -f $MyInvocation.MyCommand.Name, $career, $level, $load, $residency, $term)
        # an object to hold everything
        $obj = New-Object PSObject -Property @{
            'Career' = ''
            'Level' = ''
            'Load' = ''
            'Residency' = ''
            'Term' = ''
        }
        # format the career
        switch ($career) {
            'CORR' {$obj.Career = 'Correspondence'}
            'GRAD' {$obj.Career = 'Graduate'}
            'LAW' {$obj.Career = 'Law'}
            'MEDS' {$obj.Career = 'Medical School'}
            'PHRM' {$obj.Career = 'Pharmacy'}
            'PROF' {$obj.Career = 'Professional'}
            'UGRD' {$obj.Career = 'Undergraduate'}
            default {$obj.Career = ''}
        }
        # format the level
        switch ($level) {
            '00' {$obj.Level = 'NOt Set'}
            '01' {$obj.Level = 'First Year'}
            '02' {$obj.Level = 'Second Year'}
            '03' {$obj.Level = 'Third Year'}
            '04' {$obj.Level = 'Fourth Year'}
            '05' {$obj.Level = 'Fifth Year'}
            '06' {$obj.Level = 'Sixth Year'}
            '10' {$obj.Level = 'Freshman'}
            '20' {$obj.Level = 'Sophomore'}
            '30' {$obj.Level = 'Junior'}
            '40' {$obj.Level = 'Senior'}
            '50' {$obj.Level = '5th+ Year Senior'}
            'GR' {$obj.Level = 'Graduate'}
            'HON' {$obj.Level = 'Honors'}
            'IE' {$obj.Level = 'Industrial Experience'}
            'MAS' {$obj.Level = 'Masters'}
            'P1' {$obj.Level = 'Professional Year 1'}
            'P2' {$obj.Level = 'Professional Year 2'}
            'P3' {$obj.Level = 'Professional Year 3'}
            'P4' {$obj.Level = 'Professional Year 4'}
            'PHD' {$obj.Level = 'PhD'}
            default {$obj.Level = ''}
        }
        # format the load
        switch ($load) {
            'F' {$obj.Load = 'Full-time'}
            'H' {$obj.Load = 'Half-time'}
            'L' {$obj.Load = 'Less than Half-time'}
            'N' {$obj.Load = 'No Unit Load'}
            'P' {$obj.Load = 'Part-time'}
            'T' {$obj.Load = 'Three quarter time'}
            default {$obj.Load = ''}
        }
        # format the residency
        switch ($residency) {
            'NR' {$obj.Residency = 'Non-Resident'}
            'PND' {$obj.Residency = 'Pending'}
            'RES' {$obj.Residency = 'Resident'}
        }
        # format the term
        $y = $term.SubString(0,1) + '0' + $term.SubString(1,2)
        $t = $term.SubString(3,1)
        switch ($t) {
            '1' {$obj.Term = ("Spring {0}" -f $y)}
            '2' {$obj.Term = ("Summer {0}" -f $y)}
            '4' {$obj.Term = ("Fall {0}" -f $y)}
            '5' {$obj.Term = ("Winter {0}" -f $y)}
            default {$obj.Term = ''}
        }
        
        # output
        if($AsString) {
            ("{0}, {1}, {2}, {3}, {4}" -f $obj.Career, $obj.Level, $obj.Load, $obj.Residency, $obj.Term)
        } else {
            $obj | select Career, Level, Load, Residency, Term
        }
    }
}

#endregion

Export-ModuleMember -Function * -Alias *


# SIG # Begin signature block
# MIIUdgYJKoZIhvcNAQcCoIIUZzCCFGMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUs1z+y8KXFFIF3JNv9bFBKL2S
# pXmggg+4MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggcbMIIGA6ADAgECAgoVdA5tAAIAAB25MA0GCSqGSIb3DQEBBQUAMGoxEzARBgoJ
# kiaJk/IsZAEZFgNFRFUxFzAVBgoJkiaJk/IsZAEZFgdBcml6b25hMRMwEQYKCZIm
# iZPyLGQBGRYDRlNPMSUwIwYDVQQDExxVQSBGaW5hbmNpYWwgU2VydmljZXMgT2Zm
# aWNlMB4XDTEzMDEyOTE3MzE0OVoXDTE1MDEyOTE3MzE0OVowgY8xEzARBgoJkiaJ
# k/IsZAEZFgNFRFUxFzAVBgoJkiaJk/IsZAEZFgdBcml6b25hMRMwEQYKCZImiZPy
# LGQBGRYDRlNPMRUwEwYDVQQLEwxVc2Vyc1N5c3RlbXMxFTATBgNVBAsTDERvbWFp
# bkFkbWluczEcMBoGA1UEAxMTTWF5aGV3LCBEYW5pZWwgKERBKTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBALI9SzZE7orGPg4ACLmka7tBPbDY/Gg2vNxi
# l+ME+aeyXHA6Grj0y3BKHcW3Sj8+PfDsbAYEsT9fsrkfP43DtnZjf3vYnKdDOjrd
# xulFrYCZnKNLAJd8xkIzioGvfVbDiI1cK0g3tIlgMzzGP2mZu0XGI+l5diBxP/Wx
# brd1Efux9S6Z0RQqo+WLkvyi3Sw9jWCriR9fXl9wYAMbQUoajNcnchQJjMCe4CRO
# 0vlnzXOlKWeDSp1zOw1MSenGhsPGyCBXgsxASZ2PwC+Nq4RQ2B8a6RgM3WduxFQX
# 2UMrxJGqgFA4WWbwQb/mK8Hpg0nkfBOJMGIROBzYdZ7crlyU36sCAwEAAaOCA5sw
# ggOXMD4GCSsGAQQBgjcVBwQxMC8GJysGAQQBgjcVCITjmhyC9/g0hqWNJoa4+xmH
# /NEJgTODirMLh8yUOwIBZAIBATATBgNVHSUEDDAKBggrBgEFBQcDAzALBgNVHQ8E
# BAMCB4AwGwYJKwYBBAGCNxUKBA4wDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUDqa2
# xhJXMEzMBE2k1Ot24sP2QnYwHwYDVR0jBBgwFoAUQzXqRDY2gnFCB6ugWTNAFiVb
# lgEwggFEBgNVHR8EggE7MIIBNzCCATOgggEvoIIBK4aB02xkYXA6Ly8vQ049VUEl
# MjBGaW5hbmNpYWwlMjBTZXJ2aWNlcyUyME9mZmljZSgxKSxDTj1zdnIwMDE3LENO
# PUNEUCxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1D
# b25maWd1cmF0aW9uLERDPUZTTyxEQz1Bcml6b25hLERDPUVEVT9jZXJ0aWZpY2F0
# ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9u
# UG9pbnSGU2h0dHA6Ly9zdnIwMDE3LmZzby5hcml6b25hLmVkdS9DZXJ0RW5yb2xs
# L1VBJTIwRmluYW5jaWFsJTIwU2VydmljZXMlMjBPZmZpY2UoMSkuY3JsMIIBVgYI
# KwYBBQUHAQEEggFIMIIBRDCByAYIKwYBBQUHMAKGgbtsZGFwOi8vL0NOPVVBJTIw
# RmluYW5jaWFsJTIwU2VydmljZXMlMjBPZmZpY2UsQ049QUlBLENOPVB1YmxpYyUy
# MEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9
# RlNPLERDPUFyaXpvbmEsREM9RURVP2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RD
# bGFzcz1jZXJ0aWZpY2F0aW9uQXV0aG9yaXR5MHcGCCsGAQUFBzAChmtodHRwOi8v
# c3ZyMDAxNy5mc28uYXJpem9uYS5lZHUvQ2VydEVucm9sbC9zdnIwMDE3LmZzby5h
# cml6b25hLmVkdV9VQSUyMEZpbmFuY2lhbCUyMFNlcnZpY2VzJTIwT2ZmaWNlKDIp
# LmNydDA0BgNVHREELTAroCkGCisGAQQBgjcUAgOgGwwZZGFtYXloZXdkQEZTTy5B
# cml6b25hLkVEVTANBgkqhkiG9w0BAQUFAAOCAQEAdoNO4RId6ei3OPEDDRdBEVcN
# kEkniwrmwD31c3P1c6O8+v6ueSlkzTLrdeGrBERIawTjojMizia9eNEFvK0UyK1G
# W7o5UfspSJx8d2v9Q2vbwNViYhLinzOHx2OCjVG0vbMZ8NW0sfK0M1OQ/kiucF/a
# W09jVSuXPQOrEf9/lPIoJ6fYolxxrC9olrKqNNEkOCMo4+w8u6tlpyA/ktBo5Hvq
# 5nT3BfjLzyRDOtYQ0iRTU2WoQ/Eb6LwCwGlPTBA8gXYO+ScNbOtAFufMelvvuuSF
# jpVf2WwePkkB8iss9jLvG1TKj0Ryk/zPAWYkxVq/+eE+tGLAMvojHRsX2Y8d6jGC
# BCgwggQkAgEBMHgwajETMBEGCgmSJomT8ixkARkWA0VEVTEXMBUGCgmSJomT8ixk
# ARkWB0FyaXpvbmExEzARBgoJkiaJk/IsZAEZFgNGU08xJTAjBgNVBAMTHFVBIEZp
# bmFuY2lhbCBTZXJ2aWNlcyBPZmZpY2UCChV0Dm0AAgAAHbkwCQYFKw4DAhoFAKB4
# MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQB
# gjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkE
# MRYEFBz6ZfnFoAa5iStMavtQPi5EHzvdMA0GCSqGSIb3DQEBAQUABIIBAJm1UhSg
# 7Hf9yRnSyHuUbX9RNa3Jw4BoW+sFMwruFsnGXKlUNZRhYQmdgeAk5ztsKDuptpZK
# hJmdi6E0VAjdclCtJx9B17Rfu1tT7II4R7FHnERM0gLRQoGJaPMa+MsC60YV91Mz
# 4zU8ehxGHwGjCjpum4CGQAmcSRh3+yyaOpx9bp2uEwUXHPGOVPT1VMHtZQGvATNV
# UWx8/BltxbDjQqccAJWjBylOGc5M0KV4XirivpdzhKPtODIGwbZOgbAMe+l4kphN
# vmaI+r0VOPfVd8lbYmvjZMU+RowDV/75HQZDScOVQgsn3xmGV2GUj+DMx4Jp/boD
# 9xu8koTGHtRFTB2hggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBeMQsw
# CQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNV
# BAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQDs/0
# OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMTMxMTIyMDUzOTMzWjAjBgkqhkiG9w0BCQQx
# FgQUpOhIgrZ2LAP3a/3ANpSPXCFx7DYwDQYJKoZIhvcNAQEBBQAEggEAdMa16sUH
# uyDSzODCNPA6111M+wBIpnmWHux413vz6vRWGmtEQI3NJ5DK1DywQnO5RgESuL0w
# 38mbh8UiNwpBOqpwKUq4iDwYoM7njBa9YfNHeIK3r1tmyKKSfmvfejCw+JjvJsGe
# XZ0EehZBHYLhwTYQl+1DvrqoIXknX4HdJq92o8HjrbrE8fs83KdCJLVGmv8C6me1
# JLs31YVw/lsbtNPfNiD9F2FlGbA2SqwMxlLEjcJ1NFoS2ZIjl5KXIpsXnMySIySg
# 20BgvwRyFOtRxMVj5rgdTQLbgIxVEYkmtmBAC6BluSVofktvWwUw3G1kC625paUr
# 0oRLwikfk8X5gA==
# SIG # End signature block
