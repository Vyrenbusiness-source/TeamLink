const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const TRYCLOUDFLARE_URL_RE = /https:\/\/[a-z0-9-]+\.trycloudflare\.com/i;

let state = {
  url: null,
  process: null,
  startedAt: null,
  status: 'idle',
  lastError: null,
};

let restartConfig = null;
let restartTimer = null;
const RESTART_DELAY_MS = 5000;

function resolveBinary() {
  if (process.env.CLOUDFLARED_BIN && fs.existsSync(process.env.CLOUDFLARED_BIN)) {
    return process.env.CLOUDFLARED_BIN;
  }
  const local = path.join(__dirname, '../../bin/cloudflared.exe');
  if (fs.existsSync(local)) return local;
  return 'cloudflared';
}

function startTunnel({ port = 3000 } = {}) {
  if (state.process) return state;
  restartConfig = { port };

  const bin = resolveBinary();
  state.status = 'starting';
  state.lastError = null;
  state.startedAt = Date.now();

  let proc;
  try {
    proc = spawn(bin, ['tunnel', '--url', `http://localhost:${port}`], {
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (err) {
    state.status = 'error';
    state.lastError = err.message;
    state.process = null;
    console.error(`[cloudflared] spawn failed: ${err.message}`);
    scheduleRestart();
    return state;
  }

  state.process = proc;

  const onData = (chunk) => {
    const text = chunk.toString();
    if (process.env.CLOUDFLARED_VERBOSE) process.stderr.write(`[cloudflared] ${text}`);
    if (!state.url) {
      const m = text.match(TRYCLOUDFLARE_URL_RE);
      if (m) {
        state.url = m[0];
        state.status = 'running';
        console.log(`[cloudflared] tunnel ready: ${state.url}`);
      }
    }
  };
  proc.stdout.on('data', onData);
  proc.stderr.on('data', onData);

  proc.on('error', (err) => {
    state.status = 'error';
    state.lastError = err.message;
    state.process = null; // critical: allow next start attempt
    console.error(`[cloudflared] process error: ${err.message}`);
    scheduleRestart();
  });

  proc.on('exit', (code, signal) => {
    console.warn(`[cloudflared] exited code=${code} signal=${signal}`);
    state.process = null;
    state.url = null;
    if (signal === 'SIGTERM' || signal === 'SIGINT') {
      state.status = 'stopped';
      return; // intentional shutdown – no restart
    }
    state.status = code === 0 ? 'stopped' : 'error';
    if (code !== 0) {
      state.lastError = `cloudflared exited with code ${code}`;
      scheduleRestart();
    }
  });

  return state;
}

function scheduleRestart() {
  if (!restartConfig || restartTimer) return;
  restartTimer = setTimeout(() => {
    restartTimer = null;
    console.log('[cloudflared] auto-restart…');
    startTunnel(restartConfig);
  }, RESTART_DELAY_MS);
}

function stopTunnel() {
  restartConfig = null; // cancel any scheduled restart
  if (restartTimer) {
    clearTimeout(restartTimer);
    restartTimer = null;
  }
  if (state.process) {
    try { state.process.kill('SIGTERM'); } catch { /* ignore */ }
  }
  state.process = null;
  state.url = null;
  state.status = 'stopped';
}

function getState() {
  return {
    url: state.url,
    status: state.status,
    startedAt: state.startedAt,
    lastError: state.lastError,
  };
}

module.exports = { startTunnel, stopTunnel, getState };
