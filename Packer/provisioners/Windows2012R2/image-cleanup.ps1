<#
   .DESCRIPTION
    The script below will;
        #Download and Install Chocolatey
        Download and Install BoxStarter
        Install Boxstarter to Application Packaging via a GIST file
        Enable Remote Desktop for Administration
        Remove the Page File to reduce the Template Size
        Set the Execution Policy to Unrestricted whilst we work
        Remove all Windows Packages to reduce the Template Size
        Perform Windows Update (Criticals only) and Reboot
        Run DSIM to clean up the SXS to keep the Template uncluttered
        Zero the disk to create a better compression at the output
        Enable WIN-RM for Packer to execute a Shutdown

#>
$WinlogonPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
Remove-ItemProperty -Path $WinlogonPath -Name AutoAdminLogon
Remove-ItemProperty -Path $WinlogonPath -Name DefaultUserName

#iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
iex ((new-object net.webclient).DownloadString('https://raw.githubusercontent.com/mwrock/boxstarter/master/BuildScripts/bootstrapper.ps1'))
Get-Boxstarter -Force

$secpasswd = ConvertTo-SecureString "vagrant" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("vagrant", $secpasswd)

Import-Module $env:appdata\boxstarter\boxstarter.chocolatey\boxstarter.chocolatey.psd1
Install-BoxstarterPackage -PackageName a:\package.ps1 -Credential $cred

Enable-RemoteDesktop
Set-NetFirewallRule -Name RemoteDesktop-UserMode-In-TCP -Enabled True

Write-BoxstarterMessage "Removing page file"
$pageFileMemoryKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
Set-ItemProperty -Path $pageFileMemoryKey -Name PagingFiles -Value ""

Update-ExecutionPolicy -Policy Unrestricted

<#
Write-BoxstarterMessage "Removing unused features..."
Get-WindowsFeature |
? { $_.InstallState -eq 'Available' } |
Uninstall-WindowsFeature -Remove

Install-WindowsUpdate -AcceptEula
if(Test-PendingReboot){ Invoke-Reboot }

Write-BoxstarterMessage "Cleaning SxS..."
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase

#>

@(
    "$env:localappdata\Nuget",
    "$env:localappdata\temp\*",
    "$env:windir\logs",
    "$env:windir\panther",
    "$env:windir\temp\*",
    "$env:windir\winsxs\manifestcache"
) | % {
        if(Test-Path $_) {
            Write-BoxstarterMessage "Removing $_"
            Takeown /d Y /R /f $_
            Icacls $_ /GRANT:r administrators:F /T /c /q  2>&1 | Out-Null
            Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }

<#
Write-BoxstarterMessage "zeroing out empty space..."
wget http://download.sysinternals.com/files/SDelete.zip -OutFile sdelete.zip
[System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem")
[System.IO.Compression.ZipFile]::ExtractToDirectory("sdelete.zip", ".")
./sdelete.exe /accepteula -z c:
#>

Write-BoxstarterMessage "Recreate pagefile after sysprep"
$System = GWMI Win32_ComputerSystem -EnableAllPrivileges
$System.AutomaticManagedPagefile = $true
$System.Put()

Write-BoxstarterMessage "Setting up winrm"
Set-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC -RemoteAddress Any
Enable-WSManCredSSP -Force -Role Server

Enable-PSRemoting -Force -SkipNetworkProfileCheck
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'