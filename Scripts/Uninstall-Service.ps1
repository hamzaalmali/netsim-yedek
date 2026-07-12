$RootDir = Split-Path -Parent $PSScriptRoot
$NssmPath = Join-Path $RootDir "Tools\nssm.exe"
$ServiceName = "NetsimYedekServisi"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Bu script Yonetici (Administrator) olarak calistirilmalidir."
    exit 1
}

if (-not (Test-Path $NssmPath)) {
    Write-Host "HATA: nssm.exe bulunamadi: $NssmPath"
    exit 1
}

& $NssmPath stop $ServiceName
& $NssmPath remove $ServiceName confirm
Write-Host "Servis kaldirildi: $ServiceName"
