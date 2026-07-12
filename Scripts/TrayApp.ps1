Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

. (Join-Path $PSScriptRoot "Common.ps1")

$AppVersion = "1.0.0"
$versionFile = Join-Path $RootDir "VERSION.txt"
if (Test-Path $versionFile) { $AppVersion = (Get-Content $versionFile -Raw).Trim() }

$RepoRawVersionUrl = "https://raw.githubusercontent.com/hamzaalmali/netsim-yedek/main/VERSION.txt"
$RepoPageUrl = "https://github.com/hamzaalmali/netsim-yedek"

function New-AppIcon {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 37, 99, 235))
    $g.FillEllipse($brush, 0, 0, 31, 31)
    $font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
    $rect = New-Object System.Drawing.RectangleF 0, 0, 32, 32
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString("N", $font, [System.Drawing.Brushes]::White, $rect, $sf)
    $g.Dispose()
    return [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}

$appIcon = New-AppIcon

function Get-OrDefaultConfig {
    if (Test-Path $ConfigPath) { return Get-Config }
    return [PSCustomObject]@{
        SourcePath             = "E:\Ofisnet\Data"
        ProcessExePath         = "E:\Ofisnet\Bin\Ofisnet.exe"
        FirebirdServiceName    = ""
        BackupTime             = "23:30"
        AutoRestartAfterBackup = $true
        RetentionCount         = 5
        ExtraDestinations      = @()
        GoogleDrive            = [PSCustomObject]@{ Enabled = $false; FolderName = "Netsim Yedekler"; FolderId = ""; ClientId = ""; ClientSecretEncrypted = "" }
        LastRunDate            = ""
    }
}

$isFirstRun = -not (Test-Path $ConfigPath)
$Config = Get-OrDefaultConfig

function Get-LauncherPath { Join-Path $RootDir "Netsim-Yedekleme-Baslat.vbs" }
function Get-StartupShortcutPath { Join-Path ([Environment]::GetFolderPath("Startup")) "Netsim Yedekleme.lnk" }

function Set-AutoStart {
    param([bool]$Enabled)
    $shortcutPath = Get-StartupShortcutPath
    if ($Enabled) {
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = Get-LauncherPath
        $shortcut.WorkingDirectory = $RootDir
        $shortcut.Description = "Netsim Yedekleme"
        $shortcut.Save()
    } elseif (Test-Path $shortcutPath) {
        Remove-Item $shortcutPath -Force
    }
}

# ===================== Form =====================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Netsim Yedekleme"
$form.Icon = $appIcon
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$form.Size = New-Object System.Drawing.Size(730, 760)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::White

function New-Section {
    param([string]$Title)
    $gb = New-Object System.Windows.Forms.GroupBox
    $gb.Text = $Title
    $gb.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    $gb.Width = 650
    return $gb
}

function Add-Lbl {
    param($Parent, [string]$Text, [int]$X, [int]$Y)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text
    $lbl.Location = New-Object System.Drawing.Point($X, $Y)
    $lbl.AutoSize = $true
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $Parent.Controls.Add($lbl)
    return $lbl
}

function Add-Txt {
    param($Parent, [string]$Text, [int]$X, [int]$Y, [int]$Width = 480)
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Text = $Text
    $tb.Location = New-Object System.Drawing.Point($X, $Y)
    $tb.Width = $Width
    $Parent.Controls.Add($tb)
    return $tb
}

function Style-PrimaryButton {
    param($Button)
    $Button.FlatStyle = "Flat"
    $Button.FlatAppearance.BorderSize = 0
    $Button.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
    $Button.ForeColor = [System.Drawing.Color]::White
    $Button.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    $Button.Height = 32
}

# ---- Header ----
$pnlHeader = New-Object System.Windows.Forms.Panel
$pnlHeader.Dock = "Top"
$pnlHeader.Height = 55
$pnlHeader.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 251)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Netsim Yedekleme"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
$lblTitle.Location = New-Object System.Drawing.Point(20, 13)
$lblTitle.AutoSize = $true
$pnlHeader.Controls.Add($lblTitle)

$lblVersion = New-Object System.Windows.Forms.Label
$lblVersion.Text = "v$AppVersion"
$lblVersion.ForeColor = [System.Drawing.Color]::Gray
$lblVersion.Location = New-Object System.Drawing.Point(600, 20)
$lblVersion.AutoSize = $true
$pnlHeader.Controls.Add($lblVersion)

$form.Controls.Add($pnlHeader)

# ---- Update banner ----
$pnlUpdate = New-Object System.Windows.Forms.Panel
$pnlUpdate.Dock = "Top"
$pnlUpdate.Height = 40
$pnlUpdate.BackColor = [System.Drawing.Color]::FromArgb(255, 244, 214)
$pnlUpdate.Visible = $false

$lblUpdate = New-Object System.Windows.Forms.Label
$lblUpdate.Text = "Yeni bir surum mevcut."
$lblUpdate.Location = New-Object System.Drawing.Point(20, 11)
$lblUpdate.AutoSize = $true
$lblUpdate.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$pnlUpdate.Controls.Add($lblUpdate)

$btnUpdateOpen = New-Object System.Windows.Forms.Button
$btnUpdateOpen.Text = "GitHub'da Ac"
$btnUpdateOpen.Location = New-Object System.Drawing.Point(540, 6)
$btnUpdateOpen.Width = 110
$btnUpdateOpen.Add_Click({ Start-Process $RepoPageUrl })
$pnlUpdate.Controls.Add($btnUpdateOpen)

$form.Controls.Add($pnlUpdate)

function Test-ForUpdateAndShowBanner {
    try {
        $remoteVersion = (Invoke-RestMethod -Uri $RepoRawVersionUrl -TimeoutSec 5).ToString().Trim()
        if ($remoteVersion -and $remoteVersion -ne $AppVersion) {
            $lblUpdate.Text = "Yeni bir surum mevcut: v$remoteVersion (su an v$AppVersion kullaniyorsunuz)."
            $pnlUpdate.Visible = $true
        } else {
            $pnlUpdate.Visible = $false
        }
    } catch {
        # Internet yoksa veya GitHub'a erisilemiyorsa sessizce gec.
    }
}

# ---- Body (scrollable) ----
$pnlBody = New-Object System.Windows.Forms.Panel
$pnlBody.Dock = "Fill"
$pnlBody.AutoScroll = $true
$pnlBody.Padding = New-Object System.Windows.Forms.Padding(15)
$form.Controls.Add($pnlBody)

$bodyY = 10

# --- Program ve Veri ---
$gbGeneral = New-Section "Program ve Veri"
$iy = 25
Add-Lbl $gbGeneral "Veri klasoru (yedeklenecek fdb dosyalarinin oldugu yer):" 15 $iy | Out-Null
$iy += 20
$tbSource = Add-Txt $gbGeneral $Config.SourcePath 15 $iy 400
$tbSource.ReadOnly = $true
$btnBrowseSource = New-Object System.Windows.Forms.Button
$btnBrowseSource.Text = "Goz At..."
$btnBrowseSource.Location = New-Object System.Drawing.Point(425, $iy)
$btnBrowseSource.Width = 80
$btnBrowseSource.Add_Click({
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Yedeklenecek veri klasorunu secin"
    if ($tbSource.Text -and (Test-Path $tbSource.Text)) { $folderDialog.SelectedPath = $tbSource.Text }
    if ($folderDialog.ShowDialog() -eq "OK") { $tbSource.Text = $folderDialog.SelectedPath }
})
$gbGeneral.Controls.Add($btnBrowseSource)
$iy += 32
Add-Lbl $gbGeneral "Ofisnet.exe yolu:" 15 $iy | Out-Null
$iy += 20
$tbExe = Add-Txt $gbGeneral $Config.ProcessExePath 15 $iy 400
$tbExe.ReadOnly = $true
$btnBrowseExe = New-Object System.Windows.Forms.Button
$btnBrowseExe.Text = "Goz At..."
$btnBrowseExe.Location = New-Object System.Drawing.Point(425, $iy)
$btnBrowseExe.Width = 80
$btnBrowseExe.Add_Click({
    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.Filter = "Uygulamalar (*.exe)|*.exe|Tum dosyalar (*.*)|*.*"
    $fileDialog.Title = "Ofisnet.exe dosyasini secin"
    if ($tbExe.Text -and (Test-Path $tbExe.Text)) { $fileDialog.InitialDirectory = Split-Path -Parent $tbExe.Text }
    if ($fileDialog.ShowDialog() -eq "OK") { $tbExe.Text = $fileDialog.FileName }
})
$gbGeneral.Controls.Add($btnBrowseExe)
$iy += 32
Add-Lbl $gbGeneral "Firebird Windows servis adi (varsa; yoksa bos birakin):" 15 $iy | Out-Null
$iy += 20
$tbFirebird = Add-Txt $gbGeneral $Config.FirebirdServiceName 15 $iy 300
$iy += 32
$gbGeneral.Height = $iy + 10
$gbGeneral.Location = New-Object System.Drawing.Point(15, $bodyY)
$pnlBody.Controls.Add($gbGeneral)
$bodyY += $gbGeneral.Height + 15

# --- Zamanlama ---
$gbSchedule = New-Section "Zamanlama"
$iy = 25
Add-Lbl $gbSchedule "Gunluk yedekleme saati (SS:dd):" 15 $iy | Out-Null
$iy += 20
$tbTime = Add-Txt $gbSchedule $Config.BackupTime 15 $iy 100
$iy += 32
$chkRestart = New-Object System.Windows.Forms.CheckBox
$chkRestart.Text = "Yedekten sonra programi otomatik yeniden baslat"
$chkRestart.Location = New-Object System.Drawing.Point(15, $iy)
$chkRestart.AutoSize = $true
$chkRestart.Checked = [bool]$Config.AutoRestartAfterBackup
$gbSchedule.Controls.Add($chkRestart)
$iy += 28
Add-Lbl $gbSchedule "Saklanacak yedek sayisi (rotasyon, hem Drive hem ek konumlar icin):" 15 $iy | Out-Null
$iy += 20
$numRetention = New-Object System.Windows.Forms.NumericUpDown
$numRetention.Location = New-Object System.Drawing.Point(15, $iy)
$numRetention.Minimum = 1
$numRetention.Maximum = 365
$numRetention.Value = [int]$Config.RetentionCount
$gbSchedule.Controls.Add($numRetention)
$iy += 36
$gbSchedule.Height = $iy + 10
$gbSchedule.Location = New-Object System.Drawing.Point(15, $bodyY)
$pnlBody.Controls.Add($gbSchedule)
$bodyY += $gbSchedule.Height + 15

# --- Google Drive ---
$gbDrive = New-Section "Google Drive (opsiyonel)"
$iy = 25
$chkDrive = New-Object System.Windows.Forms.CheckBox
$chkDrive.Text = "Yedekleri Google Drive'a da yukle"
$chkDrive.Location = New-Object System.Drawing.Point(15, $iy)
$chkDrive.AutoSize = $true
$chkDrive.Checked = [bool]$Config.GoogleDrive.Enabled
$gbDrive.Controls.Add($chkDrive)
$iy += 28
Add-Lbl $gbDrive "Drive klasor adi:" 15 $iy | Out-Null
$iy += 20
$tbDriveFolder = Add-Txt $gbDrive $Config.GoogleDrive.FolderName 15 $iy 300
$iy += 32
Add-Lbl $gbDrive "Google Drive Client ID:" 15 $iy | Out-Null
$iy += 20
$tbClientId = Add-Txt $gbDrive $Config.GoogleDrive.ClientId 15 $iy 480
$iy += 32
Add-Lbl $gbDrive "Google Drive Client Secret:" 15 $iy | Out-Null
$iy += 20
$existingSecret = ""
if ($Config.GoogleDrive.ClientSecretEncrypted) {
    try { $existingSecret = Unprotect-StringLocalMachine -EncodedText $Config.GoogleDrive.ClientSecretEncrypted } catch { $existingSecret = "" }
}
$tbClientSecret = Add-Txt $gbDrive $existingSecret 15 $iy 480
$tbClientSecret.PasswordChar = '*'
$iy += 32
$lblDriveStatus = New-Object System.Windows.Forms.Label
$lblDriveStatus.Text = if (Test-Path $TokenPath) { "Durum: Bir Google hesabina bagli." } else { "Durum: Henuz bagli degil." }
$lblDriveStatus.ForeColor = if (Test-Path $TokenPath) { [System.Drawing.Color]::FromArgb(22, 130, 60) } else { [System.Drawing.Color]::FromArgb(180, 83, 9) }
$lblDriveStatus.Location = New-Object System.Drawing.Point(15, $iy)
$lblDriveStatus.AutoSize = $true
$gbDrive.Controls.Add($lblDriveStatus)
$iy += 26

function Sync-ConfigFromForm {
    $Config.SourcePath = $tbSource.Text
    $Config.ProcessExePath = $tbExe.Text
    $Config.FirebirdServiceName = $tbFirebird.Text
    $Config.BackupTime = $tbTime.Text
    $Config.AutoRestartAfterBackup = $chkRestart.Checked
    $Config.RetentionCount = [int]$numRetention.Value
    $Config.GoogleDrive.Enabled = $chkDrive.Checked
    $Config.GoogleDrive.FolderName = $tbDriveFolder.Text
    $Config.GoogleDrive.ClientId = $tbClientId.Text
    if ($tbClientSecret.Text) {
        $Config.GoogleDrive.ClientSecretEncrypted = Protect-StringLocalMachine -PlainText $tbClientSecret.Text
    }
    $extraList = @()
    for ($i = 0; $i -lt $listExtra.Items.Count; $i++) {
        $extraList += [PSCustomObject]@{ Type = "Local"; Path = $listExtra.Items[$i]; Enabled = $listExtra.GetItemChecked($i) }
    }
    $Config.ExtraDestinations = $extraList
}

$btnConnect = New-Object System.Windows.Forms.Button
$btnConnect.Text = "Google Drive'a Bagla"
$btnConnect.Location = New-Object System.Drawing.Point(15, $iy)
$btnConnect.AutoSize = $true
$btnConnect.Add_Click({
    if (-not $tbClientId.Text -or -not $tbClientSecret.Text) {
        [System.Windows.Forms.MessageBox]::Show("Once Client ID ve Client Secret alanlarini doldurun.", "Eksik Bilgi") | Out-Null
        return
    }
    Sync-ConfigFromForm
    Save-Config -Config $Config
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $PSScriptRoot 'Connect-GoogleDrive.ps1')`"" -Wait
    $connected = Test-Path $TokenPath
    $lblDriveStatus.Text = if ($connected) { "Durum: Bir Google hesabina bagli." } else { "Durum: Baglanti basarisiz oldu, konsol penceresine bakin." }
    $lblDriveStatus.ForeColor = if ($connected) { [System.Drawing.Color]::FromArgb(22, 130, 60) } else { [System.Drawing.Color]::FromArgb(180, 83, 9) }
    [System.Windows.Forms.MessageBox]::Show("Islem tamamlandi.", "Bilgi") | Out-Null
})
$gbDrive.Controls.Add($btnConnect)

$btnTestConn = New-Object System.Windows.Forms.Button
$btnTestConn.Text = "Baglantiyi Test Et"
$btnTestConn.Location = New-Object System.Drawing.Point(190, $iy)
$btnTestConn.AutoSize = $true
$btnTestConn.Add_Click({
    Sync-ConfigFromForm
    Save-Config -Config $Config
    try {
        $accessToken = Get-GoogleAccessToken -Config $Config
        $folderId = Get-OrCreateDriveFolder -AccessToken $accessToken -FolderName $Config.GoogleDrive.FolderName
        $Config.GoogleDrive.FolderId = $folderId
        Save-Config -Config $Config
        [System.Windows.Forms.MessageBox]::Show("Baglanti basarili. Klasor hazir: $($Config.GoogleDrive.FolderName)", "Basarili") | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Baglanti basarisiz: $($_.Exception.Message)", "Hata") | Out-Null
    }
})
$gbDrive.Controls.Add($btnTestConn)

$btnDisconnect = New-Object System.Windows.Forms.Button
$btnDisconnect.Text = "Hesabi Degistir"
$btnDisconnect.Location = New-Object System.Drawing.Point(340, $iy)
$btnDisconnect.AutoSize = $true
$btnDisconnect.Add_Click({
    $confirm = [System.Windows.Forms.MessageBox]::Show("Mevcut Google hesabi baglantisi kaldirilsin mi?", "Onay", "YesNo")
    if ($confirm -eq "Yes") {
        Remove-RefreshToken
        $Config.GoogleDrive.FolderId = ""
        Save-Config -Config $Config
        $lblDriveStatus.Text = "Durum: Henuz bagli degil."
        $lblDriveStatus.ForeColor = [System.Drawing.Color]::FromArgb(180, 83, 9)
        [System.Windows.Forms.MessageBox]::Show("Baglanti kaldirildi.", "Bilgi") | Out-Null
    }
})
$gbDrive.Controls.Add($btnDisconnect)
$iy += 36

$driveControls = @($tbDriveFolder, $tbClientId, $tbClientSecret, $btnConnect, $btnTestConn, $btnDisconnect)
function Set-DriveControlsEnabled {
    param([bool]$Enabled)
    foreach ($c in $driveControls) { $c.Enabled = $Enabled }
}
Set-DriveControlsEnabled -Enabled $chkDrive.Checked
$chkDrive.Add_CheckedChanged({ Set-DriveControlsEnabled -Enabled $chkDrive.Checked })

$gbDrive.Height = $iy + 10
$gbDrive.Location = New-Object System.Drawing.Point(15, $bodyY)
$pnlBody.Controls.Add($gbDrive)
$bodyY += $gbDrive.Height + 15

# --- Ek Konumlar ---
$gbExtra = New-Section "Ek Yedekleme Konumlari (opsiyonel)"
$iy = 25
Add-Lbl $gbExtra "Yerel klasor veya ag yolu ekleyin:" 15 $iy | Out-Null
$iy += 20
$listExtra = New-Object System.Windows.Forms.CheckedListBox
$listExtra.Location = New-Object System.Drawing.Point(15, $iy)
$listExtra.Size = New-Object System.Drawing.Size(480, 80)
foreach ($dest in $Config.ExtraDestinations) {
    $idx = $listExtra.Items.Add($dest.Path)
    $listExtra.SetItemChecked($idx, [bool]$dest.Enabled)
}
$gbExtra.Controls.Add($listExtra)

$btnAddDest = New-Object System.Windows.Forms.Button
$btnAddDest.Text = "Klasor Ekle"
$btnAddDest.Location = New-Object System.Drawing.Point(505, $iy)
$btnAddDest.Width = 130
$btnAddDest.Add_Click({
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($folderDialog.ShowDialog() -eq "OK") {
        $idx = $listExtra.Items.Add($folderDialog.SelectedPath)
        $listExtra.SetItemChecked($idx, $true)
    }
})
$gbExtra.Controls.Add($btnAddDest)

$btnAddNetworkDest = New-Object System.Windows.Forms.Button
$btnAddNetworkDest.Text = "Ag Yolu Ekle"
$btnAddNetworkDest.Location = New-Object System.Drawing.Point(505, ($iy + 27))
$btnAddNetworkDest.Width = 130
$btnAddNetworkDest.Add_Click({
    $path = [Microsoft.VisualBasic.Interaction]::InputBox("Ag yolunu girin (orn. \\SUNUCU\Paylasim\Yedekler):", "Ag Yolu Ekle", "")
    if ($path) {
        $idx = $listExtra.Items.Add($path)
        $listExtra.SetItemChecked($idx, $true)
    }
})
$gbExtra.Controls.Add($btnAddNetworkDest)

$btnRemoveDest = New-Object System.Windows.Forms.Button
$btnRemoveDest.Text = "Kaldir"
$btnRemoveDest.Location = New-Object System.Drawing.Point(505, ($iy + 54))
$btnRemoveDest.Width = 130
$btnRemoveDest.Add_Click({
    if ($listExtra.SelectedIndex -ge 0) { $listExtra.Items.RemoveAt($listExtra.SelectedIndex) }
})
$gbExtra.Controls.Add($btnRemoveDest)
$iy += 90
$gbExtra.Height = $iy + 10
$gbExtra.Location = New-Object System.Drawing.Point(15, $bodyY)
$pnlBody.Controls.Add($gbExtra)
$bodyY += $gbExtra.Height + 15

# --- Windows ile baslat ---
$chkAutoStart = New-Object System.Windows.Forms.CheckBox
$chkAutoStart.Text = "Windows'a giriste otomatik baslat"
$chkAutoStart.Location = New-Object System.Drawing.Point(15, $bodyY)
$chkAutoStart.AutoSize = $true
$chkAutoStart.Checked = Test-Path (Get-StartupShortcutPath)
$chkAutoStart.Add_CheckedChanged({ Set-AutoStart -Enabled $chkAutoStart.Checked })
$pnlBody.Controls.Add($chkAutoStart)
$bodyY += 35

# ---- Bottom action bar ----
$pnlActions = New-Object System.Windows.Forms.Panel
$pnlActions.Dock = "Bottom"
$pnlActions.Height = 65
$pnlActions.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 251)

$lblLastRun = New-Object System.Windows.Forms.Label
$lblLastRun.Text = if ($Config.LastRunDate) { "Son yedek: $($Config.LastRunDate)" } else { "Henuz yedek alinmadi." }
$lblLastRun.ForeColor = [System.Drawing.Color]::Gray
$lblLastRun.Location = New-Object System.Drawing.Point(20, 24)
$lblLastRun.AutoSize = $true
$pnlActions.Controls.Add($lblLastRun)

$btnBackupNow = New-Object System.Windows.Forms.Button
$btnBackupNow.Text = "Simdi Yedekle"
$btnBackupNow.Location = New-Object System.Drawing.Point(400, 16)
$btnBackupNow.Width = 130
Style-PrimaryButton $btnBackupNow
$btnBackupNow.BackColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
$pnlActions.Controls.Add($btnBackupNow)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Kaydet"
$btnSave.Location = New-Object System.Drawing.Point(540, 16)
$btnSave.Width = 130
Style-PrimaryButton $btnSave
$btnSave.Add_Click({
    if ($tbTime.Text -notmatch '^\d{2}:\d{2}$') {
        [System.Windows.Forms.MessageBox]::Show("Saat SS:dd formatinda olmali, ornek: 23:30", "Hata") | Out-Null
        return
    }
    $hasExtra = $false
    for ($i = 0; $i -lt $listExtra.Items.Count; $i++) {
        if ($listExtra.GetItemChecked($i)) { $hasExtra = $true; break }
    }
    if (-not $chkDrive.Checked -and -not $hasExtra) {
        [System.Windows.Forms.MessageBox]::Show("En az bir yedekleme hedefi secmelisiniz: Google Drive'i isaretleyin veya Ek Yedekleme Konumlari listesine bir klasor/ag yolu ekleyip isaretleyin.", "Hedef Secilmedi") | Out-Null
        return
    }
    Sync-ConfigFromForm
    Save-Config -Config $Config
    [System.Windows.Forms.MessageBox]::Show("Ayarlar kaydedildi.", "Bilgi") | Out-Null
})
$pnlActions.Controls.Add($btnSave)

$form.Controls.Add($pnlActions)

# ===================== Tray & Scheduler =====================

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = $appIcon
$notifyIcon.Text = "Netsim Yedekleme"
$notifyIcon.Visible = $true

$script:backupInProgress = $false
$script:backupProcess = $null

function Start-BackupAsync {
    if ($script:backupInProgress) { return }
    $script:backupInProgress = $true
    $notifyIcon.ShowBalloonTip(2000, "Netsim Yedekleme", "Yedekleme basladi...", [System.Windows.Forms.ToolTipIcon]::Info)
    $script:backupProcess = Start-Process powershell -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$(Join-Path $PSScriptRoot 'Backup-Engine.ps1')`"" -PassThru -WindowStyle Hidden
}

$btnBackupNow.Add_Click({
    Start-BackupAsync
    [System.Windows.Forms.MessageBox]::Show("Yedekleme arka planda baslatildi. Tamamlandiginda bildirim gelecek.", "Bilgi") | Out-Null
})

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miOpen = $menu.Items.Add("Ayarlari Ac")
$miOpen.Add_Click({
    Test-ForUpdateAndShowBanner
    $form.Show()
    $form.WindowState = "Normal"
    $form.Activate()
})
$miBackupNow = $menu.Items.Add("Simdi Yedekle")
$miBackupNow.Add_Click({ Start-BackupAsync })
$menu.Items.Add("-") | Out-Null
$miExit = $menu.Items.Add("Cikis")
$miExit.Add_Click({
    $script:allowExit = $true
    $timer.Stop()
    $notifyIcon.Visible = $false
    $form.Close()
    [System.Windows.Forms.Application]::Exit()
})
$notifyIcon.ContextMenuStrip = $menu
$notifyIcon.Add_DoubleClick({
    Test-ForUpdateAndShowBanner
    $form.Show()
    $form.WindowState = "Normal"
    $form.Activate()
})

$script:allowExit = $false
$form.Add_FormClosing({
    param($s, $e)
    if (-not $script:allowExit) {
        $e.Cancel = $true
        $form.Hide()
        $notifyIcon.ShowBalloonTip(1500, "Netsim Yedekleme", "Uygulama sistem tepsisinde calismaya devam ediyor.", [System.Windows.Forms.ToolTipIcon]::Info)
    }
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 30000
$timer.Add_Tick({
    try {
        if ($script:backupInProgress -and $script:backupProcess -and $script:backupProcess.HasExited) {
            $script:backupInProgress = $false
            $notifyIcon.ShowBalloonTip(3000, "Netsim Yedekleme", "Yedekleme tamamlandi.", [System.Windows.Forms.ToolTipIcon]::Info)
            $refreshed = Get-Config
            $lblLastRun.Text = if ($refreshed.LastRunDate) { "Son yedek: $($refreshed.LastRunDate)" } else { "Henuz yedek alinmadi." }
        }
        if (-not $script:backupInProgress) {
            $cfg = Get-Config
            $now = Get-Date
            if ($now.ToString("HH:mm") -eq $cfg.BackupTime -and $cfg.LastRunDate -ne $now.ToString("yyyy-MM-dd")) {
                Start-BackupAsync
            }
        }
    } catch {
    }
})
$timer.Start()

if ($isFirstRun) {
    $form.Show()
} else {
    Test-ForUpdateAndShowBanner
}

[System.Windows.Forms.Application]::Run()
