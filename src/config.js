const fs = require('fs');
const path = require('path');
const { app, safeStorage } = require('electron');

function configPath() {
  return path.join(app.getPath('userData'), 'config.json');
}

function defaults() {
  return {
    sourcePath: '',
    processExePath: '',
    firebirdServiceName: '',
    dailyBackupCount: 1,
    backupTimes: ['23:30'],
    schedulerState: { date: '', firedTimes: [] },
    autoRestartAfterBackup: true,
    retentionCount: 5,
    extraDestinations: [],
    googleDrive: {
      enabled: false,
      folderName: 'Netsim Yedekler',
      folderId: '',
      clientId: '',
      clientSecretEnc: '',
      refreshTokenEnc: '',
    },
    email: {
      enabled: false,
      senderEmail: '',
      appPasswordEnc: '',
      recipients: '',
      notifyOnSuccess: true,
      notifyOnFailure: true,
    },
    lastRunDate: '',
  };
}

function deepMerge(base, override) {
  const result = { ...base };
  for (const key of Object.keys(override || {})) {
    if (
      override[key] &&
      typeof override[key] === 'object' &&
      !Array.isArray(override[key]) &&
      base[key] &&
      typeof base[key] === 'object'
    ) {
      result[key] = deepMerge(base[key], override[key]);
    } else {
      result[key] = override[key];
    }
  }
  return result;
}

function load() {
  let parsed = {};
  try {
    parsed = JSON.parse(fs.readFileSync(configPath(), 'utf-8'));
  } catch {
    parsed = {};
  }
  const cfg = deepMerge(defaults(), parsed);
  const timeRe = /^([01]\d|2[0-3]):[0-5]\d$/;
  if (!Array.isArray(parsed.backupTimes) || parsed.backupTimes.length === 0) {
    cfg.backupTimes = timeRe.test(parsed.backupTime) ? [parsed.backupTime] : defaults().backupTimes;
  }
  cfg.dailyBackupCount = cfg.backupTimes.length;
  delete cfg.backupTime;
  return cfg;
}

function save(cfg) {
  const finalPath = configPath();
  const dir = path.dirname(finalPath);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  const tmpPath = finalPath + '.tmp';
  fs.writeFileSync(tmpPath, JSON.stringify(cfg, null, 2), 'utf-8');
  fs.renameSync(tmpPath, finalPath);
}

function encryptSecret(plain) {
  if (!plain) return '';
  if (!safeStorage.isEncryptionAvailable()) return Buffer.from(plain, 'utf-8').toString('base64');
  return safeStorage.encryptString(plain).toString('base64');
}

function decryptSecret(enc) {
  if (!enc) return '';
  try {
    if (!safeStorage.isEncryptionAvailable()) return Buffer.from(enc, 'base64').toString('utf-8');
    return safeStorage.decryptString(Buffer.from(enc, 'base64'));
  } catch {
    return '';
  }
}

module.exports = { load, save, encryptSecret, decryptSecret, configPath, defaults };
