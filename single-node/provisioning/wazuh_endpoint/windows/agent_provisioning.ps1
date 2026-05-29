$ossecPath = "C:\Program Files (x86)\ossec-agent"
$wazuhServiceName = "WazuhSvc"
$sysmonPath = "$ossecPath\sysmon"
$yaraPath = "$ossecPath\active-response\bin\yara"
$scaPath = "C:\Program Files (x86)\sca_policies"

$sysmonUrl = "https://download.sysinternals.com/files/Sysmon.zip"
$yaraReleaseApi = "https://api.github.com/repos/VirusTotal/yara/releases/latest"
$yararuleURL = "https://raw.githubusercontent.com/sakkarose/wazuh-rac/main/single-node/provisioning/wazuh_endpoint/windows/yara/yara_rules.yar"
$localYaraRulesPath = Join-Path $PSScriptRoot "yara\yara_rules.yar"

function Enable-PSLogging {
    # Define registry paths for ScriptBlockLogging and ModuleLogging
    $scriptBlockPath = 'HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
    $moduleLoggingPath = 'HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging'
    
    # Enable Script Block Logging
    if (-not (Test-Path $scriptBlockPath)) {
        $null = New-Item $scriptBlockPath -Force
    }
    Set-ItemProperty -Path $scriptBlockPath -Name EnableScriptBlockLogging -Value 1
    # Enable Module Logging
    if (-not (Test-Path $moduleLoggingPath)) {
        $null = New-Item $moduleLoggingPath -Force
    }
    Set-ItemProperty -Path $moduleLoggingPath -Name EnableModuleLogging -Value 1
    
    # Specify modules to log - set to all (*) for comprehensive logging
    $moduleNames = @('*')  # To specify individual modules, replace * with module names in the array
    New-ItemProperty -Path $moduleLoggingPath -Name ModuleNames -PropertyType MultiString -Value $moduleNames -Force
    Write-Output "Script Block Logging and Module Logging have been enabled."
}

# Rerun script as administrator if not already running as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

if (-not (Test-Path -Path $ossecPath)) {
    throw "Wazuh agent directory not found at '$ossecPath'. Install the Wazuh Windows agent before running this script."
}

# Stop the Wazuh agent service if it is running
$wazuhService = Get-Service -Name $wazuhServiceName -ErrorAction SilentlyContinue
if ($wazuhService -and $wazuhService.Status -ne "Stopped") {
    Stop-Service -Name $wazuhServiceName -Force -ErrorAction Stop
    $wazuhService.WaitForStatus("Stopped", "00:00:30")
}

# Download Sysmon
Invoke-WebRequest -Uri $sysmonUrl -OutFile "$PSScriptRoot\Sysmon.zip"

# Extract Sysmon
Expand-Archive -Path "$PSScriptRoot\Sysmon.zip" -DestinationPath "$PSScriptRoot" -Force

# Create Sysmon directory
if (-Not (Test-Path -Path "$sysmonPath")) {
    New-Item -ItemType Directory -Path "$sysmonPath" -Force | Out-Null
}

# Copy Sysmon to the agent
Copy-Item -Path "$PSScriptRoot\Sysmon64.exe" -Destination "$sysmonPath\Sysmon64.exe" -Force

# Copy configuration file
Copy-Item -Path "$PSScriptRoot\sysmon\sysmonconfig.xml" -Destination "$sysmonPath\sysmonconfig.xml" -Force

# Set the current location to the Sysmon directory for reliable execution
Set-Location -Path $sysmonPath

# Install Sysmon or update its configuration if it is already installed
$sysmonService = Get-Service -Name "Sysmon64" -ErrorAction SilentlyContinue
if ($sysmonService) {
    Start-Process -FilePath ".\Sysmon64.exe" -ArgumentList @("-c", ".\sysmonconfig.xml") -NoNewWindow -Wait
} else {
    Start-Process -FilePath ".\Sysmon64.exe" -ArgumentList @("-accepteula", "-i", ".\sysmonconfig.xml") -NoNewWindow -Wait
}

Set-Location -Path $PSScriptRoot

# Determine the latest YARA release for win64 and download it
$headers = @{ "User-Agent" = "WazuhProvisioningScript" }
$yaraRelease = Invoke-RestMethod -Uri $yaraReleaseApi -Headers $headers
$yaraAsset = $yaraRelease.assets | Where-Object { $_.name -match 'win64\.zip$' } | Select-Object -First 1
if (-not $yaraAsset) {
    throw "Unable to find a win64 YARA asset in the latest release."
}
$yaraUrl = $yaraAsset.browser_download_url
$yaraZipPath = Join-Path $PSScriptRoot $yaraAsset.name
$yaraExtractPath = Join-Path $PSScriptRoot "yara-download"

Invoke-WebRequest -Uri $yaraUrl -OutFile $yaraZipPath

if (Test-Path $yaraExtractPath) {
    Remove-Item -Path $yaraExtractPath -Recurse -Force
}
Expand-Archive -Path $yaraZipPath -DestinationPath $yaraExtractPath -Force

# Create the YARA directory
if (-Not (Test-Path -Path $yaraPath)) {
    New-Item -ItemType Directory -Path $yaraPath -Force | Out-Null
}

# Copy the YARA binary to the new directory
$yaraExe = Get-ChildItem -Path $yaraExtractPath -Recurse -Filter "yara64.exe" | Select-Object -First 1
if (-not $yaraExe) {
    throw "Unable to locate yara64.exe in the downloaded archive."
}
Copy-Item -Path $yaraExe.FullName -Destination $yaraPath -Force

Remove-Item -Path $yaraExtractPath -Recurse -Force
Remove-Item -Path $yaraZipPath -Force

# Create the YARA rules directory
if (-Not (Test-Path -Path "$yaraPath\rules")) {
    New-Item -ItemType Directory -Path "$yaraPath\rules" -Force | Out-Null
}

# Copy bundled YARA rules, or download them when the script is distributed alone
if (Test-Path -Path $localYaraRulesPath) {
    Copy-Item -Path $localYaraRulesPath -Destination "$yaraPath\rules\yara_rules.yar" -Force
} else {
    Invoke-WebRequest -Uri $yararuleURL -OutFile "$yaraPath\rules\yara_rules.yar"
}

# Enable PowerShell logging
Enable-PSLogging

# Active-response provisioning
Copy-Item -Path "$PSScriptRoot\active-response\*" -Destination "$ossecPath\active-response\bin\" -Recurse -Force

# Create the SCA rules directory
if (-Not (Test-Path -Path "$scaPath")) {
    New-Item -ItemType Directory -Path "$scaPath" -Force | Out-Null
}

# Copy the SCA rules to the new directory
Copy-Item -Path "$PSScriptRoot\agent_config\policies\*" -Destination "$scaPath" -Recurse -Force

# Copy the wodles folder
Copy-Item -Path "$PSScriptRoot\wodles\*" -Destination "$ossecPath\wodles\" -Recurse -Force

if ($wazuhService) {
    Start-Service -Name $wazuhServiceName -ErrorAction Stop
}

# Print a message asking the user to restart the computer
Write-Host "Provisioning completed. Please restart your computer to apply all changes."
Read-Host -Prompt "Press Enter to exit"
