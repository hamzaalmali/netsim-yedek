. (Join-Path $PSScriptRoot "Common.ps1")

Write-Host "=== Google Drive Baglantisi ==="

if (-not (Test-Path $ConfigPath)) {
    Write-Host "HATA: Once Ayarlar ekranindan (Settings-UI.ps1) Client ID / Client Secret girip Kaydet'e basin."
    exit 1
}

$Config = Get-Config

if (-not $Config.GoogleDrive.ClientId -or -not $Config.GoogleDrive.ClientSecretEncrypted) {
    Write-Host "HATA: Client ID / Client Secret bilgileri eksik."
    Write-Host "Ayarlar ekraninda 'Google Drive Client ID' ve 'Client Secret' alanlarini doldurup Kaydet'e basin, sonra tekrar deneyin."
    exit 1
}

$clientId = $Config.GoogleDrive.ClientId
$clientSecretPlain = Unprotect-StringLocalMachine -EncodedText $Config.GoogleDrive.ClientSecretEncrypted
Write-Host "Kayitli Client ID kullaniliyor: $clientId"

$redirectUri = "http://127.0.0.1:8977/"
$scope = "https://www.googleapis.com/auth/drive.file"
# prompt=consent select_account: hesap secme ekranini her seferinde gosterir, boylece
# kullanici ileride farkli bir Google hesabina gecmek isterse dogrudan secebilir.
$authUrl = "https://accounts.google.com/o/oauth2/v2/auth?client_id=$clientId&redirect_uri=$([uri]::EscapeDataString($redirectUri))&response_type=code&scope=$([uri]::EscapeDataString($scope))&access_type=offline&prompt=consent%20select_account"

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($redirectUri)
$listener.Start()

Write-Host "Tarayici aciliyor, Google hesabinizla giris yapip izin verin..."
Start-Process $authUrl

$context = $listener.GetContext()
$code = $context.Request.QueryString["code"]

$responseString = "<html><body><h2>Giris tamamlandi, bu pencereyi kapatabilirsiniz.</h2></body></html>"
$buffer = [System.Text.Encoding]::UTF8.GetBytes($responseString)
$context.Response.ContentLength64 = $buffer.Length
$context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
$context.Response.OutputStream.Close()
$listener.Stop()

if (-not $code) {
    Write-Host "HATA: Yetkilendirme kodu alinamadi."
    exit 1
}

$tokenBody = @{
    code          = $code
    client_id     = $clientId
    client_secret = $clientSecretPlain
    redirect_uri  = $redirectUri
    grant_type    = "authorization_code"
}
$tokenResp = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body $tokenBody

if (-not $tokenResp.refresh_token) {
    Write-Host "UYARI: refresh_token alinamadi."
    Write-Host "Google hesabinizin 'Uygulamalar ve site baglantilari' sayfasindan bu uygulamayi kaldirip tekrar deneyin."
    exit 1
}

Save-RefreshToken -RefreshToken $tokenResp.refresh_token
Write-Host "Google Drive basariyla baglandi."
