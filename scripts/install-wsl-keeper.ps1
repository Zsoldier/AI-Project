$ErrorActionPreference = "Stop"

$distributions = wsl.exe --list --quiet | ForEach-Object {
    ([regex]::Replace($_, "`0", "")).Trim()
}
$distribution = $distributions | Where-Object { $_ } | Select-Object -First 1
if (-not $distribution) {
    throw "No WSL distribution is installed."
}

$linuxUser = (wsl.exe -d $distribution --exec sh -lc "id -un" |
    ForEach-Object { ([regex]::Replace($_, "`0", "")).Trim() }) -join ""
if ($LASTEXITCODE -ne 0) {
    throw "Could not query the default Linux user for $distribution."
}
if (-not $linuxUser) {
    throw "Could not determine the default Linux user for $distribution."
}

wsl.exe -d $distribution -u root --exec loginctl enable-linger $linuxUser
if ($LASTEXITCODE -ne 0) {
    throw "Could not enable systemd lingering for $linuxUser."
}

$startupDirectory = [Environment]::GetFolderPath("Startup")
$keeperPath = Join-Path $startupDirectory "AI Home Lab Ollama WSL.vbs"
$escapedDistribution = $distribution.Replace('"', '""')
$escapedUser = $linuxUser.Replace('"', '""')
$keeper = @"
Set shell = CreateObject("WScript.Shell")
shell.Run "wsl.exe -d ""$escapedDistribution"" -u ""$escapedUser"" --exec tail -f /dev/null", 0, False
"@
Set-Content -Path $keeperPath -Value $keeper -Encoding ascii

$keeperProcesses = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq "wsl.exe" -and $_.CommandLine -like "*tail -f /dev/null*"
}
if (-not $keeperProcesses) {
    Start-Process -FilePath "wscript.exe" -ArgumentList "`"$keeperPath`""
}

Write-Output "Installed WSL keeper: $keeperPath"
Write-Output "Distribution: $distribution"
Write-Output "Linux user: $linuxUser"
