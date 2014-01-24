
function Disable-Task {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$Name,
    [parameter(Mandatory=$false)][string]$Server = 'SVR0211'
    )
    process {
        if($PSCmdlet.ShouldProcess("$Name")) {
            Set-Task -Name $Name -Server $Server
        }
    }    
}

function Enable-Task {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$Name,
    [parameter(Mandatory=$false)][string]$Server = 'SVR0211'
    )
    process {
        if($PSCmdlet.ShouldProcess("$Name")) {
            Set-Task -Name $Name -Server $Server -Enabled
        }
    }
}

function Get-TasksOnServer {
    param(
    [parameter(Mandatory=$false,ValueFromPipeline=$true,Position=0)][string]$ServerName = 'SVR0211',
    [parameter(Mandatory=$false)][switch]$Enabled
    )
    try {
        $scheduler = New-Object -ComObject Schedule.Service
        $scheduler.Connect($ServerName)
        if($scheduler.Connected) {
            $folder = $scheduler.GetFolder($null)
            $tasks = $folder.GetTasks(1)
            if($Enabled) {
                $tasks | ?{$_.Enabled -eq $true}
            } else {
                $tasks
            }
        } else {
            throw "Could not connect to Scheduler on {0}" -f $ServerName
        }
    } catch {
        throw $_
    } finally {
        $scheduler = $null
    }
}

function Get-TaskOnServer {
    param(
    [parameter(Mandatory=$false,ValueFromPipeline=$true,Position=1)][string]$ServerName = 'SVR0211',
    [parameter(Mandatory=$true,Position=0)][string]$Name
    )
    $ServerName | Get-TasksOnServer | ?{$_.Name -like "$Name"}
}

function Get-TaskSchedule {
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]$Task
    )
    process {
        Write-Verbose $Task.Name
        [XML]$xml = $Task.XML
        $xml.Task.Triggers.CalendarTrigger | Get-CalendarTriggerData
    }
}

function Get-CalendarTriggerData {
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]$CalendarTrigger
    )
    process {
       if($CalendarTrigger.ScheduleByDay) {
            Write-Verbose "ScheduleByDay"
            New-Object PSObject -Property @{
                ScheduleBy = 'Day'
                StartTime = (Get-Date ([datetime]$CalendarTrigger.StartBoundary) -Format HH:mm:ss)
                Interval = $CalendarTrigger.ScheduleByDay.DaysInterval
            }
        } elseif ($CalendarTrigger.ScheduleByWeek) {
            Write-Verbose "ScheduleByWeek"
            New-Object PSObject -Property @{
                ScheduleBy = 'Week'
                StartTime = (Get-Date ([datetime]$CalendarTrigger.StartBoundary) -Format HH:mm:ss)
                DaysOfWeek = $CalendarTrigger.ScheduleByWeek.DaysOfWeek.ChildNodes | Select -ExpandProperty Name
                Interval = $CalendarTrigger.ScheduleByWeek.WeeksInterval
            }
        } elseif ($CalendarTrigger.ScheduleByMonth) {
            Write-Verbose "ScheduleByMonth"
            New-Object PSObject -Property @{
                ScheduleBy = 'Month'
                StartTime = (Get-Date ([datetime]$CalendarTrigger.StartBoundary) -Format HH:mm:ss)
                Months = $CalendarTrigger.ScheduleByMonth.Months.ChildNodes | select -ExpandProperty Name
                DaysOfMonth = $CalendarTrigger.ScheduleByMonth.DaysOfMonth.Day
            }
        } elseif ($CalendarTrigger.ScheduleByYear) {
            Write-Verbose "ScheduleByYear"
            $CalendarTrigger.ScheduleByYear
        } else {
            Write-Verbose "ScheduleByOther"
            $CalendarTrigger
        }
    }
}

function Set-Task {
<#
    .Synopsis
        Sets a task with the specified name on the monitor server according to the enabled switch.
    .Description
        Without using the enabled switch the task is disabled.
    .Parameter Name
        The exact name of the task.
    .Parameter Server
        The name of the server that the monitor tasks run on.
    .Parameter Enabled
        Switch parameter, if used the task will be enabled. If it is not used the task will be set
        to disabled.
    .Inputs
        The Name parameter accepts input from the pipeline by value and by property name.
    .Example
        PS C:\> Get-MonitorTask 'web' | Set-Task
    .Example
        PS C:\> Get-MonitorTask 'Linux' | Set-Task -Enabled
#>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$Name,
    [parameter(Mandatory=$false)][string]$Server = 'SVR0211',
    [parameter(Mandatory=$false)][switch]$Enabled
    )
    process {
        Write-Verbose "Attempting to connect to Schedule Service on $server..."
        # connect to the task scheduler com object
        $scheduler = New-Object -ComObject Schedule.Service 
        $scheduler.Connect($server)
        if (!$scheduler.connected) {
        	Write-Warning "Could not connect to Schedule Service on $server."
        } else {
            Write-Verbose "Connected to Schedule Service on $server."
        	#get the root folder of tasks
        	$folder = $scheduler.GetFolder($null)
        	#Calling gettasks() with the '1' argument includes hidden tasks
        	$tasks = $folder.GetTasks(1)
        	for ($i = 1; $i -le $tasks.count; $i++) {
                if($tasks.item($i).Name -eq $Name) {
                    Write-Verbose "Setting '$($tasks.item($i).Name)': Enabled = $enabled."
                    if($PSCmdlet.ShouldProcess("Task: $Name, Server: $Server, Enabled: $Enabled")) {
                        $tasks.item($i).enabled = $enabled
                    }
                }
            }
        }
    }
}

function Start-Task {
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$false,ValueFromPipeline=$true,Position=1)][string]$ServerName = 'SVR0211',
    [parameter(Mandatory=$true,Position=0)][string]$Name
    )
    $task = Get-TaskOnServer -ServerName $ServerName -Name $Name
    $task.Run($Name)
}


# SIG # Begin signature block
# MIIUdgYJKoZIhvcNAQcCoIIUZzCCFGMCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU5i+AhthLF3IFyyon1VsZyEiS
# hZWggg+4MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# MRYEFIbPCn0r18KQZ7iS1qQWOco4haOYMA0GCSqGSIb3DQEBAQUABIIBAAuidehP
# 3TR8d2IEvSEj8eInNTPbAXIPwcfGrUOKZg1+CnC4Vtwj1ElG1vSJhB/yBiKC0YCn
# Llmig9g1VDFweV7B5H+AJAWtUatRLQHJ2YAsjevxiPv5UnvP0oyYwuserDQVSjqB
# Hm2+syIKrxkJ9qSicQbWQJxKu6xizUaQVpgQGeAJUHnd/8jSuq7uDMRfvFiPfr4O
# A6vTKJP4KONnOcwAB6WlpptvsCpD4BvQ18lNwQ0meCbR5S0N117/zuVx7UJbDG0X
# iLcvtzmGqUWhIvtGnyxn/R1tWEMXD1Sa6hn1Knq2hvlsMUq6Xyxy4OK7uVvP1kaa
# Gzwx0PU9p+0lOWuhggILMIICBwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBeMQsw
# CQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNV
# BAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQDs/0
# OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMTMwNjA1MDEwMzM5WjAjBgkqhkiG9w0BCQQx
# FgQUo6OzqUpacCSezCr2koo9GGWKyFswDQYJKoZIhvcNAQEBBQAEggEAmvmq3Zza
# DNgUWxza7T8AhMZ7aidxGUYrzVpPKZ4IIgJA7W1hS8j4JZJXHMB5U0d++OABYFUy
# RTSGyVTH/I+4qJoftK5Sv3TOROP87TP4aL4wdvffZ0dK9m0DReC6+Z/Wj0UK1RiY
# xXq+Wa1sVIkJfS2XxSuqgg5lJzPjAm7GrLSOjXwptdmFRb9tsamnnQ5IXtUBnds1
# Aq5bPD6eb2ii6VkMuCNi441Z2z9B/iF2fyo9Jx/UEmiXD754imZ1sxmR62QGxy62
# nZMDk81JYA1sWZCbHxZzcpgXtuARefR95YwP4imOZ69DP0mdL6zNnR7YGC5EOyK8
# wCILqCaEINRfeg==
# SIG # End signature block
