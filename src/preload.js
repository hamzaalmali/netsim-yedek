const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  getConfig: () => ipcRenderer.invoke('config:get'),
  saveConfig: (data) => ipcRenderer.invoke('config:save', data),
  browseFolder: () => ipcRenderer.invoke('browse:folder'),
  browseExe: () => ipcRenderer.invoke('browse:exe'),
  listRunningApps: () => ipcRenderer.invoke('processes:list'),
  connectDrive: (creds) => ipcRenderer.invoke('drive:connect', creds),
  testDrive: () => ipcRenderer.invoke('drive:test'),
  disconnectDrive: () => ipcRenderer.invoke('drive:disconnect'),
  testEmail: (formData) => ipcRenderer.invoke('email:test', formData),
  backupNow: () => ipcRenderer.invoke('backup:now'),
  getAutoStart: () => ipcRenderer.invoke('autostart:get'),
  setAutoStart: (v) => ipcRenderer.invoke('autostart:set', v),
  checkUpdate: () => ipcRenderer.invoke('update:check'),
  getVersion: () => ipcRenderer.invoke('app:version'),
  onRefreshRequest: (cb) => ipcRenderer.on('refresh-request', cb),
  onBackupStarted: (cb) => ipcRenderer.on('backup-started', cb),
  onBackupFinished: (cb) => ipcRenderer.on('backup-finished', (e, result) => cb(result)),
});
