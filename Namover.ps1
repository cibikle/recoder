#Namover.ps1
#C. Bikle

# A PowerShell script to rename the predictible parts of my recorded gameplay video names
#+and move the files into their respective subdirectories.
#+("Namer" + "Mover" = "Namover")

$playerInitials = "cib"
$ext = ".avi"
$stdNameLen = 8
$actNameLen = 4

$knowAbbrvs = @{}
$knowAbbrvs['KFGame'] = 'KF2'
$knowAbbrvs['MassEffect3'] = 'ME3'
$knowAbbrvs['KillingFloor'] = 'KF'
$knowAbbrvs['payday2'] = 'PD2'
$knowAbbrvs['R6Vegas2'] = 'R6V2'
$knowAbbrvs['RainbowSix'] = 'R6S'
$knowAbbrvs['Overwatch'] = 'OW'

$knowAddlInfo = @{}
$knowAddlInfo[$knowAbbrvs['KFGame']] = "map_dif_out"
$knowAddlInfo[$knowAbbrvs['MassEffect3']] = "map_enemy_dif"
$knowAddlInfo[$knowAbbrvs['KillingFloor']] = "map_dif_out"
$knowAddlInfo[$knowAbbrvs['payday2']] = "map_dif"
$knowAddlInfo[$knowAbbrvs['R6Vegas2']] = "map_dif"
$knowAddlInfo[$knowAbbrvs['RainbowSix']] = "dif_map_obj"
$knowAddlInfo[$knowAbbrvs['Overwatch']] = "map_obj"

function Do-Rename {
	$newName = $gameName+"_"+$dateAssemblage+"_"+$timeAssemblage+$addlInfo+$playerInitials+$ext
	Rename-Item $_ -NewName $newName
	Write-Host "New name: $newName"
	return $newName
}

function Do-Move ( [string]$target, [string]$dst ) {
	$dst = ".\"+$dst
	If ( !( Test-Path $dst ) ) {
		echo "dest $dst does not exist--creating"
		New-Item -ItemType directory -Path $dst
	}
	Move-Item $target $dst
}

Get-ChildItem ".\" -Filter *$ext |
 Foreach-Object {
	$name = $_.BaseName
	Write-Host "Original name: $name"
	If ( $name -like '*_*' ) {
		$parts = $name -split '_'
		$offset = $parts.length - $stdNameLen
		$dateAssemblage = $parts[1+$offset]+"-"+$parts[2+$offset]+"-"+$parts[3+$offset]
		$timeAssemblage = $parts[4+$offset]+$parts[5+$offset]
	} Else { #hopefully, this catches the space-deliniated filenames from Action! recorder
		$parts = $name -split ' '
		$dateParts = $parts[1] -split '-'
		$timeParts = $parts[2] -split '-'
		$month = $dateParts[0]
		If ( $month.Length -eq 1 ) {
			$month = '0'+$month
		}
		$day = $dateParts[1]
		If ( $day.Length -eq 1 ) {
			$day = '0'+$day
		}
		$dateAssemblage = $dateParts[2]+'-'+$month+'-'+$day
		$hour = [int]$timeParts[0]
		$minute = $timeParts[1]
		If ( $hour -eq 12 -AND $parts[3] -eq 'AM' ) {
			$hour = '00'
		} Elseif ( $hour -lt 10 -AND $parts[3] -eq 'AM' ) {
			$hour = '0'+$hour
		} Elseif ( $hour -ne 12 -AND $parts[3] -eq 'PM' ) {
			$hour = 12 + $hour
		}
		$timeAssemblage = ''+$hour+$minute
	}
	Write-Host "Date: $dateAssemblage"
	Write-Host "Time: $timeAssemblage"
	
	$oldGameName = $parts[0]
	
	If ( $knowAbbrvs.ContainsKey($oldGameName) ) {
		$gameName = $knowAbbrvs[$oldGameName]
		echo "Found `"$oldGameName`" ($gameName) video!"
		$addlInfo = "_"+$knowAddlInfo[$gameName]+"_"
		Do-Move (Do-Rename) $gameName
	} Else {
		If ( $knowAbbrvs.ContainsValue($oldGameName) ) {
			echo "This one's been done: $name"
			Do-Move $_ $oldGameName
		} Else {
			echo "Found some other game video! Leaving `"$oldGameName`" alone."
			$gameName = $oldGameName
			$addlInfo = "_"
			Do-Move (Do-Rename) $gameName
		}
	}
	Write-Host ''
 }