<#
    .Synopsis
        DocuWare_Functions is a compilation of functions that query the dwystem database for information regarding users.
        It also contains functions to aid in cabinet creation.
        Written by Daniel C Mayhew, August 2011
#>

#region includes

if((Get-PSSnapin -Name SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue) -eq $null) {
    try{Add-PsSnapin SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue}catch{}
}

#endregion

#region variables

$db = 'DWSYSTEM'
$dwSqlSvr = 'docuwaredb'
$sqlMaxChar = 1000000

#endregion

#region functions

function Create-DocuWareCabinetADGroups {
<#
    .Synopsis
        This function creates the DELETE, READ, and WRITE Active Directory groups for the specified cabinet.
    .Description
        This creates the groups but does not add members. To add members use the Add-ADGroupMember Cmdlet. This
        function can take multiple cabinet names via pipeline and create groups for all of them.
    .Parameter CabinetName
        The exact name of the cabinet. This will be used to create the DELETE, READ, and WRITE groups. For example,
        if the cabinet is named 'TAX-FORMS', the READ groups would be created as 'DW_TAX-FORMS_READ'.
    .Example
        PS C:\> 'TAX-FORMS' | Create-DocuWareCabinetADGroups
    .Example
        PS C:\> 'TAX-FORMS', 'PAY-FORMS' | Create-DocuWareCabinetADGroups
    .Example
        PS C:\> $grps = 'TAX-FORMS', 'PAY-FORMS', 'SECURE-FORMS'
        PS C:\> $grps | Create-DocuWareCabinetADGroups
#>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)][string]$CabinetName
    )
    begin {
        $privs = 'DELETE', 'READ', 'WRITE'
        $ouPath = "ou=DocuWare,ou=Groups,dc=fso,dc=arizona,dc=edu"
    }
    process {
        Write-Verbose ("Creating AD groups for the {0} cabinet in {1}..." -f $CabinetName, $ouPath)
        $privs | % {
            $grpName = "DW_{0}_{1}" -f $CabinetName, $_
            
            if($grpName.Contains('READ')) {
                $description = "Users with read only permissions in the $CabinetName file cabinet."
            } elseif ($grpName.Contains('WRITE')) {
                $description = "Users with standard permissions in the $CabinetName file cabinet."
            } elseif ($grpName.Contains('DELETE')) {
                $description = "Users with standard user permissions and the added ability to delete documents in the $CabinetName file cabinet."
            }
            if($PSCmdlet.ShouldProcess($grpName)) {
                New-ADGroup -Name $grpName -SamAccountName $grpName -GroupCategory Security -GroupScope Global -Description $description -DisplayName $grpName -Path $ouPath
                $grpName
            }
        }
    }
    end{
        Write-Verbose "Complete"
    }
}


function Get-DWFileCabinetsByUser {
<#
    .Synopsis
        This function returns a list of file cabinets assigned to a DocuWare user.
    .Description
        This function queries the DWSystem database and parses the settings xml to determine what
        file cabinets are assigned to the user.
    .Parameter SamAccountName
        The Active Directory SamAccountName of the DocuWare user, which is also the user's DocuWare username.
    .Inputs
        The SamAccountName accepts input via pipeline and via pipeline by property name.
   .Example
        Get-ADUser someuser | Get-DWFileCabinetsByUser        
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$SamAccountName
    )
    process {
        $result = @()
        Write-Verbose ("Getting DocuWare file cabinet access for {0}..." -f $SamAccountName)
        $query = "SELECT settings FROM DWUser WHERE name = '$SamAccountName'"
        [xml]$xml = (Invoke-Sqlcmd -ServerInstance $dwSqlSvr -Database $db -Query $query -MaxCharLength $sqlMaxChar).Settings
        $pattern = "\\(?<cabinet>[^\\]+)\.ADF$"
        $xml.DWUser.Registered.FileCabinets.FileCabinet | select path | Split-Path -Leaf | %{
            $query = "SELECT name FROM DWFileCabinet WHERE name like '{0}%'" -f [system.io.path]::GetFileNameWithoutExtension("$_")
            $result += (Invoke-Sqlcmd -ServerInstance $dwSqlSvr -Database $db -Query $query -MaxCharLength $sqlMaxChar).name
        }
        $result | sort
    }
}

function Get-DWBasketsByUser {
<#
    .Synopsis
        This function returns a list of baskets assigned to a DocuWare user.
    .Description
        This function queries the DWSystem database and parses the settings xml to determine what centrally managed
        baskets are assigned to the user.
    .Parameter SamAccountName
        The Active Directory SamAccountName of the DocuWare user, which is also the user's DocuWare username.
    .Inputs
        The SamAccountName accepts input via pipeline and via pipeline by property name.
   .Example
        Get-ADUser someuser | Get-DWBasketsByUser        
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$SamAccountName
    )
    process {
        Write-Verbose ("Getting DocuWare basket assignment for {0}..." -f $SamAccountName)
        $query = "SELECT settings FROM DWUser WHERE name = '$SamAccountName'"
        [xml]$xml = (Invoke-Sqlcmd -ServerInstance $dwSqlSvr -Database $db -Query $query -MaxCharLength $sqlMaxChar).Settings
        $pattern = "\\(?<basket>[^\\]+)\.ADF$"
        $xml.DWUser.Registered.Baskets.Basket | select -ExpandProperty path
    }
}

function Get-DWGroupMembershipByUser {
<#
    .Synopsis
        This function returns a list of DocuWare groups assigned to a DocuWare user.
    .Description
        This function queries the DWSystem database to determine what DocuWare groups are assigned to the user.
    .Parameter SamAccountName
        The Active Directory SamAccountName of the DocuWare user, which is also the user's DocuWare username.
    .Inputs
        The SamAccountName accepts input via pipeline and via pipeline by property name.
   .Example
        Get-ADUser someuser | Get-DWGroupMembershipByUser        
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$SamAccountName
    )
    process {
        Write-Verbose ("Getting DocuWare group membership for {0}..." -f $SamAccountName)
        $query ="SELECT DWGroup.name
        FROM DWGroup Join DWUserToGroup on DWGroup.gid = DWUserToGroup.gid
        WHERE DWUserToGroup.uid = (SELECT uid FROM DWUser WHERE name = '{0}')" -f $SamAccountName
        $result = Invoke-Sqlcmd -ServerInstance $dwSqlSvr -Database $db -Query $query -MaxCharLength $sqlMaxChar
        if($result) {
            $result | select -ExpandProperty name | sort
        } else {
            Write-Verbose ("No DocuWare group membership found for {0}. This is most likely because {0} is not a DocuWare user." -f $SamAccountName)
        }
    }   
}

function Get-DWRoleAssignmentByUser {
<#
    .Synopsis
        This function returns a list of DocuWare roles assigned to a DocuWare user.
    .Description
        This function queries the DWSystem database to determine what DocuWare roles are assigned to the user.
    .Parameter SamAccountName
        The Active Directory SamAccountName of the DocuWare user, which is also the user's DocuWare username.
    .Inputs
        The SamAccountName accepts input via pipeline and via pipeline by property name.
   .Example
        Get-ADUser someuser | Get-DWRoleAssignmentByUser        
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$SamAccountName
    )
    process {
        Write-Verbose ("Getting DocuWare role assignment for {0}..." -f $SamAccountName)
        $query ="SELECT DWRoles.name
        FROM DWRoles
        Join DWUserToRole on DWRoles.rid = DWUserToRole.rid
        WHERE DWUserToRole.uid = (SELECT uid FROM DWUser WHERE name = '{0}')" -f $SamAccountName
        $roles = Invoke-Sqlcmd -ServerInstance $dwSqlSvr -Database $db -Query $query -MaxCharLength $sqlMaxChar
        if($roles) {
            $roles | select -ExpandProperty name
        } else {
            Write-Verbose ("No DocuWare roles have been assigned to {0}" -f $SamAccountName)
        }
    }   
}

#endregion


# SIG # Begin signature block
# MIIUdgYJKoZIhvcNAQcCoIIUZzCCFGMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUAP8cXZWJcfa2wXmit2ViEdQ5
# 7v+ggg+4MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# MRYEFBNOaOlJOXFi++RedmSpRkEFwlxpMA0GCSqGSIb3DQEBAQUABIIBADvaeUNV
# KRH9Dwgirwa4a7oL2NC6DKdiRdBcum6WXup7oOETQxK0CSuDBLfPL206G3lh5Ywt
# jo3oPg21WsmwR7MwDMa+Y4UkIpZOP5YhOZlWkeVk/XJXoMNN4UojJuOcwxlR/vMh
# AtxQFfyJQO24oXAGaflFN5eL1W7I3gUbzSr9V9+IkF6ZKezE7L2zTS3GNrfdiRlz
# 59JF/SbbnfCkDuBm+/8lw85QV7kooLJt2laKioJqipKd+rIGKZSDfsIo18qrF3lo
# JrWdSC2GL5XOsG7dl0QaleaBBp4onsmw5LpUyhiRHJ5U5XXdfI4upK/RhABkRxVo
# ltSzxarkOSinsM2hggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBeMQsw
# CQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNV
# BAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQDs/0
# OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMTMwNjA1MDEwMzU1WjAjBgkqhkiG9w0BCQQx
# FgQUpgzqhUGzYWAJ3J70A15S744nQoMwDQYJKoZIhvcNAQEBBQAEggEAMFX64iXK
# ib8sIaRoiFkt87+ywL98thz53hG9tjE+N3Tkkup06sZlrXzbhowiYPW/S/XDytcs
# nuWeo2P71D13cIJp9Kw1UndmZql21gtWABlf/jxqJmDF3uviEzGPC09z304c4mp1
# aFEq3AnNsmhA+GbPfmMnyjTSCZWileSwpEKS5IAwo9yKvlbvCCwWl1oW1iOe5Cv4
# Uphr912wm31Cn07WhyRJGOnkhz4XBRq2rl0J+AA7yexGEnYXiWBarlmIYAet+YHL
# wtFQauu3201+qW2AMB8vQxOhz1ayKKtDBtaCA9hR0uIY9TTotrjr/3xKob8C/NoU
# emvQHNjbqEUDVA==
# SIG # End signature block
