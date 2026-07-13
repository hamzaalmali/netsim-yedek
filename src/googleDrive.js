const http = require('http');
const fs = require('fs');
const path = require('path');
const { shell } = require('electron');

const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth';
const DRIVE_FILES_URL = 'https://www.googleapis.com/drive/v3/files';
const DRIVE_UPLOAD_URL = 'https://www.googleapis.com/upload/drive/v3/files';
const SCOPE = 'https://www.googleapis.com/auth/drive.file';
const REDIRECT_PORT = 8977;
const REDIRECT_URI = `http://127.0.0.1:${REDIRECT_PORT}/`;

let activeServer = null;

function authorize(clientId, clientSecret) {
  return new Promise((resolve, reject) => {
    if (activeServer) {
      try {
        activeServer.close();
      } catch {
        /* already closed */
      }
      activeServer = null;
    }

    let settled = false;
    const server = http.createServer((req, res) => {
      const url = new URL(req.url, REDIRECT_URI);
      const code = url.searchParams.get('code');
      res.end('<html><body><h2>Giris tamamlandi, bu sekmeyi kapatabilirsiniz.</h2></body></html>');
      server.close();
      if (settled) return;
      settled = true;
      if (!code) {
        reject(new Error('Yetkilendirme kodu alinamadi.'));
        return;
      }
      exchangeCode(code, clientId, clientSecret).then(resolve).catch(reject);
    });
    activeServer = server;

    server.on('close', () => {
      if (activeServer === server) activeServer = null;
    });

    server.on('error', (err) => {
      if (settled) return;
      settled = true;
      if (err.code === 'EADDRINUSE') {
        reject(new Error('Yetkilendirme baglantisi zaten acik. Lutfen tarayicidaki islemi tamamlayin ya da birkac saniye bekleyip tekrar deneyin.'));
      } else {
        reject(err);
      }
    });

    server.listen(REDIRECT_PORT, '127.0.0.1', () => {
      const authUrl =
        `${AUTH_URL}?client_id=${encodeURIComponent(clientId)}` +
        `&redirect_uri=${encodeURIComponent(REDIRECT_URI)}` +
        `&response_type=code&scope=${encodeURIComponent(SCOPE)}` +
        `&access_type=offline&prompt=${encodeURIComponent('consent select_account')}`;
      shell.openExternal(authUrl);
    });
    setTimeout(() => {
      if (settled) return;
      settled = true;
      try {
        server.close();
      } catch {
        /* already closed */
      }
      reject(new Error('Zaman asimi: yetkilendirme tamamlanmadi.'));
    }, 120000);
  });
}

async function exchangeCode(code, clientId, clientSecret) {
  const body = new URLSearchParams({
    code,
    client_id: clientId,
    client_secret: clientSecret,
    redirect_uri: REDIRECT_URI,
    grant_type: 'authorization_code',
  });
  const resp = await fetch(TOKEN_URL, { method: 'POST', body });
  const data = await resp.json();
  if (!resp.ok || !data.refresh_token) {
    throw new Error(data.error_description || 'refresh_token alinamadi.');
  }
  return data.refresh_token;
}

async function getAccessToken(clientId, clientSecret, refreshToken) {
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    refresh_token: refreshToken,
    grant_type: 'refresh_token',
  });
  const resp = await fetch(TOKEN_URL, { method: 'POST', body });
  const data = await resp.json();
  if (!resp.ok) throw new Error(data.error_description || 'Erisim tokeni alinamadi.');
  return data.access_token;
}

async function getOrCreateFolder(accessToken, folderName) {
  const safeName = folderName.replace(/'/g, "\\'");
  const q = `mimeType='application/vnd.google-apps.folder' and name='${safeName}' and trashed=false`;
  const listUrl = `${DRIVE_FILES_URL}?q=${encodeURIComponent(q)}&fields=files(id,name)`;
  const listResp = await fetch(listUrl, { headers: { Authorization: `Bearer ${accessToken}` } });
  const listData = await listResp.json();
  if (listData.files && listData.files.length) return listData.files[0].id;

  const createResp = await fetch(DRIVE_FILES_URL, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: folderName, mimeType: 'application/vnd.google-apps.folder' }),
  });
  const createData = await createResp.json();
  if (!createResp.ok) throw new Error(createData.error?.message || 'Klasor olusturulamadi.');
  return createData.id;
}

async function uploadFile(accessToken, filePath, folderId) {
  const fileName = path.basename(filePath);
  const initResp = await fetch(`${DRIVE_UPLOAD_URL}?uploadType=resumable&fields=id,name,createdTime`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json; charset=UTF-8',
      'X-Upload-Content-Type': 'application/zip',
    },
    body: JSON.stringify({ name: fileName, parents: [folderId] }),
  });
  if (!initResp.ok) throw new Error('Yukleme baslatilamadi: ' + (await initResp.text()));
  const sessionUri = initResp.headers.get('location');

  const stat = fs.statSync(filePath);
  const stream = fs.createReadStream(filePath);
  const uploadResp = await fetch(sessionUri, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/zip', 'Content-Length': String(stat.size) },
    body: stream,
    duplex: 'half',
  });
  if (!uploadResp.ok) throw new Error('Yukleme basarisiz: ' + (await uploadResp.text()));
  return uploadResp.json();
}

async function removeOldBackups(accessToken, folderId, keepCount) {
  const q = `'${folderId}' in parents and trashed=false`;
  const url = `${DRIVE_FILES_URL}?q=${encodeURIComponent(q)}&orderBy=createdTime&fields=files(id,name,createdTime)&pageSize=1000`;
  const resp = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  const data = await resp.json();
  const files = data.files || [];
  if (files.length > keepCount) {
    const toDelete = files.slice(0, files.length - keepCount);
    for (const f of toDelete) {
      await fetch(`${DRIVE_FILES_URL}/${f.id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${accessToken}` },
      });
    }
  }
}

module.exports = { authorize, getAccessToken, getOrCreateFolder, uploadFile, removeOldBackups };
