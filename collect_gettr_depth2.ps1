# ============================================================
# GoGettr Depth-2 followers/following collection
# ============================================================
# Reads usernames from depth1_users.txt
# Collects both followers and following for each account
# Saves results under data\network_depth2
# Skips already-successful files so the script can be resumed
# ============================================================

$SeedFile = "depth1_users.txt"

$OutputDir = "data\network_depth2"
$LogDir = "logs\network_depth2"

$DelayBetweenRequests = 10
$DelayBetweenUsers = 10

# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

if (!(Test-Path $SeedFile)) {
    Write-Host ""
    Write-Host "ERROR: Seed file not found: $SeedFile" -ForegroundColor Red
    Write-Host ""
    exit 1
}

$Users = Get-Content $SeedFile |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne "" -and !$_.StartsWith("#") }

Write-Host ""
Write-Host "=========================================="
Write-Host " GoGettr Depth-2 Network Collection"
Write-Host "=========================================="
Write-Host "Seed file: $SeedFile"
Write-Host "Users found: $($Users.Count)"
Write-Host "Output directory: $OutputDir"
Write-Host ""

# ------------------------------------------------------------
# Helper: determine whether an output file is already usable
# ------------------------------------------------------------

function Test-UsableOutputFile {
    param (
        [string]$Path
    )

    if (!(Test-Path $Path)) {
        return $false
    }

    try {
        $fileInfo = Get-Item $Path

        if ($fileInfo.Length -le 0) {
            return $false
        }

        $hasJson = Get-Content $Path -ErrorAction Stop |
            Where-Object { $_.Trim().StartsWith("{") } |
            Select-Object -First 1

        return ($null -ne $hasJson)
    }
    catch {
        return $false
    }
}

# ------------------------------------------------------------
# Progress counters
# ------------------------------------------------------------

$UserIndex = 0
$FollowersSuccess = 0
$FollowingSuccess = 0
$FollowersSkipped = 0
$FollowingSkipped = 0
$Failures = 0

# ------------------------------------------------------------
# Main loop
# ------------------------------------------------------------

foreach ($User in $Users) {

    $UserIndex++

    Write-Host ""
    Write-Host "=========================================="
    Write-Host "[$UserIndex / $($Users.Count)] Processing: $User"
    Write-Host "=========================================="

    # Make username safe for Windows filenames
    $SafeUser = $User -replace '[\\/:*?"<>|]', '_'

    $FollowersFile = Join-Path $OutputDir "${SafeUser}_followers.jsonl"
    $FollowingFile = Join-Path $OutputDir "${SafeUser}_following.jsonl"

    $FollowersErrorLog = Join-Path $LogDir "${SafeUser}_followers_errors.log"
    $FollowingErrorLog = Join-Path $LogDir "${SafeUser}_following_errors.log"

    # ========================================================
    # FOLLOWERS
    # ========================================================

    if (Test-UsableOutputFile $FollowersFile) {

        Write-Host "Followers already collected. Skipping." -ForegroundColor Cyan
        $FollowersSkipped++

    }
    else {

        Write-Host "Collecting followers..."

        # Remove stale/empty output before retrying
        if (Test-Path $FollowersFile) {
            Remove-Item $FollowersFile -Force -ErrorAction SilentlyContinue
        }

        try {

            & gogettr user-followers $User `
                1> $FollowersFile `
                2> $FollowersErrorLog

            $FollowersExitCode = $LASTEXITCODE

            if (
                $FollowersExitCode -eq 0 -and
                (Test-UsableOutputFile $FollowersFile)
            ) {

                $FollowerCount = (
                    Get-Content $FollowersFile |
                    Where-Object { $_.Trim().StartsWith("{") }
                ).Count

                Write-Host "Followers saved: $FollowerCount" -ForegroundColor Green
                $FollowersSuccess++

            }
            else {

                Write-Host "Followers collection failed for $User" -ForegroundColor Yellow
                Write-Host "See: $FollowersErrorLog"

                # Remove empty/bad output so it can be retried later
                if (
                    (Test-Path $FollowersFile) -and
                    !(Test-UsableOutputFile $FollowersFile)
                ) {
                    Remove-Item $FollowersFile -Force -ErrorAction SilentlyContinue
                }

                $Failures++
            }

        }
        catch {

            $_ | Out-File -Append -Encoding utf8 $FollowersErrorLog

            Write-Host "Unexpected followers error for $User" -ForegroundColor Red

            if (
                (Test-Path $FollowersFile) -and
                !(Test-UsableOutputFile $FollowersFile)
            ) {
                Remove-Item $FollowersFile -Force -ErrorAction SilentlyContinue
            }

            $Failures++
        }
    }

    Write-Host "Waiting $DelayBetweenRequests seconds..."
    Start-Sleep -Seconds $DelayBetweenRequests

    # ========================================================
    # FOLLOWING
    # ========================================================

    if (Test-UsableOutputFile $FollowingFile) {

        Write-Host "Following already collected. Skipping." -ForegroundColor Cyan
        $FollowingSkipped++

    }
    else {

        Write-Host "Collecting following..."

        # Remove stale/empty output before retrying
        if (Test-Path $FollowingFile) {
            Remove-Item $FollowingFile -Force -ErrorAction SilentlyContinue
        }

        try {

            & gogettr user-following $User `
                1> $FollowingFile `
                2> $FollowingErrorLog

            $FollowingExitCode = $LASTEXITCODE

            if (
                $FollowingExitCode -eq 0 -and
                (Test-UsableOutputFile $FollowingFile)
            ) {

                $FollowingCount = (
                    Get-Content $FollowingFile |
                    Where-Object { $_.Trim().StartsWith("{") }
                ).Count

                Write-Host "Following saved: $FollowingCount" -ForegroundColor Green
                $FollowingSuccess++

            }
            else {

                Write-Host "Following collection failed for $User" -ForegroundColor Yellow
                Write-Host "See: $FollowingErrorLog"

                if (
                    (Test-Path $FollowingFile) -and
                    !(Test-UsableOutputFile $FollowingFile)
                ) {
                    Remove-Item $FollowingFile -Force -ErrorAction SilentlyContinue
                }

                $Failures++
            }

        }
        catch {

            $_ | Out-File -Append -Encoding utf8 $FollowingErrorLog

            Write-Host "Unexpected following error for $User" -ForegroundColor Red

            if (
                (Test-Path $FollowingFile) -and
                !(Test-UsableOutputFile $FollowingFile)
            ) {
                Remove-Item $FollowingFile -Force -ErrorAction SilentlyContinue
            }

            $Failures++
        }
    }

    Write-Host ""
    Write-Host "Finished: $User"

    if ($UserIndex -lt $Users.Count) {
        Write-Host "Waiting $DelayBetweenUsers seconds before next user..."
        Start-Sleep -Seconds $DelayBetweenUsers
    }
}

# ------------------------------------------------------------
# Final summary
# ------------------------------------------------------------

Write-Host ""
Write-Host "=========================================="
Write-Host " Depth-2 collection completed"
Write-Host "=========================================="
Write-Host "Users processed: $($Users.Count)"
Write-Host "Followers collected successfully: $FollowersSuccess"
Write-Host "Following collected successfully: $FollowingSuccess"
Write-Host "Followers skipped (already present): $FollowersSkipped"
Write-Host "Following skipped (already present): $FollowingSkipped"
Write-Host "Failed requests: $Failures"
Write-Host ""
Write-Host "Results: $OutputDir"
Write-Host "Logs:    $LogDir"
Write-Host "=========================================="
