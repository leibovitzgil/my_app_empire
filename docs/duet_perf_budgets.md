# Duet performance budgets — reader / large-PDF path

Owner-facing budgets for the score reader's hot paths, established with the
large-PDF memory strategy (**M8.2**). These are the targets the reader is
built and tuned against; the **measured** device numbers are filled in by a
human profiling run (see *Measuring* below) — this doc ships with the targets
and the design rationale, and the actuals column is deliberately left
`[HUMAN — pending device profile]` until that run lands.

## Budgets

| Path | Budget | How it's measured | Actual |
| --- | --- | --- | --- |
| **Open** a 20 MB PDF (tap piece → first page on screen) | **< 2 s** | `pdf_open` trace (M7.3) + wall-clock to first painted page | `[HUMAN — pending device profile]` |
| **Page flip**, warm (neighbour already prefetched) | **< 300 ms** | `pdf_render_page` trace (M7.3); warm flips should be a cache hit ≈ 0 render | `[HUMAN — pending device profile]` |
| **Page flip**, cold (cache miss) | render + decode of one page | `pdf_render_page` trace (M7.3) | `[HUMAN — pending device profile]` |
| **Memory**, flipping through a 60-page scan | **< 400 MB** RSS | Xcode Instruments / `flutter run --profile` memory graph on the lowest-end target iPad | `[HUMAN — pending device profile]` |

The two traces named above are the **before/after metric** for this work:
they already report `pdf_open` (with page-count + byte-size-bucket attributes)
and `pdf_render_page` on every real render, so a staging profiling session can
compare the pre-M8.2 fixed-2× / no-cache path against the cached, viewport-
fitted path directly, with no new instrumentation.

## Why these numbers, and how the design meets them

### Memory — the LRU cache sizing

The core risk M8.2 removes is a 60-page scan decoding all 60 pages and running
an older iPad out of memory. Two independent caps bound decoded-page memory:

1. **Page count cap — `PageImageCache` (LRU, `capacity = 3`).** The reader
   keeps the **current page ± 1 neighbour** warm (3 decoded full-page images);
   anything older is evicted and its `ui.Image` disposed. Three is the minimum
   that makes a forward *or* backward flip a warm hit while never holding more
   than the working set the user can actually see plus its immediate
   look-ahead. The rail's low-res previews live in a **separate**
   `ThumbnailCache` (M8.1) and don't count against this.

2. **Per-image pixel cap — `fittedRenderScale` (≤ 16 MP / page).** Regardless
   of page size or zoom, one page never renders larger than
   `maxPageImagePixels` (16 MP). At 4 bytes/pixel (RGBA8888) that's ≈ **64 MB**
   worst-case per decoded page, so the whole page cache is bounded at
   **≈ 3 × 64 MB ≈ 192 MB** of decoded pixels in the pathological
   (fully-zoomed, poster-sized) case — comfortably inside the 400 MB budget,
   and in practice far lower because a fitted base render of a sheet-music page
   is only ~2–5 MP (≈ 8–20 MB).

Worked example — a US-Letter page (612 × 792 pt) at the base viewport-fitted
scale on an iPad (≈ 2.5×): 1530 × 1980 px ≈ 3.0 MP ≈ 12 MB decoded. Three of
those ≈ 36 MB. Zooming one page to the 16 MP ceiling swaps *that page's* entry
up to ≈ 64 MB, still leaving the total well under budget.

### Open < 2 s

`PdfrxRenderService` opens one document and renders lazily; only the first
page is rendered at open. The base scale is now **fitted to the viewport**
(not a fixed 2×), so on a large-point original the first render is no larger
than the screen needs — never a gratuitous huge decode on the open path.

### Page flip < 300 ms warm

Neighbours are **prefetched on idle** (post-frame after each page settles,
cancellable when the page changes underneath), so a forward/backward flip to a
prefetched page is a cache hit and paints without a render. Cold flips pay one
`pdf_render_page` render+decode; the trace tells us the real cost per device.

### Sharpness vs. memory — render-scale-by-zoom

The base render targets the viewport at the device pixel ratio (estimated
against a ~1000 pt reference long-edge; the ≤16 MP service cap is the true
ceiling, so an off estimate costs only a little sharpness, never memory).
Zooming in past **~1.5×** of base re-renders the page sharper (debounced
~250 ms, swapped in place over the old image so the page never blanks),
capped by the same 16 MP budget.

## Measuring (device profile — [HUMAN])

The device profile is a human step (no device in CI):

1. `flutter run --profile` (or a profile build) of Duet on the **lowest-end
   target iPad**, against a real 20 MB / ~60-page scanned PDF.
2. Open the piece and read `pdf_open`; flip through all pages (both
   directions) and read `pdf_render_page` — confirm warm flips are hits.
3. Watch the memory graph (Instruments / DevTools) across the full 60-page
   sweep; confirm RSS stays under 400 MB and returns after eviction.
4. Fill the **Actual** column above; file exceptions here for any budget
   missed, with the rationale, rather than silently rebaselining.
