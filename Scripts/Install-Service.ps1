$RootDir = Split-Path -Parent $PSScriptRoot
$NssmPath = Join-Path $RootDir "Tools\nssm.exe"
$ServiceName = "NetsimYedekServisi"
$ServiceLoopScript = Join-Path $PSScriptRoot "Service-Loop.ps1"

if (-not (Test-Path $NssmPath)) {
    Write-Host "HATA: nssm.exe bulunamadi: $NssmPath"
    Write-Host "https://nssm.cc/download adresinden nssm indirin, win64\nssm.exe dosyasini"
    Write-Host "$RootDir\Tools\nssm.exe olarak kopyalayin ve bu scripti tekrar calistirin."
    exit 1
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Bu script Yonetici (Administrator) olarak calistirilmalidir."
    exit 1
}

& $NssmPath status $ServiceName *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Servis zaten kurulu, once kaldiriliyor..."
    & $NssmPath stop $ServiceName *> $null
    & $NssmPath remove $ServiceName confirm *> $null
}

& $NssmPath install $ServiceName "powershell.exe" "-NoProfile -ExecutionPolicy Bypass -File `"$ServiceLoopScript`""
& $NssmPath set $ServiceName AppDirectory $PSScriptRoot
& $NssmPath set $ServiceName DisplayName "Netsim Yedekleme Servisi"
& $NssmPath set $ServiceName Description "Netsim Otomasyon veritabani dosyalarini gunluk olarak Google Drive'a ve ek konumlara yedekler."
& $NssmPath set $ServiceName Start SERVICE_AUTO_START
& $NssmPath set $ServiceName AppStdout (Join-Path $RootDir "Logs\service-stdout.log")
& $NssmPath set $ServiceName AppStderr (Join-Path $RootDir "Logs\service-stderr.log")
& $NssmPath set $ServiceName AppRotateFiles 1
& $NssmPath set $ServiceName AppRotateBytes 1048576

Write-Host ""
Write-Host "Servisin, Ofisnet.exe'yi masaustunde yeniden acabilmesi icin bilgisayarda"
Write-Host "oturum acan gercek bir Windows kullanicisi hesabinda calismasi gerekir (LocalSystem degil)."
$cred = Get-Credential -Message "Servisin calisacagi Windows kullanici hesabini girin (DOMAIN\kullanici veya .\kullanici formatinda)"
$username = $cred.UserName
$password = $cred.GetNetworkCredential().Password
& $NssmPath set $ServiceName ObjectName $username $password

& $NssmPath start $ServiceName
Write-Host ""
Write-Host "Servis kuruldu ve baslatildi: $ServiceName"
Write-Host "Durumu kontrol etmek icin: services.msc -> 'Netsim Yedekleme Servisi'"
