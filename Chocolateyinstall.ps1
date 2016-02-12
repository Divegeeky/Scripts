$Computers = Get-ADGroupMember 'GPO_Lab_Computers'

iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
