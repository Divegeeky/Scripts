[CmdletBinding(SupportsShouldProcess=$true)]
param()

#region includes

Import-Module activedirectory
Import-Module \\fso\core\Scripts\include\Utility_Functions.psm1 -DisableNameChecking
. \\fso\core\Scripts\BGinfo\Setup-BGInfo.ps1

#endregion includes

#region functions

function Set-LocalDescription {
<#
	.Synopsis
		Set-LocalDescription sets the local description on the specified computer.
	.Description
		This function sets the registry value HKLM\System\CurrentControlSet\Services\lanmanserver\parameters\srvcomment
        according to the Description parameter value. The description change won't take effect until the machine reboots.
	.Parameter Name
		The name of the computer. This can be derived by property name from an AD computer object.
	.Parameter Description
		The string to set the description to on the specified computer. This can be derived by property name from an AD computer object.
	.Example
		PS C:\Windows\system32> Get-ADComputer svr0001 -Properties Description | Set-LocalDescription
	.Notes
		Author: Daniel C Mayhew
		Date: 5/15/2012
#>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$Name,
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)][string]$Description
    )
    process {
        if(Test-Connection $Name -Quiet -Count 2) {
            Write-Verbose ("{0}`n`tComputer: {1}`n`tDescription: {2}" -f $MyInvocation.MyCommand.Name, $Name, $Description)
            # the description can only be 48 chars or less
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("LocalMachine", $Name)
            $regKey= $reg.OpenSubKey("System\\CurrentControlSet\\Services\\lanmanserver\\parameters", $true)
            $currentDescription = $regkey.GetValue("srvcomment")
            if($currentDescription -ne $Description) {
                if($PSCmdLet.ShouldProcess("$Name - Change local description from '$currentDescription' to '$Description'")) {
                    $regKey.SetValue('srvcomment',$Description)
                }
            } else {
                Write-Verbose ("{0}`n`tThe new description, '{1}', is the same as the current description, '{2}'. No changes will be made." -f $MyInvocation.MyCommand.Name, $Description, $currentDescription)
            }
        } else {
            throw "$Name did not respond"
        }
    }
}

function Set-ServerInitialConfig {
<#
    .Synopsis
        Configures BGinfo, syncs local description with AD, and gpupdates server.
    .Parameter Name
        The name of the server.
    .Example
        PS C:\> 'svr0001' | Set-ServerInitialConfig
#>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$Name,
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)][string]$Description = ''
    )
    process {
        # get the ad computer object with description. If it doesn't exist catch the exception
        try {
            Write-Verbose ("{0}`n`tQuerying AD for {1}..." -F $MyInvocation.MyCommand.Name, $Name)
            $svr = Get-ADComputer $Name -Properties Description
            
            # if a description has been passed in set it on the AD object first
            if($Description) {
                Write-Verbose ("{0}`n`tUpdating description on {1} to '{2}'" -f $MyInvocation.MyCommand.Name, $Name, $Description)
                Set-ADComputer -Identity $svr.SamAccountName -Description $Description -Confirm:$false
                # make sure replication has occured
                $waitingForReplication = $true
                while($waitingForReplication) {
                    Write-Verbose ("{0}`n`tWaiting on AD replication..." -f $MyInvocation.MyCommand.Name)
                    $svr = Get-ADComputer $Name -Properties Description
                    if($svr.Description -eq $Description) {
                        $waitingForReplication = $false
                    }
                }
            }
            
            # determine if this machine is a dev box and set the bginfo accordingly
            if($svr.Description -and $svr.Description -like "*dev*") {
                $devgrp = 'GPO_Dev Machines_COMPUTERS'
                # see if it is already a member
                $devGrpMembers = Get-ADGroupMember $devgrp | select -ExpandProperty Name
                if($devGrpMembers -notcontains $Name) {
                    Write-Verbose ("{0}`n`t{1}'s description is '{2}'. Adding {1} to '{3}'..." -f $MyInvocation.MyCommand.Name, $Name, $svr.Description, $devgrp)
                    if($PSCmdlet.ShouldProcess("Add $Name to $devgrp")) {
                        Add-ADGroupMember -Identity $devgrp -Members $svr.SamAccountName -Confirm:$false
                    }
                } else {
                    Write-Verbose ("{0}`n`t{1} is already in {2}" -f $MyInvocation.MyCommand.Name, $Name, $devgrp)
                }
            }
            
            # if this server isn't in the correct ou, move it
            if(($svr.DistinguishedName -like "*OU=Builds*") -or ($svr.DistinguishedName -like "*CN=Computers*")) {
                $targetOu = 'OU=Servers,DC=FSO,DC=Arizona,DC=EDU'
                $svr | Move-ADObject -TargetPath $targetOu -Confirm:$false
            }
            
            # sync the local description
            $svr | Set-LocalDescription
            
            # set bginfo
            $Name | Configure-BGInfo

            # set vmtools.conf
            $Name | Set-VmToolsConf
            
            # gpupdate, have to do all this psboundparameter stuff because importing a module behaves different than dot sourcing.
            if($PSBoundParameters['Verbose']) {
                if($PSBoundParameters['WhatIf']) {
                    Run-RemoteCMD -Name $Name -Command 'gpupdate /force' -Verbose -WhatIf
                } else {
                    Run-RemoteCMD -Name $Name -Command 'gpupdate /force' -Verbose
                }
            } else {
                if($PSBoundParameters['WhatIf']) {
                    Run-RemoteCMD -Name $Name -Command 'gpupdate /force' -WhatIf
                } else {
                    Run-RemoteCMD -Name $Name -Command 'gpupdate /force'
                }
            }

        } catch {
            $_
        }
    }
}

function Set-SophosComputersAndDeletedComputers {
<#
    .Synopsis
        Updates the Sophos database to allow 2012 R2 and Windows 8.1 to be treated like 2012 and Windows 8.
    .Description
        This is a workaround to get Sophos to protect Server 2012 R2 and Windows 8.1 clients.
    .Example
        PS C:\> An example of using the command
    .Notes
        Found this solution here: http://www.sophos.com/en-us/support/knowledgebase/119728.aspx
#>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$Name,
    [parameter(Mandatory=$false)][ValidateSet('Server2012R2','Windows8.1')][string]$OperatingSystem = 'Server2012R2'
    )
    process {
        Switch ($OperatingSystem) {
            'Server2012R2' {$os = 36}
            'Windows8.1' {$os = 35}
            default {(throw "Invalid Operating System type: {0}" -f $OperatingSystem)}
        }
        if($os) {
            $query = @"
IF EXISTS(
  SELECT *
  FROM [SOPHOS521].[dbo].[ComputersAndDeletedComputers]
  WHERE Name like '{0}'
)
UPDATE [SOPHOS521].[dbo].[ComputersAndDeletedComputers]
SET OperatingSystem = {1}
WHERE Name like '{0}'
"@ -f $Name, $os
            Write-Verbose ("{0}`n`t{1}" -f $MyInvocation.MyCommand.Name, $query)
            if($PSCmdlet.ShouldProcess($query)) {
                Invoke-Sqlcmd -ServerInstance 'svr0102' -Database 'SOPHOS521' -Query $query
            }
        }
    }
}

function Set-VmToolsConf {
<#
    .Synopsis
        Creates a 'tools.conf' file to silence event logging of nuisance errors reported by VM Tools.
    .Parameter Name
        The name of the server. This is the Name property of an AD Computer object.
    .Example
        PS C:\> Get-ADComputer 'svr0001' | Set-VmToolsConf
    .Example
        PS C:\> 'svr0001' | Set-VmToolsConf
    .Example
        PS C:\> Set-VmToolsConf -Name 'svr0001'
#>
    [CmdletBinding(SupportsShouldProcess=$true) ]
    param(
    [parameter(Mandatory =$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string ]$Name
    )
    begin {
        $content = "[logging]`r`nvmusr.level = error`r`n[unity]`r`nPbrpc.enable = false"
        Write-Verbose ("Content:`n{0}" -f $content)
    }
    process {
        Write-Verbose ("Determining location of tools.conf on {0}" -f $Name)
        # determine which location to push the conf file to
        $dest = ''
        $destLegacy = '\\' + $Name + '\C$\Documents and Settings\All Users\Application Data\VMware\VMware Tools'
        $destNew = '\\' + $Name + '\C$\ProgramData\VMware\VMware Tools'
        if(Test-Path $destLegacy) {
            Write-Verbose ("Found path at {0}" -f $destLegacy)
            # this is a 2003 box, check to see if the tools.conf file already exists
            $toolsConfFullPath = (Join-Path $destLegacy 'tools.conf')
            if(Test-Path $toolsConfFullPath) {
                # overwrite existing file
                Write-Verbose "Found existing tools.conf file, overwriting contents..."
                Set-Content -Value $content -Path $toolsConfFullPath -Force | Out-Null
            } else {
                # create new file
                Write-Verbose "Creating new tools.conf file..."
                New-Item -ItemType File -Path $toolsConfFullPath -Value $content -Force | Out-Null
            }
        } elseif(Test-Path $destNew) {
            Write-Verbose ("Found path at {0}" -f $destNew)
            # this is 2008 or newer, check to see if the tools.conf file already exists
            $toolsConfFullPath = (Join-Path $destNew 'tools.conf')
            if(Test-Path (Join-Path $destNew 'tools.conf')) {
                # overwrite existing file
                Write-Verbose "Found existing tools.conf file, overwriting contents..."
                Set-Content -Value $content -Path $toolsConfFullPath -Force | Out-Null
            } else {
                # create new file
                Write-Verbose "Creating new tools.conf file..."
                New-Item -ItemType File -Path $toolsConfFullPath -Value $content -Force | Out-Null
            }

        }
        Write-Verbose "Restarting vmtools service..."
        if($PSCmdlet.ShouldProcess("Restart vmtools service on $Name")) {
            $session = New-PSSession -ComputerName $Name
            Invoke-Command -Session $session -ScriptBlock {Restart-Service vmtools}
        }

    }
    end {}
}

#endregion functions


# SIG # Begin signature block
# MIIUdgYJKoZIhvcNAQcCoIIUZzCCFGMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUtmuFswTN1FrOJpmI/pKSYXu/
# AYOggg+4MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# MRYEFDlL7GNYPOHyzymNihpjBsxOG/z2MA0GCSqGSIb3DQEBAQUABIIBACNbWxOW
# Vbf23lXX3B8d4pzwGb2/5bT2Z2YKPwafwaSqozNN0woSB5RiwYEJpM7hXFFi0KXO
# jxprUx3MyIxlfq6uFYu0jAYVpkqs0Bmv/mOKG2Ce10jU689dRGE9J8q4faq7sr/2
# DlchX9TB9dKsgeOxD1YUhtfoAEuMcTFiScuIAz4nCpfXHh19B8cuVnELOEcgYruT
# HV2bOjZJ7tFa6/sQ7mkgcJLixjyacy9dzvY03dNrL0nYs+s14MW3IWiNn20qDfxo
# h3hVggaS1fp5rR71pWKNibcVaN6fS4jhFW8STVM/rx2hBLrMABqni2Cjfcowhr22
# 7RiMHJLPHC0v4NOhggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBeMQsw
# CQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNV
# BAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQDs/0
# OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMTQwMTA2MjMzMjMzWjAjBgkqhkiG9w0BCQQx
# FgQUbDc10ZRb51n+Uw4sIn8qd7/FFBQwDQYJKoZIhvcNAQEBBQAEggEAN5aA5avz
# FsrlibfwMh29D/bOfPDath3iD4aVNFnoEbpxFukIpx2yov6z/KVA4hP0xr8XK++p
# fLRA6n96zoovOwuXYshvcM7nFQUDAToDITHuMkdTFjrefkqJdgREHfPU/FTxbm9E
# bCFUB4VijZgKgHW/2aTZC5SPxlUS5gnPvQ5JO4/hlbNN/Hul56Y6FAvf7sdr3KWV
# BzjTr+LMFelZbtOYeq/EqBiBa0CPvs4rdd93HD4iprkCvE4AVYXJIPNs/L3xQtKB
# zvTOVGgiP1mekGQnXmxc0fLtcDoRqmpR1Qr7vDrJCr/oAy2kiWOoiFdqkjIfxFAk
# OSBMZcfCMGXiyA==
# SIG # End signature block
