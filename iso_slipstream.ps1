<#
.DESCRIPTION
The script uses a number of tools listed below to extract, slipstream and compile a Windows 2012 ISO.

+ WinRAR
+ WSUS Offline
+ Windows ADK 8.1

.EXAMPLE

.PARAMETER iso
The location of the base ISO.  Must be full file path. etc c:\Temp\MyCD.iso

.PARAMETER TemplateName
The output name of the template. This will be appended with the date in a DDMMYY format for version control.

.PARAMETER TempLoc
The temporary location for slipstreaming - Must be full file path. Output ISO's will be stored here. etc c:\Temp

.PARAMETER ImageName
Must be the ACTUAL name of the install as per the install.wim file within the ISO

.PARAMETER WinRar
The full directory location for the WinRAR executable

#>

# PARAMETERS
param
(
    [string[]]$iso = "c:\ISO\SW_DVD9_Windows_Svr_Std_and_DataCtr_2012_R2_64Bit_English_-4_MLF_X19-82891.iso",
    [string[]]$TemplateName="Martin_Test",
    [string[]]$TempLoc = 'c:\ISO',
    [string[]]$ImageName = 'Windows Server 2012 R2 SERVERSTANDARD',
    [string[]]$WinRar = "C:\Program Files\WinRAR\winrar.exe",
    $MaxThreads = 2
)


#Get the date in ddMMyy format
$date = Get-Date -format "ddMMyy"

#Check that the ISO Exists
$ISOCheck = Test-Path $iso
if($ISOCheck -eq $false) { Write-Host "The specified ISO does not Exist", Break}

#Check TEMP location exists or create
$LocationTest = Test-Path $TempLoc
if($LocationTest -eq $false){
    Try {
        New-Item -ItemType Directory -Force -Path $TempLoc
    }
    Catch {$_.Exception}
}

#Create a Working Directory and DSIM offline Location
Try {
    New-Item -ItemType Directory -Force -Path $TempLoc"\"$TemplateName"_"$date
    New-Item -ItemType Directory -Force -Path $TempLoc"\"$TemplateName"_"$date"\offline"
    }
Catch {$_.Exception}

#Extract the ISO to the Working Directory
&$Winrar x $iso $TempLoc"\"$TemplateName"_"$date
Get-Process winrar | Wait-Process

#DISM Section
#Just for Reference - Get Image Information
#DISM /Get-ImageInfo /ImageFile:$TempLoc"\"$TemplateName"_"$date"\sources"\install.wim

#Mount the image for manipulation
DISM /Mount-Image /ImageFile:$TempLoc"\"$TemplateName"_"$date"\sources"\install.wim /Name:$ImageName /MountDir:$TempLoc"\"$TemplateName"_"$date"\offline"

#Install all slipstream files
$Dir = Get-Childitem C:\wsusoffline\client\w63-x64\glb\ -recurse

foreach($file in $DIR){
    DISM /image:$TempLoc"\"$TemplateName"_"$date"\offline" /add-package /packagepath:C:\wsusoffline\client\w63-x64\glb\$file
}

# Dismount the image and commit the changes
DISM /Unmount-Image /MountDir:$TempLoc"\"$TemplateName"_"$date"\offline" /Commit

Try {
# Create the bootable ISO
cd "C:\Program Files (x86)\Windows Kits\8.1\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\"
$BOOT = 'cmd.exe /C oscdimg.exe -m -u2 -b'+$TempLoc+'\'+$TemplateName+'_'+$date+'\boot\etfsboot.com -c '+$TempLoc+'\'+$TemplateName+'_'+$date+' '+$TempLoc+'\'+$TemplateName+'_'+$date+'.iso'
$BOOT
Invoke-Expression -Command:$BOOT
}
Catch {$_.Exception}

# Temporary Location Cleanup
Try {Remove-Item -Recurse -Force $TempLoc"\"$TemplateName"_"$date}
Catch {$_.Exception}