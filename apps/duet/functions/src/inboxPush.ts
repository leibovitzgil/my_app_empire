import { FieldValue } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { db, fcm } from './firebase';
import { REGION } from './region';

/**
 * The deep-link domain carried in the push `data` payload, for M5.5's
 * tap-through routing. Placeholder until the product name lands (Track B),
 * exactly like `inviteTokens.ts`'s `inviteUrlFor` — keep the two domains in
 * sync when the real one is configured.
 */
const DEEP_LINK_DOMAIN = 'https://duet.app';

/**
 * Fans an inbox message out to the recipient's devices via FCM (task M5.3).
 *
 * Every server-side sender (`sendInvite`, `sendNudge`, later M5.4's digest)
 * already writes `userInbox/{uid}/messages/{id}`; this trigger is the one
 * push sender on top of that seam. It reads the recipient's registered
 * device tokens from `deviceTokens/{uid}` (written by the client's
 * `DeviceTokenSync`) and multicasts a notification built from the message's
 * own `title`/`body`, plus a `data` payload (`type`, `pieceId`, `deepLink`)
 * for M5.5's tap-through routing.
 *
 * Foreground dedupe (the strategy, end-to-end): when at least one send
 * succeeds, the message doc is marked `pushed: true`, and the client's
 * `InboxNotificationBridge` skips its local notification for `pushed`
 * messages — without this, a message pushed to the lock screen would be
 * re-notified by the bridge on the next foreground pass. A recipient with no
 * (usable) tokens gets no `pushed` mark, so the foreground bridge remains
 * their delivery path — permission-denied users still see invites.
 *
 * Token pruning: any token FCM reports as
 * `messaging/registration-token-not-registered` (an uninstalled or
 * expired-token device) is `arrayRemove`d from `deviceTokens/{uid}`, so dead
 * tokens don't accumulate and get retried forever.
 *
 * Track A scope: this function plus mocked-messaging tests. Real delivery
 * (APNs key, `firebase_messaging` as a real client dependency, lock-screen
 * verification) is the ▸B backlog — there is no FCM emulator.
 */
export const onInboxMessageCreated = onDocumentCreated(
  { region: REGION, document: 'userInbox/{uid}/messages/{messageId}' },
  async (event) => {
    const snap = event.data;
    if (snap == null) return;
    const { uid, messageId } = event.params;
    const message = snap.data();

    const tokensSnap = await db().doc(`deviceTokens/${uid}`).get();
    const tokens = (tokensSnap.data()?.tokens ?? []) as string[];
    if (tokens.length === 0) {
      // No registered device: leave `pushed` unset so the recipient's
      // foreground inbox bridge delivers instead.
      logger.info('onInboxMessageCreated: no tokens, bridge delivers', {
        uid,
        messageId,
      });
      return;
    }

    const messageData = (message.data ?? {}) as Record<string, string>;
    const pieceId = messageData.pieceId;
    const response = await fcm().sendEachForMulticast({
      tokens,
      notification: {
        title: message.title as string,
        body: message.body as string,
      },
      // FCM data values must be strings; the inbox `data` map already is
      // (mirrors the Dart client's `Map<String, String>`).
      data: {
        ...messageData,
        ...(pieceId ? { deepLink: `${DEEP_LINK_DOMAIN}/piece/${pieceId}` } : {}),
      },
    });

    // Prune tokens FCM says are gone for good (uninstall/expiry). Other
    // failure codes (e.g. transient unavailability) keep their tokens.
    const deadTokens = tokens.filter(
      (_, i) =>
        response.responses[i].error?.code ===
        'messaging/registration-token-not-registered',
    );
    if (deadTokens.length > 0) {
      await db()
        .doc(`deviceTokens/${uid}`)
        .set(
          { tokens: FieldValue.arrayRemove(...deadTokens) },
          { merge: true },
        );
    }

    // Only a delivered push suppresses the client bridge; if every send
    // failed the bridge is still the recipient's delivery path.
    if (response.successCount > 0) {
      await snap.ref.set({ pushed: true }, { merge: true });
    }

    logger.info('onInboxMessageCreated: fanned out', {
      uid,
      messageId,
      successCount: response.successCount,
      failureCount: response.failureCount,
      prunedCount: deadTokens.length,
    });
  },
);
