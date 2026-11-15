'use strict';
const fs = require('fs');
const path = require('path');

// Tiny JSON store kept in the user's app-data folder. Everything stays on this computer.
module.exports = function createStore(file) {
  let data = {};
  try { data = JSON.parse(fs.readFileSync(file, 'utf8')) || {}; } catch { data = {}; }
  let timer = null;
  const flush = () => {
    timer = null;
    try {
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(file + '.tmp', JSON.stringify(data, null, 2));
      fs.renameSync(file + '.tmp', file);
    } catch (err) { console.error('ZOE: impossibile salvare', err); }
  };
  return {
    all: () => JSON.parse(JSON.stringify(data)),
    get: key => data[key],
    set(key, value) { data[key] = value; if (!timer) timer = setTimeout(flush, 200); },
    flush
  };
};
