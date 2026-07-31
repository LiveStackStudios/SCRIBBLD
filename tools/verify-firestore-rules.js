/**
 * Firestore security-rules regression suite.
 *
 *   node tools/verify-firestore-rules.js
 *
 * Compiles firestore.rules and runs the cases below through the Firebase
 * Rules `:test` API. Nothing is deployed and no project data is touched —
 * the rules text is evaluated server-side against synthetic documents.
 *
 * Run this before every `firebase deploy --only firestore:rules`. Each DENY
 * case is a real attack that the rules previously allowed; each ALLOW case is
 * a production flow that must keep working, so a rules change that breaks the
 * app fails here rather than in TestFlight.
 *
 * Auth reuses the Firebase CLI's own login (`firebase login` must have been
 * run). The client id/secret below are firebase-tools' published public
 * client credentials, not project secrets.
 *
 * The emulator-based alternative (`@firebase/rules-unit-testing`) is the
 * better long-term home for this but needs a local Java runtime, which this
 * machine doesn't have.
 */
const os = require('os'), fs = require('fs');
const c = require(os.homedir() + '/.config/configstore/firebase-tools.json');
const RULES = fs.readFileSync('/Users/juanayala/SCRIBBLD/firestore.rules', 'utf8');
const NOW = '2026-07-30T12:00:00Z';
const FUTURE = '2026-07-31T12:00:00Z';   // open invite expiry (unexpired)
const PAST = '2026-07-29T12:00:00Z';     // already expired

const D = (p) => `/databases/(default)/documents${p}`;

// Base open-invite game: host alone in a 5-player Stop! lobby.
const openGame = {
  type: 'stop', status: 'pending', players: ['host'], playerNames: { host: 'Host' },
  currentTurn: 'host', state: {}, maxPlayers: 5, inviteKind: 'open',
  createdAt: NOW, expiresAt: FUTURE,
};
// Per-friend Stop! invite: host + invitee listed, still has free slots.
const friendGame = { ...openGame, inviteKind: 'friend', players: ['host', 'invitee'], expiresAt: null };
// A live 2-player game in progress.
const activeGame = {
  type: 'ticTacToe', status: 'active', players: ['host', 'p2'], playerNames: { host: 'Host', p2: 'P2' },
  currentTurn: 'host', state: { cells: ['', '', '', '', '', '', '', '', ''] },
  maxPlayers: 2, inviteKind: 'friend', createdAt: NOW,
};

const tc = (name, expectation, method, path, uid, before, after, mocks) => ({
  _name: name,
  expectation,
  request: {
    auth: uid ? { uid, token: {} } : null,
    path: D(path),
    method,
    time: NOW,
    ...(after ? { resource: { data: after } } : {}),
  },
  ...(before ? { resource: { data: before } } : {}),
  ...(mocks ? { functionMocks: mocks } : {}),
});

const existsMock = (path, value) => ({
  function: 'exists',
  args: [{ exactValue: D(path) }],
  result: { value },
});

const cases = [
  // ---- ATTACKS THAT MUST BE DENIED ----
  tc('ATTACK lobby hijack: joiner evicts host from players', 'DENY', 'update', '/games/g1', 'mallory',
    openGame, { ...openGame, players: ['mallory', 'stranger'] }),
  tc('ATTACK lobby hijack: joiner replaces host with self only', 'DENY', 'update', '/games/g1', 'mallory',
    { ...openGame, players: ['host', 'p2'] }, { ...openGame, players: ['mallory', 'p2', 'p3'] }),
  tc('ATTACK stranger joins a per-friend invite via leaked gameId', 'DENY', 'update', '/games/g1', 'mallory',
    friendGame, { ...friendGame, players: ['host', 'invitee', 'mallory'] }),
  tc('ATTACK stranger reads a per-friend invite doc', 'DENY', 'get', '/games/g1', 'mallory', friendGame, null),
  tc('ATTACK join an expired open invite', 'DENY', 'update', '/games/g1', 'mallory',
    { ...openGame, expiresAt: PAST }, { ...openGame, expiresAt: PAST, players: ['host', 'mallory'] }),
  tc('ATTACK player reopens a full active game to strangers via maxPlayers', 'DENY', 'update', '/games/g1', 'host',
    activeGame, { ...activeGame, maxPlayers: 5, status: 'pending' }),
  tc('ATTACK player reverts a live game back to pending', 'DENY', 'update', '/games/g1', 'host',
    activeGame, { ...activeGame, status: 'pending' }),
  tc('ATTACK player flips inviteKind to open to expose the doc', 'DENY', 'update', '/games/g1', 'host',
    activeGame, { ...activeGame, inviteKind: 'open' }),
  tc('ATTACK non-player writes a move into someone elses game', 'DENY', 'update', '/games/g1', 'mallory',
    activeGame, { ...activeGame, state: { cells: ['x', '', '', '', '', '', '', '', ''] } }),
  tc('ATTACK write invite into arbitrary inbox spoofing sender', 'DENY', 'create', '/users/victim/invites/g9', 'mallory',
    null, { from: 'host', fromName: 'Apple Support', type: 'ticTacToe', gameId: 'g9', status: 'pending' }),
  tc('ATTACK insert self onto victims friends roster with no request', 'DENY', 'create',
    '/users/victim/friends/mallory', 'mallory', null, { displayName: 'Mom' },
    [existsMock('/users/mallory/friendRequests/victim', false)]),
  tc('ATTACK read another users private push token', 'DENY', 'get', '/users/victim/private/push', 'mallory', { fcmToken: 't' }, null),

  tc('ATTACK create a 5-seat Tic Tac Toe', 'DENY', 'create', '/games/g2', 'host', null,
    { ...activeGame, status: 'pending', players: ['host'], maxPlayers: 5 }),
  tc('ATTACK create a Stop! lobby seating more than 5', 'DENY', 'create', '/games/g2', 'host', null,
    { ...openGame, players: ['host'], maxPlayers: 8 }),
  tc('ATTACK create a game already over its own seat cap', 'DENY', 'create', '/games/g2', 'host', null,
    { ...openGame, players: ['host', 'a', 'b'], maxPlayers: 2 }),
  tc('ATTACK create a game you are not a player in', 'DENY', 'create', '/games/g2', 'mallory', null,
    { ...openGame, players: ['host'], maxPlayers: 5 }),

  // ---- BLOCKING + REPORTING (added 2026-07-30) ----
  tc('ATTACK blocked user sends an invite anyway', 'DENY', 'create', '/users/victim/invites/g5', 'mallory',
    null, { from: 'mallory', fromName: 'M', type: 'stop', gameId: 'g5', status: 'pending' },
    [existsMock('/users/victim/blocked/mallory', true)]),
  tc('ATTACK blocked user sends a friend request anyway', 'DENY', 'create',
    '/users/victim/friendRequests/mallory', 'mallory', null,
    { fromUID: 'mallory', fromName: 'M', status: 'pending' },
    [existsMock('/users/victim/blocked/mallory', true)]),
  tc('ATTACK read someone elses block list', 'DENY', 'get', '/users/victim/blocked/x', 'mallory', { displayName: 'X' }, null),
  tc('ATTACK read abuse reports', 'DENY', 'get', '/reports/r1', 'mallory',
    { reporterUID: 'a', reportedUID: 'b', reason: 'harassment' }, null),
  tc('ATTACK file a report while impersonating another reporter', 'DENY', 'create', '/reports/r2', 'mallory',
    null, { reporterUID: 'victim', reportedUID: 'someone', reason: 'harassment' }),
  tc('ATTACK report yourself to poison the queue', 'DENY', 'create', '/reports/r3', 'mallory',
    null, { reporterUID: 'mallory', reportedUID: 'mallory', reason: 'harassment' }),
  tc('ATTACK file a report with a novel-length note', 'DENY', 'create', '/reports/r4', 'mallory',
    null, { reporterUID: 'mallory', reportedUID: 'victim', reason: 'harassment', note: 'x'.repeat(2000) }),

  // ---- LEGITIMATE FLOWS THAT MUST STILL WORK ----
  tc('OK file a report as yourself', 'ALLOW', 'create', '/reports/r5', 'me',
    null, { reporterUID: 'me', reportedUID: 'peer', reason: 'offensiveName', note: 'bad name' }),
  tc('OK block someone', 'ALLOW', 'create', '/users/me/blocked/peer', 'me', null, { displayName: 'Peer' }),
  tc('OK read own block list', 'ALLOW', 'get', '/users/me/blocked/peer', 'me', { displayName: 'Peer' }, null),
  tc('OK unblocked user can still invite', 'ALLOW', 'create', '/users/opponent/invites/g6', 'host',
    null, { from: 'host', fromName: 'Host', type: 'stop', gameId: 'g6', status: 'pending' },
    [existsMock('/users/opponent/blocked/host', false)]),
  tc('OK Ink Pro host opens a 5-seat Stop! lobby', 'ALLOW', 'create', '/games/g2', 'host', null,
    { ...openGame, players: ['host'], maxPlayers: 5 }),
  tc('OK free host opens a 2-seat Stop! game', 'ALLOW', 'create', '/games/g2', 'host', null,
    { ...openGame, players: ['host'], maxPlayers: 2 }),
  tc('OK create a standard 2-player Tic Tac Toe invite', 'ALLOW', 'create', '/games/g2', 'host', null,
    { ...activeGame, status: 'pending', players: ['host', 'p2'], maxPlayers: 2 }),
  tc('OK share-link joiner appends self to open lobby', 'ALLOW', 'update', '/games/g1', 'joiner',
    openGame, { ...openGame, players: ['host', 'joiner'], playerNames: { host: 'Host', joiner: 'J' } }),
  tc('OK stranger reads an unexpired open invite before joining', 'ALLOW', 'get', '/games/g1', 'joiner', openGame, null),
  tc('OK listed player writes a move', 'ALLOW', 'update', '/games/g1', 'host',
    activeGame, { ...activeGame, state: { cells: ['x', '', '', '', '', '', '', '', ''] }, currentTurn: 'p2' }),
  tc('OK invitee accepts: pending -> active', 'ALLOW', 'update', '/games/g1', 'invitee',
    { ...friendGame, maxPlayers: 2 }, { ...friendGame, maxPlayers: 2, status: 'active' }),
  tc('OK host starts N-player lobby', 'ALLOW', 'update', '/games/g1', 'host',
    { ...openGame, players: ['host', 'j2'] }, { ...openGame, players: ['host', 'j2'], status: 'active' }),
  tc('OK inviter creates invite in opponent inbox', 'ALLOW', 'create', '/users/opponent/invites/g1', 'host',
    null, { from: 'host', fromName: 'Host', type: 'stop', gameId: 'g1', status: 'pending' },
    [existsMock('/users/opponent/blocked/host', false)]),
  tc('OK accepter writes counterpart entry onto requesters roster', 'ALLOW', 'create',
    '/users/requester/friends/me', 'me', null, { displayName: 'Me' },
    [existsMock('/users/me/friendRequests/requester', true)]),
  tc('OK owner writes own friends roster', 'ALLOW', 'create', '/users/me/friends/peer', 'me', null, { displayName: 'Peer' }),
  tc('OK owner writes own push token', 'ALLOW', 'create', '/users/me/private/push', 'me', null, { fcmToken: 'abc' }),
  tc('OK owner reads own push token', 'ALLOW', 'get', '/users/me/private/push', 'me', { fcmToken: 'abc' }, null),
  tc('OK signed-in user reads a profile for friend search', 'ALLOW', 'get', '/users/other', 'me', { displayName: 'Other' }, null),
];

(async () => {
  const params = new URLSearchParams({
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: c.tokens.refresh_token, grant_type: 'refresh_token',
  });
  const tr = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', body: params });
  const tj = await tr.json();
  if (!tj.access_token) { console.log('TOKEN_FAIL'); process.exit(1); }

  const testCases = cases.map(({ _name, ...rest }) => rest);
  const res = await fetch('https://firebaserules.googleapis.com/v1/projects/scribbld-87573:test', {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + tj.access_token, 'Content-Type': 'application/json' },
    body: JSON.stringify({ source: { files: [{ name: 'firestore.rules', content: RULES }] }, testSuite: { testCases } }),
  });
  const out = await res.json();
  if (out.issues && out.issues.length) {
    console.log('COMPILE ISSUES:', JSON.stringify(out.issues, null, 2));
  }
  const results = out.testResults || [];
  let pass = 0, fail = 0;
  results.forEach((r, i) => {
    const ok = r.state === 'SUCCESS';
    ok ? pass++ : fail++;
    console.log(`${ok ? 'PASS' : 'FAIL'}  [${cases[i].expectation}] ${cases[i]._name}`);
    if (!ok && r.errorPosition) console.log(`        at line ${r.errorPosition.line}`);
  });
  console.log(`\n${pass} passed, ${fail} failed, ${results.length} total`);
})();
