$Result = Invoke-Command -ComputerName FSO0138 -ScriptBlock {

$DBState = Test-Path -Path "HKLM\SYSTEM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\AppMgmt\{a2e07cfd-04c4-4abd-8719-6c990572df01}"

Return $DBState # you shouldn't even need Return
}

$Result 