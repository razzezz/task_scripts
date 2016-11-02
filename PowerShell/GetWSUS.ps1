<#
.DESCRIPTION
Using WSUSOffline v10.8 (wsusoffline.net), download a cache of Windows Updates for Server 2012 R2 and Win8.1
#>

$WSUSOffline = "c:\wsusoffline"
$WinRar = "C:\Program Files\WinRAR\winrar.exe"

$WSUSCheck = Test-Path $WSUSOffline
if($WSUSCheck -eq $false) {
    Invoke-WebRequest -Uri "http://download.wsusoffline.net/wsusoffline108.zip" -OutFile $HOME"\wsusoffline108.zip"
    New-Item -ItemType Directory -Force -Path $WSUSOffline
    &$Winrar x $HOME"\wsusoffline108.zip" $WSUSOffline

    Try {Remove-Item -Force $HOME"\wsusoffline108.zip"}
        Catch {$_.Exception}
}

Try {
    #Get all Windows Updates for Server 2012
    C:\wsusoffline\cmd\DownloadUpdates.cmd w63-x64 glb /includedotnet /verify
}
Catch {
    $_.Exception
}