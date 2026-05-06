$ossecPath = "C:\Program Files (x86)\ossec-agent"
$sysmonPath = "$ossecPath\sysmon"
$yaraPath = "$ossecPath\active-response\bin\yara"
$scaPath = "C:\Program Files (x86)\sca_policies"

$sysmonUrl = "https://download.sysinternals.com/files/Sysmon.zip"
$yaraReleaseApi = "https://api.github.com/repos/VirusTotal/yara/releases/latest"
$yararuleURL = "https://github.com/sakkarose/wazuh-docker/blob/main/single-node/config/wazuh_endpoint/windows/yara/yara_rules.yar"

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

# Stop the Wazuh agent service
Stop-Service -Name wazuh

# Download Sysmon
Invoke-WebRequest -Uri $sysmonUrl -OutFile "$PSScriptRoot\Sysmon.zip"

# Extract Sysmon
Expand-Archive -Path "$PSScriptRoot\Sysmon.zip" -DestinationPath "$PSScriptRoot"

# Create Sysmon directory
if (-Not (Test-Path -Path "$sysmonPath")) {
    New-Item -ItemType Directory -Path "$sysmonPath"
}

# Copy Sysmon to the agent
Copy-Item -Path "$PSScriptRoot\Sysmon64.exe" -Destination "$sysmonPath\Sysmon64.exe"

# Copy configuration file
Copy-Item -Path "$PSScriptRoot\sysmon\sysmonconfig.xml" -Destination "$sysmonPath\sysmonconfig.xml"

# Set the current location to the Sysmon directory for reliable execution
Set-Location -Path $sysmonPath

# Start Sysmon with configuration
Start-Process -FilePath ".\Sysmon64.exe" -ArgumentList @("-accepteula", "-i", ".\sysmonconfig.xml") -NoNewWindow -Wait

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
    New-Item -ItemType Directory -Path $yaraPath
}

# Copy the YARA binary to the new directory
$yaraExe = Get-ChildItem -Path $yaraExtractPath -Recurse -Filter "yara64.exe" | Select-Object -First 1
if (-not $yaraExe) {
    throw "Unable to locate yara64.exe in the downloaded archive."
}
Copy-Item -Path $yaraExe.FullName -Destination $yaraPath -Force

Remove-Item -Path $yaraExtractPath -Recurse -Force
Remove-Item -Path $yaraZipPath -Force

# Download the YARA rules file
Invoke-WebRequest -Uri $yararuleURL -OutFile "$PSScriptRoot\yara_rules.yar"

# Create the YARA rules directory
if (-Not (Test-Path -Path "$yaraPath\rules")) {
    New-Item -ItemType Directory -Path "$yaraPath\rules"
}

# Copy the YARA rules to the new directory
Copy-Item -Path "$PSScriptRoot\yara_rules.yar" -Destination "$yaraPath\rules\"

# Enable PowerShell logging
Enable-PSLogging

# Active-response provisioning
Copy-Item -Path "$PSScriptRoot\active-response\*" -Destination "$ossecPath\active-response\bin\" -Recurse

# Create the SCA rules directory
if (-Not (Test-Path -Path "$scaPath")) {
    New-Item -ItemType Directory -Path "$scaPath"
}

# Copy the SCA rules to the new directory
Copy-Item -Path "$PSScriptRoot\agent_config\policies\*" -Destination "$scaPath" -Recurse

# Copy the wodles folder
Copy-Item -Path "$PSScriptRoot\wodles\*" -Destination "$ossecPath\wodles\" -Recurse

# Print a message asking the user to restart the computer
Write-Host "Provisioning completed. Please restart your computer to apply all changes."
Read-Host -Prompt "Press Enter to exit"
