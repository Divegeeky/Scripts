#region functions

function Add-InlineHelp {
    # save the current caret postion as the starting line number
    $startLineNum = $psISE.CurrentFile.Editor.CaretLine
    # get the text and convert to an array
    $mytextarray = $psISE.CurrentFile.Editor.Text.Split("`n")
    # look for parameters after the start of the param statement
    $currLineNum = $startLineNum - 1
    $endLineNum = $currLineNum
    $openParenthesis = 0
    $closeParenthesis = 0
    # get the parameter statement
    $endOfParamStatement = $false
    while(-not $endOfParamStatement) {
        if($mytextarray[$currLineNum] -like "*CmdletBinding(*)*") {
            $currLineNum++
        }
        if($mytextarray[$currLineNum] -match "\(") {
            $openParenthesis += $Matches.Values.Count
        }
        if($mytextarray[$currLineNum] -match "\)") {
            $closeParenthesis += $Matches.Values.Count
        }
        if($openParenthesis -eq $closeParenthesis) {
            $endOfParamStatement = $true
        }
        $currLineNum++
        $endLineNum = $currLineNum
    }

    $psISE.CurrentFile.Editor.Select($startLineNum,1,$endLineNum,1)
    $global:paramStatement = $psISE.CurrentFile.Editor.SelectedText
    $psISE.CurrentFile.Editor.SetCaretPosition($startLineNum,1)

    # compile a list of parameters
    $parameters = @()
    $pattern = "\$.+\)|\$.[^,]+"
    Select-String -InputObject $paramStatement -Pattern $pattern -AllMatches | %{
        $parameters += ($_.Matches.Value | ?{$_ -notlike "`$true*" -and $_ -notlike "`$false*"}).Replace('$','').Trim()
    }

    # create the help text
    $helpText = @"
<#
    .Synopsis
        A quick description of what the command does
    .Description
        A detailed description of what the command does

"@
    $parameters | %{
        if($_ -like "*=*") {
            $thisParam = $_.Split('=')[0].Trim()
        } else {
            $thisParam = $_
        }
        $helpText += @"
    .Parameter {0}
        A description of what the {0} parameter does

"@ -f $thisParam
    }

    $helpText += @"
    .Example
        PS C:\> An example of using the command
    .Notes
        Created {0} by {1}
#>

"@ -f (Get-Date -Format MM/dd/yyyy), $env:USERNAME
    
    # insert the helptext
    $psISE.CurrentFile.Editor.InsertText($helpText)
}

function Convert-ByteArrayToString {
<#
    .Synopsis
        Returns the string representation of a System.Byte[] array.
    .Description
        ASCII string is the default, but Unicode, UTF7, UTF8 and
        UTF32 are available too.
    .Parameter ByteArray
        System.Byte[] array of bytes to put into the file. If you
        pipe this array in, you must pipe the [Ref] to the array.
        Also accepts a single Byte object instead of Byte[].
    .Parameter Encoding
        Encoding of the string: ASCII, Unicode, UTF7, UTF8 or UTF32.
        ASCII is the default.
    .Notes
        Found this function here:
        http://www.sans.org/windows-security/2010/02/11/powershell-byte-array-hex-convert
#>
    
    [CmdletBinding()]
    Param (
    [Parameter(Mandatory = $True, ValueFromPipeline = $True)] [System.Byte[]] $ByteArray,
    [Parameter()] [String] $Encoding = "ASCII"
    )

    switch ( $Encoding.ToUpper() ) {
        "ASCII" { $EncodingType = "System.Text.ASCIIEncoding" }
        "UNICODE" { $EncodingType = "System.Text.UnicodeEncoding" }
        "UTF7" { $EncodingType = "System.Text.UTF7Encoding" }
        "UTF8" { $EncodingType = "System.Text.UTF8Encoding" }
        "UTF32" { $EncodingType = "System.Text.UTF32Encoding" }
        Default { $EncodingType = "System.Text.ASCIIEncoding" }
    }
    $Encode = new-object $EncodingType
    $Encode.GetString($ByteArray)
}

function Disable-AmerXExportTask {
[CmdletBinding() ]
param()
    $task = 'Export IDMS to Amer-X'
    $svr = 'svr0211'
    Get-TaskOnServer -ServerName $svr -Name $task | Disable-Task -Server $svr -Verbose
}

function Enable-AmerXExportTask {
[CmdletBinding() ]
param()
    $task = 'Export IDMS to Amer-X'
    $svr = 'svr0211'
    Get-TaskOnServer -ServerName $svr -Name $task | Enable-Task -Server $svr -Verbose
}

function Find-FilesContainingString {
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$false)][string]$SearchDirectory = 'C:\Scripts',
    [parameter(Mandatory=$false)][string[]]$Include = ("*.ps1","*.psm1"),
    [parameter(Mandatory=$true)][string]$SearchString
    )
    if(Test-Path $SearchDirectory) {
        # get the files
        $result = @()
        $files = Get-ChildItem $SearchDirectory -Recurse -Include $Include
        
        $msg = @"
Searching {0} files in '{1}' for '{2}'...
"@ -f $files.Count, $SearchDirectory, $SearchString
        Write-Verbose $msg
        
        # search for the string
        $files | %{
            $content = Get-Content $_.FullName
            if($content -like "*$SearchString*") {
                $result += $_
            }
        }

        # output the results
        if($result) {
            $result
        } else {
            $msg = @"
Could not find '{0}'
Search Directory: {1}
Number files searched: {2}
"@ -f $SearchString, $SearchDirectory, $files.Count
            Write-Verbose $msg
        }
    } else {
        throw "Path not found: {0}" -f $SearchDirectory
    }
}

function Flush-DFSCache {
    dfsutil cache domain flush | Out-Null
    dfsutil cache referral flush | Out-Null
    dfsutil cache provider flush | Out-Null
}

function Force-Replication {
	$domain = [system.DirectoryServices.activedirectory.domain]::getcurrentdomain()
	$domainDN = $domain.getdirectoryentry().distinguishedname
	$dcs = $domain.domaincontrollers | Select-Object -ExpandProperty Name
	foreach ($dc1 in $dcs) {
		$dcs2 = $dcs | where { $_ -ne $dc1}
		foreach ($dc2 in $dcs2) {
			repadmin /replicate $dc2 $dc1 $domainDN
		}
	}
}

function Hibernate-Computer {
    shutdown /h
}

function Insert-IntoUisMartEpm_Employees {
<#
    .Synopsis
        Inserts a row in the UISMart EPM_EMPLOYEES table based on information
        found in EDS as found with the specified EmplId.
    .Description
        If the user already exists in the EPM_EMPLOYEE table a new record is not added. Throws exceptions if
        neither an EmplId nor NetId are specified, the user could not be found in EDS, if the user already exists
        in the UISMart EPM_Employees table, or if a unique EID could not be automatically generated.
    .Parameter EmplId
        The EmplId of the employee to add to the UISMart EMP_EMPLOYEES table. This must be a 
        valid EmplId.
    .Example
        PS C:\> Get-EDSInfo 'dcmayhew' | Insert-IntoUisMartEpm_Employees -Verbose -Whatif
    .Example
        PS C:\> Insert-IntoUisMartEpm_Employees 'smithj'
    .Example
        PS C:\> Insert-IntoUisMartEpm_Employees -EmplId '12345678'
    .Notes
        Requires EDS_Functions.psm1 and SqlServerCmdletSnapin100 (installed with SQL Server 2008 R2 Management Tools).
        It will import these dependencies if they are available.
#>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=0)][string]$NetID = '',
    [parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=1)][string]$EmplId = ''
    )
    begin {
        $edsModule = Get-Module -Name 'EDS_Functions'
        if(-not $edsModule) {
            $msg = "Importing EDS_Functions.psm1..."
            Write-Verbose $msg
            Import-Module '\\fso\core\Scripts\include\EDS_Functions.psm1' -DisableNameChecking
        }
        
        if((Get-PSSnapin -Name SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue) -eq $null) {
            try {
                Add-PsSnapin SqlServerCmdletSnapin100
                $msg = "Adding SQL snap-in..."
                Write-Verbose $msg
            } catch {}
        }
    }
    process {
        if($EmplId) {
            $msg = "Using EmplId '{0}' to query EDS for additional info..." -f $EmplId
            Write-Verbose $msg
            $userId = $EmplId
        } elseif ($NetID) {
            $msg = "Using NetId '{0}' to query EDS for additional info..." -f $NetID
            Write-Verbose $msg
            $userId = $NetID
        } else {
            $msg = "A Valid EmplId or NetId must be specified"
            Write-Verbose $msg
            Throw $msg
        }
        # get the EDS info for this person
        $eds = Get-EDSinfo $userId
        if($eds) {
            # pull the info we need out of the $eds object
            $EmplId = $eds.emplId
            $ln = $eds.sn
            $fn = $eds.givenName
            $dpt = $eds.employeePrimaryDept
            $email = $eds.mail
            $empStatCd = $eds.employeeStatus
            $effdt = $eds.employeeHireDate
            # convert the effdt (effective date?) to an actual datetime object
            $year,$month,$day = ''
            $effdt = $effdt.ToCharArray()
            0..3 | %{$year += $effdt[$_]}
            4..5 | %{$month += $effdt[$_]}
            6..7 | %{$day += $effdt[$_]}
            $effdt = "$year-$month-$day"

            # see if the person is in the EPM_EMPLOYEES table in UISMart
            $query = "SELECT * FROM EPM_EMPLOYEES WHERE EID = '{0}' or EMPLID = '{0}'" -f $EmplId
  
            $results = Invoke-Sqlcmd -ServerInstance 'pilot' -Database 'UISMart' -Query $query

            if($results) {
                $msg = "User with EMPLID {0} already exists in the UISMart EPM_EMPLOYEES table." -f $EmplId
                Write-Verbose $msg
                throw $msg
            } else {
                $msg = "User with EMPLID {0} is not in the UISMart EPM_EMPLOYEES table. Inserting user..." -f $EmplId
                Write-Verbose $msg
                # EID and EMPLID must be different in the EPM_EMPLOYEES table or the user will show up twice in some result sets
                # try adding a single digit to the beginning of the emplid
                $success = $false
                $prefix = 0
                $eid = ''

                $msg = "Determining an unused EID..."
                Write-Verbose $msg
                while ((-not $success) -and ($prefix -lt 10)) {
                    $eid = "{0}{1}" -f $prefix, $EmplId
                
                    $msg = "Trying $eid"
                    Write-Verbose $msg
                
                    $query = "SELECT * FROM EPM_EMPLOYEES WHERE EID = '{0}'" -f $eid
                    $results = Invoke-Sqlcmd -ServerInstance 'pilot' -Database 'UISMart' -Query $query
                    if($results) {
                        $msg = "$eid already exists, trying another..."
                        Write-Verbose $msg
                        # that EID already exists, try another
                        $prefix += 1
                        $eid = ''
                    } else {
                        $success = $true
                    }
                } # end while loop

                # check to see if we have an EID, if not throw exception
                if($eid) {
                    $msg = "Found unused EID: $eid. Inserting record..."
                    Write-Verbose $msg
                    
                    # insert the record
                    $query = @"
INSERT INTO [UISMart].[dbo].[EPM_EMPLOYEES] (EID, EMPLID, LAST_NAME, FIRST_NAME, HOME_DEPT, EMAIL_ADDR, EMPL_STAT_CD, EFFDT)
VALUES('{0}', '{1}', '{2}', '{3}', '{4}','{5}', '{6}', cast('{7}' as datetime))
"@ -f $eid, $EmplId, $ln, $fn, $dpt, $email, $empStatCd, $effdt
                    if($PSCmdlet.ShouldProcess($query)) {
                        Invoke-Sqlcmd -ServerInstance 'pilot' -Database 'UISMart' -Query $query
                    }
                } else {
                    $msg = @"
Could not determine an unused EID. Please insert the record manually on SQL Server Pilot using the following query (fill in the correct parameters):

INSERT INTO [UISMart].[dbo].[EPM_EMPLOYEES] (EID, EMPLID, LAST_NAME, FIRST_NAME, HOME_DEPT, EMAIL_ADDR, EMPL_STAT_CD, EFFDT)
VALUES('<EID not equal to EmplId>', '<EmplId>', '<last name>', '<first name>', '<primary department number>','<email address>', '<employeeStatus>', cast('<employeeHireDate in yyyy-MM-dd format>' as datetime))
"@
                    Write-Verbose $msg
                    throw $msg
                }
            }
        } else { # else no eds info found for this user
            $msg = "Could not find user with EmplId {0} in EDS" -f $EmplId
            Write-Verbose $msg
            throw $msg
        }
    } # end process block
}

function New-FileServerDirectory {
<#
    .Synopsis
        Creates a directory in \\FSO\FileServer\<parent>\<name of new file> along with associated AD groups.
    .Description
        Creates the directory, the AD Manager, Modify, and Read groups, populates membership of the groups, 
        and sets the ACL on the directory.
    .Parameter FullPath
        The full path to the new directory. The AD Groups are created based on this path. For example, a path
        of R:\FM\NewDir will result in a new directory under R:\FM called NewDir. Three security groups will
        be created, ACL_FM NewDir_MANAGER, ACL_FM NewDir_MODIFY, and ACL_FM NewDir_READ. The manager of each
        of the groups will be the ACL_FM NewDir_MANAGER group and the 'Manager can update membership list' box
        will be checked.
    .Parameter ManagerMembers
        A list of samaccountnames of users that will be added to the member list of the manager group.
    .Parameter ModifyMembers
        A list of samaccountnames of users that will have modify privs on the new directory.
    .Parameter ReadMembers
        A list of samaccountnames of users that will have read privs on the new directory.
    .Example
        PS C:\> $mgrs = 'thisperson','thatperson'
        PS C:\> $mods = 'thisperson','thatperson','someotherperson'
        PS C:\> $path = '\\fso\fileserver\FM\NewDir'
        PS C:\> New-FileServerDirectory -FullPath $path -ManagerMembers $mgrs -ModifyMembers $mods
    .Notes
        Must be run as a Domain Admin
#>
    [CmdletBinding()]
    param (
    [parameter(Mandatory=$true,Position=0)][string]$FullPath,
    [parameter(Mandatory=$false,Position=1)][array]$ManagerMembers,
    [parameter(Mandatory=$false,Position=2)][array]$ModifyMembers,
    [parameter(Mandatory=$false,Position=3)][array]$ReadMembers
    )
    # there are 3 types of groups
    $grpTypes = 'MANAGER','MODIFY','READ'
    $grps = @{}
    # the OU the groups will be created in
    $aclGrpOu = "ou=FileSystem,ou=Groups,dc=fso,dc=arizona,dc=edu"
        
    # get the name of the folder from the FullPath variable
    $dirName = Split-Path $FullPath -Leaf
    
    # get the name of the parent from the FullPath variable
    $parentDirName = Split-Path (Split-Path $FullPath -Parent) -Leaf
    
    # create the directory if it doesn't already exist
    if(-not(Test-Path $FullPath)) {
        Write-Verbose ("{0}`n`tCreating directory: {1}..." -f $MyInvocation.MyCommand.Name, $FullPath)
        New-Item -ItemType directory -Path $FullPath -Force | Out-Null
    }

    #create the group names
    $grpTypes | %{
        $grps.Add($_, ("ACL_{0} {1}_{2}" -f $parentDirName, $dirName, $_))
    }

    # create the groups
    $grpTypes | %{
        $grpName = $grps.$_
        Write-Verbose ("{0}`n`tCreating AD group: {1}..." -f $MyInvocation.MyCommand.Name, $grpName)
        $description = "Contains Groups and Users that have {0} access to the {1} folder in the FileServer\{2} folder." -f $_.ToLower(), $dirName, $parentDirName
        $myGrp = New-ADGroup -Name $grpName -SamAccountName $grpName -GroupCategory Security -GroupScope DomainLocal -DisplayName $grpName -Path $aclGrpOu -Description $description -PassThru
        
        # set the managed by attribute
        Write-Verbose ("{0}`n`tSetting the ManagedBy attribute to {1}..." -f $MyInvocation.MyCommand.Name, $grps.'MANAGER')
        Set-ADGroup -Identity $grpName -ManagedBy $grps.'MANAGER'
        
        # force replication
        Write-Verbose ("{0}`n`tWaiting for AD replication..." -f $MyInvocation.MyCommand.Name)
        Force-Replication | Out-Null
        Start-Sleep -Seconds 2

        # check the 'Manager can update membership list' box
        Write-Verbose ("{0}`n`tSetting the 'Manager can update membership list' box..." -f $MyInvocation.MyCommand.Name)
        $memberPropertyGuid = [guid]"bf9679c0-0de6-11d0-a285-00aa003049e2"
        $ID = New-Object System.Security.Principal.NTAccount('FSO', $grps.'MANAGER')
        $newACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($ID, 'WriteProperty', 'Allow', $memberPropertyGuid)
        $ADObject = [ADSI]"LDAP://$($myGrp.DistinguishedName)"
        $ADObject.psbase.ObjectSecurity.SetAccessRule($newACE)
        $ADObject.psbase.commitchanges()

        # add members
        if($_ -eq 'MANAGER' -and $ManagerMembers) {
            Write-Verbose ("{0}`n`tSetting the manager group membership..." -f $MyInvocation.MyCommand.Name)
            Add-ADGroupMember -Identity $grpName -Members $ManagerMembers
        } elseif ($_ -eq 'MODIFY' -and $ModifyMembers) {
            Write-Verbose ("{0}`n`tSetting the modify group membership..." -f $MyInvocation.MyCommand.Name)
            Add-ADGroupMember -Identity $grpName -Members $ModifyMembers
        } elseif ($_ -eq 'READ' -and $ReadMembers) {
            Write-Verbose ("{0}`n`tSetting the read group membership..." -f $MyInvocation.MyCommand.Name)
            Add-ADGroupMember -Identity $grpName -Members $ReadMembers
        }
    }

    # sleep for a few seconds to make sure the groups are created and replicated to other DCs
    Write-Verbose ("{0}`n`tWaiting for AD replication..." -f $MyInvocation.MyCommand.Name)
    Force-Replication | Out-Null
    Start-Sleep -Seconds 2
    $waiting = $true
    while($waiting) {
        try {
            $grpTypes | %{ Get-ADGroup $grps.$_ | Out-Null }
            $waiting = $false
        } catch { 
            # do nothing
        }
    }

    # Update the ACL on the new directory
    Write-Verbose ("{0}`n`tSetting the ACL on {1}..." -f $MyInvocation.MyCommand.Name, $FullPath)
    $acl = Get-Acl $FullPath
    # remove inheritence from parent, allow inheritence for subdirs
    $acl.SetAccessRuleProtection($true, $false)
    # add the Administrators group with full privs
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule('Administrators', 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
    # add the ACL_FULL group with full privs
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule('FSO\ACL_FULL', 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
    # add the MODIFY group with modify privs
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(("FSO\{0}" -f $grps.'MODIFY'), 'MODIFY', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
    # add the READ group with read privs
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(("FSO\{0}" -f $grps.'READ'), 'READANDEXECUTE', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
    # remove domain users access
    $acl.Access | ?{$_.IdentityReference -eq 'FSO\Domain Users'} | %{$acl.RemoveAccessRule($_)} | Out-Null
    # set the changes    
    $acl | Set-Acl $FullPath
}

function Offer-RA {
    param(
    [parameter(mandatory=$true,valueFromPipeline=$true)][string]$Computer
    )
    msra /offerra $Computer
}

function Refresh-Ip {
    Write-Host "Releasing IP..."
    ipconfig /release | Out-Null
    Write-Host "Renewing IP..."
    ipconfig /renew | Out-Null
    Write-Host "Registering IP in DNS..."
    ipconfig /registerdns | Out-Null
    ipconfig
}
 
function Run-RemoteCMD { 
    [CmdletBinding(SupportsShouldProcess=$true)]
    param( 
    [Parameter(Mandatory=$true,valuefrompipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$Name,
    [Parameter(Mandatory=$false)][string]$Command = 'gpupdate /force'
    ) 
    begin { 
        [string]$cmd = "CMD.EXE /C " + $Command
        Write-Verbose ("{0}`n`tCommand to run: {1}" -f $MyInvocation.MyCommand.Name, $cmd) 
    } 
    process {
        if($PSCmdlet.ShouldProcess("Computer: $Name, Command: $Command")) {
            Write-Verbose ("{0}`n`tRunning command on {1}" -f $MyInvocation.MyCommand.Name, $Name)
            $newproc = Invoke-WmiMethod -class Win32_process -name Create -ArgumentList ($cmd) -ComputerName $Name 
            if ($newproc.ReturnValue -ne 0 ) {
                Throw ("{0} failed on {1}" -f $Command, $Name)
            } else {
                Write-Verbose ("{0}`n`tSuccess running '{1}' on '{2}'" -f $MyInvocation.MyCommand.Name, $cmd, $Name)
            }
        } 
    } 
    End{}
} 

function Start-ActiveImportRDPSession {
    Start-RDP activeimport -Credential (Get-AdminVaultCredential 'activimp')
}

function Start-RDP {
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string][AllowNull()]$Name = $null,
    [parameter(Mandatory=$false)][switch]$Admin,
    [parameter(Mandatory=$false)][switch]$Fullscreen,
    [parameter(Mandatory=$false)][System.Management.Automation.PSCredential]$Credential = $null,
    [parameter(Mandatory=$false)][int]$PauseInSeconds = 0
    )
    begin {
        if($Credential) {
            Write-Verbose ("{0}`n`tStoring credential in clip..." -f $MyInvocation.MyCommand.Name)
            $Credential.GetNetworkCredential().Password | clip
        }
    }
    process {
        if($Name) {
            if($Admin) {
                if($Fullscreen) {
                    Write-Verbose ("{0}`n`tConnecting to {1} in fullscreen mode using admin switch..." -f $MyInvocation.MyCommand.Name, $Name)
                    mstsc /v:$Name /admin /F
                } else {
                    Write-Verbose ("{0}`n`tConnecting to {1} using admin switch..." -f $MyInvocation.MyCommand.Name, $Name)
                    mstsc /v:$Name /admin
                }
            } else {
                if($Fullscreen) {
                    Write-Verbose ("{0}`n`tConnecting to {1} in fullscreen mode..." -f $MyInvocation.MyCommand.Name, $Name)
                    mstsc /v:$Name /F
                } else {
                    Write-Verbose ("{0}`n`tConnecting to {1}..." -f $MyInvocation.MyCommand.Name, $Name)
                    mstsc /v:$Name
                }
            }
        } else {
            Write-Verbose ("{0}`n`tStarting Remote Desktop Connection..." -f $MyInvocation.MyCommand.Name)
            mstsc
        }
        if($PauseInSeconds -gt 0) {
            Write-Verbose ("{0}`n`tPausing {1} seconds..." -f $MyInvocation.MyCommand.Name, $PauseInSeconds)
            Start-Sleep -Seconds $PauseInSeconds
        }
    }
    end {}
}

#endregion functions


#region aliases

if(!(Get-Alias -Name frep -ErrorAction SilentlyContinue)) {
    New-Alias frep Force-Replication
}

if(! (Get-Alias -Name hc -ErrorAction SilentlyContinue)) {
    New-Alias hc Hibernate-Computer
}

if(!(Get-Alias -Name ORA -ErrorAction SilentlyContinue)) {
    New-Alias ORA Offer-RA
}

if(!(Get-Alias -Name RDP -ErrorAction SilentlyContinue)) {
    New-Alias RDP Start-RDP
}

if(! (Get-Alias -Name rdpai -ErrorAction SilentlyContinue)) {
    New-Alias rdpai Start-ActiveImportRDPSession
}

if(! (Get-Alias -Name reip -ErrorAction SilentlyContinue)) {
    New-Alias reip Refresh-Ip
}

#endregion aliases

Export-ModuleMember -Function * -Alias *


# SIG # Begin signature block
# MIIUdgYJKoZIhvcNAQcCoIIUZzCCFGMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUMlqUSnOjfDETbum6QxRptbb0
# 1FOggg+4MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# MRYEFJVTYC/RiLTXome9C1tMw5qs+umwMA0GCSqGSIb3DQEBAQUABIIBAGA/MhaE
# pxLKYD3YhajiYGphOXUIhrOMpslXmmxqhtYAfrCahOBNssI9F2XP3OeOjgvr53oY
# FIU1osUYso7zwQ4CHdd7ViflacWTy+I3VNzhp37lzFtRbkgKjgKM+IdA99BE0kZi
# 3p+1MYvmh+eNQIOWx0Fl0/liGOdHF7Ccv+owBJJZUKiS5wvW/CNM/Md6N5nMvrwK
# SQ3qXKWxNr1Z+1WplMtD0ji1mkT3wAV4WMeaTzcSdnoTRL1ff1tm2dCQYpDcHNLY
# L3bgnla6nKEhMPgqUMEnLBV2/EyfTA+F+kTXCpbmGraKfzVuIqxTV6gjfD8ARqLa
# b7/ucxx0I5tLwgmhggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBeMQsw
# CQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNV
# BAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQDs/0
# OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMTMxMjAyMjA0MDQwWjAjBgkqhkiG9w0BCQQx
# FgQUzaW+4TwAmBhtZ5qVg8Mnd6RDqgYwDQYJKoZIhvcNAQEBBQAEggEAg4403hHt
# xeG/RQL1bhp2VJXKQp9W0I48UyELLVFAFokD/wVv7DYrSGWdxms5j+hihgQ7C/Wd
# kj3I1fb7xnJoanNxN6T6icqUP7pKg5oDv4QLkeWFsPhVgXn18WOcR2uvcISibNqE
# 5mM4wl8YaX/4QxrtpLU57En5fNBp4RUOq/bAXCcxiuu8cA5wA6G4Ou0JGsUpJfqR
# J1oZN3eaXvgU18J0u106bDjCyFzZ96h9M/qbRCIDRSFrH1ner1I+WRx49o50rQ5P
# pwU/IQoSmeqwrKEslZweudcMWoDWMjiAwxtOCWVR/GMthsOn5pmSbRloFhEGf7bM
# cBvf6xJjmn772g==
# SIG # End signature block
