# uploader.ps1
# C. Bikle
# 05/23/17

# A quick script to upload a bunch of mp4 files to my server

# params: servername or address, <port>, uname, pw or file, <location of pscp>, lsrc, rdst, term
# check for pscp in programfiles and programfiles(x86)
# remember to use -batch flag
# 

#figure out params later

$RemoteHost = "Drumknott-3"
$Uname = "vidmaster"
$Passwd = "Pk3hxfUYc7kKqjXcKde3"
$Passfile = ""
$LocalSource = "E:\Videos\Recoded"
$RemoteDestination = "/home/$Uname/videos/gameplay"
$Term = ".mp4"
$PscpExe = "$env:ProgramFiles\PuTTY\pscp.exe"

if(!(Test-Path -Path "$PscpExe")) {
   Write-Host "PSCP is not installed, apparently."
   exit 1
}

if(!(Test-Connection -ComputerName $RemoteHost -Count 1 -Quiet)) {
   Write-Host "$RemoteHost did not respond to ping"
   exit 2
} else {
   Write-Host "$RemoteHost responded to ping"
}

if(!(Test-Path -Path "$LocalSource\*$Term*")) {
   Write-Host "No files matching $Term were found in $LocalSource"
   exit 3
}

Try {
   Write-Host "Trying to put $LocalSource\*$Term* to $Uname@$RemoteHost':'$RemoteDestination"
   Measure-Command { & $PscpExe -v -batch -sftp -2 -pw $Passwd $LocalSource\*$Term* $Uname@$RemoteHost':'$RemoteDestination }
} Catch {
   Write-Host $_.Exception.Message
}

