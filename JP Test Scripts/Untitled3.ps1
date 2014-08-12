Import-Module \\FSO\CORE\Scripts\include\Get_Functions.psm1
$clients = Get-AllClients | Select Name
$Resultinfo = @()
function Get-AdobeInfo {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)]
    [Alias('Names')]
    [string]$Name
    )

    process{
        if (Test-Connection $Name -Quiet -Count 2){
            try {
                $AdobeInfo = Get-WMIObject -ComputerName $Name -Class Win32_product | Where-Object {$_.IdentifyingNumber -match 'AC76BA86-1033-FFFF-7760-000000000006'}
            }
            catch{
            }
            if ($AdobeInfo){
                New-Object PSObject -Property @{
                    Name = $Name
                    AppName = $AdobeInfo.Name
                    AppVendor = $AdobeInfo.Vendor
                    Version = $AdobeInfo.Version
                    Caption = $AdobeInfo.Caption
                }
            }
        }
    }
}

$Resultinfo = $Clients| Get-AdobeInfo
