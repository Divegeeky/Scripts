#region global variables
$start = Get-Date
$errors = @()
$events = @()
$client = Get-WMIObject Win32_ComputerSystem | Select Name
$currentprinter
$currentrenamedprinter
$csvpath = '\\Fso\core\ManagedSoftware\PrinterMigTest\CSVs\'

#endregion global variables

#region main
$msg = "Starting work on {0} with the user of {1}" -f $client.Name,$env:USERNAME
$events+=$msg

$printers = get-Wmiobject -Class Win32_printer | Where-Object {$_.SystemName -like '*SVR0210*'}
if($printers){
    $printers| %{
        $msg = "Beginning work on {0} with user {1} and printer {2}"-f $client.Name,$env:USERNAME,$_.Name
        $events+=$msg
        $tempprinter = $_
        $currentprinter= $_
        $class = [wmiclass]"Win32_Printer"
        $tempprintername = $_ | Select -ExpandProperty Name
        $tempprintername = $tempprintername.ToUpper()
        $printername = $tempprintername.replace("SVR0210", "SVR0213")
        $currentrenamedprinter = $printername
        #Remove-Printer -Name $tempprintername
        
        try{
            $tempprinter.PSBase.Delete()
        }
        catch{
            $msg = "There was an error deleting the printer {0} on System {1} and User {2}"-f $currentprinter.Name, $client.Name, $env:USERNAME
            $errors += New-Object PSObject -Property @{
                Error = $msg
                ComputerName = $Client.Name
                User = $env:USERNAME
                Printer = $currentprinter.Name
                Function = $MyInvocation.MyCommand.Name
            }
        }

        #Add-Printer -ConnectionName $printername
        try{
            $class.AddPrinterConnection($printername)
        }
        catch{
            $msg = "There was an error adding the printer {0} on System {1} and User {2}"-f $currentrenamedprinter, $client.Name, $env:USERNAME
            $errors += New-Object PSObject -Property @{
                Error = $msg
                ComputerName = $Client.Name
                User = $env:USERNAME
                Printer = $currentrenamedprinter
                Function = $MyInvocation.MyCommand.Name
            }

        }

    }
}
Else{
    $msg= "There appears to be no printers that are connected to SVR0210 on {0} for the user {1}"-f $client.Name,$env:USERNAME
    $events+=$msg
}
$end = Get-Date
$total = New-TimeSpan $start $end
$msg = "Start: $start`nEnd: $end`nTotal: $total`n`nThe script ran!`n"

if($events) {
    $msg += "`nEvents:`n"
    $events | %{
        $msg += "$_`n"
    }
    $clientname = $client.Name
    $username = $env:USERNAME
    $csvname = "$csvpath Events $clientname $username.TXT"
    $events | Out-File $csvname -Force
}

if($errors) {
    $msg += "`nThe following errors occured:`n"
    $i = 1
    $errors | %{
        $msg += "`n{0}. Function: {1}`nError: {2}`n" -f $i++, $_.Function, $_.Error
    }

    $clientname = $client.Name
    $username = $env:USERNAME
    $csvname = "$csvpath Errors $clientname $username.CSV"
    $errors | Export-Csv -Path $csvname -Force -NoTypeInformation
} 
#endregion main

# SIG # Begin signature block
# MIIUkQYJKoZIhvcNAQcCoIIUgjCCFH4CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUxNVroK3JIpC3/ngNGZqMCzWS
# uKqggg/JMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# ggcsMIIGFKADAgECAhMYAAAp5i3kzAPRO4ikAAMAACnmMA0GCSqGSIb3DQEBBQUA
# MGoxEzARBgoJkiaJk/IsZAEZFgNFRFUxFzAVBgoJkiaJk/IsZAEZFgdBcml6b25h
# MRMwEQYKCZImiZPyLGQBGRYDRlNPMSUwIwYDVQQDExxVQSBGaW5hbmNpYWwgU2Vy
# dmljZXMgT2ZmaWNlMB4XDTE1MDkyMjIyNTMzM1oXDTE3MDkyMTIyNTMzM1owgZAx
# EzARBgoJkiaJk/IsZAEZFgNFRFUxFzAVBgoJkiaJk/IsZAEZFgdBcml6b25hMRMw
# EQYKCZImiZPyLGQBGRYDRlNPMRUwEwYDVQQLEwxVc2Vyc1N5c3RlbXMxFTATBgNV
# BAsTDERvbWFpbkFkbWluczEdMBsGA1UEAxMUUG90b3Rza3ksIEphc29uIChEQSkw
# ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCkhSK5kD9mkAS+40EofdXj
# m2OnyFAiM7lM610hogFg6fV+H4JwlkqwSC3xRlh+01nlmqTjBGOTP6WYs7zgSQcs
# tzeiI5GEw7SeXdlvrcqRWmJgdrkVKYj3CoFR+1BVFzIigFmYc1FIxxSSM1zKNRmp
# oVJj/I9jDio759iqkuiyhGxddpFTTb6xohEwoB68RZ5EyVx8kMXyTagrUq8dkJBu
# DkoPPd+AC2eB5t1LwlAI6VnmVvdmZcaYsXec3ZZPWzVOe1iW0uib0HQki82MIsP+
# pqhHUOx4VmMvX1h/zzgRFA85GsKwD5EEo3Cy40hIxexTj1Ohr2Q8vk1Ftc4V/TKR
# AgMBAAGjggOiMIIDnjALBgNVHQ8EBAMCB4AwPgYJKwYBBAGCNxUHBDEwLwYnKwYB
# BAGCNxUIhOOaHIL3+DSGpY0mhrj7GYf80QmBM4OKswuHzJQ7AgFkAgEBMB0GA1Ud
# DgQWBBR16MjrF+jqSE39/e6qwxptaI5BwDAfBgNVHSMEGDAWgBRDNepENjaCcUIH
# q6BZM0AWJVuWATCCAcUGA1UdHwSCAbwwggG4MIIBtKCCAbCgggGshoHTbGRhcDov
# Ly9DTj1VQSUyMEZpbmFuY2lhbCUyMFNlcnZpY2VzJTIwT2ZmaWNlKDEpLENOPXN2
# cjAwMTcsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZp
# Y2VzLENOPUNvbmZpZ3VyYXRpb24sREM9RlNPLERDPUFyaXpvbmEsREM9RURVP2Nl
# cnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RDbGFzcz1jUkxEaXN0
# cmlidXRpb25Qb2ludIaB02xkYXA6Ly8vQ049VUElMjBGaW5hbmNpYWwlMjBTZXJ2
# aWNlcyUyME9mZmljZSgxKSxDTj1TVlIwMjExLENOPUNEUCxDTj1QdWJsaWMlMjBL
# ZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPUZT
# TyxEQz1Bcml6b25hLERDPUVEVT9jZXJ0aWZpY2F0ZVJldm9jYXRpb25MaXN0P2Jh
# c2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9uUG9pbnQwgdsGCCsGAQUFBwEB
# BIHOMIHLMIHIBggrBgEFBQcwAoaBu2xkYXA6Ly8vQ049VUElMjBGaW5hbmNpYWwl
# MjBTZXJ2aWNlcyUyME9mZmljZSxDTj1BSUEsQ049UHVibGljJTIwS2V5JTIwU2Vy
# dmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1GU08sREM9QXJp
# em9uYSxEQz1FRFU/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNzPWNlcnRp
# ZmljYXRpb25BdXRob3JpdHkwEwYDVR0lBAwwCgYIKwYBBQUHAwMwGwYJKwYBBAGC
# NxUKBA4wDDAKBggrBgEFBQcDAzA2BgNVHREELzAtoCsGCisGAQQBgjcUAgOgHQwb
# ZGFqcG90b3Rza3lARlNPLkFyaXpvbmEuRURVMA0GCSqGSIb3DQEBBQUAA4IBAQAn
# KpkGFDogWEn27ioJs0RFR77kyFCemiGM8HgwxoAezJAy9kSZ4Z2kWWz0+4jcueus
# OcttEYfHY/7wmTnWTi//xN0Vhs4pnBTky9jdEE8zXDbVw7+BalBDrog97uehUTXG
# E03/68+OOJYwXSiBOWVPDt2feYQ6QffrmmmcISS13rQcXhNJ1dxMj0i6wUjluXVR
# jhghTWV987tdyBld8uxOuwML3Ui08ESOMsqR7X4+7t1Ca9KP/XfQZ1w/clhEIWep
# Xve63t8+KY46tuPYZqlRVISq+Jvvbr8xVXouPP2smbMJ4FNVParunNJflR/Hd/7V
# LkjFTbxTclvssOhOgljjMYIEMjCCBC4CAQEwgYEwajETMBEGCgmSJomT8ixkARkW
# A0VEVTEXMBUGCgmSJomT8ixkARkWB0FyaXpvbmExEzARBgoJkiaJk/IsZAEZFgNG
# U08xJTAjBgNVBAMTHFVBIEZpbmFuY2lhbCBTZXJ2aWNlcyBPZmZpY2UCExgAACnm
# LeTMA9E7iKQAAwAAKeYwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKA
# AKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFMB1+K6um0MFuOs+Uo2Zed9g
# +al8MA0GCSqGSIb3DQEBAQUABIIBAENpTWQwe91wwKmbOZkQOeMhLKxS5bXPqGui
# vN0Ad8B7mw1j/WnQ1+C3l+I/AweSfuk/DV42Ktw4AS1b0IevDt9idb664Bl9iluV
# SP767szoJ7cRwzFuZEWJewAC8DogStHCiEaTdY5bJCJoOGvQ8kbbCD4qtGUj4Po0
# RjcYTZSN6wo00wmsFzceyGLgnilq0ULRn/RK7Hyk+Koj2b8T9UWOn2mo3aFsAO1G
# Q2gf5JU5/y1pLFf7ugLsTTsQot4g8/jkOhmnf8HFuqH7Yk1vJUAC4Iyxv7KoBdl1
# GGLc1ipib1JrQ0iy4gSV2bCiysHRlDlmF83cFR+TW4jn+zVzZsqhggILMIICBwYJ
# KoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBeMQswCQYDVQQGEwJVUzEdMBsGA1UEChMU
# U3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFudGVjIFRpbWUgU3Rh
# bXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQDs/0OMj+vzVuBNhqmBsaUDAJBgUrDgMC
# GgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcN
# MTUwOTIyMjMxNzA5WjAjBgkqhkiG9w0BCQQxFgQU3gV613UYIvi9Nopuujo1wF/2
# kN4wDQYJKoZIhvcNAQEBBQAEggEAJED33fIGYItaRwqcmambMyTg6SstAVeAAucg
# gqggbrQxg1Wk2sd0Bz9uBJxlE/pSite8iwdTzrWHSkWf1t1EaQ28p5j3ofjCA6Gj
# 6GVkcSi7+jP7XOrwD+0Kecp71mP+ssj1y0/q9Qak+5pvJY2Q/cQR24Q8YJKC4ndB
# nCgZhGLE4n6rH/zTpcDVeTB+ORnQwH/OF9p8G4NSD8mUKqAUAlWhlQkZ0TRQK9hk
# qxXoK94eqotuyWhbuI+sOaXhDRpoGD37xnzEvL04lM+utXto4gWJGBzadnq3jTej
# HVpGfTKiCZdYFEcpi216OEdmH02Psq5KE7a3VY9RPjcgEPvOlw==
# SIG # End signature block
