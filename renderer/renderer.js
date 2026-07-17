let extraDestinations = [];
let backupTimes = ['23:30'];

function $(id) {
  return document.getElementById(id);
}

function renderTimesList() {
  const container = $('timesList');
  container.innerHTML = '';
  backupTimes.forEach((t, idx) => {
    const row = document.createElement('div');
    row.className = 'time-item';

    const label = document.createElement('span');
    label.textContent = `${idx + 1}. yedek saati`;

    const input = document.createElement('input');
    input.type = 'time';
    input.className = 'input input-sm';
    input.value = t || '23:30';
    input.addEventListener('change', () => {
      backupTimes[idx] = input.value;
    });

    row.appendChild(label);
    row.appendChild(input);
    container.appendChild(row);
  });
}

function syncBackupTimesCount(count) {
  count = Math.max(1, Math.min(10, count || 1));
  while (backupTimes.length < count) backupTimes.push('23:30');
  backupTimes.length = count;
  renderTimesList();
}

function showToast(message, type = '') {
  const toast = $('toast');
  toast.textContent = message;
  toast.className = 'toast visible' + (type ? ' ' + type : '');
  clearTimeout(showToast._t);
  showToast._t = setTimeout(() => {
    toast.className = 'toast';
  }, type === 'error' ? 9000 : 3500);
}

function renderExtraList() {
  const container = $('extraList');
  container.innerHTML = '';
  if (!extraDestinations.length) {
    container.innerHTML = '<div class="hint" style="margin:0;">Henuz ek konum eklenmedi.</div>';
    return;
  }
  extraDestinations.forEach((dest, idx) => {
    const row = document.createElement('div');
    row.className = 'extra-item';

    const toggleLabel = document.createElement('label');
    toggleLabel.className = 'toggle';
    const cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.checked = dest.enabled;
    cb.addEventListener('change', () => {
      extraDestinations[idx].enabled = cb.checked;
    });
    const slider = document.createElement('span');
    slider.className = 'slider';
    toggleLabel.appendChild(cb);
    toggleLabel.appendChild(slider);

    const span = document.createElement('span');
    span.textContent = dest.path;

    const removeBtn = document.createElement('button');
    removeBtn.textContent = 'Kaldir';
    removeBtn.addEventListener('click', () => {
      extraDestinations.splice(idx, 1);
      renderExtraList();
    });

    row.appendChild(toggleLabel);
    row.appendChild(span);
    row.appendChild(removeBtn);
    container.appendChild(row);
  });
}

function setDriveFieldsEnabled(enabled) {
  $('driveFields').style.opacity = enabled ? '1' : '0.45';
  $('driveFields')
    .querySelectorAll('input, button')
    .forEach((el) => (el.disabled = !enabled));
}

function setEmailFieldsEnabled(enabled) {
  $('emailFields').style.opacity = enabled ? '1' : '0.45';
  $('emailFields')
    .querySelectorAll('input, button')
    .forEach((el) => (el.disabled = !enabled));
}

function setDriveStatus(connected) {
  const el = $('driveStatus');
  el.textContent = connected ? 'Durum: Bir Google hesabina bagli.' : 'Durum: Henuz bagli degil.';
  el.className = 'status-line ' + (connected ? 'ok' : 'warn');

  $('driveCredFields').style.display = connected ? 'none' : '';
  $('btnConnectDrive').style.display = connected ? 'none' : '';
  $('btnTestDrive').style.display = connected ? '' : 'none';
}

async function loadRunningApps(selectedPath) {
  const sel = $('selProcess');
  sel.innerHTML = '<option value="">-- Calisan uygulamalardan secin --</option>';
  const apps = await window.api.listRunningApps();
  apps.forEach((a) => {
    const opt = document.createElement('option');
    opt.value = a.path;
    opt.textContent = `${a.name} - ${a.title}`;
    if (a.path === selectedPath) opt.selected = true;
    sel.appendChild(opt);
  });
}

async function loadConfig() {
  const cfg = await window.api.getConfig();

  $('tbSource').value = cfg.sourcePath || '';
  $('tbExe').value = cfg.processExePath || '';
  $('tbFirebird').value = cfg.firebirdServiceName || '';
  backupTimes = cfg.backupTimes && cfg.backupTimes.length ? cfg.backupTimes.slice() : ['23:30'];
  $('numBackupCount').value = backupTimes.length;
  renderTimesList();
  $('chkRestart').checked = !!cfg.autoRestartAfterBackup;
  $('numRetention').value = cfg.retentionCount || 5;

  $('chkDrive').checked = !!cfg.googleDrive.enabled;
  $('tbDriveFolder').value = cfg.googleDrive.folderName || '';
  $('tbClientId').value = cfg.googleDrive.clientId || '';
  $('tbClientSecret').value = cfg.googleDrive.clientSecret || '';
  setDriveFieldsEnabled(cfg.googleDrive.enabled);
  setDriveStatus(cfg.googleDrive.connected);

  $('chkEmail').checked = !!cfg.email.enabled;
  $('tbSenderEmail').value = cfg.email.senderEmail || '';
  $('tbAppPassword').value = cfg.email.appPassword || '';
  $('tbRecipients').value = cfg.email.recipients || '';
  $('chkNotifySuccess').checked = cfg.email.notifyOnSuccess !== false;
  $('chkNotifyFailure').checked = cfg.email.notifyOnFailure !== false;
  setEmailFieldsEnabled(cfg.email.enabled);

  extraDestinations = (cfg.extraDestinations || []).map((d) => ({ ...d }));
  renderExtraList();

  $('lblLastRun').textContent = cfg.lastRunDate ? `Son yedek: ${cfg.lastRunDate}` : 'Henuz yedek alinmadi.';

  const autoStart = await window.api.getAutoStart();
  $('chkAutoStart').checked = autoStart;

  await loadRunningApps(cfg.processExePath);
}

async function checkForUpdate() {
  const info = await window.api.checkUpdate();
  if (info) {
    $('updateText').textContent = `Yeni bir surum mevcut: v${info.latestVersion} (su an v${info.currentVersion} kullaniyorsunuz).`;
    $('updateBanner').classList.add('visible');
    $('btnUpdateOpen').onclick = () => window.open(info.url, '_blank');
  } else {
    $('updateBanner').classList.remove('visible');
  }
}

function collectFormData() {
  return {
    sourcePath: $('tbSource').value,
    processExePath: $('tbExe').value,
    firebirdServiceName: $('tbFirebird').value,
    backupTimes: backupTimes.slice(),
    autoRestartAfterBackup: $('chkRestart').checked,
    retentionCount: parseInt($('numRetention').value, 10) || 5,
    extraDestinations,
    googleDrive: {
      enabled: $('chkDrive').checked,
      folderName: $('tbDriveFolder').value,
      clientId: $('tbClientId').value,
      clientSecret: $('tbClientSecret').value,
    },
    email: {
      enabled: $('chkEmail').checked,
      senderEmail: $('tbSenderEmail').value,
      appPassword: $('tbAppPassword').value,
      recipients: $('tbRecipients').value,
      notifyOnSuccess: $('chkNotifySuccess').checked,
      notifyOnFailure: $('chkNotifyFailure').checked,
    },
  };
}

function promptForText(title) {
  return new Promise((resolve) => {
    $('promptTitle').textContent = title;
    $('promptInput').value = '';
    $('promptOverlay').classList.add('visible');
    $('promptInput').focus();

    function cleanup(value) {
      $('promptOverlay').classList.remove('visible');
      $('promptOk').onclick = null;
      $('promptCancel').onclick = null;
      resolve(value);
    }
    $('promptOk').onclick = () => cleanup($('promptInput').value.trim());
    $('promptCancel').onclick = () => cleanup(null);
  });
}

function wireEvents() {
  $('btnBrowseSource').addEventListener('click', async () => {
    const folder = await window.api.browseFolder();
    if (folder) $('tbSource').value = folder;
  });

  $('btnBrowseExe').addEventListener('click', async () => {
    const file = await window.api.browseExe();
    if (file) $('tbExe').value = file;
  });

  $('btnRefreshProcesses').addEventListener('click', () => loadRunningApps($('tbExe').value));

  $('selProcess').addEventListener('change', () => {
    if ($('selProcess').value) $('tbExe').value = $('selProcess').value;
  });

  $('numBackupCount').addEventListener('input', () =>
    syncBackupTimesCount(parseInt($('numBackupCount').value, 10))
  );

  $('chkDrive').addEventListener('change', () => setDriveFieldsEnabled($('chkDrive').checked));
  $('chkEmail').addEventListener('change', () => setEmailFieldsEnabled($('chkEmail').checked));

  $('btnConnectDrive').addEventListener('click', async () => {
    const clientId = $('tbClientId').value.trim();
    const clientSecret = $('tbClientSecret').value.trim();
    if (!clientId || !clientSecret) {
      showToast('Once Client ID ve Client Secret alanlarini doldurun.', 'error');
      return;
    }
    showToast('Tarayicida Google hesabinizla giris yapin...');
    try {
      await window.api.connectDrive({ clientId, clientSecret });
      await loadConfig();
      showToast('Google Drive baglandi.', 'success');
    } catch (e) {
      showToast('Baglanti basarisiz: ' + e.message, 'error');
    }
  });

  $('btnTestDrive').addEventListener('click', async () => {
    await window.api.saveConfig(collectFormData());
    try {
      await window.api.testDrive();
      showToast('Baglanti basarili.', 'success');
    } catch (e) {
      showToast('Baglanti basarisiz: ' + e.message, 'error');
    }
  });

  $('btnDisconnectDrive').addEventListener('click', async () => {
    await window.api.disconnectDrive();
    await loadConfig();
    showToast('Baglanti kaldirildi.');
  });

  $('btnTestEmail').addEventListener('click', async () => {
    const formData = collectFormData();
    if (!formData.email.senderEmail || !formData.email.recipients) {
      showToast('Gonderen ve alici e-posta alanlarini doldurun.', 'error');
      return;
    }
    try {
      await window.api.testEmail(formData.email);
      showToast('Test e-postasi gonderildi.', 'success');
    } catch (e) {
      showToast('E-posta gonderilemedi: ' + e.message, 'error');
    }
  });

  $('btnAddFolder').addEventListener('click', async () => {
    const folder = await window.api.browseFolder();
    if (folder) {
      extraDestinations.push({ path: folder, enabled: true });
      renderExtraList();
    }
  });

  $('btnAddNetwork').addEventListener('click', async () => {
    const path = await promptForText('Ag Yolu Ekle');
    if (path) {
      extraDestinations.push({ path, enabled: true });
      renderExtraList();
    }
  });

  $('chkAutoStart').addEventListener('change', async () => {
    await window.api.setAutoStart($('chkAutoStart').checked);
  });

  $('btnBackupNow').addEventListener('click', async () => {
    await window.api.backupNow();
    showToast('Yedekleme arka planda baslatildi.');
  });

  $('btnSave').addEventListener('click', async () => {
    const timeRe = /^([01]\d|2[0-3]):[0-5]\d$/;
    if (!backupTimes.length || backupTimes.some((t) => !timeRe.test(t))) {
      showToast('Gecerli yedekleme saatleri secin.', 'error');
      return;
    }
    const hasExtra = extraDestinations.some((d) => d.enabled);
    if (!$('chkDrive').checked && !hasExtra) {
      showToast('En az bir yedekleme hedefi secmelisiniz (Google Drive veya ek konum).', 'error');
      return;
    }
    await window.api.saveConfig(collectFormData());
    showToast('Ayarlar kaydedildi.', 'success');
  });

  window.api.onRefreshRequest(() => {
    loadConfig();
    checkForUpdate();
  });

  window.api.onBackupFinished((result) => {
    loadConfig();
    if (result.skipped) {
      showToast('Veri degismedi, yedekleme atlandi.');
    } else {
      showToast(result.success ? 'Yedekleme tamamlandi.' : 'Yedekleme basarisiz oldu.', result.success ? 'success' : 'error');
    }
  });
}

async function init() {
  const version = await window.api.getVersion();
  $('lblVersion').textContent = 'v' + version;
  wireEvents();
  await loadConfig();
  await checkForUpdate();
}

init();
