
function Test-CsvFormat {
<#
    .Synopsis
        Verifies the properties of a CSV file.
    .Description
        Verifies the path to the file and that the file contains at least the properties specified.
        If the strict switch is used the file may only contain the listed properties.
    .Parameter CsvFilePath
        The full path including file name of the CSV file to test.
    .Parameter Properties
        A list of property names the file should contain.
    .Parameter Strict
        Switch parameter if used will verify the file contains only the specified properties.
    .Parameter OutputResults
        Switch parameter if used will set the functin to return an object with a boolean and 
        2 lists: missing and extra properties instead of just true of false.
    .Example
        PS C:\> Test-CsvFormat C:\temp\test.csv -Properties @('Column1','Column2')

        This example returns true if the csv file contains at least the properties specified.
    .Example
        PS C:\> Test-CsvFormat C:\temp\test.csv -Properties @('Column1','Column2') -Strict

        This example returns true if the csv file contains only the properties specified.
    .Example
        PS C:\> Test-CsvFormat C:\temp\test.csv -Properties @('Column1','Column2') -OutputResults

        Thie example returns an object that contains a boolean named 'Verified' that is set to true if
        the file contains at least the properties specified, a list named 'Missing' that contains specified
        properties that the csv does not have, a list named 'Extra' that contains properties the 
        csv file has that are not specified, and a list of errors encountered. Any or all lists may be empty.
    .Example
        PS C:\> Test-CsvFormat C:\temp\test.csv -Properties @('Column1','Column2') -Strict -OutputResults

        Thie example returns an object that contains a boolean named 'Verified' that is set to true if
        the file contains only the properties specified, a list named 'Missing' that contains specified
        properties that the csv does not have, a list named 'Extra' that contains properties the 
        csv file has that are not specified, and a list named 'Errors' that contains any other errors encountered.
#>
    [CmdletBinding()]
    param (
    [parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)][ValidateScript({Test-Path $_})][String]$CsvFilePath,
    [parameter(Mandatory=$true,Position=1)][ValidateNotNull()][Array]$Properties,
    [parameter(Mandatory=$false)][switch]$Strict,
    [parameter(Mandatory=$false)][switch]$OutputResults
    )
    process {
        Write-Verbose ("{0}`n`tVerifying {1} is a .csv file..." -f $MyInvocation.MyCommand.Name, $CsvFilePath)
        $item = Get-Item $CsvFilePath
        $missing = @()
        $extra = @()
        $errors = @()
        if($item.Extension -like '.csv') {
            Write-Verbose ("{0}`n`tImporting '{1}'..." -f $MyInvocation.MyCommand.Name, (Split-Path $CsvFilePath -Leaf))
            $csv = Import-Csv $CsvFilePath -WarningAction SilentlyContinue
            Write-Verbose ("{0}`n`tGetting header names..." -f $MyInvocation.MyCommand.Name)
            $csvFields = $csv | select -first 1 | Get-Member -MemberType NoteProperty | select -ExpandProperty Name 
            Write-Verbose ("{0}`n`tTesting for missing properties..." -f $MyInvocation.MyCommand.Name)
            $missing = @()
            foreach ($property in $Properties) {
                if ($csvFields -notcontains $property) {
                    $missing += $property
                }
            }
            Write-Verbose ("{0}`n`tTesting for extra properties..." -f $MyInvocation.MyCommand.Name)
            $extra = @()
            foreach ($field in $csvFields) {
                if ($Properties -notcontains $field) {
                    $extra += $field
                }
            }

            if($Strict) {
                Write-Verbose ("{0}`n`tStrict switch used, verifying there are no missing or extra properties..." -f $MyInvocation.MyCommand.Name)
                $verified = (Test-IsNullOrBlankOrEmpty $missing) -and (Test-IsNullOrBlankOrEmpty $extra)
            } else {
                Write-Verbose ("{0}`n`tVerifying there are no missing properties..." -f $MyInvocation.MyCommand.Name)
                $verified = Test-IsNullOrBlankOrEmpty $missing
            }
            
        } else {
            Write-Verbose ("{0}`n`t{1} is not a .csv file" -f $MyInvocation.MyCommand.Name, $CsvFilePath)
            $verified = $false
            $errors += "{0} is not a .csv file" -f $CsvFilePath
        }

        if($OutputResults) {
            Write-Verbose ("{0}`n`tOutputing results..." -f $MyInvocation.MyCommand.Name)
            New-Object PSObject -Property @{
                Verified = $verified
                Missing = $missing
                Extra = $extra
                Errors = $errors
            }
        } else {
            $verified
        }
    }
}

function Test-IsByteArray {
<#
    .Synopsis
        Returns true if the object is a byte array, false otherwise.
    .Example
        PS C:\> $objectToTest | Test-IsByteArray
#>

    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]$Obj
    )
    process {
        $Obj.GetType().Name -eq 'Byte[]'
    }
}

function Test-IsDBNull {
<#
    .Synopsis
        Returns true if the specified object property is of type DBNull, false otherwise.
    .Parameter Property
        The object property to test for DBNull
    .Example
        $result[0].MiddleName | Test-DBNull
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
    [AllowEmptyCollection()]
    [AllowEmptyString()]
    [AllowNull()]
    $Property
    )
    process {
        Write-Verbose ("{0}`n`tTesting {1} for DBNull..." -f $MyInvocation.MyCommand.Name, $Property)
        $Property.GetType().Name -eq 'DBNull'
    }
}

function Test-IsNotNullOrBlankOrEmpty {
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,Position=0)]
    [AllowEmptyCollection()]
    [AllowEmptyString()]
    [AllowNull()]
    $Obj
    )
    process {
        (-not(Test-IsNullOrBlankOrEmpty $Obj))
    }
}

function Test-IsNullOrBlankOrEmpty {
<#
    .Synopsis
        Returns true if the sepecified Object is Null, DBNull, Empty, Zero, or consists
        only of white-space characters.
    .Description
        If the passed in object is a string this function trims the string and passes
        it to String's IsNullOrEmpty function.  If the object is not a string this
        function checks to see if it is of type DBNull, if it is equal to Null, or if 
        its length is equal to zero.
    .Parameter Obj
        The object to test.
    .Inputs
        This function does not accept input via pipeline.
    .Outputs
        Boolean only.
    .Example
        $a = @()
        PS C:\> $a | Test-IsNullOrBlankOrEmpty
#>
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,Position=0)]
    [AllowEmptyCollection()]
    [AllowEmptyString()]
    [AllowNull()]
    $Obj
    )
    process {
        Write-Verbose ("{0}`n`tTesting Obj..." -f $MyInvocation.MyCommand.Name)
        try {
            if($Obj -eq $null) {
                Write-Verbose ("{0}`n`tObj equals null" -f $MyInvocation.MyCommand.Name)
                $true
            } elseif($Obj -is [string]) {
                Write-Verbose ("{0}`n`tObj is a string" -f $MyInvocation.MyCommand.Name)
                [string]::IsNullOrEmpty(($Obj.Trim()))
            } elseif($Obj -is [array] -or $Obj -is [hashtable]) {
                Write-Verbose ("{0}`n`tObj is an array or hashtable" -f $MyInvocation.MyCommand.Name)
                ($Obj.Length -eq 0) -or ($Obj.Count -eq 0)
            } elseif (($Obj | Test-IsDBNull)) {
                Write-Verbose ("{0}`n`tObj is a {1}" -f $MyInvocation.MyCommand.Name, $Obj.GetType())
                $true
            } elseif(-not ($Obj)) {
                Write-Verbose ("{0}`n`tPowershell seems to think Obj is empty or null or has a value of zero..." -f $MyInvocation.MyCommand.Name)
                $true
            } else {
                Write-Verbose ("{0}`n`tCould not make definitive determination, assuming Obj is not null." -f $MyInvocation.MyCommand.Name)
                $false
            }
        } catch [System.Management.Automation.RuntimeException] {
            if($_.FullyQualifiedErrorID -eq 'InvokeMethodOnNull') {
                Write-Verbose ("{0}`n`tObj generated InvokeMethodOnNull exception" -f $MyInvocation.MyCommand.Name)
                $true
            }
            Write-Verbose ("{0}`n`tException caught!`n{1}" -f $MyInvocation.MyCommand.Name, $_)
        } catch {
            Write-Verbose ("{0}`n`tException caught!`n{1}" -f $MyInvocation.MyCommand.Name, $_)
            $_
        }
    }
}


# SIG # Begin signature block
# MIIUdgYJKoZIhvcNAQcCoIIUZzCCFGMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUrMyPpjmjANJc595hedSp/YJg
# sveggg+4MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# MRYEFAgqvRNK5MQE6lZEPx2JZZ3lZCcsMA0GCSqGSIb3DQEBAQUABIIBAAQK8tNn
# taxPp71G9Z5WT6JEciq6WMBUbklkZvw6yWHMquIRgmuj+U3Cs8H57xKUCSZy9ChU
# C0pDQTxdnKPULDE/KJjSxdEwY6n4ZTgukrX3m6sJVbjB8PeZINU+0+qt6MjsIRNg
# JqYOUOz+Pp80trwMZlNJLjOA4mR4tLV/Tnn37Plj6a+J/0Tmp2uMdhMrdcaQbMh3
# CIca9WFTtsLOR6WKp1vUFYwZqbqcpLA2j/6DDdj/LZ2KDRNJ4zLktosQgFIIv6uT
# Pypy+VdfnIsV+gvC5kDQJ4tpB9JbRrVachfoAILmgJVbECLM38wBauOvgPUGgYIv
# nQe1vuYoySGcWaGhggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBeMQsw
# CQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNV
# BAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQDs/0
# OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMTMxMjAyMjAxMTM4WjAjBgkqhkiG9w0BCQQx
# FgQUMUnGGDuw+Oo/ElV5eSfKsWUfOhcwDQYJKoZIhvcNAQEBBQAEggEARMjzWXiJ
# UzzkzFXHXmJV0t/u2hYJzejyes19u3KlOk0LUXeB03B/QiRNoW+Hor62VNxRoo9q
# DRYPWbtMLmWjV1BuupX/ALO/RHMhUGxfSuEkpGuiXy1PwFEgJbpPI/zJuY/KaVv9
# BeA/tENC11rUMG77i5p3zk35n85BAMx+GN0u+jAFnX8bAyIczsSuah84xsWuzkJe
# hDr3p46329F5b7266XEhGNQ3oQNx4kh5mI0sK+nS9Y2fovcnLFrGKA7IEg1qg3k+
# C7metrwx6PkvVewy0ywCrUKakMgglnvc1HsQfR1z7OhKqFEPuXneoqPrTXXomc+7
# lThgago3xh/zhQ==
# SIG # End signature block
