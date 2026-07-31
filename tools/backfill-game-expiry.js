/**
 * One-off backfill: stamp `expiresAt` on game docs that predate it.
 *
 *   node tools/backfill-game-expiry.js          # dry run, prints the plan
 *   node tools/backfill-game-expiry.js --apply  # writes
 *
 * Why this exists: a Firestore TTL policy on `games.expiresAt` has been
 * ACTIVE, but only the open-invite path ever wrote the field. Per-friend
 * invites and every game that actually got played had no `expiresAt` at all,
 * so the TTL policy could never see them and they accumulated forever.
 *
 * The app now stamps `expiresAt` on every write path, so this is only needed
 * once, for documents created before that change.
 *
 * Auth reuses the Firebase CLI login (`firebase login`). The client
 * id/secret are firebase-tools' published public credentials.
 */
const os = require('os');
const c = require(os.homedir() + '/.config/configstore/firebase-tools.json');
const PROJ = 'scribbld-87573';
const APPLY = process.argv.includes('--apply');

// Mirrors LiveGameService.ttl(for:) — keep in sync.
const DAY = 86400000;
const TTL = { pending: 1 * DAY, active: 7 * DAY, completed: 1 * DAY, abandoned: 1 * DAY };

async function token() {
  const params = new URLSearchParams({
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: c.tokens.refresh_token, grant_type: 'refresh_token',
  });
  const r = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', body: params });
  return (await r.json()).access_token;
}

(async () => {
  const t = await token();
  const H = { Authorization: 'Bearer ' + t, 'Content-Type': 'application/json' };
  const base = `https://firestore.googleapis.com/v1/projects/${PROJ}/databases/(default)/documents`;

  const r = await fetch(`${base}:runQuery`, {
    method: 'POST', headers: H,
    body: JSON.stringify({ structuredQuery: { from: [{ collectionId: 'games' }], limit: 1000 } }),
  });
  const rows = await r.json();
  if (!Array.isArray(rows)) { console.log('QUERY ERR', JSON.stringify(rows).slice(0, 400)); process.exit(1); }

  const docs = rows.filter(x => x.document).map(x => x.document);
  const now = Date.now();
  const plan = [];

  for (const d of docs) {
    const f = d.fields || {};
    if (f.expiresAt) continue;                      // already stamped
    const id = d.name.split('/').pop();
    const status = (f.status && f.status.stringValue) || 'completed';
    const updated = f.updatedAt && f.updatedAt.timestampValue
      ? Date.parse(f.updatedAt.timestampValue)
      : (f.createdAt && f.createdAt.timestampValue ? Date.parse(f.createdAt.timestampValue) : now);
    // Base the expiry on last activity, so long-dead games are already past
    // their stamp and get swept on the next TTL pass instead of gaining a
    // fresh lease on life.
    const expires = new Date(updated + (TTL[status] || DAY));
    plan.push({ id, status, updated: new Date(updated).toISOString(), expires: expires.toISOString(), overdue: expires.getTime() < now });
  }

  console.log(`${docs.length} game docs, ${plan.length} missing expiresAt\n`);
  plan.forEach(p => console.log(`  ${p.id}  ${p.status.padEnd(10)} last=${p.updated.slice(0, 10)}  expires=${p.expires.slice(0, 10)}  ${p.overdue ? '→ sweeps on next TTL pass' : '→ future'}`));

  if (!APPLY) { console.log('\nDry run. Re-run with --apply to write.'); return; }

  let ok = 0, fail = 0;
  for (const p of plan) {
    const url = `${base}/games/${p.id}?updateMask.fieldPaths=expiresAt`;
    const res = await fetch(url, {
      method: 'PATCH', headers: H,
      body: JSON.stringify({ fields: { expiresAt: { timestampValue: p.expires } } }),
    });
    if (res.ok) { ok++; } else { fail++; console.log('  FAILED', p.id, res.status, (await res.text()).slice(0, 200)); }
  }
  console.log(`\nstamped ${ok}, failed ${fail}`);
})();
