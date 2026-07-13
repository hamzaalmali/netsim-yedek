const { app, BrowserWindow, Tray, Menu, ipcMain, dialog, nativeImage } = require('electron');
const path = require('path');
const fs = require('fs');
const configModule = require('./config');
const driveAuth = require('./googleDrive');
const processes = require('./processes');
const { runBackup } = require('./backup');

const REPO = 'hamzaalmali/netsim-yedek';

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  let mainWindow = null;
  let tray = null;
  let isQuitting = false;
  let backupInProgress = false;
  let schedulerTimer = null;

  const userDataDir = () => app.getPath('userData');
  const logDir = () => path.join(userDataDir(), 'Logs');
  const stagingDir = () => path.join(userDataDir(), 'Staging');

  app.on('second-instance', () => showWindow());

  function createWindow() {
    mainWindow = new BrowserWindow({
      width: 800,
      height: 840,
      minWidth: 700,
      minHeight: 600,
      icon: path.join(__dirname, '..', 'build', 'icon.png'),
      autoHideMenuBar: true,
      show: false,
      backgroundColor: '#F8FAFC',
      webPreferences: {
        preload: path.join(__dirname, 'preload.js'),
        contextIsolation: true,
        nodeIntegration: false,
      },
    });
    mainWindow.setMenuBarVisibility(false);
    mainWindow.loadFile(path.join(__dirname, '..', 'renderer', 'index.html'));

    mainWindow.once('ready-to-show', () => {
      if (isFirstRunFlag) mainWindow.show();
    });

    mainWindow.on('close', (e) => {
      if (!isQuitting) {
        e.preventDefault();
        mainWindow.hide();
        notify('Netsim Yedekleme', 'Uygulama sistem tepsisinde calismaya devam ediyor.');
      }
    });

    return mainWindow;
  }

  function showWindow() {
    if (!mainWindow || mainWindow.isDestroyed()) createWindow();
    mainWindow.show();
    mainWindow.focus();
    mainWindow.webContents.send('refresh-request');
  }

  function notify(title, content) {
    if (tray && !tray.isDestroyed()) {
      try {
        tray.displayBalloon({ title, content, icon: nativeImage.createFromPath(path.join(__dirname, '..', 'build', 'icon.png')) });
      } catch {
        /* balloon not supported on this platform */
      }
    }
  }

  function createTray() {
    const icon = nativeImage.createFromPath(path.join(__dirname, '..', 'build', 'tray.png'));
    tray = new Tray(icon);
    tray.setToolTip('Netsim Yedekleme');
    const menu = Menu.buildFromTemplate([
      { label: 'Ayarlari Ac', click: () => showWindow() },
      { label: 'Simdi Yedekle', click: () => triggerBackup() },
      { type: 'separator' },
      {
        label: 'Cikis',
        click: () => {
          isQuitting = true;
          app.quit();
        },
      },
    ]);
    tray.setContextMenu(menu);
    tray.on('double-click', () => showWindow());
  }

  async function triggerBackup() {
    if (backupInProgress) return { started: false };
    backupInProgress = true;
    notify('Netsim Yedekleme', 'Yedekleme basladi...');
    if (mainWindow && !mainWindow.isDestroyed()) mainWindow.webContents.send('backup-started');
    const result = await runBackup({ logDir: logDir(), stagingDir: stagingDir() });
    backupInProgress = false;
    notify(
      'Netsim Yedekleme',
      result.success ? 'Yedekleme tamamlandi.' : `Yedekleme basarisiz: ${result.error}`
    );
    if (mainWindow && !mainWindow.isDestroyed()) mainWindow.webContents.send('backup-finished', result);
    return { started: true };
  }

  function startScheduler() {
    schedulerTimer = setInterval(() => {
      if (backupInProgress) return;
      const cfg = configModule.load();
      const now = new Date();
      const hh = String(now.getHours()).padStart(2, '0');
      const mm = String(now.getMinutes()).padStart(2, '0');
      const nowStr = `${hh}:${mm}`;
      const todayStr = now.toISOString().slice(0, 10);
      if (nowStr === cfg.backupTime && cfg.lastRunDate !== todayStr) {
        triggerBackup();
      }
    }, 30000);
  }

  let isFirstRunFlag = false;

  app.whenReady().then(() => {
    isFirstRunFlag = !fs.existsSync(configModule.configPath());
    createTray();
    createWindow();
    startScheduler();
  });

  app.on('window-all-closed', () => {
    /* keep running in tray */
  });
  app.on('before-quit', () => {
    isQuitting = true;
    if (schedulerTimer) clearInterval(schedulerTimer);
  });

  // ---- IPC handlers ----
  ipcMain.handle('config:get', () => {
    const cfg = configModule.load();
    return {
      ...cfg,
      googleDrive: {
        ...cfg.googleDrive,
        clientSecret: configModule.decryptSecret(cfg.googleDrive.clientSecretEnc),
        connected: !!cfg.googleDrive.refreshTokenEnc,
      },
      email: {
        ...cfg.email,
        appPassword: configModule.decryptSecret(cfg.email.appPasswordEnc),
      },
    };
  });

  ipcMain.handle('config:save', (e, formData) => {
    const cfg = configModule.load();
    cfg.sourcePath = formData.sourcePath;
    cfg.processExePath = formData.processExePath;
    cfg.firebirdServiceName = formData.firebirdServiceName;
    cfg.backupTime = formData.backupTime;
    cfg.autoRestartAfterBackup = formData.autoRestartAfterBackup;
    cfg.retentionCount = formData.retentionCount;
    cfg.extraDestinations = formData.extraDestinations;

    cfg.googleDrive.enabled = formData.googleDrive.enabled;
    cfg.googleDrive.folderName = formData.googleDrive.folderName;
    cfg.googleDrive.clientId = formData.googleDrive.clientId;
    if (formData.googleDrive.clientSecret) {
      cfg.googleDrive.clientSecretEnc = configModule.encryptSecret(formData.googleDrive.clientSecret);
    }

    cfg.email.enabled = formData.email.enabled;
    cfg.email.senderEmail = formData.email.senderEmail;
    cfg.email.recipients = formData.email.recipients;
    cfg.email.notifyOnSuccess = formData.email.notifyOnSuccess;
    cfg.email.notifyOnFailure = formData.email.notifyOnFailure;
    if (formData.email.appPassword) {
      cfg.email.appPasswordEnc = configModule.encryptSecret(formData.email.appPassword);
    }

    configModule.save(cfg);
    return { ok: true };
  });

  ipcMain.handle('browse:folder', async () => {
    const result = await dialog.showOpenDialog(mainWindow, { properties: ['openDirectory'] });
    return result.canceled ? null : result.filePaths[0];
  });

  ipcMain.handle('browse:exe', async () => {
    const result = await dialog.showOpenDialog(mainWindow, {
      properties: ['openFile'],
      filters: [{ name: 'Uygulamalar', extensions: ['exe'] }],
    });
    return result.canceled ? null : result.filePaths[0];
  });

  ipcMain.handle('processes:list', () => processes.listRunningApps());

  ipcMain.handle('drive:connect', async (e, { clientId, clientSecret }) => {
    const cfg = configModule.load();
    cfg.googleDrive.clientId = clientId;
    cfg.googleDrive.clientSecretEnc = configModule.encryptSecret(clientSecret);
    configModule.save(cfg);
    const refreshToken = await driveAuth.authorize(clientId, clientSecret);
    cfg.googleDrive.refreshTokenEnc = configModule.encryptSecret(refreshToken);
    configModule.save(cfg);
    return { ok: true };
  });

  ipcMain.handle('drive:test', async () => {
    const cfg = configModule.load();
    const clientSecret = configModule.decryptSecret(cfg.googleDrive.clientSecretEnc);
    const refreshToken = configModule.decryptSecret(cfg.googleDrive.refreshTokenEnc);
    if (!refreshToken) throw new Error("Once Google Drive'a baglanin.");
    const accessToken = await driveAuth.getAccessToken(cfg.googleDrive.clientId, clientSecret, refreshToken);
    const folderId = await driveAuth.getOrCreateFolder(accessToken, cfg.googleDrive.folderName);
    cfg.googleDrive.folderId = folderId;
    configModule.save(cfg);
    return { folderId };
  });

  ipcMain.handle('drive:disconnect', () => {
    const cfg = configModule.load();
    cfg.googleDrive.refreshTokenEnc = '';
    cfg.googleDrive.folderId = '';
    configModule.save(cfg);
    return { ok: true };
  });

  ipcMain.handle('email:test', async (e, formData) => {
    const email = require('./email');
    const appPassword =
      formData.appPassword || configModule.decryptSecret(configModule.load().email.appPasswordEnc);
    await email.sendNotification({
      senderEmail: formData.senderEmail,
      appPassword,
      recipients: formData.recipients,
      subject: 'Netsim Yedekleme: Test E-postasi',
      text: 'Bu bir test e-postasidir. E-posta bildirimleri dogru calisiyor.',
    });
    return { ok: true };
  });

  ipcMain.handle('backup:now', () => triggerBackup());

  ipcMain.handle('autostart:get', () => app.getLoginItemSettings().openAtLogin);
  ipcMain.handle('autostart:set', (e, enabled) => {
    app.setLoginItemSettings({ openAtLogin: enabled });
    return { ok: true };
  });

  ipcMain.handle('update:check', async () => {
    try {
      const resp = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`);
      if (!resp.ok) return null;
      const data = await resp.json();
      const latestVersion = (data.tag_name || '').replace(/^v/, '');
      const currentVersion = app.getVersion();
      if (latestVersion && latestVersion !== currentVersion) {
        return { latestVersion, currentVersion, url: data.html_url };
      }
      return null;
    } catch {
      return null;
    }
  });

  ipcMain.handle('app:version', () => app.getVersion());
}
