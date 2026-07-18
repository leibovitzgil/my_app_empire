import * as logger from 'firebase-functions/logger';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { db } from './firebase';
import { DEEP_LINK_DOMAIN, sendPushAndPrune } from './pushSender';
import { REGION } from './region';

/**
 * Fans an inbox message out to the recipient's devices via FCM (task M5.3).
 *
 * Every server-side sender (`sendInvite`, `sendNudge`) already writes
 * `userInbox/{uid}/messages/{id}`; this trigger is the push sender on top of
 * that seam. It reads the recipient's registered device tokens from
 * `deviceTokens/{uid}` (written by the client's `DeviceTokenSync`) and
 * multicasts a notification built from the message's own `title`/`body`,
 * plus a `data` payload (`type`, `pieceId`, `deepLink`) for M5.5's
 * tap-through routing. The send + dead-token pruning live in
 * `pushSender.ts`'s [sendPushAndPrune], shared with M5.4's digest drain.
 *
 * Foreground dedupe (the strategy, end-to-end): when at least one send
 * succeeds, the message doc is marked `pushed: true`, and the client's
 * `InboxNotificationBridge` skips its local notification for `pushed`
 * messages — without this, a message pushed to the lock screen would be
 * re-notified by the bridge on the next foreground pass. A recipient with no
 * (usable) tokens gets no `pushed` mark, so the foreground bridge remains
 * their delivery path — permission-denied users still see invites.
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
    const summary = await sendPushAndPrune(uid, tokens, {
      title: message.title as string,
      body: message.body as string,
      // FCM data values must be strings; the inbox `data` map already is
      // (mirrors the Dart client's `Map<String, String>`).
      data: {
        ...messageData,
        ...(pieceId ? { deepLink: `${DEEP_LINK_DOMAIN}/piece/${pieceId}` } : {}),
      },
    });

    // Only a delivered push suppresses the client bridge; if every send
    // failed the bridge is still the recipient's delivery path.
    if (summary.successCount > 0) {
      await snap.ref.set({ pushed: true }, { merge: true });
    }

    logger.info('onInboxMessageCreated: fanned out', {
      uid,
      messageId,
      successCount: summary.successCount,
      failureCount: summary.failureCount,
      prunedCount: summary.prunedCount,
    });
  },
);
