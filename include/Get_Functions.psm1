Import-Module activedirectory

function Get-ADDomainControllers {
<#
	.Synopsis
		Returns a list of all domain controllers.
	.Description
		This function returns a list of objects that is comprised of all domain controllers.
        System.DirectoryServices is queried and therefore the objects returned have different
        properties than ADComputer objects that are returned from the ActiveDirectory module.
	.Example
		PS C:\> Get-ADDomainControllers
	.Notes
		Created by Jeffrey B Smith
#>
	([system.DirectoryServices.activedirectory.domain]::getcurrentdomain()).domaincontrollers
}

function Get-ADGroupMembership {
<#
    .Synopsis
        Returns the names of the groups the specified samAccountName is a member of.
    .Parameter SamAccountName
        The SamAccountName of the user.  This parameter also accepts an ADUser object.
    
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$SamAccountName
    )
    process {
        try {
            Get-ADUser $SamAccountName -Properties MemberOf | select -ExpandProperty memberof | sort | %{($_.Split(',')[0]).replace('CN=', '')}
        } catch {
            Get-ADGroup $SamAccountName -Properties MemberOf | select -ExpandProperty memberof | sort | %{($_.Split(',')[0]).replace('CN=', '')}
        }
    }
}

function Get-ADGUID {
<#
    .Synopsis
        Retrieves the UUID of the specified computer from the computer's AD object.
    .Parameter Name
        The name of the computer in shortname or longname format.  This parameter also accepts an ADComputer object.
    .Notes
        May return null if the AD computer object has no value listed for netbootguid.
#>
    [CmdletBinding()]
    param(
	[parameter(mandatory=$true,valueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][Alias('DNSHostName')][string]$Name
	)
    process {
        try {
            $Name = $Name | Get-ShortName
            $adguid = Get-ADComputer -Identity $Name -Properties netbootguid | select -ExpandProperty 'netbootguid' -ErrorAction SilentlyContinue
            [system.bitconverter]::tostring($adguid)
        } catch {
            $null
        }
    } 
}

function Get-AllClients {
<#
    .Synopsis
        Returns a list of all client computers in the domain.
    .Description
        Returns a list of all AD Computer objects that are not servers.
    .Example
        PS C:\> Get-AllClients | select name | sort name       
    #>
    $internalClients = Get-ADComputer -Filter {enabled -eq $true} -SearchBase "ou=FSOInternal,dc=fso,dc=arizona,dc=edu" -Properties Description | sort name
    $externalClients = Get-ADComputer -Filter {enabled -eq $true} -SearchBase "ou=FSOExternal,dc=fso,dc=arizona,dc=edu" -Properties Description | sort name
    $internalClients + $externalClients
}

function Get-AllServers {
<#
	.Synopsis
		Returns a list of all servers in the domain.
	.Description
		This function returns a list of ADComputer objects that is comprised of all member servers and 
		domain controllers.
	.Example
		PS C:\> Get-AllServers
#>
	$members = Get-ADComputer -Filter * -SearchBase "ou=servers,dc=fso,dc=arizona,dc=edu" -Properties Description | sort name
    $dcs = Get-ADComputer -Filter * -SearchBase "ou=Domain Controllers,dc=fso,dc=arizona,dc=edu" -Properties Description | sort name
    $members + $dcs | sort name
}

function Get-AllServersCSV {
<#
    .Synopsis
        Returns a list of all servers in the domain sorted by name.
    .Description
        The list returned includes all domain controllers and member servers. It is
        sorted by server name. Only 2 columns are returned: Name and Description.
        The file is created in the user's temp directory and is named
        'AllServers_<timestamp>.csv'.
    .Example
        Get-AllServersCSV
    #>
    $name = "AllServers_{0}.csv" -f (Get-Date -Format yyyyMMddHHmmss)
    $path = Join-Path $env:temp $name
    Get-AllServers | Select Name, Description, @{n='Status';e={'NA'}} | sort Name | Export-Csv -Path $path -NoTypeInformation -Force
    Invoke-Item $path
}

function Get-AllUsers {
    (Get-DAUsers) + (Get-FSOUsers) + (Get-ExternalUsers)
}

function Get-AutoServices {
    <#
    .Synopsis
        Returns the state of all services set to start automatically on the specified server.
    .Description
        Returns the display name, start mode, and current state of all services
        set to start automatically on the specified server.
    .Parameter Name
        The server to query.
    .Parameter NotRunning
        Switch parameter.  If used the function will return only those services set to start automatically
        that are not running.
    .Example
        PS C:\> 'svr0001' | Get-AutoServices       
    #>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][Alias('DNSHostName')][string]$Name,
    [parameter(Mandatory=$false)][switch]$NotRunning
    )
    process {
        Write-Verbose ("{0}" -f $Name)
        if($NotRunning) {
            $query = "select * from Win32_Service where startmode='Auto' and state!='Running'"
        } else {
            $query = "select * from Win32_Service where startmode='Auto'"
        }
        Get-WmiObject -ComputerName $Name -Query $query | select DisplayName, State | sort DisplayName
    }
}

function Get-ComputerInfo {
    <#
    .Synopsis
        Returns computer information
    .Description
        Returns the name, AD description, model, user, and department associated with the specified
        computer identified by the 'Name' parameter.
    .Parameter Name
        The computer name.
    .Example
        PS C:\> 'FSO0051' | Get-ComputerInfo
    .Exemple
        PS C:\> Get-ADComputer -Filter * -SearchBase 'OU=Computers,OU=FSOInternal,DC=FSO,DC=Arizona,DC=EDU' | Get-ComputerInfo
    #>
    [CmdletBinding()]
    param(
    [parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$Name
    )
    process {
        # get a reference to the AD object to make sure the computer exists in the domain
        $comp = Get-ADComputer -Identity $Name -Properties Description
        if($comp) {
            # create a hashtable to pass into new-object
            $props = @{
                Name = $comp.Name
                Description = $comp.Description
                Model = 'Unknown'
                User = 'Unknown'
                Department = 'Unknown'
            }
            # if the computer can be contacted attempt to get more info
            if(Test-Connection -ComputerName $Name -Count 2 -Quiet) {
                $loggedOnUser = Get-LoggedOnUser -Name $Name
                if($loggedOnUser) {
                    $loggedOnUser = $loggedOnUser.split('\')[-1]
                    $adUser = Get-ADUser -Identity $loggedOnUser -Properties Description | select Name, Description
                    $props.User = $adUser.Name
                    $props.Department = $adUser.Description
                    
                }
                $model = Get-WmiObject win32_computersystem -ComputerName $Name | select -ExpandProperty Model
                if($model) {
                    $props.Model = $model
                }
            }
            New-Object PSObject -Property $props | Select Name, Description, Model, User, Department
        }
    }
}

function Get-DAUsers {
<#
    .Synopsis
        Returns a list of ADUser objects that are in the FSOInternal ou.
        
    .Description
        Uses the Get-ADUser commandlet to return a list of ADUser objects that 
        exist in "ou=domainadmins,ou=userssystems,dc=fso,dc=arizona,dc=edu".
        By default it will return all users in the ou and the following properties for each user:
            DistinguishedName
            Enabled
            GivenName
            Name
            ObjectClass
            ObjectGUID
            SamAccountName
            SID
            Surname
            UserPrincipalName
            Description
            EmailAddress
            Department
            Office
            OfficePhone
            Manager
            EmployeeID
            Title
            
        The selection can be filtered using the filter variable. All properties 
        can be returned by using the allProperties switch.
#>
    [CmdletBinding()]
    param(
	[parameter(Mandatory=$false)][string]$Filter = '*',
    [parameter(Mandatory=$false)][switch]$AllProperties
	)
    if($allProperties) {
        $properties = '*'
    } else {
        $properties = 'SamAccountName', 'Description', 'EmailAddress', 'Department', 'Office', 'OfficePhone', 'Manager', 'EmployeeID', 'Title', 'ProfilePath'
    }
    Get-ADUser -Filter $filter -Properties $properties -SearchBase "ou=domainadmins,ou=userssystems,dc=fso,dc=arizona,dc=edu"
}

function Get-Departments {
<#
    .Synopsis
        Returns a list of current departments from fso internal and external OUs. Descriptions are now used for the department field,
        Don't shoot the messenger, it wasn't my idea.
#>
    $departments = @()
    (Get-FSOUsers) + (Get-ExternalUsers) | %{
        if($_.description) {
            if($departments -notcontains $_.description) {
                $departments += $_.description
            }
        }
    
#        if($_.department){
#            if($departments -notcontains $_.department) {
#                $departments += $_.department
#            }
#        }

    }
    $departments | sort
}

function Get-DfsrBacklog {
<#
    .Synopsis
        Displays the backlog of replication data to send from one replication group member to another replication group member.
    .Parameter ReplicationGroupName
        The display name of the replication group.
    .Parameter ReplicatedFolderName
        The name of the replicated folder.
    .Parameter ReceivingMember
        The FQDN of the server receiving the data.
    .Parameter SendingMember
        The FQDN of the server sending the data.
    .Example
        PS C:\> Get-DfsrBacklog -ReplicationGroupName ereports -ReplicatedFolderName ereports -ReceivingMember svr0105.fso.arizona.edu -SendingMember svr0101.fso.arizona.edu
#>
    [CmdletBinding()]
    param (
    [parameter(Mandatory=$true)][string]$ReplicationGroupName,
    [parameter(Mandatory=$true)][string]$ReplicatedFolderName,
    [parameter(Mandatory=$true)][string]$ReceivingMember,
    [parameter(Mandatory=$true)][string]$SendingMember
    )
    $cmd = "dfsrdiag.exe backlog /rgname:{0} /rfname:{1} /receivingmember:{2} /sendingmember:{3}" -f $ReplicationGroupName, $ReplicatedFolderName, $ReceivingMember, $SendingMember
    Invoke-Expression $cmd
}

function Get-DirectorySize {
<#
    .Synopsis
        Returns the size in bytes of the specified directory.
    .Description
        Uses Get-ChildItem to recursivly calculate the size of the specified directory.
    .Parameter Root
        The path to the directory the size of which this function will return.
    .Example
        'C:\Windows' | Get-DirectorySize
#>
    [CmdletBinding()]
    param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$Root = $(resolve-path .)
    )
    process {
        Write-Verbose ("{0}`n`tRoot: {1}" -f $MyInvocation.MyCommand.Name, $Root)
        Get-ChildItem -Recurse $Root -ErrorAction SilentlyContinue | ?{ -not $_.PSIsContainer } | Measure-Object -Sum -Property Length
    }
}

function Get-DiskFreeSpace {
<#
    .Synopsis
        This function returns stats on disk free space for the specified computer.
    .Description
        This function uses a wmi query to Win32_LogicalDisk and parses the information to return a list of
        objects for each drive on the server. The objects contain the server name, the name of the drive,
        the size of the drive, the size of free space on the drive, and the percentage of free space on the
        drive.
    .Parameter Name
        The name of the computer to query for drive space statistics.
    .Inputs
        The Name variable accepts input via pipeline and via pipeline by property name.
    .Example
        Get-ADComputer svr0001 | Get-DiskFreeSpace
    .Example
        'svr0001' | Get-DiskFreeSpace
    .Notes
        Depends on helper function Get-Size.
#>
	[CmdletBinding()]
	param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$Name
    )
	process{
		$disks = Get-WmiObject -query "SELECT * FROM Win32_LogicalDisk WHERE DriveType = 3" -ComputerName $Name |
			select  @{name='Server';expression={($Name.split('.')[0])}},
                @{name='Drive';expression={$_.Name}},
                @{name='Size';expression={'{0}' -f ($_ | Get-Size)}},
                @{name='Free Space';expression={'{0}' -f ($_.Freespace | Get-Size)}},
                @{name='PercentFree';expression = {'{0:P2}' -f ($_.Freespace/$_.Size)}}
		$disks
	}
}

function Get-DomainControllers {
<#
    .Synopsis
        Returns a list of all domain controllers.
    .Description
        This function returns a list of ADComputer objects that is comprised of all
        domain controllers.
    .Example
        PS C:\> Get-DomainControllers        
    #>
    Get-ADComputer -Filter {(enabled -eq $true) -and (name -like "svr*")} -SearchBase "ou=domain controllers,dc=fso,dc=arizona,dc=edu" -Properties Description | sort name
}

function Get-DomainRoot {
<#
	.Synopsis
		Returns the root dns of the domain.
	.Description
		This function returns the root dns of the current domain.
	.Example
		PS C:\> Get-DomainRoot
		PS C:\> FSO.Arizona.EDU
	.Notes
		Created by Daniel C Mayhew, 07-01-2010
#>
	(Get-ADDomain | Select DNSRoot).DNSRoot
}

function Get-ExternalUsers {
<#
    .Synopsis
        Returns a list of ADUser objects that are in the FSOInternal ou.
        
    .Description
        Uses the Get-ADUser commandlet to return a list of ADUser objects that 
        exist in "ou=users,ou=fsoexternal,dc=fso,dc=arizona,dc=edu".  By default
        it will return all users in the ou and the following properties for each user:
            DistinguishedName
            Enabled
            GivenName
            Name
            ObjectClass
            ObjectGUID
            SamAccountName
            SID
            Surname
            UserPrincipalName
            Description
            EmailAddress
            Department
            Office
            OfficePhone
            Manager
            EmployeeID
            Title
            
        The selection can be filtered using the filter variable. All properties 
        can be returned by using the allProperties switch.
#>
    [CmdletBinding()]
    param(
	[parameter(Mandatory=$false)][string]$Filter = '*',
    [parameter(Mandatory=$false)][switch]$AllProperties
	)
    if($allProperties) {
        $properties = '*'
    } else {
        $properties = 'SamAccountName', 'Description', 'EmailAddress', 'Department', 'Office', 'OfficePhone', 'Manager', 'EmployeeID', 'Title', 'ProfilePath'
    }
    Get-ADUser -Filter $filter -Properties $properties -SearchBase "ou=fsoexternal,dc=fso,dc=arizona,dc=edu"
}

function Get-FileEncoding
{
 [CmdletBinding()] 
 Param (
  [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] 
   [string]$Path
 )
 
 [byte[]]$byte = get-content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $Path
 #Write-Host Bytes: $byte[0] $byte[1] $byte[2] $byte[3]
 
 # EF BB BF (UTF8)
 if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf )
 { Write-Output 'UTF8' }
 
 # FE FF  (UTF-16 Big-Endian)
 elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff)
 { Write-Output 'Unicode UTF-16 Big-Endian' }
 
 # FF FE  (UTF-16 Little-Endian)
 elseif ($byte[0] -eq 0xff -and $byte[1] -eq 0xfe)
 { Write-Output 'Unicode UTF-16 Little-Endian' }
 
 # 00 00 FE FF (UTF32 Big-Endian)
 elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff)
 { Write-Output 'UTF32 Big-Endian' }
 
 # FE FF 00 00 (UTF32 Little-Endian)
 elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff -and $byte[2] -eq 0 -and $byte[3] -eq 0)
 { Write-Output 'UTF32 Little-Endian' }
 
 # 2B 2F 76 (38 | 38 | 2B | 2F)
 elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76 -and ($byte[3] -eq 0x38 -or $byte[3] -eq 0x39 -or $byte[3] -eq 0x2b -or $byte[3] -eq 0x2f) )
 { Write-Output 'UTF7'}
 
 # F7 64 4C (UTF-1)
 elseif ( $byte[0] -eq 0xf7 -and $byte[1] -eq 0x64 -and $byte[2] -eq 0x4c )
 { Write-Output 'UTF-1' }
 
 # DD 73 66 73 (UTF-EBCDIC)
 elseif ($byte[0] -eq 0xdd -and $byte[1] -eq 0x73 -and $byte[2] -eq 0x66 -and $byte[3] -eq 0x73)
 { Write-Output 'UTF-EBCDIC' }
 
 # 0E FE FF (SCSU)
 elseif ( $byte[0] -eq 0x0e -and $byte[1] -eq 0xfe -and $byte[2] -eq 0xff )
 { Write-Output 'SCSU' }
 
 # FB EE 28  (BOCU-1)
 elseif ( $byte[0] -eq 0xfb -and $byte[1] -eq 0xee -and $byte[2] -eq 0x28 )
 { Write-Output 'BOCU-1' }
 
 # 84 31 95 33 (GB-18030)
 elseif ($byte[0] -eq 0x84 -and $byte[1] -eq 0x31 -and $byte[2] -eq 0x95 -and $byte[3] -eq 0x33)
 { Write-Output 'GB-18030' }
 
 else
 { Write-Output 'ASCII' }
}

function Get-FSOCatSvrIpAddress {
<#
    .Synopsis
        Returns the IP Address of the FSOCATSVR.CatNet.Arizona.EDU server.
    .Description
        A Detailed Description of what the command does
    .Example
        PS C:\> Get-FSOCatSvrIpAddress
#>
    (Get-DhcpServerv4Reservation -ComputerName svr0207.fso.arizona.edu -ScopeId 150.135.237.128 | ?{$_.Name -like "FSOCATSVR*"}).IPAddress.IPAddressToString
}

function Get-FSOUsers {
<#
    .Synopsis
        Returns a list of ADUser objects that are in the FSOInternal ou.
        
    .Description
        Uses the Get-ADUser commandlet to return a list of ADUser objects that 
        exist in "ou=users,ou=fsointernal,dc=fso,dc=arizona,dc=edu".  By default
        it will return all users in the ou and the following properties for each user:
            DistinguishedName
            Enabled
            GivenName
            Name
            ObjectClass
            ObjectGUID
            SamAccountName
            SID
            Surname
            UserPrincipalName
            Description
            EmailAddress
            Department
            Office
            OfficePhone
            Manager
            EmployeeID
            Title
            
        The selection can be filtered using the filter variable. All properties 
        can be returned by using the allProperties switch.
#>
    [CmdletBinding()]
    param(
	[parameter(Mandatory=$false)][string]$Filter = '*',
    [parameter(Mandatory=$false)][switch]$AllProperties
	)
    if($allProperties) {
        $properties = '*'
    } else {
        $properties = 'SamAccountName', 'Description', 'EmailAddress', 'Department', 'Office', 'OfficePhone', 'Manager', 'EmployeeID', 'Title', 'ProfilePath'
    }
    Get-ADUser -Filter $filter -Properties $properties -SearchBase "ou=users,ou=fsointernal,dc=fso,dc=arizona,dc=edu"
}

function Get-HostName {
<#
    .Synopsis
        Returns the server name of a DNS host record.
    .Description
        Will return the hostname of a DNS record.
    .Example
        PS C:\> 'titan' | Get-HostName
        PS C:\> SVR0104.FSO.Arizona.EDU
#>
    param(
    [parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$Hostname
    )
    process {
        try {
            $dns = [System.Net.Dns]::GetHostByName("$hostname") 
            if ($dns.aliases) {
                return $dns.Hostname
            } else {
                return [System.Net.Dns]::GetHostByAddress($dns.AddressList[0]) | select -expand HostName
            }
        }
        catch {
            return $hostname
        }
        
    }
}

function Get-IdmsInfoByEmplId {
<#
	.Synopsis
		Returns basic information from the arizona table of the IDMS database on idmsSql for the specified EmplId number.
	.Description
		Returns the ISO, LASTNAME, FIRSTNAME, MIDDLENAME, ISSUED, EMPLID, PICTID, SIGID from the arizona table in the IDMS database on idmsSql
        associated with the specified EmplId. 
	.Parameter EmplId
		The EmplId number that is used to search the arizona table in the IDMS database.
	.Example
		PS C:\Windows\system32> Get-IdmsInfoByEmplId '12345678'
	.Notes
		Throws exception if the SqlServerCmdletSnapin100 PSSnapin is not registered.
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]$EmplId
    )
    process {
        $query = @"
SELECT RTRIM(LTRIM(ISO)) as ISO,
RTRIM(LTRIM(LNAME)) as LASTNAME,
RTRIM(LTRIM(FNAME)) as FIRSTNAME,
RTRIM(LTRIM(MNAME)) as MIDDLENAME,
RTRIM(LTRIM(ISSUED)) as ISSUED,
RTRIM(LTRIM(UNIVID)) as EMPLID,
RTRIM(LTRIM(PICTID)) as PICTID,
RTRIM(LTRIM(SIGID)) as SIGID,
RTRIM(LTRIM(NOTES)) as NOTES
FROM arizona
WHERE UNIVID like '{0}'
"@ -f $EmplId
        
        Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
        $r = Invoke-Sqlcmd -ServerInstance idmsSql -Database IDMS -Query $query
        if($r) {
            $r | select ISO, EMPLID, LASTNAME, FIRSTNAME, MIDDLENAME, ISSUED, PICTID, SIGID, NOTES
        }
    }
}

function Get-IdmsInfoByIso {
<#
	.Synopsis
		Returns basic information from the arizona table of the IDMS database on idmsSql for the specified ISO number.
	.Description
		Returns the ISO, LASTNAME, FIRSTNAME, MIDDLENAME, ISSUED, EMPLID, PICTID, SIGID from the arizona table in the IDMS database on idmsSql
        associated with the specified ISO. 
	.Parameter ISO
		The ISO number that is used to search the arizona table in the IDMS database.
	.Example
		PS C:\Windows\system32> Get-IdmsInfoByIso '6017090201999999'
	.Notes
		Throws exception if the SqlServerCmdletSnapin100 PSSnapin is not registered.
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]$ISO
    )
    process {
        $query = @"
SELECT RTRIM(LTRIM(ISO)) as ISO,
RTRIM(LTRIM(LNAME)) as LASTNAME,
RTRIM(LTRIM(FNAME)) as FIRSTNAME,
RTRIM(LTRIM(MNAME)) as MIDDLENAME,
RTRIM(LTRIM(ISSUED)) as ISSUED,
RTRIM(LTRIM(UNIVID)) as EMPLID,
RTRIM(LTRIM(PICTID)) as PICTID,
RTRIM(LTRIM(SIGID)) as SIGID,
RTRIM(LTRIM(NOTES)) as NOTES
FROM arizona
WHERE ISO like '{0}'
"@ -f $ISO

        Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
        $r = Invoke-Sqlcmd -ServerInstance idmsSql -Database IDMS -Query $query
        if($r) {
            $r | select ISO, EMPLID, LASTNAME, FIRSTNAME, MIDDLENAME, ISSUED, PICTID, SIGID, NOTES
        }
    }
}

function Get-IdmsAuditLogInfoByEmplId {
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]$EmplId
    )
    process {
        $query = @"
SELECT RTRIM(LTRIM(CARD_NUM)) as ISO,
RTRIM(LTRIM(LAST)) as LASTNAME,
RTRIM(LTRIM(FIRST)) as FIRSTNAME,
RTRIM(LTRIM(MIDDLE)) as MIDDLENAME,
RTRIM(LTRIM(DATE)) as DATE,
RTRIM(LTRIM(TIME)) as TIME,
RTRIM(LTRIM(EDIT_DATE)) as EDIT_DATE,
RTRIM(LTRIM(ACTION)) as ACTION,
RTRIM(LTRIM(DETAIL)) as DETAIL,
RTRIM(LTRIM(ID_NUM)) as EMPLID,
RTRIM(LTRIM(PHOTO)) as PICTID,
RTRIM(LTRIM(SIGNATURE)) as SIGID
FROM AuditLog
WHERE ID_NUM like '{0}'
"@ -f $EmplId

        Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
        $r = Invoke-Sqlcmd -ServerInstance idmsSql -Database IDMS -Query $query -QueryTimeout 120
        if($r) {
            $r | select ISO, LASTNAME, FIRSTNAME, MIDDLENAME, DATE, TIME, EDIT_DATE, ACTION, DETAIL, EMPLID, PICTID, SIGID
        }
    }
}

function Get-IdmsAuditLogInfoByISO {
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]$ISO
    )
    process {
        $query = @"
SELECT RTRIM(LTRIM(CARD_NUM)) as ISO,
RTRIM(LTRIM(LAST)) as LASTNAME,
RTRIM(LTRIM(FIRST)) as FIRSTNAME,
RTRIM(LTRIM(MIDDLE)) as MIDDLENAME,
RTRIM(LTRIM(DATE)) as DATE,
RTRIM(LTRIM(TIME)) as TIME,
RTRIM(LTRIM(EDIT_DATE)) as EDIT_DATE,
RTRIM(LTRIM(ACTION)) as ACTION,
RTRIM(LTRIM(DETAIL)) as DETAIL,
RTRIM(LTRIM(ID_NUM)) as EMPLID,
RTRIM(LTRIM(PHOTO)) as PICTID,
RTRIM(LTRIM(SIGNATURE)) as SIGID
FROM AuditLog
WHERE CARD_NUM like '{0}'
"@ -f $ISO

        Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
        $r = Invoke-Sqlcmd -ServerInstance idmsSql -Database IDMS -Query $query -QueryTimeout 120
        if($r) {
            $r | select ISO, LASTNAME, FIRSTNAME, MIDDLENAME, DATE, TIME, EDIT_DATE, ACTION, DETAIL, EMPLID, PICTID, SIGID
        }
    }
}

function Get-IISServers {
<#
	.Synopsis
		Get-IISServers retrieves a collection of servers that run IIS.
    .Description
		This function retrieves a collection of servers that have W3SVC running.
    .Parameter Servers
    .Example
		Get-IISServers
    .Notes
		Created by Daniel C Mayhew, 03-23-2010
#>
	[CmdletBinding()]
	param(
    [parameter(ValueFromPipeline=$true)][array]$Servers=(Get-AllServers | Select -ExpandProperty Name)
	)
	begin {
		[array]$iisServers = @()
	} process {
		foreach ($server in $servers) {
			$server = $server | Get-LongName
			[array]$svcs = Get-Service -ComputerName $server
			foreach ($svc in $svcs) {
				if($svc.Name -eq 'W3SVC') {
					$IISServers += $server
				}
			}
		}
	} end {
		$iisServers
	}
}

function Get-IpAddressFromDhcp {
<#
    .Synopsis
        Returns all IP Addresses found in DHCP associated with a computer name.
    .Description
        Searches all DHCP scopes for the computer name and returns all IP Addresses associated with a lease for the
        specified computer name.
    .Parameter Name
        The name of the computer.
    .Example
        PS C:\> Get-IpAddressFromDhcp fso0148
    .Example
        PS C:\> 'fso0148','fso0147' | Get-IpAddressFromDhcp
    .Example
        PS C:\> Get-AllClients | Get-IpAddressFromDhcp
    .Example
        PS C:\> Get-ADComputer 'fso0148' | Get-IpAddressFromDhcp
    .Notes
        Created 02/25/2013 by damayhewd
#>
    [CmdletBinding()]
    param (
    [parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true,Position=0)][string]$Name
    )
    begin {
        $dhcpServer = 'svr0207.fso.arizona.edu'
        Write-Verbose ("Getting all leases in all scopes from DHCP server {0}..." -f $dhcpServer)
        # get the scope IDs
        $scopeIDs = Get-DhcpServerv4Scope -ComputerName $dhcpServer | select -ExpandProperty ScopeId | select -ExpandProperty IPAddressToString
        # get the leases for all scopeIDs
        $leases = @()
        $scopeIDs | %{
            $scopeLeases = Get-DhcpServerv4Lease -ComputerName $dhcpServer -ScopeId $_
            $scopeLeases | ?{$_.HostName} | %{
                $machineName = ($_ | select -ExpandProperty HostName).Split('.')[0]
                $ip = ($_ | select -ExpandProperty IPAddress | select -ExpandProperty IPAddressToString)
                $leases += New-Object PSObject -Property @{
                    HostName = $machineName
                    IpAddress = $ip
                }
            }
        }
    }
    process {
        Write-Verbose ("Finding all IP Addresses for {0}..." -f $Name)
        $leases | ?{$_.HostName -like $Name} | Select HostName, IpAddress | sort HostName
    }
}

function Get-LoggedOnUser {
<#
    .Synopsis
        Returns the username and logon type (local or remote) if a user or users are logged on interactively
        or remotely to the specified computer.
    .Description
        Determines if a user is logged on interactively or remotely to the specified computer. If a user
        is logged on interactively or remotely the username and logon type is returned, otherwise nothing
        is returned.
    .Parameter Name
        The computer to query.  Can be in longname (fso0001.fso.arizona.edu) or shortname
        (fso0001) format.  This parameter will also accept ADComputer objects as input.
    .Example
        'fso0001' | Get-LoggedOnUser
    .Example
        Get-ADComputer fso0001 | Get-LoggedOnUser        
    #>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string][Alias('DNSHostName')][string]$Name
    )
    process {
        Write-Verbose "Checking for a logged on user on $Name"
        try {
            $loggedOnUsers = @{}
            $userLoggedOn = Get-WmiObject Win32_ComputerSystem -ComputerName $Name -ErrorAction Stop
            if($userLoggedOn.username) {
                $userName = $userLoggedOn.username
                $obj = New-Object PSObject -Property @{
                    Username = $userName
                    LogonType = 'Local'
                }
                $loggedOnUsers.Add($userName, $obj)
            } else {
                Write-Verbose "Couldn't find locally logged on user, checking for remotely logged on user..."
                $explorerprocesses = @(Get-WmiObject -Query "Select * FROM Win32_Process WHERE Name='explorer.exe'" -ErrorAction SilentlyContinue -ComputerName $Name)
                if ($explorerprocesses.Count -eq 0)
                {
                    Write-Verbose "Nobody remotely logged on to $Name"
                } else {
                    $explorerprocesses | %{
                        $userName = $_.GetOwner().User
                        if(-not($loggedOnUsers.$userName)) {
                            $obj = New-Object PSObject -Property @{
                                Username = $userName
                                LogonType = 'Remote'
                            }
                            $loggedOnUsers.Add($userName, $obj)
                        }
                    }
                }
            }
            # if any users found, return the list
            if($loggedOnUsers) {
                $loggedOnUsers.Values | select Username, LogonType
            }
        } catch {
            Write-Error $_
        }
    }
}

function Get-LogonHistory {
<#
    .Synopsis
        This function looks in the users directory for all ntuser.dat files and returns a list of usernames
        and last access times.
    .Description
        This function takes a computer name (if none provided it will use the local computer), and searches
        the users directory for all ntuser.dat files. It then compiles a list of usernames (based on user directory name)
        and last access time for each user account that does not start with 'Default'. With this list you can determine 
        who last logged on to the computer.
    .Parameter ComputerName
        The computer to query.
    .Example
        PS C:\> Get-LogonHistory rover
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$false,ValueFromPipeline=$true,Position=0)][String]$ComputerName = $env:COMPUTERNAME
    )
    process {
        
        Write-Verbose ("{0}`n`tTesting connection to {1}..." -f $MyInvocation.MyCommand.Name, $ComputerName)
        
        if(Test-Connection $ComputerName -Quiet -Count 3) {
            
            Write-Verbose ("{0}`n`tCompiling a list of user logons based on ntuser.dat lastAccessTime..." -f $MyInvocation.MyCommand.Name)

            $adminShare = "\\{0}\C$" -f $ComputerName
            $profilePath = Join-Path $adminShare "users\*\ntuser.dat"

            Get-ChildItem $profilePath -Force | 
                select @{l="Username";e={(Split-path $_.Directory -Leaf)}}, lastAccessTime | 
                ?{$_.Username -notlike "Default*"} | 
                sort lastAccessTime -Descending
            
        } else {
            Write-Verbose ("{0}`n`tCould not contact {1}" -f $MyInvocation.MyCommand.Name, $ComputerName)
        }
    }
}

function Get-LongName {
<#
	.Synopsis
		Get-LongName returns a FQDN by appending the domain dns root.
	.Description
		Takes MYSERVER and returns an FQDN, i.e. myserver.domain.com.
	.PARAMETER shortName
		A name without the DNS root exception.
	.INPUTS
		System.String
	.Example
		PS C:\> SVR0001 | Get-LongName
		PS C:\> svr0001.FSO.arizona.EDU
	.Notes
		Created by Daniel C Mayhew, 07-01-2010
#>
	[CmdletBinding()]
	param(
    [parameter(Mandatory=$true,ValueFromPipeLine=$true)][string]$ShortName
	)
	process {
		if(!($ShortName.Contains('.'))) {
			"$($shortName.ToUpper()).$domain"
		} else {
			$ShortName.ToUpper()
		}
	}
}

function Get-MachineGUID {
<#
    .Synopsis
        Retrieves the UUID from the specified computer
    .Parameter Name
        The name of the computer.  This parameter also accepts an ADComputer object.
#>
    [CmdletBinding()]
    param(
	[parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][Alias('DSNHostName')][String]$Name
	)
    process {
        try {
            $guid = ([system.guid](gwmi -query "select uuid from win32_computersystemproduct" -ComputerName $Name | select -ExpandProperty UUID)).tobytearray()
            [system.bitconverter]::tostring($guid)
        } catch {
            $null
        }   
    }   
}

function Get-NameFromDN {
<#
    .Synopsis
        Returns the name from a DistinguishedName.
    .Description
        Takes a distinguished name and returns the name, e.g., takes 
        CN=CSO0337,OU=Laptops,OU=Computers,OU=FSOInternal,DC=FSO,DC=Arizona,DC=EDU
        and returns CSO0337.
    .Parameter DistinguishedName
        The DN of the object.
    .Example
        PS C:\> CN=CSO0337,OU=Laptops,OU=Computers,OU=FSOInternal,DC=FSO,DC=Arizona,DC=EDU | Get-NameFromDN
        PS C:\> cso0337
    .Notes
        Created by Daniel C Mayhew, 8-29-2010
#>
    [CmdletBinding()]
    param(
	[parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][String]$DistinguishedName
	)
    process {
        $dn = $DistinguishedName
        $dn = $dn.Substring($dn.IndexOf('CN=') + 3, $dn.IndexOf('OU') - 4)
        if($dn.Contains('\')) {
            $dn = $dn.Replace('\', '')
        }
        $dn
    }
}

function Get-NextAvailableClientName {
    [CmdletBinding()]
    param()
<#
    .Synopsis
        Returns the next unused client name.
    .Example
        C:\> Get-NextAvailableClientName
#>
    $clients = Get-ADComputer -Filter * | ?{$_.distinguishedname -notlike "*servers*" -and $_.distinguishedname -notlike "*domain*" -and $_.Name -like "FSO*"} | sort name | select -ExpandProperty name
    $i = 1
    $clients | %{
        Write-Verbose ("Testing {0} against target: {1}..." -f $_, $target)
        if($_.StartsWith('FSO')) {
            $target = "FSO{0:D4}" -f $i++
            if($_ -notlike $target) {
                $target
                break
            }
        }    
    }
}

function Get-OfficeLocations {
<#
    .Synopsis
        Returns a list of current office locations from FSO internal and external OUs
#>
    $oLocs = @()
    (Get-FSOUsers) + (Get-ExternalUsers) | %{
        if($_.Office){
            if($oLocs -notcontains $_.Office) {
                $oLocs += $_.Office
            }
        }
    }
    $oLocs | sort
}

function Get-Positions {
<#
    .Synopsis
        Returns a list of postitions in FSO based on the names of the user templates in the UsersTemplates OU.
#>
    Get-UserTemplates  | Select -ExpandProperty Name | sort
}

function Get-ScriptDirectory{
<#
	.Synopsis
		Returns the parent path of the current script.
	.Description
		This function must be called from within a saved script.
	.Example
		PS C:\Windows\system32> Get-ScriptDirectory
	.Notes
		From PowerShell.com power tip of the day.
#>
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    try {
        Split-Path $Invocation.MyCommand.Path -ea 0
    }
    catch {
    Write-Warning 'You need to call this function from within a saved script.'
    }
}

function Get-ServerMaintenanceMessage {
<#
	.Synopsis
		Returns a string that can be passed to clip and pasted in to an FSO Intranet News Item.
	.Description
		This function can format a string based on specified parameters which can then be sent
        to clip.exe and from there be used elsewhere.
	.Parameter StartTime
		The start time of the maintenance period.
	.Parameter EndTime
		The end time of the maintenance period.
	.Parameter WindowsUpdates
		Switch parameter, use to indicate Windows Updates will be performed.
	.Parameter PasswordReset
		Switch parameter, use to indicate that systems password reset will be performed.
	.Parameter OtherTasks
		An array that holds a list of strings to be included as additional tasks in the message.
	.Parameter AffectedServices
		An array that holds a list of services that are affected by the maintenance.
	.Example
		PS C:\Windows\system32> Get-ServerMaintenanceMessage -WindowsUpdates
	.Notes
		Author: Daniel C Mayhew
		Date: 1/14/2013
		Contact: dcmayhew@email.arizona.edu
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$false)][string]$StartTime = "8pm",
    [parameter(Mandatory=$false)][string]$EndTime = "12am",
    [parameter(Mandatory=$false)][switch]$WindowsUpdates,
    [parameter(Mandatory=$false)][switch]$PasswordReset,
    [parameter(Mandatory=$false)][string[]]$OtherTasks = @(),
    [parameter(Mandatory=$false)][string[]]$AffectedServices = ('R: drive','Titan','ISW','SharePoint','DocuWare','FSO VPN','Bottomline','Web Sites','AirWatch','Sophos','Fileserver','SecureAdmin', 'FTP', 'Web services', 'JSS')
    )
    $haveTasks = $false
    $tasks = "The following tasks are being performed:"

    if($WindowsUpdates) {
        $haveTasks = $true
        $tasks += "`n* Windows Updates"
    }

    if($PasswordReset) {
        $haveTasks = $true
        $tasks += "`n* Server Admin Password Resets"
    }

    if($OtherTasks) {
        $haveTasks = $true
        $OtherTasks | %{
            $tasks += "`n* " + $_
        }
    }

    if($AffectedServices) {
        $as = "The following services may be affected by this maintenance:"
        $AffectedServices | sort | %{
            $as += "`n* " + $_
        }
    }

    $str = "FSOIT Systems will be performing server maintenance Wednesday night from $StartTime to $EndTime. Services hosted by FSO may be intermittently unavailable."
    if($haveTasks) {
        $str += "`n`n" + $tasks
    }
    if($AffectedServices) {   
        $str += "`n`n" + $as + "`n`n"
    } else {
        $str += "`n`n"
    }
    $str += "Please submit a Redmine ticket at https://redmine.fso.arizona.edu if you have any questions or concerns.`n`nSincerely,`n`nFSOIT Systems"
    $str
}

function Get-Servers {
<#
	.Synopsis
		Returns a list of all member servers in the domain.

	.Description
		This funtion returns a list of ADComputer objects that is comprised of all
        member servers in ou=Servers,dc=fso,dc=arizona,dc=edu.

	.Example
		PS C:\> Get-Servers

	.Notes
		Created by Daniel C Mayhew, 07-01-2010
#>
	Get-ADComputer -searchbase "ou=Servers,dc=fso,dc=arizona,dc=edu" -filter {(enabled -eq $true)} -Properties Description | Sort name
}

function Get-ShortName {
<#
	.Synopsis
		Get-ShortName shortens a FQDN by removing the domain extension.
	.Description
		Takes a FQDN, i.e. myserver.domain.com, and returns MYSERVER.
	.PARAMETER longName
		A FQDN.
	.INPUTS
		System.String
	.Example
		PS C:\> "svr0001.FSO.arizona.EDU" | Get-ShortName 
		PS C:\> SVR0001
	.Notes
		Created by Daniel C Mayhew, 03-20-2010
#>
	[CmdletBinding()]
	param(
	[parameter(Mandatory=$true,ValueFromPipeLine=$true)][string]$LongName
	)
	process {
		if($longName.Contains('.')) {
			($longName.split('.')[0]).ToUpper()
		} else {
			$longName.ToUpper()
		}
	}
}

function Get-Size {
<#
    .Synopsis
        This function returns a formatted version of the size of a drive.
    .Description
        This function takes a size based on KB and returns the value converted to either TB, MB, or GB.
    .Parameter Size
        A long integer representing the size of data in KB.
    .Example
        Get-WmiObject -query "SELECT * FROM Win32_LogicalDisk WHERE DriveType = 3" -ComputerName 'svr0010' | Get-Size
#>
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][alias("FreeSpace")][long]$Size
    )
    process {
        switch ($Size){
            {$_ -ge 1TB} {"{0:n3} TB" -f ($_/1TB)} 
			{$_ -lt 1GB} {"{0:n3} MB" -f ($_/1MB)} 
			default {"{0:n3} GB" -f ($_/1GB)}
		}
    }
}

function Get-SophosServer {
<#
	.Synopsis
		Get-Sophos dynamically locates the Sophos management server.

	.Description
		This function determines the Sophos management server by searching each member server
		for 3 unique services: Sophos Certification Manager, Sophos EMLibUpdate Agent, and
		Sophos Management Service. If the Sophos server is found it is returned, otherwise
		null is returned.

	.Example
		PS C:\> Get-SophosServer

	.Notes
		Created by Daniel C Mayhew, 07-07-2010
#>
	foreach ($server in (Get-Servers | select -ExpandProperty Name)) {
		[array]$svcs = Get-Service -ComputerName $server
		# Count the number of Sophos management services - there should be 3:
		# Sophos Certification Manager, Sophos EMLibUpdate Agent, and
		# Sophos Management Service. When all three are found the current 
		# server is the Sophos server.
		[int]$numSophosSvcs = 3
		foreach ($svc in $svcs) {
			if(($svc.Name -eq 'Sophos Certification Manager') -or `
				($svc.Name -eq 'Sophos EMLibUpdate Agent') -or `
				($svc.Name -eq 'Sophos Management Service')) {
				$numSophosSvcs -= 1
			}
			if ($numSophosSvcs -eq 0) {
				$sophosServer = $server
			}
		}
	}
	if($sophosServer) {
		$sophosServer
	} else {
		$null
	}
}

function Get-SQLServers {
<#
	.Synopsis
		Get-SQLServers retrieves a collection of servers that run MSSQL.

	.Description
		This function returns a collection of servers that have the MSSQLSERVER 
		service running.

	.Example
		PS C:\> Get-SQLServers

	.Notes
		Created by Daniel C Mayhew, 03-20-2010
#>
	[CmdletBinding()]
	param(
	[parameter(ValueFromPipeline=$true)][array]$Servers=(Get-AllServers | select -ExpandProperty name)
	)
	begin {
		[array]$sqlSvrs = @()
	} process {
		foreach ($server in $servers) {
			$server = $server | Get-LongName
			[array]$svcs = Get-Service -ComputerName $server
			foreach ($svc in $svcs) {
				if($svc.Name -eq 'MSSQLSERVER') {
					$sqlSvrs += $server
				}
			}
		}
	} end {
		$sqlSvrs
	}
}

function Get-StagedNewHires {
<#
    .Synopsis
        Returns a list of staged new hire employees from UsersNewHires OU.
#>
    $newHires = Get-ADUser -Filter * -SearchBase 'ou=UsersNewHires,dc=fso,dc=arizona,dc=edu' -Properties '*'
    if($newHires) {
        $newHires | sort name
    }
}

function Get-StatementPeriod {
<#
    .Synopsis
        Returns the transaction statement period for a PCard transaction based on the 
        transaction's post date as found in EPM. 
    .Description
        This function has the same logic used in Titan to determine the statement period
        of a PCard transaction for the PCard Coversheets app, as well as the PCard reports.
    .Example
        PS C:\> Get-StatementPeriod '5/6/2013'
#>
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)][datetime]$PostDate
    )
    process {
        # On the 5th and it's a Friday, the transaction belongs to the previous month's statement period.
        if(($PostDate.Day -eq 5) -and ($PostDate.DayOfWeek -eq 'Friday')) {
            (Get-Date ($PostDate.AddDays(-10)) -Format 'MMMM yyyy').ToUpper()
        }
        # On the 6th and it's a Saturday, the transaction belongs to the previous month's statement period. This should never happen.
        elseif(($PostDate.Day -eq 6) -and ($PostDate.DayOfWeek -eq 'Saturday')) {
            (Get-Date ($PostDate.AddDays(-10)) -Format 'MMMM yyyy').ToUpper()
        }
        # On the 6th and it's a Sunday, the transaction belongs to the previous month's statement period. This should never happen.
        elseif(($PostDate.Day -eq 6) -and ($PostDate.DayOfWeek -eq 'Sunday')) {
            (Get-Date ($PostDate.AddDays(-10)) -Format 'MMMM yyyy').ToUpper()
        }
        # On the 7th and it's a Monday, the transaction belongs to the previous month's statement period.
        elseif(($PostDate.Day -eq 7) -and ($PostDate.DayOfWeek -eq 'Monday')) {
            (Get-Date ($PostDate.AddDays(-10)) -Format 'MMMM yyyy').ToUpper()
        }
        # When the date is after the 6th, it belongs to this month's statement period
        elseif($PostDate.Day -gt 6) {
            (Get-Date $PostDate -Format 'MMMM yyyy').ToUpper()
        }
        # else it's last month's statement period
        else {
            (Get-Date ($PostDate.AddDays(-10)) -Format 'MMMM yyyy').ToUpper()
        }
    }
}

function Get-Titles {
<#
    .Synopsis
        Returns a list of job titles currently in use in FSO and external units.
#>
    $titles = @()
    (Get-FSOUsers) + (Get-ExternalUsers) | %{
        if($_.Title){
            if($titles -notcontains $_.Title) {
                $titles += $_.Title
            }
        }
    }
    $titles | sort
}

function Get-UserComputer {
<#
    .Synopsis
        Returns the name of the computer and the logged on user.
    .Description
        This function searches Active Directory for a computer that has a description that contains the 
        specified surname. If it finds one, it then attempts to find a logged on user on that computer.
        The function returns either or both if found in a PSObject.
    .Parameter Surname
        The last name of the user.
    .Example
        PS C:\> Get-AdUser smithj | Get-UserComputer
    .Example
        PS C:\> 'smith' | Get-UserComputer
    .Example
        PS C:\> Get-UserComputer -Surname 'smith'
    .Notes
        Created 05/23/2013 by damayhewd
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=0)][alias("SN")][string]$Surname
    )
    process {
        $props = @{}
        $filter = "*$Surname*"
        $c = Get-ADComputer -Properties description -Filter {Description -like $filter} | Select -ExpandProperty Name
        if($c) {
            $props.Add('Name', $c)
            $u = gwmi Win32_ComputerSystem -ComputerName $c | select -ExpandProperty Username
            if($u) {
                $props.Add('LoggedOnUser', $u)
            }
        }
        if($props) {
            New-Object PSObject -Property $props
        }
    }
}

function Get-UserDepartmentsFromDescription {
<#
	.Synopsis
		Returns an array of departments a user is a member of based on the description field in Active Directory.
	.Parameter Description
		The AD User's Description. If it contains a string with one or more semi-colons it is split into 
        multiple strings and returned with each string a separte element in the array. If it does not contain
        any semi-colons it is not split but is still returned as an array with one element.
	.Example
		PS C:\Windows\system32> Get-ADUser 'jandurap' -Properties Description | Get-UserDepartmentsFromDescription
#>
    [CmdletBinding()]
    param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$Description
    )
    process {
        $depts = @()
        if($Description -like "*;*") {
            $depts = $Description.Split(';')
        } else {
            $depts += $Description
        }
        $depts
    }
}

function Get-UserTemplates {
<#
    .Synopsis
        Returns a list of user templates that exist in the UsersTemplates OU.
#>
    Get-ADUser -Filter * -Searchbase 'ou=userstemplates,dc=fso,dc=arizona,dc=edu' -Properties accountExpires, c, `
        CannotChangePassword, City, co, Company, Country, countryCode, Department, Description, l, MemberOf, Office, `
        physicalDeliveryOfficeName, POBox, PostalCode, ProfilePath, st, State, StreetAddress, telephoneNumber, `
        Title, UserPrincipalName, directReports | sort name
}

[string]$domain = Get-DomainRoot

# SIG # Begin signature block
# MIIUdgYJKoZIhvcNAQcCoIIUZzCCFGMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUAnLYDM3a/Sz0o217M03za/0/
# XAKggg+4MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# MRYEFK4hgBHpQ+GITjeZq6EPs2cks0IiMA0GCSqGSIb3DQEBAQUABIIBAF0R8Au8
# nQr96DKXu4mrw39y76wFuV/cOHRxU/a59dpbDnze5nl7S2RNpUaqgpnBtyU0aBcg
# eXe9DAs3Mvpa9xa7ldTfKNEAaRv2rpN5cYGu4FWHzw7wCAQfQ+GbSKg2Hj5WPhIT
# 7LaDuyR3X3ZqJP3cCQb9awSCYmtBApKVHGq5tVi2Y/jQXLh471KVmsHLi1Bt39Tj
# rRxdBdOK6XZ+TbRcxivxEeVAU9gAMsbOdcSTxEJwoH3t3KXSXlsZYcRvMAMmigQn
# 8CnT7FwNRKRrWLGJEF4i/Ev5wg1jzUaXtQISDX0V1nTwuGMOk3TeVrvRAU2MVq6C
# jgWaK3KyGuiP1fqhggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBeMQsw
# CQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNV
# BAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQDs/0
# OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMTQwMTIyMjI0ODUxWjAjBgkqhkiG9w0BCQQx
# FgQULRdwo1aIAgCSmh/SzGhLwCxc3CcwDQYJKoZIhvcNAQEBBQAEggEAhSKazfbs
# XPjLUdMY2PLWPETaWLh8huMS6+4C3aK+SviHM/z8p0xRirxCOHS+gDXT+11H5xZ7
# qgSp29hQfsR6bBB5+FYBksG35eSNBLhoisWbre47cWf8CFu6ufiM7ieZV3FoplHB
# 6o9imXQWgtyHHbxfpncG2Q+y/y+CjNoC0NPZPrMSljY+Bdzw35TLu7CERaTgAiRG
# bt4xKNNq5BwKVOTn0mBRCULV8qrLwD1QWbR/TmikFLjgKTAWn8a3Io44PkQLmVX+
# cLzHiDomVSfbeBosuThaKZAxY/YgWoCr8ieuC7nvb4FCyBuf/KXURavW08MbTTn8
# FZVvITPF+Bk8VA==
# SIG # End signature block
