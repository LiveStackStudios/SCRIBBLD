/**
 * Verify an APNs Auth Key (.p8) is actually valid for push, before uploading
 * it to the Firebase Console.
 *
 *   node tools/check-apns-key.js "/path/to/AuthKey_XXXXXXXXXX.p8"
 *
 * Mints an ES256 provider JWT from the key and sends one push to APNs against
 * a deliberately bogus device token. What we're reading is the *auth* result,
 * not the delivery result:
 *
 *   400 BadDeviceToken     → the key authenticated. It IS a working APNs key.
 *   403 InvalidProviderToken → wrong key, wrong team, or not an APNs key.
 *   403 MissingTopic / TopicDisallowed → key works, bundle id mismatch.
 *
 * Key ID is read from the filename (AuthKey_<KEYID>.p8).
 */
const fs = require('fs');
const crypto = require('crypto');
const http2 = require('http2');

const TEAM_ID = 'H2V83VFF6B';
const BUNDLE_ID = 'com.livestackstudios.scribbld';
const keyPath = process.argv[2];
if (!keyPath) { console.error('usage: node tools/check-apns-key.js <AuthKey_*.p8>'); process.exit(1); }

const keyId = (keyPath.match(/AuthKey_([A-Z0-9]+)\.p8$/i) || [])[1];
if (!keyId) { console.error('Could not read Key ID from filename.'); process.exit(1); }

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const header = b64({ alg: 'ES256', kid: keyId });
const claims = b64({ iss: TEAM_ID, iat: Math.floor(Date.now() / 1000) });
const signer = crypto.createSign('SHA256');
signer.update(`${header}.${claims}`);
const sig = signer.sign(
  { key: fs.readFileSync(keyPath, 'utf8'), dsaEncoding: 'ieee-p1363' }
).toString('base64url');
const jwt = `${header}.${claims}.${sig}`;

// Bogus but well-formed device token — we only care about the auth verdict.
const fakeToken = 'a'.repeat(64);

for (const host of ['api.sandbox.push.apple.com', 'api.push.apple.com']) {
  const client = http2.connect(`https://${host}`);
  client.on('error', (e) => { console.log(`${host}: connection error ${e.message}`); });
  const req = client.request({
    ':method': 'POST',
    ':path': `/3/device/${fakeToken}`,
    authorization: `bearer ${jwt}`,
    'apns-topic': BUNDLE_ID,
    'apns-push-type': 'alert',
    'content-type': 'application/json',
  });
  let status = 0, body = '';
  req.on('response', (h) => { status = h[':status']; });
  req.on('data', (d) => { body += d; });
  req.on('end', () => {
    const reason = (() => { try { return JSON.parse(body).reason; } catch { return body; } })();
    const verdict =
      status === 400 && reason === 'BadDeviceToken' ? 'KEY IS VALID FOR APNs (auth accepted)'
      : reason === 'InvalidProviderToken' ? 'KEY REJECTED — not an APNs key, or wrong Team/Key ID'
      : reason === 'MissingTopic' || reason === 'TopicDisallowed' ? 'auth OK but bundle id mismatch'
      : `unexpected: ${status} ${reason}`;
    console.log(`${host.padEnd(28)} kid=${keyId}  ${status}  ${reason}  →  ${verdict}`);
    client.close();
  });
  req.end(JSON.stringify({ aps: { alert: 'probe' } }));
}
