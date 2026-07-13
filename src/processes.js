const { execFile } = require('child_process');
const util = require('util');

const execFileAsync = util.promisify(execFile);

async function listRunningApps() {
  const psScript =
    "Get-Process | Where-Object { $_.MainWindowTitle -ne '' -and $_.Path } | " +
    'Select-Object ProcessName, Id, MainWindowTitle, Path | ConvertTo-Json -Compress';
  try {
    const { stdout } = await execFileAsync(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-Command', psScript],
      { windowsHide: true, maxBuffer: 10 * 1024 * 1024 }
    );
    let data = JSON.parse(stdout || '[]');
    if (!Array.isArray(data)) data = [data];
    const seen = new Set();
    return data
      .map((p) => ({ name: p.ProcessName, title: p.MainWindowTitle, path: p.Path }))
      .filter((p) => {
        if (seen.has(p.path)) return false;
        seen.add(p.path);
        return true;
      });
  } catch {
    return [];
  }
}

module.exports = { listRunningApps };
