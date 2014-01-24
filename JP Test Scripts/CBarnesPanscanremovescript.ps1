#region include
Import-Module \\fso\Core\Scripts\include\Get_Functions.psm1
Import-Module \\fso\Core\Scripts\include\Utility_Functions.psm1


#endregion include
#region variables
$FileList = Import-Csv C:\Temp\Bursarsresult.csv -Header "Name", "Path"

#endregion variables
#region functions
function Bye-PanScan {
    [CmdletBinding()]
    Param(
    [Parameter(ValueFromPipeline=$True)] $obj 
    )

    process {
        $adminshare = "\\{0}\C`$\Users\" -f $obj.Name
        $fullpath = Join-Path $adminshare -ChildPath $obj.Path
                                  
        if (Test-Path $fullpath) {
            Remove-Item -Path $fullpath -Verbose -Force
            }
        }
    }
                        
#endregion functions
#region main
$FileList | Bye-PanScan




#endregion main 
