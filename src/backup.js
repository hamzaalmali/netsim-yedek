const { execFile } = require('child_process');
const util = require('util');
const fs = require('fs');
const path = require('path');
const archiver = require('archiver');
const configModule = require('./config');
const drive = require('./googleDrive');
const email = require('./email');

const execFileAsync = util.promisify(execFile);

function log(logDir, message, level = 'INFO') {
  if (!fs.existsSync(logDir)) fs.mkdirSync(logDir, { recursive: true });
  const file = path.join(logDir, `backup_${new Date().toISOString().slice(0, 10)}.log`);
  const line = `${new Date().toISOString().replace('T', ' ').slice(0, 19)} [${level}] ${message}\n`;
  fs.appendFileSync(file, line);
}

async function isProcessRunning(exePath) {
  const name = path.basename(exePath);
  try {
    const { stdout } = await execFileAsync('tasklist', ['/FI', `IMAGENAME eq ${name}`, '/FO', 'CSV', '/NH']);
    return stdout.toLowerCase().includes(name.toLowerCase());
  } catch {
    return false;
  }
}

async function stopNetsimProcess(cfg, logDir) {
  if (!cfg.processExePath) return false;
  const name = path.basename(cfg.processExePath);
  const running = await isProcessRunning(cfg.processExePath);
  if (running) {
    log(logDir, `Program kapatiliyor: ${name}`);
    try {
      await execFileAsync('taskkill', ['/IM', name]);
    } catch {
      /* may already be gracefully closing */
    }
    await new Promise((r) => setTimeout(r, 5000));
    if (await isProcessRunning(cfg.processExePath)) {
      log(logDir, 'Program kapanmadi, zorla sonlandiriliyor.');
      try {
        await execFileAsync('taskkill', ['/IM', name, '/F']);
      } catch {
        /* ignore */
      }
    }
  }
  if (cfg.firebirdServiceName) {
    try {
      log(logDir, `Firebird servisi durduruluyor: ${cfg.firebirdServiceName}`);
      await execFileAsync('net', ['stop', cfg.firebirdServiceName]);
    } catch (e) {
      log(logDir, `Firebird servisi durdurulamadi: ${e.message}`, 'WARN');
    }
  }
  return running;
}

async function startNetsimProcess(cfg, logDir) {
  if (cfg.firebirdServiceName) {
    try {
      await execFileAsync('net', ['start', cfg.firebirdServiceName]);
    } catch (e) {
      log(logDir, `Firebird servisi baslatilamadi: ${e.message}`, 'WARN');
    }
  }
  if (cfg.processExePath && fs.existsSync(cfg.processExePath)) {
    try {
      const child = execFile(cfg.processExePath, [], { detached: true, stdio: 'ignore' });
      child.unref();
      log(logDir, `Program yeniden baslatildi: ${cfg.processExePath}`);
    } catch (e) {
      log(logDir, `Program yeniden baslatilamadi: ${e.message}`, 'WARN');
    }
  }
}

function createZip(sourcePath, destZipPath) {
  return new Promise((resolve, reject) => {
    const output = fs.createWriteStream(destZipPath);
    const archive = archiver('zip', { zlib: { level: 9 } });
    output.on('close', resolve);
    output.on('error', reject);
    archive.on('error', reject);
    archive.on('warning', (err) => {
      if (err.code !== 'ENOENT') reject(err);
    });
    archive.pipe(output);
    archive.directory(sourcePath, false);
    archive.finalize();
  });
}

function removeOldLocalBackups(folderPath, keepCount, logDir) {
  if (!fs.existsSync(folderPath)) return;
  const files = fs
    .readdirSync(folderPath)
    .filter((f) => f.startsWith('NetsimYedek_') && f.endsWith('.zip'))
    .map((f) => {
      const full = path.join(folderPath, f);
      return { name: f, full, time: fs.statSync(full).birthtimeMs };
    })
    .sort((a, b) => a.time - b.time);
  if (files.length > keepCount) {
    const toDelete = files.slice(0, files.length - keepCount);
    for (const f of toDelete) {
      fs.unlinkSync(f.full);
      log(logDir, `Eski yedek silindi (${folderPath}): ${f.name}`);
    }
  }
}

function timestampForFilename() {
  const now = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}_${pad(now.getHours())}-${pad(now.getMinutes())}`;
}

async function sendEmailNotification(cfg, logDir, result) {
  if (!cfg.email.enabled) return;
  if (result.success && !cfg.email.notifyOnSuccess) return;
  if (!result.success && !cfg.email.notifyOnFailure) return;
  if (!cfg.email.senderEmail || !cfg.email.recipients) return;
  try {
    const appPassword = configModule.decryptSecret(cfg.email.appPasswordEnc);
    const subject = result.success
      ? 'Netsim Yedekleme: Basarili'
      : 'Netsim Yedekleme: BASARISIZ';
    const text = result.success
      ? `Yedekleme basariyla tamamlandi.\nTarih: ${new Date().toLocaleString('tr-TR')}`
      : `Yedekleme basarisiz oldu.\nHata: ${result.error}\nTarih: ${new Date().toLocaleString('tr-TR')}`;
    await email.sendNotification({
      senderEmail: cfg.email.senderEmail,
      appPassword,
      recipients: cfg.email.recipients,
      subject,
      text,
    });
    log(logDir, 'Bildirim e-postasi gonderildi.');
  } catch (e) {
    log(logDir, `Bildirim e-postasi gonderilemedi: ${e.message}`, 'ERROR');
  }
}

async function runBackup(paths) {
  const { logDir, stagingDir } = paths;
  const cfg = configModule.load();
  let result;
  try {
    log(logDir, '===== Yedekleme basladi =====');
    const wasRunning = await stopNetsimProcess(cfg, logDir);

    if (!fs.existsSync(stagingDir)) fs.mkdirSync(stagingDir, { recursive: true });
    const zipName = `NetsimYedek_${timestampForFilename()}.zip`;
    const zipPath = path.join(stagingDir, zipName);
    await createZip(cfg.sourcePath, zipPath);
    log(logDir, `Yedek arsivi olusturuldu: ${zipPath}`);

    if (wasRunning && cfg.autoRestartAfterBackup) {
      await startNetsimProcess(cfg, logDir);
    }

    if (cfg.googleDrive.enabled) {
      const clientSecret = configModule.decryptSecret(cfg.googleDrive.clientSecretEnc);
      const refreshToken = configModule.decryptSecret(cfg.googleDrive.refreshTokenEnc);
      if (!refreshToken) throw new Error("Google Drive bagli degil.");
      const accessToken = await drive.getAccessToken(cfg.googleDrive.clientId, clientSecret, refreshToken);
      let folderId = cfg.googleDrive.folderId;
      if (!folderId) {
        folderId = await drive.getOrCreateFolder(accessToken, cfg.googleDrive.folderName);
        cfg.googleDrive.folderId = folderId;
        configModule.save(cfg);
      }
      await drive.uploadFile(accessToken, zipPath, folderId);
      log(logDir, `Yedek Google Drive'a yuklendi (klasor: ${cfg.googleDrive.folderName}).`);
      await drive.removeOldBackups(accessToken, folderId, cfg.retentionCount);
    }

    for (const dest of cfg.extraDestinations) {
      if (dest.enabled) {
        try {
          if (!fs.existsSync(dest.path)) fs.mkdirSync(dest.path, { recursive: true });
          fs.copyFileSync(zipPath, path.join(dest.path, zipName));
          log(logDir, `Yedek ek konuma kopyalandi: ${dest.path}`);
          removeOldLocalBackups(dest.path, cfg.retentionCount, logDir);
        } catch (e) {
          log(logDir, `HATA (ek konum ${dest.path}): ${e.message}`, 'ERROR');
        }
      }
    }

    removeOldLocalBackups(stagingDir, cfg.retentionCount, logDir);

    cfg.lastRunDate = new Date().toISOString().slice(0, 10);
    configModule.save(cfg);
    log(logDir, '===== Yedekleme tamamlandi =====');
    result = { success: true, lastRunDate: cfg.lastRunDate };
  } catch (e) {
    log(logDir, `HATA: ${e.message}`, 'ERROR');
    result = { success: false, error: e.message };
  }
  await sendEmailNotification(cfg, logDir, result);
  return result;
}

module.exports = { runBackup, log };
