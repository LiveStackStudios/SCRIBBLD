// Pre-submission check for SCRIBBLD.
//
//   node tools/preflight-appstore.js
//
// Reads the live App Store Connect state and reports what still blocks
// "Submit for Review". Read-only — it changes nothing.
//
// Worth re-running before every submission: it caught the version still
// pointing at an older build after a newer one had been uploaded, which would
// have shipped the wrong binary.
const fs = require('fs'), os = require('os'), crypto = require('crypto');

const KEY_ID = '43PX5XQX7U', ISSUER = '247485c7-4940-4281-9624-96a54fbfcad9', APP = '6771195391';
const key = fs.readFileSync(os.homedir() + '/.appstoreconnect/private_keys/AuthKey_43PX5XQX7U.p8', 'utf8');

function jwt() {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const h = b64({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' });
  const p = b64({ iss: ISSUER, iat: now, exp: now + 900, aud: 'appstoreconnect-v1' });
  const s = crypto.createSign('SHA256'); s.update(h + '.' + p);
  return `${h}.${p}.${s.sign({ key, dsaEncoding: 'ieee-p1363' }).toString('base64url')}`;
}
async function api(path) {
  const r = await fetch('https://api.appstoreconnect.apple.com' + path, { headers: { Authorization: 'Bearer ' + jwt() } });
  const t = await r.text();
  try { return { status: r.status, json: t ? JSON.parse(t) : null }; } catch { return { status: r.status, text: t }; }
}

const BLOCK = [], WARN = [], OK = [];
const ok = (m) => OK.push(m);
const block = (m) => BLOCK.push(m);
const warn = (m) => WARN.push(m);

(async () => {
  // --- App-level ---
  const app = (await api(`/v1/apps/${APP}`)).json.data.attributes;
  ok(`App: ${app.name} (${app.bundleId})`);
  app.contentRightsDeclaration ? ok(`Content rights: ${app.contentRightsDeclaration}`)
                               : block('Content rights declaration not answered');

  // --- App Info: categories, subtitle, privacy URL, age rating ---
  const infos = (await api(`/v1/apps/${APP}/appInfos`)).json.data;
  const infoStub = infos.find(i => ['PREPARE_FOR_SUBMISSION','READY_FOR_DISTRIBUTION','WAITING_FOR_REVIEW','IN_REVIEW'].includes(i.attributes.appStoreState)) || infos[0];
  // NOTE: App Store Connect only populates relationship `data` when you ask
  // for it with ?include=. Reading categories off the list endpoint (or off a
  // plain single fetch) always looks empty and produces a false "not set".
  const info = (await api(`/v1/appInfos/${infoStub.id}?include=primaryCategory,primarySubcategoryOne,primarySubcategoryTwo`)).json.data;
  const rel = info.relationships;
  rel.primaryCategory?.data ? ok(`Primary category: ${rel.primaryCategory.data.id}`) : block('Primary category not set');
  if (rel.primarySubcategoryOne?.data) ok(`Subcategory: ${rel.primarySubcategoryOne.data.id}${rel.primarySubcategoryTwo?.data ? ' + ' + rel.primarySubcategoryTwo.data.id : ''}`);

  const il = (await api(`/v1/appInfos/${info.id}/appInfoLocalizations`)).json.data;
  for (const l of il) {
    const a = l.attributes;
    a.name ? ok(`[${a.locale}] name: ${a.name}`) : block(`[${a.locale}] app name missing`);
    a.subtitle ? ok(`[${a.locale}] subtitle: ${a.subtitle}`) : warn(`[${a.locale}] subtitle empty (optional)`);
    a.privacyPolicyUrl ? ok(`[${a.locale}] privacy URL set`) : block(`[${a.locale}] Privacy Policy URL missing`);
  }

  const ard = (await api(`/v1/appInfos/${info.id}?include=ageRatingDeclaration`)).json;
  const decl = (ard.included || []).find(x => x.type === 'ageRatingDeclarations');
  if (!decl) block('Age rating not started');
  else {
    const answered = Object.entries(decl.attributes).filter(([k, v]) => v !== null && !k.includes('Override')).length;
    answered > 5 ? ok(`Age rating: ${answered} questions answered`) : block(`Age rating only ${answered} answered`);
  }

  // --- Version ---
  const vers = (await api(`/v1/apps/${APP}/appStoreVersions?limit=5`)).json.data;
  const v = vers.find(x => ['PREPARE_FOR_SUBMISSION','DEVELOPER_REJECTED','REJECTED','METADATA_REJECTED'].includes(x.attributes.appStoreState)) || vers[0];
  ok(`Version ${v.attributes.versionString} — state: ${v.attributes.appStoreState}`);
  ok(`Release type: ${v.attributes.releaseType}`);

  const vl = (await api(`/v1/appStoreVersions/${v.id}/appStoreVersionLocalizations`)).json.data;
  for (const l of vl) {
    const a = l.attributes;
    a.description ? ok(`[${a.locale}] description ${a.description.length} chars`) : block(`[${a.locale}] description missing`);
    a.keywords ? ok(`[${a.locale}] keywords ${a.keywords.length}/100`) : warn(`[${a.locale}] keywords empty`);
    a.supportUrl ? ok(`[${a.locale}] support URL set`) : block(`[${a.locale}] Support URL missing`);
    a.promotionalText ? ok(`[${a.locale}] promo text set`) : warn(`[${a.locale}] promo text empty (optional)`);

    // Screenshots
    const sets = (await api(`/v1/appStoreVersionLocalizations/${l.id}/appScreenshotSets`)).json.data || [];
    if (!sets.length) block(`[${a.locale}] NO screenshots`);
    for (const s of sets) {
      const shots = (await api(`/v1/appScreenshotSets/${s.id}/appScreenshots`)).json.data || [];
      const bad = shots.filter(x => (x.attributes.assetDeliveryState || {}).state !== 'COMPLETE');
      if (!shots.length) block(`[${a.locale}] ${s.attributes.screenshotDisplayType}: empty set`);
      else if (bad.length) block(`[${a.locale}] ${s.attributes.screenshotDisplayType}: ${bad.length} not processed`);
      else ok(`[${a.locale}] ${s.attributes.screenshotDisplayType}: ${shots.length} screenshots OK`);
    }
  }

  // --- Build ---
  const b = (await api(`/v1/appStoreVersions/${v.id}/build`)).json.data;
  if (!b) block('No build attached to the version');
  else {
    const bd = (await api(`/v1/builds/${b.id}`)).json.data.attributes;
    ok(`Build attached: ${bd.version} (${bd.processingState})`);
    if (bd.processingState !== 'VALID') block(`Build state is ${bd.processingState}`);
    if (bd.expired) block('Attached build has EXPIRED');
    if (bd.usesNonExemptEncryption === null) warn('Build encryption declaration unanswered (Info.plist key should cover it)');
    else ok(`Encryption: usesNonExemptEncryption=${bd.usesNonExemptEncryption}`);
  }

  // --- Review details ---
  const rd = (await api(`/v1/appStoreVersions/${v.id}/appStoreReviewDetail`)).json.data;
  if (!rd) block('App Review details missing');
  else {
    const a = rd.attributes;
    a.contactEmail && a.contactPhone ? ok(`Review contact: ${a.contactFirstName} ${a.contactLastName}`) : block('Review contact incomplete');
    a.notes ? ok(`Review notes: ${a.notes.length} chars`) : warn('Review notes empty');
    ok(`Demo account required: ${a.demoAccountRequired}`);
  }

  // --- Phased release / price ---
  const pr = await api(`/v1/apps/${APP}/appPriceSchedule`);
  if (pr.status === 200 && pr.json.data) ok('Price schedule exists'); else warn('Price schedule not confirmed via API — check the app is set to Free in Pricing');

  // --- IAP (should NOT block a free 1.0) ---
  const subs = (await api(`/v1/apps/${APP}/subscriptionGroups`)).json.data || [];
  for (const g of subs) {
    const s = (await api(`/v1/subscriptionGroups/${g.id}/subscriptions`)).json.data || [];
    for (const x of s) warn(`Subscription "${x.attributes.name}" is ${x.attributes.state} — fine as long as you do NOT add it to this submission`);
  }

  console.log('\n================ BLOCKERS ================');
  BLOCK.length ? BLOCK.forEach(m => console.log('  ✗ ' + m)) : console.log('  none');
  console.log('\n================ WARNINGS ===============');
  WARN.length ? WARN.forEach(m => console.log('  ! ' + m)) : console.log('  none');
  console.log('\n================ OK =====================');
  OK.forEach(m => console.log('  ✓ ' + m));
})();
