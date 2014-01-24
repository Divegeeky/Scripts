#region Variable
$Clients = Get-Content C:\Temp\Computers.txt

#endregion Variable

#region Functions
function Get-SnFromPnpDeviceID {
    param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][string]$PNPDeviceID
    )
    process {
        $str = $PNPDeviceID.Substring($PNPDeviceID.LastIndexOf('\') + 3)
        $str = $str.Substring(0,$str.IndexOf('&'))
        $str
    }
}
function Convert-SerialNumber {
[CmdletBinding()]
Param(
[Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)][string]$str
)
process{   
           $str = [Convert]::ToInt32($str,16)
           $str                                                 
               }
}

function Get-VideoCardInfo { 
    [CmdletBinding()] 
    Param( 
    [Parameter(Mandatory=$True,ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)][string]$Name,
    [parameter(Mandatory=$false)][System.Management.Automation.PSCredential]$Credential 
    )   
    process{ 
        if (Test-Connection $Name -Quiet -Count 2){ 
            try {
                if($Credential) { 
                    $wmi = Get-WmiObject -Credential $Credential -ComputerName $Name Win32_VideoController -ErrorAction SilentlyContinue
                } else {
                    $wmi = Get-WmiObject -ComputerName $Name Win32_VideoController -ErrorAction SilentlyContinue
                }
                if ($wmi){ 
                    New-Object PSObject -Property @{ 
                        ComputerName = $Name 
                        SerialNumber = ([array]($wmi.PNPDeviceID))[0] | Get-SnFromPnpDeviceID | Convert-SerialNumber
                        VideoCardDescripton = ([array]($wmi.Description))[0]
                    } | Select ComputerName,  VideoCardDescripton, SerialNumber
                } 
            } catch{ 
                # do nothing?
            } 
        } 
    } 
}  


#endregion function

#region main
$Clients | Get-VideoCardInfo | Export-Csv C:\Temp\VideoCarddata.CSV

#endregion main
