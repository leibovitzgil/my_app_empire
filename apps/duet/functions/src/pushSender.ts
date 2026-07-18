import { FieldValue } from 'firebase-admin/firestore';

import { db, fcm } from './firebase';

/**
 * The deep-link domain carried in push `data` payloads, for M5.5's
 * tap-through routing. Placeholder until the product name lands (Track B),
 * exactly like `inviteTokens.ts`'s `inviteUrlFor` — keep the two domains in
 * sync when the real one is configured.
 */
export const DEEP_LINK_DOMAIN = 'https://duet.app';

/** What a push says: FCM notification title/body + string-only data map. */
export interface PushPayload {
  title: string;
  body: string;
  data: Record<string, string>;
}

/** The outcome of one [sendPushAndPrune] multicast. */
export interface PushSendSummary {
  successCount: number;
  failureCount: number;
  prunedCount: number;
}

/**
 * Multicasts [payload] to [tokens] and prunes dead tokens — the one FCM send
 * path, extracted from M5.3's `onInboxMessageCreated` so M5.4's digest drain
 * rides the exact same delivery + pruning behavior.
 *
 * Pruning: any token FCM reports as
 * `messaging/registration-token-not-registered` (an uninstalled or
 * expired-token device) is `arrayRemove`d from `deviceTokens/{uid}`, so dead
 * tokens don't accumulate and get retried forever. Other failure codes (e.g.
 * transient unavailability) keep their tokens.
 *
 * Callers read `deviceTokens/{uid}` themselves (they need its other fields —
 * the drain honors `pushEnabled`) and pass the token list in; this helper
 * owns only the send and the prune-back write.
 */
export async function sendPushAndPrune(
  uid: string,
  tokens: string[],
  payload: PushPayload,
): Promise<PushSendSummary> {
  const response = await fcm().sendEachForMulticast({
    tokens,
    notification: { title: payload.title, body: payload.body },
    data: payload.data,
  });

  const deadTokens = tokens.filter(
    (_, i) =>
      response.responses[i]?.error?.code ===
      'messaging/registration-token-not-registered',
  );
  if (deadTokens.length > 0) {
    await db()
      .doc(`deviceTokens/${uid}`)
      .set({ tokens: FieldValue.arrayRemove(...deadTokens) }, { merge: true });
  }

  return {
    successCount: response.successCount,
    failureCount: response.failureCount,
    prunedCount: deadTokens.length,
  };
}
