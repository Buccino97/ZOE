'use strict';
const { contextBridge, ipcRenderer } = require('electron');

const EVENTS = new Set(['cursor', 'open-command', 'open-settings']);

contextBridge.exposeInMainWorld('zoe', {
  setInteractive: on => ipcRenderer.send('set-interactive', !!on),
  release: () => ipcRenderer.send('release'),
  copy: text => ipcRenderer.send('copy', String(text)),
  notify: (title, body) => ipcRenderer.send('notify', { title: String(title), body: String(body) }),
  load: () => ipcRenderer.invoke('store-all'),
  save: (key, value) => ipcRenderer.send('store-set', key, value),
  quit: () => ipcRenderer.send('quit'),
  on: (channel, fn) => { if (EVENTS.has(channel)) ipcRenderer.on(channel, (_e, data) => fn(data)); }
});
