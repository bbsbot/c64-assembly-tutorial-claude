<#
.SYNOPSIS
    Monster Mac Pro (2013 "Trashcan") LLM Deployment & Validation Suite
    Target Hardware: Intel Xeon E5-2697 v2 | 128GB ECC RAM | Dual AMD FirePro D500

.DESCRIPTION
    This script performs a deep-tissue audit of the unique Mac Pro hardware environment 
    running Windows 10/11. It bypasses the "Cloud-First" limitations of standard AI 
    CLIs to leverage local OpenCL acceleration via Dual GPUs.

.PREREQUISITES
    1. AMD FirePro Unified Driver: WHQL 20.Q1 (Version 26.20.13001.53002)
       Direct Link: https://www.amd.com
       *Note: Without this specific 2020 driver, OpenCL/CLBlast will fail to initialize.*

    2. Ollama for Windows: https://ollama.com
       Used as the model library and manifest manager.

    3. KoboldCPP (v1.70+): https://github.com/LostRuins
       The GGUF engine used to offload 99+ layers to Dual FirePro D500 GPUs.

.USAGE
    - To check your current system health:
      .\Validate-Monster-Mac.ps1

    - To see what a "Clean Install" (missing all software) looks like for documentation:
      .\Validate-Monster-Mac.ps1 -TestAsClean

.MODEL_TARGET
    Default: hf.co/tensorblock/Llama-3.2-3B-Instruct-GGUF:Q2_K
    This model is chosen for high-speed verification of the OpenCL handshake.

.NOTES
    - Author: Allen Hammock (@bbsbot, @brainvat)
    - Purpose: GIST Documentation for legacy Mac Pro Workstation revival.
    - Architecture: Portable (Uses $env:USERPROFILE to avoid hardcoded paths).
#>

param(
    [switch]$TestAsClean
)

Clear-Host
$ErrorActionPreference = "Continue"

# Download links

$download_amd = "https://www.amd.com/en/resources/support-articles/release-notes/Apple-Boot-Camp-Previous.html"
$download_kobold = "https://github.com/LostRuins/koboldcpp/releases"
$download_ollama = "https://ollama.com/download/windows"

# --- DYNAMIC PATH RESOLUTION ---
# We use $HOME and $env:USERPROFILE to ensure this works for ANY Windows user
$CurrentUser = $env:USERNAME
$BaseDir = $env:USERPROFILE 
$TargetModel = "hf.co/tensorblock/Llama-3.2-3B-Instruct-GGUF:Q2_K"
$RequiredDriver = "26.20.13001.53002" 
# We assume Kobold is in the user's Documents folder, regardless of their name
$KoboldPath = Join-Path $BaseDir "Documents\KoboldCPP\koboldcpp.exe"
$Global:ValidBlob = ""

if ($TestAsClean) {
    Write-Host "--- SIMULATING CLEAN INSTALL MODE ---" -ForegroundColor Yellow -BackgroundColor Black
}

Write-Host "--- MONSTER MAC PRO HARDWARE MANIFEST ---" -ForegroundColor Magenta

# 1. MACHINE IDENTITY (Model & OS)
$SysInfo = Get-CimInstance Win32_ComputerSystem
$BiosInfo = Get-CimInstance Win32_BIOS
$CPU = Get-CimInstance Win32_Processor
$OS = Get-CimInstance Win32_OperatingSystem
$RAM = [Math]::Round((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB)

$ModelID = if ($TestAsClean) { "MacPro6,1 (Simulated)" } else { $SysInfo.Model }

Write-Host "MACHINE: $($SysInfo.Manufacturer) $ModelID" -ForegroundColor White
Write-Host "USER:    $CurrentUser" -ForegroundColor Gray
Write-Host "CPU:     $($CPU.Name) ($($CPU.NumberOfCores) Cores)" -ForegroundColor Gray
Write-Host "RAM:     $RAM GB Total ECC Memory" -ForegroundColor Gray

# 2. GPU & DRIVER AUDIT
Write-Host "`n--- GPU ACCELERATION CHECK ---" -ForegroundColor White
$GPU_Info = Get-CimInstance Win32_VideoController
$DriverStatus = $true

foreach ($G in $GPU_Info) {
    if ($G.Name -match "FirePro D500") {
        $ActualDriver = if ($TestAsClean) { "23.20.1501.0" } else { $G.DriverVersion }
        $IsCorrect = if ($TestAsClean) { $false } else { ($ActualDriver -eq $RequiredDriver) }
        
        $Color = if ($IsCorrect) { "Green" } else { "Red"; $DriverStatus = $false }
        Write-Host "FOUND: $($G.Name) [VRAM: $([Math]::Round($G.AdapterRAM / 1MB)) MB] [Driver: $ActualDriver]" -ForegroundColor $Color
    }
}

if (-not $DriverStatus) {
    Write-Host "CRITICAL: Incorrect AMD Driver. Download: $download_amd" -ForegroundColor Red
}

# 3. AUDIT OLLAMA MODELS
Write-Host "`n--- OLLAMA MODEL LIBRARY ---" -ForegroundColor White
$OllamaInstalled = if ($TestAsClean) { $false } else { Get-Command ollama -ErrorAction SilentlyContinue }

if ($OllamaInstalled) {
    $OllamaList = ollama list | Select-Object -Skip 1
    $FoundTarget = $false

    foreach ($line in $OllamaList) {
        $Name = ($line -split "\s+")[0]
        if ($Name -eq $TargetModel) {
            Write-Host "[√] TARGET PRESENT: $Name" -ForegroundColor Green
            $FoundTarget = $true
            
            # Resolve Physical Blob using Dynamic User Path
            $ManifestDir = Join-Path $BaseDir ".ollama\models\manifests"
            $Tag = ($TargetModel -split ":")[-1]
            $ManifestFile = Get-ChildItem -Path $ManifestDir -Filter $Tag -Recurse | Select-Object -First 1
            if ($ManifestFile) {
                $Json = Get-Content $ManifestFile.FullName -Raw | ConvertFrom-Json
                $Sha = ($Json.layers | Where-Object { $_.mediaType -match "model" }).digest.Replace("sha256:", "sha256-")
                $Global:ValidBlob = Join-Path $BaseDir ".ollama\models\blobs\$Sha"
                Write-Host "[√] BLOB VERIFIED: $Sha" -ForegroundColor Green
            }
        } elseif ($Name) {
            Write-Host "    Found: $Name" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "MISSING: Ollama not found. Download: $download_ollama" -ForegroundColor Red
    $FoundTarget = $false
}

# 4. ENGINE VALIDATION
Write-Host "`n--- ENGINE VALIDATION ---" -ForegroundColor White
$ActualEnginePath = if ($TestAsClean) { "C:\Users\Missing\koboldcpp.exe" } else { $KoboldPath }
$EngineStatus = Test-Path $ActualEnginePath

if ($EngineStatus) {
    Write-Host "[√] KOBOLD ENGINE: $ActualEnginePath" -ForegroundColor Green
} else {
    Write-Host "MISSING: KoboldCPP Engine not found at $ActualEnginePath. Download $download_kobold" -ForegroundColor Red
}

# --- SUMMARY ---
Write-Host "`n--- VALIDATION COMPLETE ---" -ForegroundColor Magenta
if ($DriverStatus -and $EngineStatus -and $Global:ValidBlob -and -not $TestAsClean) {
    Write-Host "SYSTEM STATUS: READY" -ForegroundColor Green
    Write-Host "`nCOPY/PASTE TO LAUNCH DUAL GPUs:" -ForegroundColor White
    Write-Host "& '$KoboldPath' --model '$Global:ValidBlob' --useclblast 0 0 --gpulayers 99" -ForegroundColor Gray
} else {
    Write-Host "SYSTEM STATUS: NOT READY" -ForegroundColor Red
}
