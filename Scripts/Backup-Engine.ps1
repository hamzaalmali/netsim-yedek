. (Join-Path $PSScriptRoot "Common.ps1")

function Start-NetsimBackup {
    try {
        Write-Log "===== Yedekleme basladi ====="
        $Config = Get-Config

        $wasRunning = Stop-NetsimProcess -Config $Config

        if (-not (Test-Path $StagingDir)) { New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null }
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
        $zipName = "NetsimYedek_$timestamp.zip"
        $zipPath = Join-Path $StagingDir $zipName

        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        Compress-Archive -Path (Join-Path $Config.SourcePath "*") -DestinationPath $zipPath -CompressionLevel Optimal
        Write-Log "Yedek arsivi olusturuldu: $zipPath"

        if ($wasRunning -and $Config.AutoRestartAfterBackup) {
            Start-NetsimProcess -Config $Config
        }

        if ($Config.GoogleDrive.Enabled) {
            $accessToken = Get-GoogleAccessToken -Config $Config
            $folderId = $Config.GoogleDrive.FolderId
            if (-not $folderId) {
                $folderId = Get-OrCreateDriveFolder -AccessToken $accessToken -FolderName $Config.GoogleDrive.FolderName
                $Config.GoogleDrive.FolderId = $folderId
                Save-Config -Config $Config
            }
            Invoke-DriveUpload -AccessToken $accessToken -FilePath $zipPath -FolderId $folderId | Out-Null
            Write-Log "Yedek Google Drive'a yuklendi (klasor: $($Config.GoogleDrive.FolderName))."
            Remove-OldDriveBackups -AccessToken $accessToken -FolderId $folderId -KeepCount $Config.RetentionCount
        }

        foreach ($dest in $Config.ExtraDestinations) {
            if ($dest.Enabled) {
                try {
                    if (-not (Test-Path $dest.Path)) { New-Item -ItemType Directory -Path $dest.Path -Force | Out-Null }
                    Copy-Item -Path $zipPath -Destination $dest.Path -Force
                    Write-Log "Yedek ek konuma kopyalandi: $($dest.Path)"
                    Remove-OldLocalBackups -FolderPath $dest.Path -KeepCount $Config.RetentionCount
                } catch {
                    Write-Log "HATA (ek konum $($dest.Path)): $($_.Exception.Message)" "ERROR"
                }
            }
        }

        Remove-OldLocalBackups -FolderPath $StagingDir -KeepCount $Config.RetentionCount

        $Config.LastRunDate = (Get-Date -Format "yyyy-MM-dd")
        Save-Config -Config $Config

        Write-Log "===== Yedekleme tamamlandi ====="
    } catch {
        Write-Log "HATA: $($_.Exception.Message)" "ERROR"
        Write-Log $_.ScriptStackTrace "ERROR"
    }
}

# Dogrudan calistirilirsa hemen yedekle; Service-Loop.ps1 tarafindan dot-source edilirse
# sadece fonksiyonu tanimla, otomatik calistirma.
if ($MyInvocation.InvocationName -ne '.') {
    Start-NetsimBackup
}
