
function New-PSLogSource
{
<#
	.SYNOPSIS
		Registers a new Event Log source on the local machine based on the name of the calling script.

	.DESCRIPTION
		Gets the name of the calling script, then checks to see if it exists in the 'FSO PowerShell Scripts' event log. 
		If this log does not exist, it is created. If the source is not registered already, it is registered in this event log.
		NOTE: This function MUST be called from a script -- it will not properly identify a source if run directly from the console.

	.EXAMPLE
		$eventSource = New-PSLogSource
		write-eventlog -logName $logname -source $eventSource -message 'This is a test event.' -eventID 1
		
		These commands, when run inside a PowerShell Script, will generate a new Informational event in the $logname
		Event Log, using the name of the script (the .ps1 file) as the registered source for the event.

	.INPUTS
		This function takes no input -- the needed input is derived automatically from the calling script.

	.OUTPUTS
		None

	.NOTES
		This function establishes the global variable $logName, which can be used with the Log-* functions inside a script to log events to this
		new source. The Log-Verbose function requires that a global variable "$verbose" be set to true in order to actually log the event. This way 
		you can add a -verbose parameter to your script and the Log-Verbose messages will only be logged when the script is called with this switch enabled.
#>

	$global:logName = 'FSO PowerShell Scripts'
	$global:source = $null
	[string]$script =  $global:myinvocation.MyCommand.Definition
    $global:source = Split-Path -leaf $script.Substring(0,($script.IndexOf('.ps1')))
	
	if ([System.Diagnostics.EventLog]::Exists($logName))
	{
		if (![system.Diagnostics.EventLog]::SourceExists($global:source))
		{
			[System.Diagnostics.Eventlog]::CreateEventSource($global:source, $logName)
		}
	}
	else
	{
		New-EventLog -LogName $logName -Source $global:source
	}
}

function Log-Info {
	param ([string]$message = "No event message supplied.",$eventID = 1)
	Write-EventLog -LogName $logname -Source $global:source -EventID $eventID -EntryType Information -Message $message
}

function Log-Error {
	param ([string]$message = "No event message supplied.",$eventID = 3)
	Write-EventLog -LogName $logname -Source $global:source -EventID $eventID -EntryType Error -Message $message
}

function Log-Warning {
	param ([string]$message = "No event message supplied.",$eventID = 2)
	Write-EventLog -LogName $logname -Source $global:source -EventID $eventID -EntryType Warning -Message $message
}

function Log-Verbose {
	param ([string]$message = "No event message supplied.",$eventID = 4)
	if ($global:verbose)
	{
		Write-EventLog -LogName $logname -Source $global:source -EventID $eventID -EntryType Information -Message "Verbose: $message"
	}
}

function Log-Debug
{
#To be used to log events while debugging a script. Would work similar to Log-Verbose, using a global switch variable.
}

# SIG # Begin signature block
# MIIUdgYJKoZIhvcNAQcCoIIUZzCCFGMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUpFpfVNq2OfCZZ0uW+kBxt9jH
# 6viggg+4MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# MRYEFD33Akhjg6RwNr9GTlISAtVTEe1mMA0GCSqGSIb3DQEBAQUABIIBAB84naKz
# xlxfoN4JcGwQtY4pvdkYYdP6YVX5QSoo0MPLWhYwy3+UnJ++wIFB3ZmCkTUzfpBB
# rqIAe67HG2/8NmU+6dA70aOMZQyUffGRzireu+F5uMkqruM0SedQn3lsRgTdK5uf
# ARDB/je7tuc/f5P7frAr+8dfxTtJPKPZwgIdQVmhvNdZVw0Nl1RE3uqnIE24/XhS
# B8J/xieH13clKc3qfIL8+FaIr4cNBi1TltVt38nexaKtJ5KFqmxK9Wk799XG1G1X
# Sw9nT/q12VkC3Z/focCkqNF3CtEukZZTMaxlQ2fzsoZizrsClxQfQkcPTGdFWycG
# pjU5S3qV1nZlNV6hggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBeMQsw
# CQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNV
# BAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQDs/0
# OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMTMwNjA1MDEwMzQ3WjAjBgkqhkiG9w0BCQQx
# FgQUrcpT5ef5DyIXJ/zkq1/gOzVUwGUwDQYJKoZIhvcNAQEBBQAEggEAYKLVTYen
# ZVrLDmTaYcErwyad/nytzbjzQ5FQKIFqfGpwLQ6tJcE1qjixx92GZvnIX+SbWPEE
# ZBfIW2sYCaRHWETI6ZKYNdcZ4KXrzCv8t68w1mFhQxHKvWmhWyITNyO9eXAZucOF
# 4gD3eahWn2NsCy+7QHLxiIfY0uT/QGVPEhiaKCUJSwjMNYsgvxnlhoHGbMiDLkyU
# GqdsT7lCVe1U1y+TC9CBcd5p0CbHcwPgtjS+dbmUUjSPOHmy1z7swmXzfuwtOrtj
# 4xu9ymUiQ5dKJW02qElUtCH1xPaS3Mbz49xWWkzTe6xBZ2132Q8dcXYg2wtISfJ/
# mIytHpzKmauzmg==
# SIG # End signature block
