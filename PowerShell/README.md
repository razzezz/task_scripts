# PowerShell
Various Windows based scripts cobbled together for repeatable admin task

### GetWSUS.ps1
The script will download and execute WSUS Online and download all updates for Windows Server 2012 R2 and Win8.1 to a local directory

### iso_slipstream.ps1
This will take a Windows ISO, unzip with WinRAR, mount with DISM, slipstream with offline patches (see GetWSUS) and package as a fresh ISO for installation.