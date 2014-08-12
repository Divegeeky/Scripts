$Computers = Get-AllClients | Select Name
function Get-Adobe {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)]
    [Alias('Names')]
    [string]$Name
    )

    process{
        if (Test-Connection $Name -Quiet -Count 2){
            try {
                 $Fromunda = (Invoke-Command -ComputerName $Name -ScriptBlock {
                 $Test = Get-WMIObject -Class Win32_product | Where-Object {$_.IdentifyingNumber -match 'AC76BA86-1033-FFFF-7760-000000000006'}
                 Return $Test}) }
            catch{
                 } 
         if($Fromunda){ New-Object PSObject -Property @{
                    Name = $Name
                    AppName = $Fromunda.Name
                    AppVendor = $Fromunda.Vendor
                    Version = $Fromunda.Version
                    Caption = $Fromunda.Caption
                                                        }
                      }
            
        
      
                                                    }
               }
}
$IHAVEADOBE = $Computers | Get-Adobe
$IHAVEADOBE | Export-Csv C:\Temp\Adobe.csv
