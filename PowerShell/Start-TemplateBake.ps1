param
( 
	[string]$n="Adapt", # Template Name,
    [string]$i="c:\ISO\SW_DVD9_Windows_Svr_Std_and_DataCtr_2012_R2_64Bit_English_-4_MLF_X19-82891.iso", # ISO Location,
	[string]$v="2012R2" # OS Version
)

<#
	.DESCRIPTION
	Workflow to obtain Offline Windows Updates, slipstream updates into 
	a Windows ISO and then use the ISO to compile a Virtual Machine Template
	for wider use. The output could be VMWare, VirtualBox or AWS AMI

#>
	
function Get-PreRequisites {
	<#
		.SECTION INFO
		WINRAR is a requirement for various segments so we need to ensure it is installed
		Download and Extract WSUSOffline v10.8 (wsusoffline.net)
        Download and Extract Packer (packer.io)
        Download and Install Microsoft ADK
	#>

	$WinRar = "C:\Program Files\WinRAR\winrar.exe"
	$WinRarCheck = Test-Path $WinRar
	if($WinRarCheck -eq $false) {
		Invoke-WebRequest -Uri "https://ninite.com/winrar/ninite.exe" -OutFile $HOME"\Downloads\ninite.exe"
        Invoke-Expression -Command:$HOME"\Downloads\ninite.exe"
        Start-Sleep -s 20
        
	    #Try {Remove-Item -Force $HOME"\Downloads\ninite.exe"}
	    #   Catch {$_.Exception}
    }

	$WSUSOffline = "c:\wsusoffline"

	$WSUSCheck = Test-Path $WSUSOffline
	if($WSUSCheck -eq $false) {
		Invoke-WebRequest -Uri "http://download.wsusoffline.net/wsusoffline108.zip" -OutFile $HOME"\Downloads\wsusoffline108.zip"
		#New-Item -ItemType Directory -Force -Path "c:\"
		&$Winrar x $HOME"\Downloads\wsusoffline108.zip" "c:\"

		#Try {Remove-Item -Force $HOME"\Downloads\wsusoffline108.zip"}
		#    Catch {$_.Exception}
	}

    $Packer = "c:\packer\packer.exe"

    $PackerCheck = Test-Path $Packer
	if($PackerCheck -eq $false) {
		Invoke-WebRequest -Uri "https://releases.hashicorp.com/packer/0.11.0/packer_0.11.0_windows_amd64.zip" -OutFile $HOME"\Downloads\packer_0.11.0_windows_amd64.zip"
		New-Item -ItemType Directory -Force -Path "c:\packer"
		&$Winrar x $HOME"\Downloads\packer_0.11.0_windows_amd64.zip" "c:\packer"

		#Try {Remove-Item -Force $HOME"\Downloads\wsusoffline108.zip"}
		#    Catch {$_.Exception}
	}

    $ADKDIR = "C:\Program Files (x86)\Windows Kits\8.1\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"

    $ADKCheck = Test-Path $ADKDIR
	if($PackerCheck -eq $false) {
        #Install Microsoft ADK
        Invoke-WebRequest -Uri "https://download.microsoft.com/download/6/A/E/6AEA92B0-A412-4622-983E-5B305D2EBE56/adk/adksetup.exe" -OutFile $HOME"\Downloads\adksetup.exe"
        Invoke-Expression -Command:$HOME"\Downloads\adksetup.exe /features OptionId.DeploymentTools /norestart /quiet"
    }
    return "Pre-Requiresites installed"
}

function Get-OfflineUpdates {
	param ([string]$v)
	<#
		.SECTION INFO
		Using WSUSOffline, download a cache of Windows Updates for Server 2012 R2 and Win8.1
	#>

	switch ($v)
	{
		2012 { Invoke-Expression -Command:"C:\wsusoffline\cmd\DownloadUpdates.cmd w62-x64 glb /verify" }
		2012R2 { Invoke-Expression -Command:"C:\wsusoffline\cmd\DownloadUpdates.cmd w63-x64 glb /verify" }
		2016 { Invoke-Expression -Command:"C:\wsusoffline\cmd\DownloadUpdates.cmd w100-x64 glb /verify" }
	}

	Try {
		#Get all Windows Updates for Server 2012
		Invoke-Expression -Command:"C:\wsusoffline\cmd\DownloadUpdates.cmd '+$V+' glb /verify"
	}
	Catch {
		$_.Exception
	}
}

function Get-SlipStream {
	param (
        [string]$i,
        [string]$n,
        [string]$d,
        [string]$v,
        [string]$o = 'Windows Server 2012 R2 SERVERSTANDARD'
    )
	<#
		.SECTION INFO
		Extract the ISO
        Mount the image with DISM
        Slipstream the Packages
        Dismount the image from DISM
        Compile into an ISO
	#>

    #Check that the ISO Exists
    $ISOCheck = Test-Path $i
    if($ISOCheck -eq $false) { return "The specified ISO does not Exist" }

	Try {
		#Check TEMP location exists or create
        $LocationTest = Test-Path "c:\cache"
        if($LocationTest -eq $false){
            New-Item -ItemType Directory -Force -Path "c:\cache"
        }
       
        $WorkDir = "c:\cache\"+$n+"_"+$d

        New-Item -ItemType Directory -Force -Path $WorkDir
        New-Item -ItemType Directory -Force -Path $WorkDir"\offline"

        $WinRar = "C:\Program Files\WinRAR\winrar.exe"

        &$Winrar x $i $WorkDir
        Get-Process winrar | Wait-Process

        #Install all slipstream files
        $Dir = Get-Childitem C:\wsusoffline\client\w63-x64\glb\ -recurse
        foreach($file in $DIR){
            DISM /image:$WorkDir"\offline" /add-package /packagepath:C:\wsusoffline\client\w63-x64\glb\$file
        }

        #Mount the image for manipulation
        DISM /Mount-Image /ImageFile:$WorkDir"\sources"\install.wim /Name:$o /MountDir:$WorkDir"\offline"

        # Dismount the image and commit the changes
        DISM /Unmount-Image /MountDir:$WorkDir"\offline" /Commit

        Try {
            # Create the bootable ISO
            #cd "C:\Program Files (x86)\Windows Kits\8.1\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\"
            #$BOOT = 'cmd.exe /C oscdimg.exe -m -u2 -b'+$WorkDir+'\boot\etfsboot.com -c '+$WorkDir+' c:\cache\'+$n+'_'+$date+'.iso'
            #Invoke-Expression -Command:$BOOT
            Invoke-Expression -Command:'cmd.exe /C "C:\Program Files (x86)\Windows Kits\8.1\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe" -m -u2 -b'+$WorkDir+'\boot\etfsboot.com -c '+$WorkDir+' c:\cache\'+$n+'_'+$date+'.iso'
        }
        Catch {$_.Exception}

        # Temporary Location Cleanup
        Try {Remove-Item -Recurse -Force $WorkDir}
        Catch {$_.Exception}

        $NewISO = "c:\cache\"+$n+"_"+$date+".iso"

        return $NewISO
	}
	Catch {
		$_.Exception
	}
}

function Update-JSON {
    param
    (
        [string]$a="C:\users\Administrator\Desktop\my.json",
        [string]$i,
        [string]$n,
        [string]$v,
        [string]$d
    )

    # Declare the output file for the new JSON File
    $NewJSON = "C:\packer\"+$n+"_"+$d+".json"

    #Get the MD5 CHECKSUM for the ISO
    $hash = Get-FileHash -Path $i -Algorithm MD5

    $PackerTemplate = Get-Content $a -raw | ConvertFrom-Json
    # Pass Variables into the JSON File for PACKER
    $PackerTemplate.variables.iso_url = $i
    $PackerTemplate.variables.iso_checksum = $hash.hash
    $PackerTemplate.variables.TemplateName = $n

    #Set OS Type
    switch ($v)
	{
		2012 { $v = "Windows2012_64" }
		2012R2 { $v = "Windows2012_64" }
		2016 { $v = "Windows2012_64" }
	}
    $PackerTemplate.builders.guest_os_type = $v
    $PackerTemplate | ConvertTo-Json  | set-content $NewJSON

    return $NewJSON
}

function Build-Template {
    param (
        [string]$n,
        [string]$j,
        [string]$d
    )

    $PackerCommand = 'cmd.exe /C c:\packer\packer.exe build '+$j
    Invoke-Expression -Command:$PackerCommand
}


$date = Get-Date -format "ddMMyy" # The date is used in the ISO and Template outputs for version tracking

#Get-PreRequisites
#Get-OfflineUpdates -v $v
#$NewISO = Get-SlipStream -i $i -n $n -d $date
#$NewISO = "c:\ISO\SW_DVD9_Windows_Svr_Std_and_DataCtr_2012_R2_64Bit_English_-4_MLF_X19-82891.iso"
#$JSON = Update-JSON -i $NewISO -a my.json -n $n -d $date -v $v
Build-Template -n $n -d $d -j "c:\packer\Adapt_111116.json

## NEED TO INSTALL GIT, DOWNLOAD THE REPOSITORY SO IT'S LOCAL, MODIFY THE JSON OUTPUT TO BUILD IN TEMPLATE DIRECTORY THEN EXECUTE PACKER