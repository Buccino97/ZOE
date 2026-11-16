'use strict';
const {
  app, BrowserWindow, ipcMain, screen, Tray, Menu, nativeImage,
  globalShortcut, clipboard, Notification
} = require('electron');
const path = require('path');
const createStore = require('./store');

// The window is a transparent area at the top-centre of the screen.
// Only the strip inside it takes mouse clicks; everything else is click-through.
const W = 720, H = 400;
const SHORTCUT = 'CommandOrControl+Shift+Space';

let win = null, tray = null, cursorTimer = null, store = null;

if (!app.requestSingleInstanceLock()) { app.quit(); }

function placeWindow() {
  if (!win) return;
  const { workArea } = screen.getPrimaryDisplay();
  win.setBounds({ x: Math.round(workArea.x + (workArea.width - W) / 2), y: workArea.y, width: W, height: H });
}

function createWindow() {
  win = new BrowserWindow({
    width: W, height: H, show: false,
    frame: false, transparent: true, backgroundColor: '#00000000', hasShadow: false,
    resizable: false, movable: false, minimizable: false, maximizable: false, fullscreenable: false,
    skipTaskbar: true, alwaysOnTop: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true, nodeIntegration: false, sandbox: true
    }
  });
  win.setAlwaysOnTop(true, 'screen-saver');
  if (process.platform === 'darwin') win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: false });
  win.setIgnoreMouseEvents(true, { forward: true });
  placeWindow();
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  win.once('ready-to-show', () => win.showInactive());

  // Stream the cursor position so ZOE's eyes can follow it and the strip knows when it is hovered.
  // Polling works on every OS, unlike forwarded mouse events (not supported on Linux).
  cursorTimer = setInterval(() => {
    if (!win || win.isDestroyed() || !win.isVisible()) return;
    const p = screen.getCursorScreenPoint(), b = win.getBounds();
    win.webContents.send('cursor', { x: p.x - b.x, y: p.y - b.y });
  }, 50);

  win.on('closed', () => { win = null; clearInterval(cursorTimer); });
}

function trayIcon() {
  // tray.png is 16px; Electron picks tray@2x.png automatically on high-DPI screens.
  return nativeImage.createFromPath(path.join(__dirname, 'assets', 'tray.png'));
}

function createTray() {
  tray = new Tray(trayIcon());
  tray.setToolTip('ZOE');
  const send = ch => () => { if (!win) return; win.showInactive(); summon(); win.webContents.send(ch); };
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: 'Chiedi qualcosa…', accelerator: SHORTCUT, click: send('open-command') },
    { label: 'Personalizza ZOE…', click: send('open-settings') },
    { type: 'separator' },
    { label: 'Mostra / nascondi', click: () => { if (!win) return; win.isVisible() ? win.hide() : win.showInactive(); } },
    { label: 'Avvia con il computer', type: 'checkbox', checked: app.getLoginItemSettings().openAtLogin,
      click: item => app.setLoginItemSettings({ openAtLogin: item.checked }) },
    { type: 'separator' },
    { label: 'Esci', click: () => app.quit() }
  ]));
}

// Make the window clickable and focused so the user can type straight away.
function summon() {
  if (!win) return;
  win.setIgnoreMouseEvents(false);
  // On macOS ZOE has no Dock icon, so the app itself must be activated before its window can take the keyboard.
  if (process.platform === 'darwin') app.focus({ steal: true });
  win.focus();
}

const STORE_KEYS = new Set(['settings', 'water', 'reminders', 'stats']);

function registerIpc() {
  ipcMain.on('set-interactive', (_e, on) => {
    if (win) win.setIgnoreMouseEvents(!on, { forward: true });
  });
  ipcMain.on('release', () => {
    if (!win) return;
    win.setIgnoreMouseEvents(true, { forward: true });
    win.blur();
  });
  ipcMain.on('copy', (_e, text) => clipboard.writeText(String(text).slice(0, 10000)));
  ipcMain.on('notify', (_e, { title, body }) => {
    if (Notification.isSupported()) new Notification({ title: String(title), body: String(body) }).show();
  });
  ipcMain.handle('store-all', () => store.all());
  ipcMain.on('store-set', (_e, key, value) => { if (STORE_KEYS.has(key)) store.set(key, value); });
  ipcMain.on('quit', () => app.quit());
}

app.whenReady().then(() => {
  if (process.platform === 'win32') app.setAppUserModelId('app.zoe.desktop');
  if (process.platform === 'darwin' && app.dock) app.dock.hide();
  store = createStore(path.join(app.getPath('userData'), 'zoe.json'));
  registerIpc();
  createWindow();
  createTray();
  globalShortcut.register(SHORTCUT, () => { if (!win) return; win.showInactive(); summon(); win.webContents.send('open-command'); });
  screen.on('display-metrics-changed', placeWindow);
  screen.on('display-added', placeWindow);
  screen.on('display-removed', placeWindow);
});

app.on('second-instance', () => { if (win) { win.showInactive(); summon(); win.webContents.send('open-command'); } });
app.on('will-quit', () => globalShortcut.unregisterAll());
app.on('window-all-closed', () => app.quit());
