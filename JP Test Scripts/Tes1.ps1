#region include
Import-Module \\fso\core\Scripts\include\Get_Functions.psm1 -DisableNameChecking
Import-Module \\fso\core\Scripts\include\Log_functions.psm1 -DisableNameChecking
Import-Module \\fso\core\Scripts\include\Alert_Functions.psm1 -DisableNameChecking

if((Get-PSSnapin -Name SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue) -eq $null) {
    try{Add-PsSnapin SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue}catch{}
}

#endregion include

#region variables





#endregion variable

#region functions





#endregion functions

#region main




#endregion main