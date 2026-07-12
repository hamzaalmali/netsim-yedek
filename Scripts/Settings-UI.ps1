Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

. (Join-Path $PSScriptRoot "Common.ps1")

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
        GoogleDrive            = [PSCustomObject]@{ Enabled = $true; FolderName = "Netsim Yedekler"; FolderId = ""; ClientId = ""; ClientSecretEncrypted = "" }
        LastRunDate            = ""
    }
}

$Config = Get-OrDefaultConfig

$form = New-Object System.Windows.Forms.Form
$form.Text = "Netsim Yedekleme Ayarlari"
$form.Size = New-Object System.Drawing.Size(640, 720)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$y = 15

function New-FormLabel($text, $yPos) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $text
    $lbl.Location = New-Object System.Drawing.Point(20, $yPos)
    $lbl.AutoSize = $true
    $form.Controls.Add($lbl)
}

function New-FormTextBox($text, $yPos, $width = 380) {
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Text = $text
    $tb.Location = New-Object System.Drawing.Point(20, $yPos)
    $tb.Width = $width
    $form.Controls.Add($tb)
    return $tb
}

New-FormLabel "Veri klasoru (fdb dosyalarinin oldugu yer):" $y
$y += 20
$tbSource = New-FormTextBox $Config.SourcePath $y
$y += 32

New-FormLabel "Ofisnet.exe yolu:" $y
$y += 20
$tbExe = New-FormTextBox $Config.ProcessExePath $y
$y += 32

New-FormLabel "Firebird Windows servis adi (varsa; yoksa bos birakin):" $y
$y += 20
$tbFirebird = New-FormTextBox $Config.FirebirdServiceName $y 250
$y += 32

New-FormLabel "Gunluk yedekleme saati (SS:dd):" $y
$y += 20
$tbTime = New-FormTextBox $Config.BackupTime $y 100
$y += 32

$chkRestart = New-Object System.Windows.Forms.CheckBox
$chkRestart.Text = "Yedekten sonra programi otomatik yeniden baslat"
$chkRestart.Location = New-Object System.Drawing.Point(20, $y)
$chkRestart.AutoSize = $true
$chkRestart.Checked = [bool]$Config.AutoRestartAfterBackup
$form.Controls.Add($chkRestart)
$y += 28

New-FormLabel "Saklanacak yedek sayisi (rotasyon, hem Drive hem ek konumlar icin):" $y
$y += 20
$numRetention = New-Object System.Windows.Forms.NumericUpDown
$numRetention.Location = New-Object System.Drawing.Point(20, $y)
$numRetention.Minimum = 1
$numRetention.Maximum = 365
$numRetention.Value = [int]$Config.RetentionCount
$form.Controls.Add($numRetention)
$y += 36

$chkDrive = New-Object System.Windows.Forms.CheckBox
$chkDrive.Text = "Google Drive'a yukle"
$chkDrive.Location = New-Object System.Drawing.Point(20, $y)
$chkDrive.AutoSize = $true
$chkDrive.Checked = [bool]$Config.GoogleDrive.Enabled
$form.Controls.Add($chkDrive)
$y += 28

New-FormLabel "Drive klasor adi:" $y
$y += 20
$tbDriveFolder = New-FormTextBox $Config.GoogleDrive.FolderName $y 250
$y += 32

New-FormLabel "Google Drive Client ID:" $y
$y += 20
$tbClientId = New-FormTextBox $Config.GoogleDrive.ClientId $y 380
$y += 32

New-FormLabel "Google Drive Client Secret:" $y
$y += 20
$existingSecret = ""
if ($Config.GoogleDrive.ClientSecretEncrypted) {
    try { $existingSecret = Unprotect-StringLocalMachine -EncodedText $Config.GoogleDrive.ClientSecretEncrypted } catch { $existingSecret = "" }
}
$tbClientSecret = New-FormTextBox $existingSecret $y 380
$tbClientSecret.PasswordChar = '*'
$y += 32

$lblDriveStatus = New-Object System.Windows.Forms.Label
$lblDriveStatus.Text = if (Test-Path $TokenPath) { "Durum: Bir Google hesabina bagli." } else { "Durum: Henuz bagli degil." }
$lblDriveStatus.Location = New-Object System.Drawing.Point(20, $y)
$lblDriveStatus.AutoSize = $true
$form.Controls.Add($lblDriveStatus)
$y += 22

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
$btnConnect.Location = New-Object System.Drawing.Point(20, $y)
$btnConnect.AutoSize = $true
$btnConnect.Add_Click({
    if (-not $tbClientId.Text -or -not $tbClientSecret.Text) {
        [System.Windows.Forms.MessageBox]::Show("Once Client ID ve Client Secret alanlarini doldurun.", "Eksik Bilgi") | Out-Null
        return
    }
    Sync-ConfigFromForm
    Save-Config -Config $Config
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $PSScriptRoot 'Connect-GoogleDrive.ps1')`"" -Wait
    $lblDriveStatus.Text = if (Test-Path $TokenPath) { "Durum: Bir Google hesabina bagli." } else { "Durum: Baglanti basarisiz oldu, yukaridaki pencereye bakin." }
    [System.Windows.Forms.MessageBox]::Show("Islem tamamlandi. Basarili olup olmadigini yukaridaki konsol penceresinde gorebilirsiniz.", "Bilgi") | Out-Null
})
$form.Controls.Add($btnConnect)

$btnTestConn = New-Object System.Windows.Forms.Button
$btnTestConn.Text = "Baglantiyi Test Et"
$btnTestConn.Location = New-Object System.Drawing.Point(180, $y)
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
$form.Controls.Add($btnTestConn)

$btnDisconnect = New-Object System.Windows.Forms.Button
$btnDisconnect.Text = "Hesabi Degistir"
$btnDisconnect.Location = New-Object System.Drawing.Point(320, $y)
$btnDisconnect.AutoSize = $true
$btnDisconnect.Add_Click({
    $confirm = [System.Windows.Forms.MessageBox]::Show("Mevcut Google hesabi baglantisi kaldirilsin mi? Sonra 'Google Drive'a Bagla' ile farkli bir hesap secebilirsiniz.", "Onay", "YesNo")
    if ($confirm -eq "Yes") {
        Remove-RefreshToken
        $Config.GoogleDrive.FolderId = ""
        Save-Config -Config $Config
        $lblDriveStatus.Text = "Durum: Henuz bagli degil."
        [System.Windows.Forms.MessageBox]::Show("Baglanti kaldirildi.", "Bilgi") | Out-Null
    }
})
$form.Controls.Add($btnDisconnect)
$y += 36

New-FormLabel "Ek yedekleme konumlari (yerel klasor veya ag yolu, opsiyonel):" $y
$y += 20
$listExtra = New-Object System.Windows.Forms.CheckedListBox
$listExtra.Location = New-Object System.Drawing.Point(20, $y)
$listExtra.Size = New-Object System.Drawing.Size(380, 80)
foreach ($dest in $Config.ExtraDestinations) {
    $idx = $listExtra.Items.Add($dest.Path)
    $listExtra.SetItemChecked($idx, [bool]$dest.Enabled)
}
$form.Controls.Add($listExtra)

$btnAddDest = New-Object System.Windows.Forms.Button
$btnAddDest.Text = "Klasor Ekle"
$btnAddDest.Location = New-Object System.Drawing.Point(410, $y)
$btnAddDest.Width = 110
$btnAddDest.Add_Click({
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($folderDialog.ShowDialog() -eq "OK") {
        $idx = $listExtra.Items.Add($folderDialog.SelectedPath)
        $listExtra.SetItemChecked($idx, $true)
    }
})
$form.Controls.Add($btnAddDest)

$btnAddNetworkDest = New-Object System.Windows.Forms.Button
$btnAddNetworkDest.Text = "Ag Yolu Ekle"
$btnAddNetworkDest.Location = New-Object System.Drawing.Point(410, ($y + 25))
$btnAddNetworkDest.Width = 110
$btnAddNetworkDest.Add_Click({
    $path = [Microsoft.VisualBasic.Interaction]::InputBox("Ag yolunu girin (orn. \\SUNUCU\Paylasim\Yedekler):", "Ag Yolu Ekle", "")
    if ($path) {
        $idx = $listExtra.Items.Add($path)
        $listExtra.SetItemChecked($idx, $true)
    }
})
$form.Controls.Add($btnAddNetworkDest)
Add-Type -AssemblyName Microsoft.VisualBasic

$btnRemoveDest = New-Object System.Windows.Forms.Button
$btnRemoveDest.Text = "Kaldir"
$btnRemoveDest.Location = New-Object System.Drawing.Point(410, ($y + 50))
$btnRemoveDest.Width = 110
$btnRemoveDest.Add_Click({
    if ($listExtra.SelectedIndex -ge 0) { $listExtra.Items.RemoveAt($listExtra.SelectedIndex) }
})
$form.Controls.Add($btnRemoveDest)
$y += 100

$btnTest = New-Object System.Windows.Forms.Button
$btnTest.Text = "Simdi Yedekle (Test)"
$btnTest.Location = New-Object System.Drawing.Point(20, $y)
$btnTest.AutoSize = $true
$btnTest.Add_Click({
    $btnTest.Enabled = $false
    $btnTest.Text = "Yedekleniyor, bekleyin..."
    [System.Windows.Forms.Application]::DoEvents()
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $PSScriptRoot 'Backup-Engine.ps1')`"" -Wait -WindowStyle Hidden
    $btnTest.Enabled = $true
    $btnTest.Text = "Simdi Yedekle (Test)"
    [System.Windows.Forms.MessageBox]::Show("Yedekleme tamamlandi. Detaylar icin Logs klasorune bakabilirsiniz.", "Bilgi") | Out-Null
})
$form.Controls.Add($btnTest)
$y += 40

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Kaydet"
$btnSave.Location = New-Object System.Drawing.Point(20, $y)
$btnSave.Width = 100
$btnSave.Add_Click({
    if ($tbTime.Text -notmatch '^\d{2}:\d{2}$') {
        [System.Windows.Forms.MessageBox]::Show("Saat SS:dd formatinda olmali, ornek: 23:30", "Hata") | Out-Null
        return
    }
    Sync-ConfigFromForm
    Save-Config -Config $Config
    [System.Windows.Forms.MessageBox]::Show("Ayarlar kaydedildi.", "Bilgi") | Out-Null
})
$form.Controls.Add($btnSave)

$form.ShowDialog() | Out-Null
