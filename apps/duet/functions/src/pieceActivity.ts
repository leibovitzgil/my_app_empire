import { Timestamp } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

import { db } from './firebase';
import { REGION } from './region';

/**
 * Bumps a piece's `updatedAt` (and the editing author's own read watermark) so
 * an annotation write surfaces as unread activity to *other* participants
 * (M3.7). Annotation writes land in the per-author `layers/{uid}` and
 * `notes/{noteId}` subcollections and never touch the parent piece doc, so
 * without this trigger `pieces/{id}.updatedAt` would never move and the
 * library's unread dots (`updatedAt` vs. each reader's watermark) would never
 * fire cross-user.
 *
 * The editor's own `reads/{uid}.lastOpenedAt` is advanced to the *same*
 * timestamp, so an author never sees their own edit as unread while every other
 * participant does. `updatedAt` must be a Firestore `Timestamp` (the client's
 * `pieceFromFirestore` hard-casts it), so both writes use one `Timestamp.now()`
 * value. Writing the piece doc doesn't re-trigger this (there is no piece-doc
 * trigger) and writing `reads` isn't a layer/note, so there is no loop.
 */
async function bumpPieceActivity(pieceId: string, editorUid: string) {
  const now = Timestamp.now();
  const firestore = db();
  const batch = firestore.batch();
  batch.update(firestore.doc(`pieces/${pieceId}`), { updatedAt: now });
  batch.set(
    firestore.doc(`pieces/${pieceId}/reads/${editorUid}`),
    { uid: editorUid, lastOpenedAt: now },
    { merge: true },
  );
  await batch.commit();
}

/** A participant wrote their ink layer (doc id == their uid). */
export const onLayerWrite = onDocumentWritten(
  { region: REGION, document: 'pieces/{pieceId}/layers/{layerId}' },
  async (event) => {
    // Only a create/update is new activity; a layer removal (delete, or the
    // M3.8 cascade) leaves nothing to advance and the piece may be gone.
    if (event.data?.after?.exists !== true) return;
    await bumpPieceActivity(event.params.pieceId, event.params.layerId);
  },
);

/** A participant wrote an audio note (its `authorId` is the editor). */
export const onNoteWrite = onDocumentWritten(
  { region: REGION, document: 'pieces/{pieceId}/notes/{noteId}' },
  async (event) => {
    const after = event.data?.after;
    if (after?.exists !== true) return;
    const authorId = after.data()?.authorId;
    if (typeof authorId !== 'string') return;
    await bumpPieceActivity(event.params.pieceId, authorId);
  },
);
