<#

	.DESCRIPTION
	This is the Post Install Script for the Windows2012R2 Template
#>

Set-ExplorerOptions -showHidenFilesFoldersDrives -showProtectedOSFiles -showFileExtensions

#Install the appropriate Windows Features
Install-WindowsFeature telnet-client
Install-WindowsFeature SNMP-Service

#Load the Boxstarter and Chocolatey Modules to execute commands
$secpasswd = ConvertTo-SecureString "vagrant" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("vagrant", $secpasswd)

Import-Module $env:appdata\boxstarter\boxstarter.chocolatey\boxstarter.chocolatey.psd1
Install-BoxstarterPackage -PackageName git -Credential $cred
Install-BoxstarterPackage -PackageName powershell -Credential $cred
Install-BoxstarterPackage -PackageName chefdk -Credential $cred
Install-BoxstarterPackage -PackageName systernals -Credential $cred
