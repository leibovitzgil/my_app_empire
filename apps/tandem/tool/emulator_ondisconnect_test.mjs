// Integration test for the RTDB presence `onDisconnect` flow against the local
// Firebase Emulator Suite. Proves the exact mechanism FirebasePresenceRepository
// relies on: a client that disconnects WITHOUT writing "I left" is removed from
// presence by the *server*, so no client heartbeat/TTL is needed.
//
// Run:
//   firebase emulators:start --only firestore,database --project demo-tandem &
//   cd apps/tandem/tool && npm install firebase && node emulator_ondisconnect_test.mjs
//
// Exits 0 on ONDISCONNECT_PASS, non-zero otherwise.
import { initializeApp } from 'firebase/app';
import { getDatabase, ref, set, onDisconnect, goOffline } from 'firebase/database';

const NS = 'demo-tandem';
const restGet = async (p) => {
  const r = await fetch(`http://127.0.0.1:9000/${p}.json?ns=${NS}`);
  return r.json();
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const app = initializeApp({ databaseURL: `http://127.0.0.1:9000?ns=${NS}` });
const db = getDatabase(app);
const node = ref(db, 'presence/household/me');

// Exactly what FirebasePresenceRepository.enter() does:
await onDisconnect(node).remove();
await set(node, { name: 'You', colorValue: 0xff3b82f6, since: Date.now() });

const before = await restGet('presence/household');
console.log('BEFORE (presence written):', JSON.stringify(before));

// Simulate the client disconnecting without a clean "leave" (app killed, network
// drop). The server detects the closed socket and runs the onDisconnect handler.
goOffline(db);

let after = '(unchecked)';
let cleared = false;
for (let i = 0; i < 10; i++) {
  await sleep(1500);
  after = await restGet('presence/household');
  if (after === null) {
    cleared = true;
    break;
  }
}
console.log('AFTER (socket dropped):', JSON.stringify(after));

const pass = before && before.me && before.me.name === 'You' && cleared;
console.log('RESULT:', pass ? 'ONDISCONNECT_PASS' : 'ONDISCONNECT_FAIL');
process.exit(pass ? 0 : 1);
