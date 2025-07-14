# Function to check if ADB is available
function Test-ADB {
    try {
        $adbVersion = adb version
        return $true
    }
    catch {
        Write-Host "ADB is not installed or not in PATH. Please install Android Platform Tools."
        return $false
    }
}



#--------------------------------
# Main script execution

# Check ADB installation
if (-not (Test-ADB)) {
    exit
}

# Check device connection
$deviceList = adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "device$" }
if ($deviceList.Count -eq 0) {
    Write-Host "❌ No device connected. Please connect your Android device and enable USB debugging."
    exit
}

# Get device model
Write-Host "📦 Device found, getting device model..."
$model = adb shell getprop ro.product.model
$model = $model.Trim()
Write-Host "✅ Connected Device: $model"

Start-Sleep 1

# Check for Adopted Storage
Write-Host "📦 Getting volumes list..."
$volumes = adb shell sm list-volumes all
$volumes
Start-Sleep 1
Write-Host "📦 Determining adopted storage volumes..."
$adoptedUuid = ($volumes | Select-String -Pattern "private:[\d,]+ mounted ([a-f0-9\-]+)" | ForEach-Object { $_.Matches.Groups[1].Value })

if (-not $adoptedUuid) {
    Write-Host "❌ No adopted (SD card) storage found."
    exit
}
else {
    $adoptedStorage = $true
    Write-Host "✅ Adopted Storage identified = $adoptedStorage"
    Start-Sleep 1
    Write-Host "✅ Adopted Storage UUID: $adoptedUuid"
    $Storageconfirmation = Read-Host "Do you want to proceed? (type y to continue)"
    if ($Storageconfirmation -ne 'y' -and $Storageconfirmation -ne 'Y') 
    {
    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    exit
    }
}

Start-Sleep 1

# Get all package info once
Write-Host "📦 Getting all package info..."
$allPackages = adb shell pm list packages -f

# Build a list of objects: @{Path=..., Package=..., Storage=...}
$apps = @()
foreach ($line in $allPackages) {
    if ($line -match "^package:(.+?)base.apk=(.+)$") {
        $path = $matches[1]
        $pkg = $matches[2]
        $storage = if ($path -like "/data/app/*") { "INTERNAL" }
                   elseif ($path -like "/mnt/expand/*") { "ADOPTED" }
                   else { "OTHER" }
        $apps += [PSCustomObject]@{Path=$path; Package=$pkg; Storage=$storage}
    }
}

# List internal apps
Write-Host "`nApps in Internal Storage:"
$internalApps = $apps | Where-Object { $_.Storage -eq "INTERNAL" }
for ($i = 0; $i -lt $internalApps.Count; $i++) {
    Write-Host "$($i+1). [INTERNAL] APK: $($internalApps[$i].Package) (Path: $($internalApps[$i].Path))"
}

# List adopted apps
$adoptedApps = $apps | Where-Object { $_.Storage -eq "ADOPTED" }
if ($adoptedApps.Count -gt 0) {
    Write-Host "`nApps in Adopted Storage:"
    for ($i = 0; $i -lt $adoptedApps.Count; $i++) {
        Write-Host "$($i+1 + $internalApps.Count). [ADOPTED] APK: $($adoptedApps[$i].Package) (Path: $($adoptedApps[$i].Path))"
    }
}

#---------------

# Get user input
Write-Host "`nEnter the numbers of apps to move (separated by commas):"
$selectedNumbers = Read-Host

# Convert app number to index
$selectedIndexes = $selectedNumbers -split ',' | ForEach-Object { 
    $trimmed = $_.Trim()
    if ($trimmed -match '^[0-9]+$') { [int]$trimmed - 1 } else { -1 }
}

foreach ($index in $selectedIndexes) {
    # Find app by index
    if ($index -lt 0) {
        Write-Host "Invalid input detected. Please enter valid numbers only."
        continue
    }
    $app = $null

    if ($index -ge 0 -and $index -lt $internalApps.Count) {
        $app = $internalApps[$index]

    } elseif ($index -ge $internalApps.Count -and $index -lt ($internalApps.Count + $adoptedApps.Count)) {
        $app = $adoptedApps[$index - $internalApps.Count]

    } else {
        Write-Host "Invalid selection: $($index + 1)"
        continue
    }

    #$app

   # Determine target mount point
    if ($($app.Storage) -eq "INTERNAL") {
        $moveTo = "ADOPTED"
        $mountPoint = "$adoptedUuid"
    } else {
        $moveTo = "INTERNAL"
        $mountPoint = "null"
    }

    # Get available space on the target storage (in MB)
    if ($mountPoint -eq $adoptedUuid) {
        $dfOutput = adb shell df /mnt/expand/$mountPoint
    }
    else {
        $dfOutput = adb shell df /data/app
    }
    ## Split into lines, skip the header, and get the line that starts with "/dev/block/"
    $Sizedata = ($dfOutput -split "`n")[1]

    ## Normalize spaces and split into columns
    $columns = ($Sizedata -replace '\s+', ' ').Trim() -split ' '

    $availableKB = $columns[3]  ## 0-based: Filesystem, 1K-blocks, Used, Available
    $availableMB = [math]::Round($availableKB / 1024, 2)
    #Write-Host "📂 Available space on $($app.Storage) storage: $availableMB MB"
    

    # Get app size (in MB)
    # Process each line to find the exact directory match
    $appdu = adb shell "du -h '$($app.Path)' 2>/dev/null"
    $appSize = $appdu -split "`n" | ForEach-Object {
        $line = $_.Trim()
        
        if ($line -match "^(?<size>\d+(\.\d+)?)(?<unit>[KMG])\s+$([regex]::Escape($($app.Path)))$") {
            $num = [double]$matches['size']
            $unit = $matches['unit']
    
            switch ($unit) {
                'K' { return $num / 1024 }      # KB to MB
                'M' { return $num }             # MB
                'G' { return $num * 1024 }      # GB to MB
                default { return $num }         # Fallback
            }
        }
    }
    

    #$appdu
    #$appSize
    
    # Confirmation
    Write-Host "📂 $($app.Package) App size: $appSize MB, Destination ($moveto storage) available size: $availableMB MB"

    $Moveconfirmation = Read-Host "Do you want to Move $($app.Package) from $($app.Storage) storage to $moveto storage ? (type y to continue)"

    if ($Moveconfirmation -eq 'y' -and $Moveconfirmation -eq 'Y') 
    {
    Start-Sleep 1
        # Compare and move
        if ($availableMB -gt $appSize) {
            Write-Host "Moving $($app.Package) from $($app.Storage) storage >>>>> $moveTo storage ... "
            adb shell pm move-package $($app.Package) $mountPoint

            Start-Sleep 3
            Write-Host "Moved Successfully !"
        } else {
            Write-Host "Not enough space in $moveTo storage to move $($app.Package) (App size: $appSizeMB MB, Available: $spaceMB MB)"
        }
    }
    else {
        Start-Sleep 1
        Write-Host "Operation cancelled by user and $($app.Package) did not move." -ForegroundColor Yellow
    }
}

