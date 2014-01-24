
#region includes

if((Get-PSSnapin -Name SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue) -eq $null) {
    try{Add-PsSnapin SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue}catch{}
}
Import-Module \\fso\core\Scripts\include\Test_Functions.psm1 -DisableNameChecking

#endregion


#region variables

$sqlSvr = 'appsql'
$database = 'AdminVault'

#endregion variables


#region get functions


function Get-AdminVaultCredential {
<#
	.Synopsis
		Get-AdminVaultCredential retrieves a credential from the AdminVault database.
	.Description
		This function retrieves the encrypted password and key from the Credentials
        table in the AdminVault database and stores them in a PSCredential object that
        is then returned.
	.Parameter UserName
		The name of the user whose credentials should be returned.
	.Example
		PS C:\Windows\system32> Get-AdminVaultCredential 'spcontent'
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)][string]$UserName
    )
    process {
        $query = @"
SELECT RTRIM(LTRIM(UserName)) as UserName, RTRIM(LTRIM(Password)) as Password, RTRIM(LTRIM(PasswordKey)) as PasswordKey
FROM Credentials
WHERE UserName = '{0}'
"@ -f $UserName
        Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
        $r = Invoke-Sqlcmd -ServerInstance $sqlSvr -Database $database -Query $query
        if($r) {
            $password = $r.Password | ConvertTo-SecureString -Key ($r.PasswordKey.trim() -split ', ')
            New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $password

        }
    }
}

function Get-AdminVaultData {
<#
	.Synopsis
		Returns all data in plain text for one or all usernames.
	.Description
		If a username is passed by pipe, position, or named parameter
        a PSObject with UserName, Password, and Description note properties
        is returned. If no username is specified this function returns all
        usernames, passwords, and descriptions contained in the vault.
	.Parameter UserName
        The username associated with the data to be returned.
	.Example
		PS C:\Windows\system32> (Get-AdminVaultUserNamesAndDescriptions | select username) | Get-AdminVaultData
    .Example
        PS C:\Windows\system32> Get-AdminVaultData 'myname'
    .Example
        PS C:\Windows\system32> Get-AdminVaultData
#>
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$false,
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        ParameterSetName="peruser")]
    [string]$UserName = '',
    [Parameter(Mandatory=$false)]
    [switch]$AsPlainText
    )
    process {
        switch($PSCmdlet.ParameterSetName) {
            "peruser" {
                if(Test-AdminVaultUserNameExists $UserName) {
                    $query = @"
SELECT RTRIM(LTRIM(UserName)) as UserName,
       RTRIM(LTRIM(Password)) as Password,
       RTRIM(LTRIM(Description)) as Description,
       PasswordChangeInterval,
       PasswordLastChangedDate
FROM Credentials
WHERE UserName = '{0}'
"@ -f $UserName
                    Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
                    $resultSet = Invoke-Sqlcmd -ServerInstance $sqlSvr -Database $database -Query $query
                    if($AsPlainText) {
                        $resultSet | select UserName, @{l='Password';e={Get-AdminVaultPassword -UserName $_.UserName}}, Description, PasswordChangeInterval, PasswordLastChangedDate
                    } else {
                        $resultSet | select UserName, @{l='Password';e={(Get-AdminVaultCredential -UserName $_.UserName).Password}}, Description, PasswordChangeInterval, PasswordLastChangedDate
                    }
                } else {
                    Write-Verbose ("{0}`n`tUserName, '{1}', does not exist in the AdminVault" -f $MyInvocation.MyCommand.Name, $UserName)
                }
            }
            default {
                
                $query = @"
SELECT RTRIM(LTRIM(UserName)) as UserName,
       RTRIM(LTRIM(Password)) as Password,
       RTRIM(LTRIM(Description)) as Description,
       PasswordChangeInterval,
       PasswordLastChangedDate
FROM Credentials
ORDER BY UserName
"@
                Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
                $resultSet = Invoke-Sqlcmd -ServerInstance $sqlSvr -Database $database -Query $query
                if($AsPlainText) {
                    $resultSet | select UserName, @{l='Password';e={Get-AdminVaultPassword -UserName $_.UserName}}, Description, PasswordChangeInterval, PasswordLastChangedDate
                } else {
                    $resultSet | select UserName, @{l='Password';e={'Use AsPlainText switch to view'}}, Description, PasswordChangeInterval, PasswordLastChangedDate
                }
    
            }
        }
    }
}

function Get-AdminVaultDescription {
<#
	.Synopsis
		Get-AdminVaultDescription retrieves a description for a credential from the
        AdminVault database.
	.Description
		This function returns the description for the specified user name.
	.Parameter UserName
		The name of the user whose description should be returned.
	.Example
		PS C:\Windows\system32> Get-AdminVaultDescription 'spcontent'
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=0)][string]$UserName
    )
    process {
        $query = @"
SELECT RTRIM(LTRIM(Description)) as Description
FROM Credentials
WHERE UserName = '{0}'
"@ -f $UserName
        Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
        $r = Invoke-Sqlcmd -ServerInstance $sqlSvr -Database $database -Query $query
        if($r) {
            $r.Description.trim()
        }
    }
}

function Get-AdminVaultExpiredCredentials {
<#
    .Synopsis
        Returns a list of all credentials that need their passwords changed.
    .Description
        Returns a list of credentials where today is past the credential's
        PasswordLastChangedDate + PasswordChangeInterval.
    .Example
        PS C:\> Get-AdminVaultExpiredCredentials
#>
    [CmdletBinding()]
    param()
$query = @"
Select RTRIM(LTRIM(c.UserName)) as UserName,
	   RTRIM(LTRIM(c.PasswordLastChangedDate)) as PasswordLastChangedDate,
	   RTRIM(LTRIM(c.PasswordChangeInterval)) as PasswordChangeInterval,
       RTRIM(LTRIM(c.Description)) as Description
from Credentials c
WHERE c.PasswordChangeInterval <> 0
AND (GETDATE()) > (DATEADD(DAY, c.PasswordChangeInterval, c.PasswordLastChangedDate))
ORDER BY UserName
"@  
    Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
    Invoke-Sqlcmd -ServerInstance $sqlSvr -Database $database -Query $query | select UserName, Description, PasswordChangeInterval, PasswordLastChangedDate
}

function Get-AdminVaultPassword {
<#
	.Synopsis
		Get-AdminVaultPassword returns the decrypted password associated with the
        specified user name.
	.Parameter UserName
		The name of the user whose password should be returned.
	.Example
		PS C:\Windows\system32> Get-AdminVaultPassword 'someuser'
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=0)][string]$UserName
    )
    process {
        (Get-AdminVaultCredential $UserName) | Get-Password
    }
}

function Get-AdminVaultPasswordChangeInterval {
<#
    .Synopsis
        Returns the password change interval in days for the specified username.
    .Description
        An integer representing the number of days between password changes for
        the specified username is returned.
    .Parameter UserName
        The username associated with the credential.
    .Example
        PS C:\> Get-AdminVaultPasswordChangeInterval -UserName 'admin'
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=0)][string]$UserName
    )
    process {
        $query = @"
SELECT PasswordChangeInterval
FROM Credentials
WHERE UserName = '{0}'
"@ -f $UserName
        Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
        Invoke-Sqlcmd -ServerInstance $sqlSvr -Database $database -Query $query | select -ExpandProperty PasswordChangeInterval
    }
}

function Get-AdminVaultPasswordLastChangedDate {
<#
    .Synopsis
        Returns the date the password for the specified user was last changed.
    .Description
        If the password is static this will return nothing.
    .Parameter UserName
        The username associated with the specified credential.
    .Example
        PS C:\> Get-AdminVaultPasswordLastChangedDate -UserName 'admin'
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=0)][string]$UserName
    )
    process {
        $query = @"
SELECT PasswordLastChangedDate
FROM Credentials
WHERE UserName = '{0}'
"@ -f $UserName
        Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
        $r = Invoke-Sqlcmd -ServerInstance $sqlSvr -Database $database -Query $query
        if(Test-IsNotNullOrBlankOrEmpty $r.PasswordLastChangedDate) {
            $pwdLastChgDt = $r.PasswordLastChangedDate
            if((New-TimeSpan $pwdLastChgDt (Get-Date '1900-01-01')) -ne 0) {
                $pwdLastChgDt
            } else {
                $msg = @"
{0}`n`tIt appears this password has never been changed.
It's most likely a static password that does not require changing.
Its password change interval is set to '{1}'.
"@ -f $MyInvocation.MyCommand.Name, (Get-AdminVaultPasswordChangeInterval -UserName $UserName)
                Write-Verbose $msg
            }
        }
    }
}

function Get-AdminVaultUserNamesAndDescriptions {
<#
	.Synopsis
		Get-AdminVaultUserNamesAndDescriptions returns all usernames and their
        associated descriptions from AdminVault.dbo.Credentials.
	.Example
		PS C:\Windows\system32> Get-AdminVaultUserNamesAndDescriptions
#>
    [CmdletBinding()]
    param()
    $query = @"
SELECT RTRIM(LTRIM(UserName)) as UserName, RTRIM(LTRIM(Description)) as Description
FROM Credentials
ORDER BY UserName
"@
    Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
    Invoke-Sqlcmd -ServerInstance $sqlSvr -Database $database -Query $query
}

function Get-Password {
<#
	.SYNOPSIS
		Takes a PSCredential object and returns the password stored in the secure string.
	.PARAMETER credential
		The PScredential object with the password you wish to retrieve. Typically this is generated using the Get-Credential cmdlet. Accepts pipeline input.
	.OUTPUTS
		The password as System.String
#>    
    param(
    [parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [System.Management.Automation.PSCredential]$Credential
    )
    process {
        $Credential.GetNetworkCredential().Password
    }
}

function Get-PasswordSheetData {
<#
	.Synopsis
		Get-PasswordSheetData returns a string that contains a list of user names
        and passwords.
	.Description
		The data returned is specific to the Type parameter.
	.Parameter Name
		The name of the person who will own this password sheet.
	.Parameter Type
		The type of password sheet to create. Valid entries are 'dev','desktop', and 'admin'.
	.Parameter Console
		If used the output will go to the console, otherwise output is sent to clip.exe.
	.Example
		PS C:\Windows\system32> 'Pete','Dan','Tyson' | Get-PasswordSheetData -Type admin
#>
    [CmdletBinding()]
    param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$Name,
    [parameter(Mandatory=$true)][ValidateSet('dev','desktop','admin')][string]$Type,
    [parameter(Mandatory=$false)][switch]$Console
    )
    begin {
        $spacer = ''
        0..49 | %{$spacer += '-'}
        $spacer += "`n"
        $output = $spacer
        $admin = @{}
        $str = ""
        switch($Type) {
            'admin' {
                'vader','palpatine','root','dsrm','sa', 'skywalker' | sort | %{
                    $str += "{0,-15}{1}`n" -f $_, (Get-AdminVaultPassword $_)
                }
            }
            'desktop' {
                'skywalker','administrator' | sort | %{
                    $str += "{0,-15}{1}`n" -f $_, (Get-AdminVaultPassword $_)
                }
            }
            'dev' {
                'root','sa' | sort | %{
                    $str += "{0,-15}{1}`n" -f $_, (Get-AdminVaultPassword $_)
                }
            }
            default {}
        }
    }
    process {
        $Name | %{
            $output += ("{0} - {1}`n" -f $Name.ToUpper(), (Get-Date -Format MM/dd/yy)) + $str + $spacer
        }
    }
    end {
        if($Console) {
            $output
        } else {
            $output | clip
        }
    }
}


#endregion get functions


#region find functions


function Find-AdminVaultUserData {
<#
    .Synopsis
        Searches the AdminVault for all user names containing the specified target string.
    .Description
        This function will return all user names and descriptions for all records that contain
        the specified target string any where in the user name.
    .Parameter Target
        The search string. This is used in a SQL query. Wildcards are not permitted.
    .Example
        PS C:\> Find-AdminVaultUserData 'kfs'
        UserName                Description
        --------                -----------
        dwkfs                   DocuWare account used by KFS
        kfsftp                  Used by KFS Control M to SFTP data files to \\fso\core\kfs...
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,Position=0)][string]$Target
    )
    $query = @"
SELECT RTRIM(LTRIM(UserName)) as UserName, RTRIM(LTRIM(Description)) as Description
FROM Credentials
WHERE UserName like '%{0}%'
"@ -f $Target
        Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
        $r = Invoke-Sqlcmd -ServerInstance $sqlSvr -Database $database -Query $query
        if($r) {
            $r
        } else {
            Write-Verbose ("{0}`n`tCould not find any usernames containing '{1}'" -f $MyInvocation.MyCommand.Name, $Target)
        }
}


#endregion find functions


#region new functions


function New-Credential {
<#
	.Synopsis
		Returns a credential object created from the specified username and password.
	.Description
		Takes a SecureString password and string username and returns a PSCredential object.
	.Parameter Password
		The password that will be in the Password property of the returned credential object.
	.Parameter UserName
		The name of the user that will be in the UserName property of the returned credential object.
	.Example
		PS C:\Windows\system32> $myCred = New-Credential -Password (ConvertTo-SecureString 'mypassword' -AsPlainText -Force) -User 'myname'
#>
    param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [System.Security.SecureString]$Password,
    [Parameter(Mandatory=$false)]
    [alias("User")]
    [string]$UserName = 'UserName'
    )
    process {
        New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $Password
    }
}

function New-PasswordAndKey {
<#
	.Synopsis
		Returns an encrypted password and the associated key.
	.Description
		This function takes a credential object and returns a PSObject
        that has 2 note properties: Password and Key.
	.Parameter Credential
		A PSCredential containing the Username and Password.
	.Example
		PS C:\Windows\system32> $passwordAndKey = New-PasswordAndKey
#>
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
    [System.Management.Automation.PSCredential]$Credential
    )
    process {
        # Generate a random 256-bit Rijndael encryption key.
        $key = 1..32 | %{ get-random -max 256}
        # Using generic names for the properties since they appear in plaintext in the created file.
        $pwd = ConvertFrom-SecureString -SecureString $Credential.Password -Key $key
        $key = $key -join ', '
        New-Object PSObject -Property @{
            Password = $pwd
            Key = $key
        }
    }
}


#endregion new functions


#region remove functions


function Remove-AdminVaultCredential {
<#
	.Synopsis
		Remove-AdminVaultCredential deletes a record from the AdminVault database.
	.Description
		This function will delete the row associated with the specified user name
        from the AdminVault database.
	.Parameter UserName
		The name of the user whose record should be removed.
	.Example
		PS C:\Windows\system32> Remove-AdminVaultCredential 'someuser'
#>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=0)][string]$UserName
    )
    process {
        if(Get-AdminVaultCredential $UserName) {
            $query = @"
IF EXISTS(
    SELECT RTRIM(LTRIM(UserName)) as UserName
    FROM Credentials
    WHERE UserName = '{0}'
)
DELETE
FROM Credentials
WHERE UserName = '{0}'
"@ -f $UserName
            Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
            if($PSCmdlet.ShouldProcess($UserName)) {
                Invoke-Sqlcmd -ServerInstance $sqlSvr -Database $database -Query $query
            }
        } else {
            $msg = "UserName '$UserName' not found"
            Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $msg)
            throw $msg
        }
    }
}


#endregion remove functions


#region set functions


function Save-AdminVaultCredential {
<#
	.Synopsis
		Save-AdminVaultCredential saves a credential to the AdminVault database.
	.Description
		This function takes a credential object and a description. It then
        encrypts the password and saves it in the Credentials table of the AdminVault
        database on appsql. There is a unique constraint on the UserName.
	.Parameter Credential
		A PSCredential object that contains the username and password to be stored.
	.Parameter Description
		A description to associate with the credential. The description is required.
    .Parameter PasswordChangeInterval
        The number of days between required password changes for this credential. If not
        specified the password is considered static and does not require changing.
	.Example
        PS C:\Windows\system32> $cred = Get-Credential 'someuser'
        PS C:\Windows\system32> Save-AdminVaultCredential $cred 'this is used by some person'
    .Example
        PS C:\Windows\system32> $cred = Get-Credential 'someuser'
        PS C:\Windows\system32> Save-AdminVaultCredential -Credential $cred -Description 'this is used by some person' -PasswordChangeInterval 0
#>
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
    [System.Management.Automation.PSCredential]$Credential,
    [Parameter(Mandatory=$true,Position=1)][string]$Description,
    [Parameter(Mandatory=$false,Position=2)]$PasswordChangeInterval = $null,
    [parameter(Mandatory=$false,Position=3)]$PasswordLastChangedDate = $null
    )
    process {
        $pk = New-PasswordAndKey -Credential $Credential

        # if the PasswordChangeInterval is null, set it to default value of 0
        # did it this way because there is a chance that this could be used to set the change interval to 0
        # so we couldn't use 0 as the default value in the parameter statement
        if($PasswordChangeInterval) {
            $pwdChgInt = $PasswordChangeInterval
        } else {
            $pwdChgInt = 0
        }

        # if the PasswordLastChangedDate is null, set it to default value of '1900-01-01'
        # did it this way because null datetime gets stored as '1900-01-01 00:00:00.000' in SQL
        if($PasswordLastChangedDate) {
            $pwdLastChgDt = (Get-Date $PasswordLastChangedDate -Format 'dd-MM-yyyy')
        } else {
            $pwdLastChgDt = Get-Date '1900-01-01' -Format 'dd-MM-yyyy'
        }

        $query = @"
INSERT INTO Credentials (UserName, Password, PasswordKey, Description, PasswordChangeInterval, PasswordLastChangedDate)
VALUES ('{0}', '{1}', '{2}', '{3}', {4}, CAST('{5}' as DATETIME))
"@ -f $Credential.GetNetworkCredential().UserName, $pk.Password, $pk.Key, $Description, $pwdChgInt, $pwdLastChgDt
        Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
        Invoke-Sqlcmd -ServerInstance $sqlSvr -Database $database -Query $query
    }
}

function Set-AdminVaultCredential {
<#
	.Synopsis
		Creates or updates an AdminVault record.
	.Description
		This function first checks to see if the username is already in the vault. If it is,
        the user is prompted if it should be overwritten. If the username doesn't yet exist
        the credential and description are stored in the vault.
	.Parameter Credential
		A PSCredential object that contains the username and password to be stored.
	.Parameter Description
		A description to associate with the credential. If this is a new entry in the AdminVault the description
        is required. If this is an update to a current entry the description is not required, and the current
        description will not be altered.
   	.Example
		PS C:\Windows\system32>  Set-AdminVaultCredential (Get-Credential 'username') -Description 'my description'
#>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
    [System.Management.Automation.PSCredential]$Credential,
    [Parameter(Mandatory=$false,Position=2)][string]$Description = '',
    [Parameter(Mandatory=$false,Position=3)]$PasswordChangeInterval = $null,
    [Parameter(Mandatory=$false,Position=4)]$PasswordLastChangedDate = $null
    )
    process {
        $username = $Credential.GetNetworkCredential().Username
        
        $existingCred = Get-AdminVaultCredential ($username)
        if($existingCred) {
            # determine what needs to be updated by comparing parameter values to existing values
            Update-AdminVaultCredential -Credential $Credential -Description $Description -PasswordChangeInterval $PasswordChangeInterval -PasswordLastChangedDate $PasswordLastChangedDate
        } else {
            Save-AdminVaultCredential -Credential $Credential -Description $Description -PasswordChangeInterval $PasswordChangeInterval -PasswordLastChangedDate $PasswordLastChangedDate
        }
    }
}

function Set-AdminVaultPasswordChangeInterval {
<#
    .Synopsis
        Sets the PasswordChangeInterval to the specified value for the specified user.
    .Parameter UserName
        The name of the user to update.
    .Parameter PasswordChangeInterval
        An integer representing the number of days between required password changes for this username.
    .Example
        PS C:\> Set-AdminVaultPasswordChangeInterval -UserName 'blah' -PasswordChangeInterval 60
#>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0,ValueFromPipelineByPropertyName=$true)][string]$UserName,
    [Parameter(Mandatory=$true,Position=1)][ValidateScript({$anInt = 1;[System.Int32]::TryParse($_, [ref]$anInt)})]$PasswordChangeInterval
    )
    process {
        $query = @"
IF EXISTS(SELECT * FROM Credentials WHERE UserName = '{0}')
    UPDATE Credentials
    SET PasswordChangeInterval = {1}
    WHERE UserName = '{0}'
"@ -f $UserName, $PasswordChangeInterval

        Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
        if($PSCmdlet.ShouldProcess("UserName: $UserName, New PasswordChangeInterval: $PasswordChangeInterval")) {
            Invoke-Sqlcmd -ServerInstance $sqlSvr -Database $database -Query $query
            Get-AdminVaultData -UserName $UserName | select UserName, PasswordChangeInterval, PasswordLastChangedDate
        }
    }
}

function Set-AdminVaultPasswordLastChangedDate {
<#
    .Synopsis
        Sets the PasswordLastChangedDate to the specified date for the specified username.
    .Description
        If no PasswordLastChangedDate is specified Get-Date is used.
    .Parameter UserName
        The name of the user to update.
    .Parameter PasswordLastChangedDate
        The date to set the username's PasswordLastChangedDate value to.
    .Example
        PS C:\> Set-AdminVaultPasswordlastChangedDate -UserName 'blah' -PasswordLastChangedDate '1/1/2013'
#>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$UserName,
    [Parameter(Mandatory=$false,Position=1)][datetime]$PasswordLastChangedDate = (Get-Date -Format 'yyyy-MM-dd')
    )
    process {
        $query = @"
IF EXISTS(SELECT * FROM Credentials WHERE UserName = '{0}')
    UPDATE Credentials
    SET PasswordLastChangedDate = CAST('{1}' as DATETIME)
    WHERE UserName = '{0}'
"@ -f $UserName, $PasswordLastChangedDate

        Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
        if($PSCmdlet.ShouldProcess("UserName: $UserName, New PasswordLastChangedDate: $PasswordLastChangedDate")) {
            Invoke-Sqlcmd -ServerInstance $sqlSvr -Database $database -Query $query
            Get-AdminVaultData -UserName $UserName | select UserName, PasswordChangeInterval, PasswordLastChangedDate
        }
    }
}

#endregion set functions


#region test functions


function Test-AdminVaultPasswordChangeNeeded {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)][string]$UserName
    )
    process {
        Write-Verbose ("{0}`n`tChecking user '{1}'..." -f $MyInvocation.MyCommand.Name, $UserName)
        
        if(Test-AdminVaultUserNameExists -UserName $UserName) {
            $query = @"
SELECT *
FROM Credentials
WHERE UserName = '{0}'
"@ -f $UserName
            Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
            $userData = Invoke-Sqlcmd -ServerInstance $sqlSvr -Database $database -Query $query
            if(($userData.PasswordChangeInterval -ge 0) -and (Test-IsNotNullOrBlankOrEmpty $userData.PasswordLastChangedDate)) {
                Write-Verbose ("{0}`n`tChecking PasswordChangeInterval against the PasswordLastChangedDate..." -f $MyInvocation.MyCommand.Name)
                if($userData.PasswordChangeInterval -le 0) {
                    $msg = @"
{0}`n`tUser '{1}' has a PasswordChangeInterval of '{2}'.
This user account is considered static and does not
require password changes. If this user should be
scheduled for password changes please set the
PasswordChangeInterval to a value greater than 0.
"@ -f $MyInvocation.MyCommand.Name, $UserName, ($userData.PasswordChangeInterval)
                    Write-Verbose $msg
                    $false
                } else {
                    $changeDate = (Get-Date ($userData.PasswordLastChangedDate)).AddDays($userData.PasswordChangeInterval)
                    $changeDate -le (Get-Date)
                }
            }
        }
    }
}

function Test-AdminVaultUserNameExists {
<#
    .Synopsis
        Returns a boolean indicating whether the specified username exists or not.
    .Parameter UserName
        The username to test.
    .Example
        PS C:\> 'admin' | Test-AdminVaultUserNameExists
    .Example
        PS C:\> Test-AdminVaultUserNameExists 'admin'
    .Example
        PS C:\> Test-AdminVaultUserNameExists -UserName 'admin'
#>
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)][string]$UserName
    )
    process {
        $query = @"
SELECT *
FROM Credentials
WHERE UserName = '{0}'
"@ -f $UserName
        Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
        $r = Invoke-Sqlcmd -ServerInstance $sqlSvr -Database $database -Query $query
        if(($r) -and (Test-IsNotNullOrBlankOrEmpty $r.UserName)) {
            $true
        } else {
            $false
        }
    }
}


#endregion test functions


#region update functions


function Update-AdminVaultCredential {
<#
	.Synopsis
		Update-AdminVaultCredential will modify a current record in the AdminVault database.
	.Description
		This function will update the current record with the specified credential and description.
	.Parameter Credential
		A PSCredential object containing the user name and password for the user whose record
        should be modified.
	.Parameter Description
		A description to associate with the credential.
	.Example
		PS C:\Windows\system32> Update-AdminVaultCredential (Get-Credential 'pre-existinguser')
#>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
    [System.Management.Automation.PSCredential]$Credential,
    [Parameter(Mandatory=$false,Position=2)][string]$Description = '',
    [Parameter(Mandatory=$false,Position=3)]$PasswordChangeInterval = $null,
    [Parameter(Mandatory=$false,Position=4)]$PasswordLastChangedDate = $null
    )
    process {
        $username = $Credential.GetNetworkCredential().UserName
        
        if(Get-AdminVaultCredential $username) {
            
            $pk = New-PasswordAndKey -Credential $Credential
            # don't clobber the description if no new description is passed in
            if(-not($Description)) {
                Write-Verbose ("{0}`n`tDescription has not changed. Getting current description from AdminVault..." -f $MyInvocation.MyCommand.Name)
                $Description = Get-AdminVaultDescription -UserName $username
            }
            # don't clobber the PasswordChangeInterval if a new value hasn't been passed in
            
            if(($PasswordChangeInterval -ne 0) -and ($PasswordChangeInterval -eq $null)) {
                Write-Verbose ("{0}`n`tPasswordChangeInterval has not changed. Getting current PasswordChangeInterval from AdminVault..." -f $MyInvocation.MyCommand.Name)
                $pwdChgInt = Get-AdminVaultPasswordChangeInterval -Username $username
            } else {
                Write-Verbose ("{0}`n`tPasswordChangeInterval has changed to '{1}'." -f $MyInvocation.MyCommand.Name, $PasswordChangeInterval)
                $pwdChgInt = $PasswordChangeInterval
            }
            # don't clobber the PasswordLastChangedDate if a new value hasn't been passed in
            if(-not $PasswordLastChangedDate) {
                Write-Verbose ("{0}`n`tPasswordLastChangedDate has not changed. Getting current PasswordLastChangedDate from AdminVault..." -f $MyInvocation.MyCommand.Name)
                $pwdLastChgDt = Get-AdminVaultPasswordLastChangedDate -UserName $username
            } else {
                Write-Verbose ("{0}`n`tPasswordLastChangedDate has changed to '{1}'" -f $MyInvocation.MyCommand.Name, $PasswordLastChangedDate)
                $pwdLastChgDt = Get-Date $PasswordLastChangedDate -Format 'yyyy-MM-dd'
            }

            $query = @"
UPDATE Credentials
SET Password = '{0}', PasswordKey = '{1}', Description = '{2}', PasswordChangeInterval = {3}, PasswordLastChangedDate = CAST('{4}' as DATETIME)
WHERE UserName = '{5}'
"@ -f $pk.Password, $pk.Key, $Description, $pwdChgInt, $pwdLastChgDt, $username

            Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)

            if($PSCmdlet.ShouldProcess($username)) {
                Invoke-Sqlcmd -ServerInstance $sqlSvr -Database $database -Query $query
            }
        } else {
            $msg = "UserName '$username' not found"
            Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $msg)
            throw $msg
        }
    }
}


#endregion update functions


#region exportmodulemember


$adminVaultFunctions = 'Find-AdminVaultUserData', 'Get-AdminVaultCredential', 'Get-AdminVaultData', 'Get-AdminVaultDescription', `
    'Get-AdminVaultExpiredCredentials', 'Get-AdminVaultPassword', 'Get-AdminVaultPasswordChangeInterval', `
    'Get-AdminVaultPasswordLastChangedDate', 'Get-AdminVaultUserNamesAndDescriptions', 'Get-PasswordSheetData', `
    'Remove-AdminVaultCredential', 'Set-AdminVaultCredential', 'Set-AdminVaultPasswordChangeInterval', `
    'Set-AdminVaultPasswordLastChangedDate', 'Test-AdminVaultPasswordChangeNeeded', 'Test-AdminVaultUserNameExists'

    Export-ModuleMember -Function $adminVaultFunctions


#endregion exportmodulemember

# SIG # Begin signature block
# MIIUdgYJKoZIhvcNAQcCoIIUZzCCFGMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUw07ct/c5Rh2jYpATaDaZcilG
# Zwmggg+4MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# MRYEFFB5AQOn1XThzl0sRdv706YvgUAWMA0GCSqGSIb3DQEBAQUABIIBABceW49e
# tvT43GtVG3vX0mGLMAEZueR+BScMl4XrIk6z5sEXVR1HRUt4YDRIEsVrTKJ8VAnT
# QNb4qbF9I6HxgYrCnzoV8bXtgQuAbt6Sx0r/BWRyOxkl3DL6JfpPDcN2ZaiXP37Y
# F3NOwTo68Tz/Mg6adO17SIri2XTcGKFfkVhwITdq3rABWykfqw1u3D+TxJL0Etsg
# zc5QLxVwY+t9hOYDbcXv0LpRmeKaYf+x4MdFYD3+umUI6OpYNruGeirIaNEleP2t
# CQkHVJeuSU7eD9IY84shy+09R8ydo6lQ43JGjqQU2A2aoH76fztq3fsoWp1wi5Vk
# eW2XBPyW8MbtnmWhggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBeMQsw
# CQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNV
# BAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQDs/0
# OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMTMwODEyMTg0ODA5WjAjBgkqhkiG9w0BCQQx
# FgQUk+VMIbRR76j1nJrJQ5wXsz1FfVMwDQYJKoZIhvcNAQEBBQAEggEAoSxGxS4P
# gNbR3IYOI2dH5kQAXYSJhwT9iyKf0QKZr6ibeayGKUOh3EVS2wZx72u7RTwsQkNp
# MMMV5Rg90Ll5xQ22H8rtbfgD3kIRJdPCESvVv8eFzbXI7mR5wpvstUfGEPIGGNn/
# 4bHNj3BF0BFZMw//joPX3VB4z0SGxJimPj+2q2S/VofyDnunwfe22PnSzcTvhUN+
# YwIo9k7aYa2H90RAjp6Ez2Lm0qgFcUIyB9kglli1s/ZdMM6L9UX4G2YMjHgiBjQq
# 1G/Jms/bff6h1jR+XaUeJxoOBgSaG0KyKU5Wt+HtULhHBV+h4Z1nzdqWvO8dm1Im
# ctTeRiDdfI6xjQ==
# SIG # End signature block
