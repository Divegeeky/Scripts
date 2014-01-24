# save the start time 
$start = Get-Date

#region includes

Import-Module \\fso\core\Scripts\include\Get_Functions.psm1 -DisableNameChecking
Import-Module \\fso\core\Scripts\include\Log_functions.psm1 -DisableNameChecking
Import-Module \\fso\core\Scripts\include\Alert_Functions.psm1 -DisableNameChecking

if((Get-PSSnapin -Name SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue) -eq $null) {
    try{Add-PsSnapin SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue}catch{}
}

#endregion includes


#region variables

$clients = Get-AllClients
$clientData = @()
$errors = @()

#endregion variables


#region functions

function Set-ClientDataRecord {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]$ClientDataRecord
    )
    process {
        $query = @"
IF EXISTS (SELECT * FROM ClientData WHERE ComputerName like '{0}')
BEGIN
    UPDATE ClientData
    SET ComputerDescription = '{1}', LastLoggedOnUser = '{2}', LastAccessTime = '{3}'
    WHERE ComputerName = '{0}'
END
ELSE
BEGIN
    INSERT INTO ClientData (ComputerName, ComputerDescription, LastLoggedOnUser, LastAccessTime, LastUpdateTime)
    VALUES ('{0}','{1}','{2}','{3}','{4}')
END
"@ -f $ClientDataRecord.ComputerName, $ClientDataRecord.ComputerDescription, $ClientDataRecord.LastLoggedOnUser, $ClientDataRecord.LastAccessTime, (Get-Date)
    
        Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
        if($PSCmdlet.ShouldProcess(("{0}" -f $ClientDataRecord.ComputerName))) {
            try {
                Invoke-Sqlcmd -ServerInstance 'monitorDb' -Database 'MonitorDomain' -Query $query
            } catch {
                $errors += New-Object PSObject -Property @{
                    Function = $MyInvocation.MyCommand.Name
                    Error = $_
                }
            }
        }
    }
}

function Remove-ClientDataRecord {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][int]$ClientDataID
    )
    process {

        $query = @"
IF EXISTS (SELECT * FROM ClientData WHERE ClientDataID = {0})
BEGIN
    DELETE FROM ClientData
    WHERE ClientDataID = {0}
END
"@ -f $ClientDataID

        Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
        if($PSCmdlet.ShouldProcess("ClientDataID = $ClientDataID")) {
            Invoke-Sqlcmd -ServerInstance 'monitorDb' -Database 'MonitorDomain' -Query $query
        }
    }
}

function Clean-ClientDataTable {
    [CmdletBinding()]
    param()
    Write-Verbose ("{0}`n`tGetting a list of client data from the MonitorDomain.ClientData table..." -f $MyInvocation.MyCommand.Name)
    # get a list of clientdata from the database
    $query = "SELECT * FROM ClientData"
    $clientDataTable = Invoke-Sqlcmd -ServerInstance 'monitorDb' -Database 'MonitorDomain' -Query $query

    # complile a list of clients that exist in the database but not in AD
    if($clientDataTable) {
        Write-Verbose ("{0}`n`tCompiling a list of clients that exist in the database but not in AD..." -f $MyInvocation.MyCommand.Name)
        [array]$toDelete = $clientDataTable | ?{($clients | select -ExpandProperty Name) -notcontains $_.ComputerName}
    }

    # remove any clients that are in the list from the database
    if($toDelete) {
        Write-Verbose ("{0}`n`tRemoving {1} records..." -f $MyInvocation.MyCommand.Name, $toDelete.Count)
        $toDelete | Remove-ClientDataRecord
    }
}

#endregion functions


#region main

# clean out any records in the ClientData table that don't have a matching AD Computer object
Clean-ClientDataTable

# loop through the clients and figure out who last logged on, assume that is who owns the machine
$clients | %{
    $c = $_.Name
    # make sure we can contact the client before anything else
    if(Test-Connection $c -Quiet -Count 2) {
        try {
            # get a list of last logged on users based on ntuser.dat last access time from C:\users\*\
            $clientUsers = Get-LogonHistory $c
                
            # make sure we got something back, then exclude any admin accounts
            if($clientUsers) {
                # store a list of the users that are not admin accounts
                $potentialUsers = @()
                $clientUsers | %{
                    try {
                        # see if this user is not an admin account
                        $u = Get-ADUser $_.Username
                        if($u.DistinguishedName -notlike "*UsersSystems*") {
                            $potentialUsers += New-Object PSObject -Property @{
                                Name = $u.Name
                                LastAccessTime = $_.LastAccessTime
                            }
                        }
                    } catch {
                        # do nothing, we just want to avoid seeing an exception when we try to query AD for an account that no longer exists
                    }
                }
                # now we have a list of potential users, pick the most recent one and update the description in AD
                # if no potential users (all accounts were admin or no longer exist) then update description to 'unknown'
                $clientData += New-Object PSObject -Property @{
                    ComputerName = $c
                    ComputerDescription = $_.Description
                    LastLoggedOnUser = $potentialUsers | select -First 1 | select -ExpandProperty Name
                    LastAccessTime = $potentialUsers | select -First 1 | select -ExpandProperty LastAccessTime
                }
            
            }
        } catch {
            $errors += New-Object PSObject -Property @{
                Function = $MyInvocation.MyCommand.Name
                Error = $_
            }
        }
    }

    # insert/update the ClientData table in the MonitorDomain database
    $clientData | Set-ClientDataRecord
}






#endregion main