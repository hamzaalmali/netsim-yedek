. (Join-Path $PSScriptRoot "Common.ps1")
. (Join-Path $PSScriptRoot "Backup-Engine.ps1")

Write-Log "Netsim Yedekleme Servisi baslatildi."

while ($true) {
    try {
        $Config = Get-Config
        $now = Get-Date
        $todayStr = $now.ToString("yyyy-MM-dd")
        $nowStr = $now.ToString("HH:mm")

        if ($nowStr -eq $Config.BackupTime -and $Config.LastRunDate -ne $todayStr) {
            Start-NetsimBackup
        }
    } catch {
        Write-Log "Servis dongusu hatasi: $($_.Exception.Message)" "ERROR"
    }
    Start-Sleep -Seconds 30
}
