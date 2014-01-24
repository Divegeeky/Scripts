function Store-Password {
<#
    .Synopsis
        Takes a secure string and writes it (encrypted) to the filesystem for later retrieval.
    .Description
        Uses the -Key parameter in ConvertFrom-SecureString to encrypt the password in a way that any other user can decrypt it. Uses Export-Clixml to store the data as XML in a file.
    .Parameter credential
        This required parameter is the credential object containing the password you wish to store. This can be an array of credentials passed down the pipeline.
    .Parameter filename
        The full path and filename of the file location where you wish to store the password.This file should NOT already exist. This parameter is not required; if no filename is provided,
        the function will create a temporary file in the user's temp directory.
    .OUTPUTS
        Returns an object containing the full path of the file containing the encrypted password data and the randomly-generated key used for encryption. NOTE: This key MUST 
        be maintained in order to retrieve the password.
    .Example
       $pass = read-host -AsSecureString
       $pass | Store-Password -filename 'C:\password.xml'
    .Notes
        Created 07/19/2010 Jeffrey B Smith
       
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [System.Management.Automation.PSCredential]$credential,
        [string]$filename = [System.IO.Path]::GetTempFileName()
    )
    begin {
        if(!(Test-Path $filename)) {
            Set-content -Path $filename -Value $null
        }
        else {
            throw {File already exists!}
        }
        [array]$results = $null
        [hashtable]$hash = $null
        
    }
    process {
        # Generate a random 256-bit Rijndael encryption key.
        $key = 1..32 | %{ get-random -max 256}
        # Using generic names for the properties since they appear in plaintext in the created file.
        $hash += @{
            $credential.Username = ConvertFrom-SecureString -SecureString $credential.Password -Key $key
            
        }
        $output = @{
            UserName=$credential.username
            File=$filename
            Key=$key
        }
        $results += New-Object PSObject -Property $output
    }
    end {
        $hash | Export-Clixml $filename
        $results
       
    }
}


function Retrieve-Password {
<#
.Synopsis
    Retrieves a secure string from the filesystem.
.Description
    Essentially just a wrapper around Convertto-SecureString
.Parameter user
    This required parameter is the username you wish to retrieve from the password store designated with the file parameter.
.Parameter key
    This parameter is the unique key used to encrypt the password found in 'file.' This should be passed as an array of numbers (bytes).
.Parameter file
    The full path and filename of the file location from which you wish to retrieve and decrypt password data.
.OUTPUTS
    [System.Security.SecureString] or [System.Security.SecureString[]]
.Notes
    Created 07/19/2010 Jeffrey B Smith
   
#>
    param(
		[parameter(Mandatory=$true)][string]$user,
        [Parameter(Mandatory=$true)][array]$key,
        [Parameter(Mandatory=$true)][string]$file
    )
    if(!(Test-Path $file)) {
    	Throw {"File not found!"}
    }
    else {
        (Import-Clixml $file).$user | ConvertTo-SecureString -Key $key
    }
}
        
function New-Credential {
    param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [System.Security.SecureString]$password,
    [string]$user = 'FSO\DummyUser'
    )
    process {
        New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password
    }
}

function Test-Credential {
<#
	.SYNOPSIS
		Takes a PSCredential object and validates it against the domain (or local machine, or ADAM instance).

	.PARAMETER cred
		A PScredential object with the username/password you wish to test. Typically this is generated using the Get-Credential cmdlet. Accepts pipeline input.
		
	.PARAMETER context
		An optional parameter specifying what type of credential this is. Possible values are 'Domain','Machine',and 'ApplicationDirectory.' The default is 'Domain.'
	
	.OUTPUTS
		A boolean, indicating whether the credentials were successfully validated.

	.NOTES
		Created by Jeffrey B Smith, 6/30/2010
        Based on testing, the Machine and ApplicationDirectory contexts may not be working properly. Use this solely for domain tests at the moment. JBS 7/13/2010
#>
	param(
		[parameter(Mandatory=$true,ValueFromPipeline=$true)]
		[System.Management.Automation.PSCredential]$credential,
		[parameter()][validateset('Domain','Machine','ApplicationDirectory')]
		[string]$context = 'Domain'
	)
	begin {
		Add-Type -assemblyname system.DirectoryServices.accountmanagement
		$DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext($context) 
	}
	process {
		$DS.ValidateCredentials($credential.UserName, $credential.GetNetworkCredential().password)
	}
}


function Get-Password {
<#
	.SYNOPSIS
		Takes a PSCredential object and returns the password stored in the secure string.

	.PARAMETER credential
		The PScredential object with the password you wish to retrieve. Typically this is generated using the Get-Credential cmdlet. Accepts pipeline input.
		
	.OUTPUTS
		The password as System.String

	.NOTES
		Created by Jeffrey B Smith, 12/13/2010
#>    
    param([parameter(Mandatory=$true, ValueFromPipeline=$true)][System.Management.Automation.PSCredential]$credential)
    $credential.getNetworkCredential().password
}

function New-RandomPassword {
<#
	.SYNOPSIS
		Generates a new random password.

	.PARAMETER Length
		An integer that determines the length (number of characters) of the generated password. Default value is 12.
        
    .PARAMETER MinNumSpecial
		An integer that determines the minimum number of non-alphanumeric ("special") characters in the generated password. There might be more than the minimum.
        Default value is 1.
		
	.OUTPUTS
		The password as System.String

	.NOTES
		Created by Jeffrey B Smith, 8/2/2011
#>    

    param(
        [int]$length = 12,
        [int]$minNumSpecial = 1
    )
    
    begin {
        [system.reflection.assembly]::LoadWithPartialName('System.Web') | Out-Null
    }
    process {
        [system.web.security.membership]::GeneratePassword($length, $minSpecial)
    }
}
# SIG # Begin signature block
# MIIUdgYJKoZIhvcNAQcCoIIUZzCCFGMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUITkzegTG+GMi80gCeRFpeCzI
# Kvaggg+4MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# MRYEFOu+faVtIppb4M/BQF+dxhclj4MoMA0GCSqGSIb3DQEBAQUABIIBAJNXvPlz
# jvzB9aZUP+brM4zW6djrzeqgwRLtWef5vt5FiwUpKM1wAFJXInYBEtBin0aZaLWS
# TZ+hpveffru7D7CLYByg/KbhZ6qeoSkL/5f2aBBQnHNt0krpHw0e24w/V3Px4GtY
# f4dZOaesR02u87+qQl5AzHtRL+0z4/syY0AGm6aDb2XFCXQy36QS/vPxu18V4J6N
# cZCYoV7UIQbjkQIC7joPwkmLBBYz7w3YWuV+plBrNV4qGTc8FJRP8QJoqOOBii26
# H1RAZ9geMT4n1Ajq9+NUGQoBclM+cjIyvio1aXRt/AErG+ZHT14hotvVxIw/jrTk
# 657by194l8Q/9fChggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBeMQsw
# CQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNV
# BAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQDs/0
# OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMTMwNjA1MDEwMzQ1WjAjBgkqhkiG9w0BCQQx
# FgQUkEBeFf/5jkAWAxNX+d6iwZ7bPsUwDQYJKoZIhvcNAQEBBQAEggEAnZrfMfES
# GCahCsgQwJcpOyIbbbFKoqRmB4wFACOyBO99JSSi5ozHOk1iKKqVyRIhYqiftu5m
# VnjMpuJHqbRHdziZBtfubnG+zvS3K7XRUf07TPti+qmZTuVCXEDJJe8HTWJZiLsJ
# gRw/4PvX0vv4xwisid2NI/qbyrtCeuil4qO07Jm0Eh3tYHivWngoL8qyRI4eFit4
# xLrtwzObF7zVdHR5HPn7AoDI1TtOWXB8HwbX1a0ZjuzD6z/WYWSFXZ2eTTQlouXJ
# Bkgr37iWnr1jdPTnnXIgoQD17x7zn+vJFLvp9YsNJSv4ViaT9NpXDOCTI7OmJMcd
# /iV/9XbCX7KEgg==
# SIG # End signature block
