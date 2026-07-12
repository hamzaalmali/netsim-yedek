$RootDir = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $RootDir "Config\config.json"
$TokenPath = Join-Path $RootDir "Config\refresh_token.dat"
$LogDir = Join-Path $RootDir "Logs"
$StagingDir = Join-Path $RootDir "Staging"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    $logFile = Join-Path $LogDir ("backup_{0}.log" -f (Get-Date -Format "yyyy-MM-dd"))
    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

function Get-Config {
    if (-not (Test-Path $ConfigPath)) {
        throw "Config dosyasi bulunamadi: $ConfigPath. Once Settings-UI.ps1 ile ayarlari yapin."
    }
    return Get-Content $ConfigPath -Raw | ConvertFrom-Json
}

function Save-Config {
    param($Config)
    $configDir = Split-Path -Parent $ConfigPath
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8
}

# LocalMachine scope (not CurrentUser): the OAuth setup is run interactively by one user,
# but the Windows Service may run under a different account, so the secret must be
# decryptable by any account on this machine rather than bound to whoever ran setup.
function Protect-StringLocalMachine {
    param([string]$PlainText)
    Add-Type -AssemblyName System.Security
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
    $protected = [System.Security.Cryptography.ProtectedData]::Protect($bytes, $null, [System.Security.Cryptography.DataProtectionScope]::LocalMachine)
    return [Convert]::ToBase64String($protected)
}

function Unprotect-StringLocalMachine {
    param([string]$EncodedText)
    Add-Type -AssemblyName System.Security
    $bytes = [Convert]::FromBase64String($EncodedText)
    $unprotected = [System.Security.Cryptography.ProtectedData]::Unprotect($bytes, $null, [System.Security.Cryptography.DataProtectionScope]::LocalMachine)
    return [System.Text.Encoding]::UTF8.GetString($unprotected)
}

function Save-RefreshToken {
    param([string]$RefreshToken)
    $enc = Protect-StringLocalMachine -PlainText $RefreshToken
    $tokenDir = Split-Path -Parent $TokenPath
    if (-not (Test-Path $tokenDir)) { New-Item -ItemType Directory -Path $tokenDir -Force | Out-Null }
    Set-Content -Path $TokenPath -Value $enc -Encoding UTF8
}

function Get-RefreshToken {
    if (-not (Test-Path $TokenPath)) { return $null }
    $enc = Get-Content $TokenPath -Raw
    return Unprotect-StringLocalMachine -EncodedText $enc.Trim()
}

function Remove-RefreshToken {
    if (Test-Path $TokenPath) { Remove-Item $TokenPath -Force }
}

function Get-GoogleAccessToken {
    param($Config)
    $refreshToken = Get-RefreshToken
    if (-not $refreshToken) { throw "Google Drive bagli degil. Once Connect-GoogleDrive.ps1 calistirin (Ayarlar ekranindan 'Google Drive'a Bagla')." }
    $clientSecret = Unprotect-StringLocalMachine -EncodedText $Config.GoogleDrive.ClientSecretEncrypted
    $body = @{
        client_id     = $Config.GoogleDrive.ClientId
        client_secret = $clientSecret
        refresh_token = $refreshToken
        grant_type    = "refresh_token"
    }
    $resp = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body $body
    return $resp.access_token
}

function Get-OrCreateDriveFolder {
    param([string]$AccessToken, [string]$FolderName)
    $headers = @{ Authorization = "Bearer $AccessToken" }
    $query = "mimeType='application/vnd.google-apps.folder' and name='$FolderName' and trashed=false"
    $uri = "https://www.googleapis.com/drive/v3/files?q=$([uri]::EscapeDataString($query))&fields=files(id,name)"
    $resp = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    if ($resp.files.Count -gt 0) {
        return $resp.files[0].id
    }
    $metadata = @{ name = $FolderName; mimeType = "application/vnd.google-apps.folder" } | ConvertTo-Json
    $createResp = Invoke-RestMethod -Uri "https://www.googleapis.com/drive/v3/files" -Headers $headers -Method Post -ContentType "application/json" -Body $metadata
    return $createResp.id
}

function Invoke-DriveUpload {
    param([string]$AccessToken, [string]$FilePath, [string]$FolderId)
    $fileName = Split-Path -Leaf $FilePath
    $metadata = @{ name = $fileName; parents = @($FolderId) } | ConvertTo-Json -Compress

    $initHeaders = @{
        Authorization           = "Bearer $AccessToken"
        "Content-Type"          = "application/json; charset=UTF-8"
        "X-Upload-Content-Type" = "application/zip"
    }
    $initResp = Invoke-WebRequest -Uri "https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&fields=id,name,createdTime" -Method Post -Headers $initHeaders -Body $metadata
    $sessionUri = $initResp.Headers["Location"]
    if ($sessionUri -is [array]) { $sessionUri = $sessionUri[0] }

    $uploadHeaders = @{ Authorization = "Bearer $AccessToken" }
    $result = Invoke-WebRequest -Uri $sessionUri -Method Put -Headers $uploadHeaders -InFile $FilePath -ContentType "application/zip"
    return ($result.Content | ConvertFrom-Json)
}

function Remove-OldDriveBackups {
    param([string]$AccessToken, [string]$FolderId, [int]$KeepCount)
    $headers = @{ Authorization = "Bearer $AccessToken" }
    $query = "'$FolderId' in parents and trashed=false"
    $uri = "https://www.googleapis.com/drive/v3/files?q=$([uri]::EscapeDataString($query))&orderBy=createdTime&fields=files(id,name,createdTime)&pageSize=1000"
    $resp = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    $files = @($resp.files)
    if ($files.Count -gt $KeepCount) {
        $toDelete = $files[0..($files.Count - $KeepCount - 1)]
        foreach ($f in $toDelete) {
            Invoke-RestMethod -Uri "https://www.googleapis.com/drive/v3/files/$($f.id)" -Headers $headers -Method Delete | Out-Null
            Write-Log "Eski yedek silindi (Google Drive): $($f.name)"
        }
    }
}

function Remove-OldLocalBackups {
    param([string]$FolderPath, [int]$KeepCount)
    if (-not (Test-Path $FolderPath)) { return }
    $files = @(Get-ChildItem -Path $FolderPath -Filter "NetsimYedek_*.zip" | Sort-Object CreationTime)
    if ($files.Count -gt $KeepCount) {
        $toDelete = $files[0..($files.Count - $KeepCount - 1)]
        foreach ($f in $toDelete) {
            Remove-Item $f.FullName -Force
            Write-Log "Eski yedek silindi ($FolderPath): $($f.Name)"
        }
    }
}

function Stop-NetsimProcess {
    param($Config)
    $procName = [System.IO.Path]::GetFileNameWithoutExtension($Config.ProcessExePath)
    $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
    $wasRunning = [bool]$procs
    if ($procs) {
        foreach ($p in $procs) {
            Write-Log "Program kapatiliyor: $($p.ProcessName) (PID $($p.Id))"
            $p.CloseMainWindow() | Out-Null
        }
        Start-Sleep -Seconds 5
        $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($procs) {
            $procs | Stop-Process -Force
            Write-Log "Program kapanmadigi icin zorla sonlandirildi."
        }
    }

    if ($Config.FirebirdServiceName) {
        $svc = Get-Service -Name $Config.FirebirdServiceName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq "Running") {
            Write-Log "Firebird servisi durduruluyor: $($Config.FirebirdServiceName)"
            Stop-Service -Name $Config.FirebirdServiceName -Force
        }
    }

    return $wasRunning
}

function Start-NetsimProcess {
    param($Config)
    if ($Config.FirebirdServiceName) {
        $svc = Get-Service -Name $Config.FirebirdServiceName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne "Running") {
            Write-Log "Firebird servisi yeniden baslatiliyor: $($Config.FirebirdServiceName)"
            Start-Service -Name $Config.FirebirdServiceName
        }
    }
    if (Test-Path $Config.ProcessExePath) {
        Start-Process -FilePath $Config.ProcessExePath
        Write-Log "Program yeniden baslatildi: $($Config.ProcessExePath)"
    } else {
        Write-Log "UYARI: Program exe bulunamadi: $($Config.ProcessExePath)" "WARN"
    }
}
