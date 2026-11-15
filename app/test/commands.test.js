'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const C = require('../src/renderer/commands.js');

// Saturday 15 Nov 2026, 15:00 local time
const NOW = new Date(2026, 10, 15, 15, 0, 0).getTime();
const at = (d, h, m) => new Date(2026, 10, d, h, m || 0, 0).getTime();

test('durations', () => {
  assert.equal(C.parseDuration('10 minuti'), 10 * 60e3);
  assert.equal(C.parseDuration('1 ora e 30 minuti'), 90 * 60e3);
  assert.equal(C.parseDuration("mezz'ora"), 30 * 60e3);
  assert.equal(C.parseDuration("un'ora e mezza"), 90 * 60e3);
  assert.equal(C.parseDuration('90 sec'), 90e3);
  assert.equal(C.parseDuration('cinque minuti'), 5 * 60e3);
  assert.equal(C.parseDuration('ciao'), 0);
});

test('timers', () => {
  assert.deepEqual(C.parse('timer 10 minuti', NOW), { type: 'timer', ms: 600e3, label: 'Timer' });
  assert.deepEqual(C.parse('Metti un timer di 8 minuti per la pasta', NOW), { type: 'timer', ms: 480e3, label: 'pasta' });
  assert.equal(C.parse('5 minuti', NOW).ms, 300e3);
  assert.deepEqual(C.parse('avvia un pomodoro', NOW), { type: 'timer', ms: 25 * 60e3, label: 'Focus' });
  assert.equal(C.parse('focus 50 minuti', NOW).ms, 50 * 60e3);
  assert.equal(C.parse('timer', NOW).type, 'timer-incomplete');
  assert.equal(C.parse('stop timer', NOW).type, 'timer-cancel');
  assert.equal(C.parse('Annulla', NOW).type, 'timer-cancel');
});

test('reminders', () => {
  assert.deepEqual(C.parse('Ricordami di chiamare la mamma alle 18', NOW), { type: 'reminder', text: 'chiamare la mamma', at: at(15, 18) });
  assert.deepEqual(C.parse('ricordami di comprare il latte alle 18:30', NOW), { type: 'reminder', text: 'comprare il latte', at: at(15, 18, 30) });
  assert.deepEqual(C.parse('ricordami tra 20 minuti di spegnere il forno', NOW), { type: 'reminder', text: 'spegnere il forno', at: NOW + 20 * 60e3 });
  assert.deepEqual(C.parse('domani alle 9 ricordami di pagare la bolletta', NOW), { type: 'reminder', text: 'pagare la bolletta', at: at(16, 9) });
  assert.deepEqual(C.parse('ricordami di uscire alle 7 e mezza', NOW), { type: 'reminder', text: 'uscire', at: at(15, 19, 30) });
  // 10 in the morning has passed at 15:00, and 22:00 is a stretch: schedule for tomorrow… unless "10" can be 22
  assert.equal(C.parse('ricordami di dormire alle 10', NOW).at, at(15, 22));
  assert.equal(C.parse('ricordami alle 14 di bere', NOW).at, at(16, 14));
  assert.equal(C.parse('Ricordami di chiamare Luca alle 18', NOW).text, 'chiamare Luca');
  assert.deepEqual(C.parse("tra un'ora ricordami di scrivere a Giulia", NOW), { type: 'reminder', text: 'scrivere a Giulia', at: NOW + 3600e3 });
  assert.deepEqual(C.parse("ricordami tra mezz'ora di uscire", NOW), { type: 'reminder', text: 'uscire', at: NOW + 1800e3 });
  assert.equal(C.parse('ricordami di chiamare Luca', NOW).type, 'reminder-incomplete');
  assert.equal(C.parse('cancella tutti i promemoria', NOW).type, 'reminder-clear');
});

test('calculator', () => {
  assert.equal(C.calculate('2+2*3'), 8);
  assert.equal(C.calculate('(2+2)*3'), 12);
  assert.equal(C.calculate('10 x 3'), 30);
  assert.equal(C.calculate('7 diviso 2'), 3.5);
  assert.equal(C.calculate('2^10'), 1024);
  assert.equal(C.calculate('20% * 50'), 10);
  assert.equal(C.calculate('3,5 + 1,5'), 5);
  assert.equal(C.calculate('alert(1)'), null);
  assert.equal(C.calculate('2+'), null);
  assert.deepEqual(C.parse('quanto fa 12 per 12', NOW), { type: 'calc', expr: '12 per 12', value: 144 });
  assert.equal(C.parse('15 * 4', NOW).value, 60);
});

test('other intents', () => {
  assert.deepEqual(C.parse('ho bevuto un bicchiere', NOW), { type: 'water', delta: 1 });
  assert.deepEqual(C.parse('ho bevuto 2 bicchieri d’acqua', NOW), { type: 'water', delta: 2 });
  assert.deepEqual(C.parse('generami una password di 24 caratteri', NOW), { type: 'password', length: 24 });
  assert.equal(C.parse('password', NOW).length, 16);
  assert.equal(C.parse('che ore sono?', NOW).type, 'time');
  assert.equal(C.parse('che giorno è oggi', NOW).type, 'date');
  assert.equal(C.parse('lancia una moneta', NOW).type, 'coin');
  assert.equal(C.parse('tira un dado', NOW).type, 'dice');
  assert.equal(C.parse('raccontami una barzelletta', NOW).type, 'joke');
  assert.equal(C.parse('Ciao!', NOW).type, 'greet');
  assert.equal(C.parse('grazie mille', NOW).type, 'thanks');
  assert.equal(C.parse('sono stanco', NOW).type, 'comfort');
  assert.equal(C.parse('cosa sai fare?', NOW).type, 'help');
  assert.equal(C.parse('buonanotte', NOW).type, 'sleep');
  assert.equal(C.parse('qual è il senso della vita', NOW).type, 'unknown');
  assert.equal(C.parse('   ', NOW).type, 'empty');
});

test('formatting', () => {
  assert.equal(C.formatDuration(90 * 60e3), '1 ora e 30 minuti');
  assert.equal(C.formatDuration(25 * 60e3), '25 minuti');
  assert.equal(C.formatDuration(45e3), '45 secondi');
  assert.equal(C.formatClock(65e3), '1:05');
  assert.equal(C.formatClock(3725e3), '1:02:05');
});
