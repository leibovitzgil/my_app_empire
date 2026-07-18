import * as logger from 'firebase-functions/logger';
import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { adminAuth, bucket, db } from './firebase';
import { REGION } from './region';

/**
 * App Check enforcement is env-driven so it stays **off on the emulator**
 * (Track A tests have no App Check token). Turning it on — and flipping the
 * console enforcement for Firestore/Functions in staging then prod — is the
 * Track B / [HUMAN] step (see task M2.5 step 2; M0.3 sets up the monitoring).
 * Mirrors `lookupEmail`'s gate.
 */
const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === 'true';

/**
 * Once-per-day per uid. Reuses M2.5's fixed-window limiter pattern
 * (`rateLimits/{uid}`, `{windowStart, count}`, mutated in a transaction) with
 * a **distinct key** (`rateLimits/{uid}__export`) so it never collides with
 * `lookupEmail`'s per-minute counter on the same collection, and a **distinct
 * window** (24 h, budget 1). A full export is expensive (fan-out reads + a
 * Storage write + signing), so a hard daily cap bounds abuse without ever
 * getting in a real user's way.
 */
const EXPORT_LIMIT = 1;
const EXPORT_WINDOW_MS = 24 * 60 * 60 * 1000;

/**
 * How long the returned links stay valid. The bundle URL is spec'd at 24 h;
 * the per-note audio URLs are minted for the **same** lifetime so a downloaded
 * bundle's links keep working for as long as the bundle link itself does
 * (a shorter audio TTL would leave dead links inside a still-valid export).
 */
const SIGNED_URL_TTL_MS = 24 * 60 * 60 * 1000;

/** Firestore `Timestamp` → ISO-8601 string; anything else → null. */
function toIso(value: unknown): string | null {
  return value instanceof Timestamp ? value.toDate().toISOString() : null;
}

type StorageBucket = ReturnType<typeof bucket>;

/** One audio recording the caller authored, plus a link to fetch it. */
interface AudioAssetExport {
  noteId: string;
  assetId: string;
  path: string;
  downloadUrl: string | null;
}

/** A piece the caller participates in, with only the caller's own slice. */
interface PieceExport {
  pieceId: string;
  title: string | null;
  ownerId: string | null;
  ownerName: string | null;
  role: 'owner' | 'collaborator';
  participantIds: string[];
  collaborators: unknown[];
  basePdfChecksum: string | null;
  createdAt: string | null;
  updatedAt: string | null;
  /** The caller's own annotation layer (`layers/{uid}`), or null. */
  layer: Record<string, unknown> | null;
  /** The caller's own audio notes (`notes where authorId == uid`). */
  notes: Record<string, unknown>[];
  audioAssets: AudioAssetExport[];
}

/** The self-service GDPR bundle — everything Duet holds about one uid. */
export interface ExportBundle {
  schema: 'duet.export.v1';
  generatedAt: string;
  uid: string;
  profile: {
    uid: string;
    email: string | null;
    displayName: string | null;
    photoUrl: string | null;
    createdAt: string | null;
    lastSignInAt: string | null;
    providers: string[];
  };
  /** Every `usersByEmail` entry keyed to this uid (an old address lingers). */
  directory: {
    emailKey: string;
    email: string | null;
    displayName: string | null;
    discoverable: boolean;
  }[];
  /** Server-side entitlement mirror (`entitlements/{uid}`), or null if free. */
  entitlement: { pro: boolean } | null;
  /** FCM device tokens registered for this uid. */
  deviceTokens: string[];
  /** Inbox messages addressed to this uid (invites, nudges, …). */
  inbox: Record<string, unknown>[];
  pieces: PieceExport[];
}

/**
 * Gathers everything Duet holds about [uid], reading only docs scoped to the
 * caller — the isolation that makes the export contain *exactly and only* the
 * caller's data:
 *
 * - `usersByEmail where uid ==` (never derived from the token — the doc id is
 *   an email key that may not be the account's current address);
 * - `pieces where participantIds array-contains uid` — piece metadata only,
 *   plus the caller's own `layers/{uid}` doc and `notes where authorId == uid`
 *   (a collaborator's notes/layers stay out);
 * - each own note's audio object path, signed if [options.bucket] is present
 *   (best-effort — one signing failure never sinks the export; absent bucket,
 *   as in the auth+firestore-only test emulator, yields a null URL + the path).
 *
 * Kept separate from the callable so the two-user isolation test can assert
 * the bundle directly, the way `deleteAccount`'s purge logic is asserted.
 */
export async function gatherExport(
  uid: string,
  options: { bucket?: StorageBucket; signedUrlTtlMs?: number } = {},
): Promise<ExportBundle> {
  const firestore = db();
  const ttlMs = options.signedUrlTtlMs ?? SIGNED_URL_TTL_MS;

  const userRecord = await adminAuth().getUser(uid);
  const profile: ExportBundle['profile'] = {
    uid,
    email: userRecord.email ?? null,
    displayName: userRecord.displayName ?? null,
    photoUrl: userRecord.photoURL ?? null,
    createdAt: userRecord.metadata.creationTime
      ? new Date(userRecord.metadata.creationTime).toISOString()
      : null,
    lastSignInAt: userRecord.metadata.lastSignInTime
      ? new Date(userRecord.metadata.lastSignInTime).toISOString()
      : null,
    providers: userRecord.providerData.map((p) => p.providerId),
  };

  const directorySnap = await firestore
    .collection('usersByEmail')
    .where('uid', '==', uid)
    .get();
  const directory = directorySnap.docs.map((doc) => {
    const data = doc.data();
    return {
      emailKey: doc.id,
      email: (data.email as string | undefined) ?? null,
      displayName: (data.displayName as string | undefined) ?? null,
      discoverable: data.discoverable === true,
    };
  });

  const entitlementSnap = await firestore.doc(`entitlements/${uid}`).get();
  const entitlement = entitlementSnap.exists
    ? { pro: entitlementSnap.data()?.pro === true }
    : null;

  const tokenSnap = await firestore.doc(`deviceTokens/${uid}`).get();
  const deviceTokens = tokenSnap.exists
    ? ((tokenSnap.data()?.tokens as string[] | undefined) ?? [])
    : [];

  const inboxSnap = await firestore
    .collection(`userInbox/${uid}/messages`)
    .get();
  const inbox = inboxSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

  const piecesSnap = await firestore
    .collection('pieces')
    .where('participantIds', 'array-contains', uid)
    .get();

  const pieces: PieceExport[] = [];
  for (const pieceDoc of piecesSnap.docs) {
    const data = pieceDoc.data();
    const pieceId = pieceDoc.id;

    const layerSnap = await firestore
      .doc(`pieces/${pieceId}/layers/${uid}`)
      .get();
    const notesSnap = await firestore
      .collection(`pieces/${pieceId}/notes`)
      .where('authorId', '==', uid)
      .get();

    const audioAssets: AudioAssetExport[] = [];
    for (const noteDoc of notesSnap.docs) {
      const assetId = noteDoc.data().audioAssetId as unknown;
      if (typeof assetId !== 'string' || assetId.length === 0) continue;
      const path = `pieces/${pieceId}/audio/${assetId}`;
      audioAssets.push({
        noteId: noteDoc.id,
        assetId,
        path,
        downloadUrl: await signAudioUrl(options.bucket, path, ttlMs),
      });
    }

    pieces.push({
      pieceId,
      title: (data.title as string | undefined) ?? null,
      ownerId: (data.ownerId as string | undefined) ?? null,
      ownerName: (data.ownerName as string | undefined) ?? null,
      role: data.ownerId === uid ? 'owner' : 'collaborator',
      participantIds: (data.participantIds as string[] | undefined) ?? [],
      collaborators: (data.collaborators as unknown[] | undefined) ?? [],
      basePdfChecksum: (data.basePdfChecksum as string | undefined) ?? null,
      createdAt: toIso(data.createdAt),
      updatedAt: toIso(data.updatedAt),
      layer: layerSnap.exists ? (layerSnap.data() ?? null) : null,
      notes: notesSnap.docs.map((n) => ({ id: n.id, ...n.data() })),
      audioAssets,
    });
  }

  return {
    schema: 'duet.export.v1',
    generatedAt: new Date().toISOString(),
    uid,
    profile,
    directory,
    entitlement,
    deviceTokens,
    inbox,
    pieces,
  };
}

/** A read URL for [path], or null when there's no bucket or signing fails. */
async function signAudioUrl(
  storageBucket: StorageBucket | undefined,
  path: string,
  ttlMs: number,
): Promise<string | null> {
  if (storageBucket == null) return null;
  try {
    const [url] = await storageBucket.file(path).getSignedUrl({
      action: 'read',
      expires: Date.now() + ttlMs,
    });
    return url;
  } catch (err) {
    logger.warn('exportMyData: audio URL signing skipped', { path, err });
    return null;
  }
}

/** What the callable returns (the bundle itself lives in Storage). */
interface ExportResult {
  status: 'exported';
  generatedAt: string;
  /** Signed URL to the JSON bundle (24 h), or null if Storage is absent. */
  downloadUrl: string | null;
  storagePath: string | null;
  counts: {
    pieces: number;
    notes: number;
    audioAssets: number;
    directoryEntries: number;
  };
}

/**
 * Server-authoritative self-service data export (task M7.5).
 *
 * Gathers everything Duet holds about the caller (auth profile, directory
 * entries, entitlement, device tokens, inbox, and every piece they
 * participate in with only their own layer/notes/audio), writes it as a JSON
 * bundle to a private `exports/{uid}/{ts}.json` Storage object, and returns a
 * 24 h signed URL to download it. A callable — not a client-side gather —
 * because the rules (correctly) scope a client to its own docs one at a time,
 * so a complete, cross-collection export is a server job; the same
 * server-authoritative posture as `deleteAccount` (task M1.8).
 *
 * Rate-limited to once per day per uid. Auth required. Storage cleanup / URL
 * signing degrade gracefully with no bucket configured (the auth+firestore
 * test emulator), returning a null `downloadUrl` — the live staging export is
 * the ▸B verification tail.
 */
// TODO(M0.3): add `enforceAppCheck: true` once App Check is enforced.
export const exportMyData = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request): Promise<ExportResult> => {
    if (request.auth == null) {
      throw new HttpsError(
        'unauthenticated',
        'Exporting your data requires a signed-in caller.',
      );
    }
    const uid = request.auth.uid;

    await enforceDailyExportLimit(uid);

    // Best-effort bucket: absent (unit test, no FIREBASE_CONFIG bucket) means
    // no Storage write and a null URL — the Firestore gather still runs whole.
    let storageBucket: StorageBucket | null = null;
    try {
      storageBucket = bucket();
    } catch {
      storageBucket = null;
    }

    const exportBundle = await gatherExport(uid, {
      bucket: storageBucket ?? undefined,
    });

    let downloadUrl: string | null = null;
    let storagePath: string | null = null;
    if (storageBucket != null) {
      storagePath = `exports/${uid}/${Date.now()}.json`;
      try {
        const file = storageBucket.file(storagePath);
        await file.save(JSON.stringify(exportBundle, null, 2), {
          contentType: 'application/json',
          // Private object; the only way in is the signed URL below.
          metadata: { cacheControl: 'private, max-age=0, no-store' },
        });
        const [url] = await file.getSignedUrl({
          action: 'read',
          expires: Date.now() + SIGNED_URL_TTL_MS,
        });
        downloadUrl = url;
      } catch (err) {
        logger.error('exportMyData: bundle write/sign failed', { uid, err });
        storagePath = null;
      }
    }

    const notes = exportBundle.pieces.reduce((n, p) => n + p.notes.length, 0);
    const audioAssets = exportBundle.pieces.reduce(
      (n, p) => n + p.audioAssets.length,
      0,
    );
    const counts: ExportResult['counts'] = {
      pieces: exportBundle.pieces.length,
      notes,
      audioAssets,
      directoryEntries: exportBundle.directory.length,
    };
    // uid + counts only — email addresses (directory doc ids) stay out of the
    // logs, matching `deleteAccount`'s audit-record discipline.
    logger.info('exportMyData: export complete', { uid, ...counts });
    return {
      status: 'exported',
      generatedAt: exportBundle.generatedAt,
      downloadUrl,
      storagePath,
      counts,
    };
  },
);

/**
 * Trips `resource-exhausted` once [uid] has exported within the last
 * [EXPORT_WINDOW_MS]. Same fixed-window transaction as `lookupEmail`'s
 * limiter, on a **separate** doc (`rateLimits/{uid}__export`) so the two
 * counters never overwrite each other. The collection is server-only
 * (deny-by-default in the rules — clients never touch it).
 */
async function enforceDailyExportLimit(uid: string): Promise<void> {
  const ref = db().doc(`rateLimits/${uid}__export`);
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    const data = snap.data() as
      | { windowStart?: Timestamp; count?: number }
      | undefined;
    const windowStart = data?.windowStart?.toMillis() ?? 0;

    if (now - windowStart >= EXPORT_WINDOW_MS) {
      tx.set(ref, { windowStart: Timestamp.fromMillis(now), count: 1 });
      return;
    }
    if ((data?.count ?? 0) >= EXPORT_LIMIT) {
      throw new HttpsError(
        'resource-exhausted',
        'You can export your data once a day. Please try again tomorrow.',
      );
    }
    tx.update(ref, { count: (data?.count ?? 0) + 1 });
  });
  logger.debug('exportMyData: within daily rate limit', { uid });
}
