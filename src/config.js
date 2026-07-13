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
    backupTime: '23:30',
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
  try {
    const raw = fs.readFileSync(configPath(), 'utf-8');
    return deepMerge(defaults(), JSON.parse(raw));
  } catch {
    return defaults();
  }
}

function save(cfg) {
  const dir = path.dirname(configPath());
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(configPath(), JSON.stringify(cfg, null, 2), 'utf-8');
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
