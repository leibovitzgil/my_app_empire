import { db } from './firebase';

/**
 * Server-side mirror of `CollaboratorLimits`
 * (apps/duet/lib/domain/src/domain/piece.dart) — the single per-piece
 * collaborator cap predicate, duplicated here because a Cloud Function can't
 * import Dart. Keep the two in sync.
 *
 * The cap is per-piece and tier-dependent: free = 1, paid = 8. The owner's
 * tier comes from `entitlements/{uid}` via [ownerIsPro]: until M6.3's
 * RevenueCat webhook populates that collection nothing writes it, so every
 * owner resolves to the free tier — which is exactly the pre-monetization
 * truth. M5.2's invite-token callables enforce the cap through this lookup;
 * the M2.4 email-path callables still defer their cap to M6.3.
 */
export const FREE_TIER_COLLABORATORS = 1;
export const PAID_TIER_COLLABORATORS = 8;

/** The cap that applies given [isPro] (mirrors `CollaboratorLimits.capFor`). */
export function capFor(isPro: boolean): number {
  return isPro ? PAID_TIER_COLLABORATORS : FREE_TIER_COLLABORATORS;
}

/**
 * Whether [ownerId] is on the paid tier, per `entitlements/{ownerId}`
 * (`{pro: true}`, docs/duet_cloud_schema.md). Absent or non-pro → free
 * tier. M6.3's webhook is the only writer of that collection (the rules
 * deny clients).
 */
export async function ownerIsPro(ownerId: string): Promise<boolean> {
  const entitlement = (await db().doc(`entitlements/${ownerId}`).get()).data();
  return entitlement?.pro === true;
}
