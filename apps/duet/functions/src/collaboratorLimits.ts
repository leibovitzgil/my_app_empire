/**
 * Server-side mirror of `CollaboratorLimits`
 * (packages/core/pieces/lib/src/domain/piece.dart) — the single per-piece
 * collaborator cap predicate, duplicated here because a Cloud Function can't
 * import Dart. Keep the two in sync.
 *
 * The cap is per-piece and tier-dependent: free = 1, paid = 8. Pre-M3 the
 * server has no `pieces` document to count existing collaborators against, so
 * the callables can't yet *enforce* the count — they carry this constant and a
 * `// M3.6` marker where the real check lands once piece docs exist. M6.3
 * upgrades the pro lookup (today only the free tier is knowable server-side).
 */
export const FREE_TIER_COLLABORATORS = 1;
export const PAID_TIER_COLLABORATORS = 8;

/** The cap that applies given [isPro] (mirrors `CollaboratorLimits.capFor`). */
export function capFor(isPro: boolean): number {
  return isPro ? PAID_TIER_COLLABORATORS : FREE_TIER_COLLABORATORS;
}
