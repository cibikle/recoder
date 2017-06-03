# recoder.ps1
# C. Bikle
# 06/30/16

# A quick script to run a bunch of files through HandbrakeCLI

# TODO: compare input file and output file durations & fps √ and log √ and maybe remediate if different
# + rewrite to use labels rather than blind column numbers
# + change logging to log after *each* recode rather than at the end √
# TODO: a switch for remediatation (so that we can write needed remediatation to log for later use
# + or put the job back in the queue for immediate or delayed remediation)
# TODO: switch to generate only the queueFile
# TODO: switch to take a premade queueFile
# TODO: output size prediction and estimation of job runtime
# + add stub run of hbCLI to get Duration before main run
# + get size of input file
# + do maths and things
# TODO: add switch to reread que file after each recode finishes
# + NEED SOME WAY TO MARK COMPLETE--maybe move to another file?
# TODO: add simple commands, such as stop/pause, that can be read from the que file
# TODO: add args for
# + SRC [optional; defaults to .], √
# + DST [optional; defaults to ..\..\Recoded], √
# + TERM [optional; defaults to .avi], √
# + INPUTFORMAT [optional; defaults to AVI], √
# + OUTFORMAT [optional; defaults to MP4], √
# + CLI [optional; defaults to $env:programfiles\HandBrakeCLI]
# + waaay down the line should allow all the same options and presets and things
# + that HandBrake does
# TODO: recheck that file exists before trying transcode?
# TODO: add "X encodes queued" or whatever √

# HandBrakeCLI -i [input] -o [output] --preset=[preset] --two-pass -O #(optimize)

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

if(!(Test-Path "$src")) {
   Write-Host "Source directory $src does not exist. Exiting..."
   exit 1
} else {
   $srcDir = (Resolve-Path "$src").ProviderPath
}

$defaultDst = "..\..\Recoded"
if(!(Test-Path "$dst")) {
   Write-Host " Destination directory $dst does not exist."
   if("$dst" -eq "$defaultDst") {
      Write-Host "Creating..."
      $dstDir = (Resolve-Path "$dst").ProviderPath
   } else {
      Write-Host "Exiting..."
      exit 2
   }
} else {
   $dstDir = (Resolve-Path "$dst").ProviderPath
}

$hbCLI = "HandBrakeCLI.exe"
if(!(Test-Path "$cli\$hbCLI")) {
   Write-Host "HandBrake CLI is not installed in $cli.  Exiting..."
   exit 3
}

if(!(Test-Path "$logs")) {
   Write-Host "Logs directory $logs does not exist. Exiting..."
   exit 4
} else {
   $hbLog = (Resolve-Path "$logs").ProviderPath
}

if(!(Test-Path "$data")) {
   Write-Host "Data directory $data does not exist. Exiting..."
   exit 5
} else {
   $dataDir = (Resolve-Path "$data").ProviderPath
}

switch($sleep) {
   $True { Write-Host "recoder will sleep after job"; break }
   $False { Write-Host "recoder will NOT sleep after job"; break }
}

$queFile = "queueFile.que"
$logFile = "recoderLogFile.txt"
$presetNew='"Fast 1080p30"'
$offset = 2
$lenColumn = 27
$fpsColumn = 309
$lenLabel = "Length"
$fpsLabel = "Frame rate"
$lenInd = 0
$fpsInd = 1
$hbOut = ""
$inFNameInd = 1
$outFNameInd = 3

# param: full filename and path
# returns length and framerate of the target
function Get-VideoInfo {
   param (
      [Parameter(Mandatory=$True)]
      [string]$fpath,
      [Parameter(Mandatory=$True)]
      [string]$file
   )
   
   if(!(Test-Path "$fpath\$file")) {
      return $null
   } else {
      $objShell = New-Object -ComObject Shell.Application
      $objDir = $objShell.NameSpace($fpath)
      $objFile = $objDir.ParseName($file)
      $duration = $objDir.GetDetailsOf($objFile, $lenColumn)
      $framerate = ($objDir.GetDetailsOf($objFile, $fpsColumn)).Substring(1)
      return @($duration, $framerate)
   }
}

function Get-TimeStamp {
   return (Get-Date -Format o).Substring(0,16).Replace(":","")
}

# param: path to the source directory and the search term
# returns an ArrayList containing the queued jobs as bar separated strings
function Build-Queue {
   param (
      [Parameter(Mandatory=$True)]
      [string]$srcDir,
      [Parameter(Mandatory=$True)]
      [string]$term
   )
   
   $queue = New-Object System.Collections.ArrayList
   Get-ChildItem $srcDir -Filter *$term* |
    Foreach-Object {
      $inputFName = $_.FullName
      $outputFName = $_.BaseName + "." + $outFormat
      $jobParams = ("--input|$inputFName|--output|$dstDir\$outputFName|--preset=$presetNew|--vfr|--optimize")
      [void] $queue.Add($jobParams)
    }
   Write-Host "$($queue.Count)" -NoNewLine -ForegroundColor "yellow"
   Write-Host " jobs enqueued"
   return $queue
}

# param: the ArrayList queue of jobs, the full path and name of the data file
function Process-Queue {
   param (
      [Parameter(Mandatory=$True)]
      [System.Collections.ArrayList]$queue,
      [Parameter(Mandatory=$True)]
      [string]$dataFName
   )
   
   $i = 1
   $n = $queue.Count
   foreach ($job in $queue) {
      $params = $job.Split("{|}")
      Write-Host "$i (of $n). $params"
      $inFName = $params[$inFNameInd]
      Try {
         Measure-Command { & "$cli\$hbCLI" $params }
      } Catch {
         $tstamp = Get-TimeStamp
         Add-Content $logFile "[$tstamp] $_.Exception.Message"
         $i++
         Continue
      }
      
      $inFName = (Split-Path $params[$inFNameInd] -leaf)
      $srcInfo = Get-VideoInfo $script:srcDir $inFName
      $outFName = (Split-Path $params[$outFNameInd] -leaf)
      $outInfo = Get-VideoInfo $script:dstDir $outFName
      $data = @($outFName, $srcInfo, $outInfo)
      
      Add-Content $dataFName "$i. $($data[0])`r`n$($data[1])`r`n$($data[2])"

      if($outInfo[$lenInd] -ne $srcInfo[$lenInd]) {
         Write-Host "Output video length is not equal to input video: "$outInfo[$lenInd]" rather than "$srcInfo[$lenInd] -ForegroundColor "red"
      } else {
         Write-Host "Both files are the same length: "$outInfo[$lenInd]
      }
      if($outInfo[$fpsInd] -ne $srcInfo[$fpsInd]) {
         Write-Host "Output video framerate is not equal to input video: "$outInfo[$fpsInd]" rather than "$srcInfo[$fpsInd] -ForegroundColor "red"
      } else {
         Write-Host "Both files have the same framerate: "$outInfo[$fpsInd]
      }
      Write-Host ""
      $i++
   }
}

function Sleep-Computer {
   Add-Type -AssemblyName System.Windows.Forms
   Write-Host "Sleeping at $(Get-TimeStamp)"
   [System.Windows.Forms.PowerState] $PowerState = [System.Windows.Forms.PowerState]::Suspend
   [System.Windows.Forms.Application]::SetSuspendState($PowerState, $false, $false) | Out-Null
   Write-Host "Awoken at $(Get-TimeStamp)"
}

# "MAIN"

$queue = Build-Queue $srcDir $term
$queue > $queFile

Write-Host $queue
Write-Host ""

$timestamp = Get-TimeStamp
$dataFName = "data_$($timestamp).txt"
Process-Queue $queue "$dataDir\$dataFName"

switch($sleep) {
   $True {Sleep-Computer}
}