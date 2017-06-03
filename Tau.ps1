#Tau.ps1
#C. Bikle
#created 06/04/16
#actually worked on 06/03/17

# A PowerShell script to transcode .AVIs to web-optimized .MP4s using HandbrakeCLI,
#+then delete the .AVIs and upload the .MP4s to a remote server using SCP or SFTP
#+before calling a script on the server (via SSH?) to move the files into place on the server.
#+Should probably include intelligent queing that takes file sizes and disk space
#+into account.
#+Also, possibly saving the queues to file so that recovery can take place following
#+interruptions.
#+Oh, and a function that checks the video lengths & sizes to make sure the whole thing transcoded
#+and uploaded properly.

# (Transcode And Upload)

# GLOBAL PARAM
param (
   [string]$src = ".\",
   [string]$dst = "..\Recoded",
   [string]$term = ".avi",
   [string]$inputFormat = "avi",
   [string]$outFormat = "mp4",
   [string]$cli = "$env:programfiles\HandBrakeCLI",
   [string]$logs = ".\logs",
   [string]$data = ".\data",
   [switch]$sleep = $False
)

function Get-TimeStamp {
   return (Get-Date -Format o).Substring(0,16).Replace(":","")
}

function Sleep-Computer {
   Add-Type -AssemblyName System.Windows.Forms
   Write-Host "Sleeping at $(Get-TimeStamp)"
   [System.Windows.Forms.PowerState] $PowerState = [System.Windows.Forms.PowerState]::Suspend
   [System.Windows.Forms.Application]::SetSuspendState($PowerState, $false, $false) | Out-Null
   Write-Host "Awoken at $(Get-TimeStamp)"
}

# "MAIN"

$LocalPath = (Split-Path $MyInvocation.MyCommand.Path)

Invoke-Expression -Command "$LocalPath\recoder.ps1 -src `"$src`" -dst `"$dst`" -term `"$term`" -inputFormat $inputFormat -outFormat $outFormat -cli `"$cli`" -logs `"$logs`" -data `"$data`""

Invoke-Expression -Command $LocalPath\uploader.ps1

switch($sleep) {
   $True {Sleep-Computer}
}