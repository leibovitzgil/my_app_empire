# Tandem — Product Brief

> **The grocery list you shop together, in real time — so nothing gets missed
> and nobody buys it twice.**

Tandem is a real-time, shared grocery-list app built from the `my_app_empire`
factory. This brief is the product-lifecycle record behind the MVP: the market
research it stands on, the problem it solves, the features that ship, and what
comes next.

---

## 1. The problem

Most households already "share" a grocery list — but they shop it **blind**:

- You can't see what your partner already grabbed, so you both buy milk.
- You don't know who flagged the out-of-stock item, or whether anyone's even at
  the store.
- A check-off is a black hole: was it bought, or did someone tap it by mistake?

The shared list is treated as a CRUD form. Tandem treats it as a **live, two-way
shopping session**.

## 2. Market research

We studied the leaders and the gaps (2025–2026 feature sets):

| App | Real-time sync | Item status | Per-item attribution | Live presence | Notable gap |
| --- | --- | --- | --- | --- | --- |
| **AnyList** | Strong, per-list sharing | Reversible cross-off, Recent Items recovery | ❌ none | ❌ | Best features paywalled (web app, recipes, reminders) |
| **OurGroceries** | Solid, account-grouped | Single-tap cross-off to a section | ❌ none | ❌ | Deletes can be irreversible; weak offline |
| **Bring!** | Strong, activity feed | Tap tiles, emoji reactions | Only in a separate feed | ❌ | Reactions are "thanks", not actionable status |
| **Listonic** | Good | Check-off + categories | ❌ | ❌ | Monetizes via ads / price features, not the core |
| **Cozi** | Auto-shared family | Generic checklist | ❌ | ❌ | Grocery is one feature among many; aggressive paywall |
| **Out of Milk / Keep / Reminders / Todoist** | Varies | Binary checkbox | ❌ (or generic) | ❌ | Generic to-do tools; sync or platform-locked (Apple-only) |

**Cross-cutting insights**

1. **Nobody does inline, per-item attribution.** Leaders either omit it or bury
   "who did what" in a separate activity feed/notification.
2. **Nobody shows live presence** ("Sam is shopping now"). All presence is
   after-the-fact history.
3. **Status is binary** (checked / unchecked). The real question co-shoppers ask
   is *"is it already in the cart, or still to grab?"* — a third state.
4. **Sync is the viral hook, yet several apps paywall it** (Cozi gates change
   notifications; Todoist gates collaborators). The household network effect dies
   behind a paywall.
5. **Destructive deletes erode trust** (OurGroceries' irreversible delete, Out of
   Milk's sync horror stories). Recoverability is table stakes.

## 3. Our wedge

Tandem wins on the exact axis the leaders fumble, while matching their table
stakes:

- **Inline per-item attribution** — every row stamps *"In cart · Dana · just
  now"*, not buried in a feed.
- **Live shopper presence** — a *"Dana is shopping"* banner with avatars, with a
  heartbeat TTL so it never goes stale.
- **Three-state status** — `needed → in-cart → done`, so co-shoppers see
  "already grabbed" vs "still to get" and stop double-buying.
- **Conversational flags + reactions** — `out of stock` / `get extra` / `urgent`
  with one-tap *"On it"*, tied to actionable status (not just a thank-you heart).
- **Never paywall sync or presence** — the household hook stays free.
- **Recoverable by design** — reversible check-off, undo snackbars, and a
  recently-deleted bin. A swipe never destroys someone else's item.

## 4. Target users

- Couples & families splitting one grocery run across two phones.
- Roommates sharing a household list.
- Mixed-OS households (iPhone + Android) underserved by Apple-only sync.
- The primary shopper who delegates "grab milk while you're out" and wants live
  confirmation it's done.

## 5. MVP scope

All six **P0** features ship in this build and are covered by automated tests.
Acceptance criteria are encoded as bloc/widget tests (see
`packages/features/feature_grocery_list/test/`).

| ID | Feature | Status |
| --- | --- | --- |
| **F1** | Shared list with real-time sync (stream repo, simulated multi-device) | ✅ Shipped |
| **F2** | Three-state item status with inline attribution | ✅ Shipped |
| **F3** | Live shopper presence (heartbeat + TTL auto-clear) | ✅ Shipped |
| **F4** | Conversational flags with reactions + attention filter | ✅ Shipped |
| **F5** | Add item with autocomplete + auto-categorization | ✅ Shipped |
| **F6** | Reversible delete with undo + recently-deleted bin | ✅ Shipped |
| F7 | Offline-tolerant durable outbox + per-row sync status | 🔜 Roadmap |
| F8 | Invite a member via shareable link (full join flow) | 🔶 Partial (copy-link affordance shipped) |
| F9 | Premium gate at value moments (household subscription) | 🔜 Roadmap |

### The "magic moment"

On launch the list is already populated, and within a few seconds a **simulated
collaborator ("Dana")** enters shopping mode, grabs an item (the row flips to
*"In cart · Dana · just now"*), flags one as out of stock, then finishes — all
live, with no backend. This proves the real-time experience on day one. It's
driven entirely behind the repository contract, so swapping in Firestore/Supabase
later requires **zero** changes to blocs, events, states, or UI.

## 6. Success metrics

- p95 edit-to-appear-on-another-device latency < 1s.
- % of new lists that gain a 2nd member within 24h (viral loop).
- % of lists reaching a "completed shared shop" (≥1 item set to done by a
  non-owner) within 7 days (activation).
- Presence engagement: % of shops where ≥2 members are present simultaneously.
- Zero irreversible-delete incidents (recovery trust).

## 7. Out of scope (for the MVP) & roadmap

**Out of scope now:** recipes/meal planning, pantry/barcode, price/budget
tracking, voice/smartwatch, multi-list, a real backend, full CRDT.

**Roadmap:** swap the in-memory stream repo for Firestore/Supabase Realtime
behind the existing contract → durable offline outbox (F7) → invite/join deep
links (F8) → value-moment paywall (F9) → multiple lists, recurring staples,
recipes, and budget tracking.

---

*Built with the factory's product → UX → architecture → build → QA pipeline. See
[`apps/tandem/README.md`](../apps/tandem/README.md) for the technical design.*
