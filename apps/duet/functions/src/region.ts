/**
 * The single region every Duet Cloud Function deploys to.
 *
 * Regions are immutable per Firebase project, so the real value is decided
 * when the projects are created (task M0.H in
 * docs/duet_implementation_breakdown.md) and recorded in
 * docs/duet_environments.md. The emulator ignores the region for placement —
 * locally it only shapes callable URLs
 * (http://<host>:5001/demo-duet/<region>/<name>).
 *
 * TODO(M0.H): replace with the recorded production region. Keep
 * apps/duet/dev.sh's REGION in sync (it dials the healthcheck callable).
 */
export const REGION = 'europe-west1';
