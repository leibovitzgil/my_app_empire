---
name: screenshot
description: Capture real, readable screenshots of a running app flow (multiple screens, real navigation, real text) in a headless container with no device/simulator/display. Use when the user wants visual feedback on a feature, asks to "see" or "show" a screen/flow, or when reviewing your own UI work before reporting it done.
---

# Screenshot a live app flow (headless, no device)

`golden` (see that skill) renders one widget in the Dart test VM — fast and
exact for regression diffs, but text comes out as solid blocks (fallback test
font) because headless `flutter test` can't fetch/shape real fonts. When you or
the user need to actually **look at** a flow — multiple screens, real
navigation, real text, real icons — build the app for **web** and drive it with
the pre-installed Playwright Chromium instead. This renders through the real
Skia/CanvasKit pipeline, so screenshots look like the real app.

This is a from-scratch recipe (not a `melos` script) because it's for one-off
visual review, not a CI gate. Everything it creates is scratch — see Cleanup.

## Why not `flutter run -d chrome` / `tool/web_e2e.sh`?

Both need a real browser reachable the normal way. This container's egress is
policy-filtered and Chromium doesn't inherit the agent's `HTTPS_PROXY`, so a
stock web build shows a **blank white page** (CanvasKit fetches itself from
`gstatic.com`) or **renders layout with zero text** (CanvasKit also fetches a
"Roboto" fallback font from `gstatic.com` for *any* text shaping — this is an
engine-level fetch, unrelated to whether the app uses `google_fonts`). This
skill's build/serve/patch/intercept steps route around exactly those two
network dependencies with zero app-code changes. `tool/web_e2e.sh` additionally
needs a Chrome/chromedriver version match (see `KNOWN_ISSUES.md`); driving the
pre-installed Playwright Chromium directly sidesteps that entirely.

## Steps

Work in the scratchpad directory for scripts/output; only touch the app dir for
the build itself.

### 1. Add the web platform (if the app doesn't have one)

```bash
cd apps/<app>
flutter create --platforms=web .
rm -f test/widget_test.dart   # default scaffold test; not the app's real test
```

### 2. Build

```bash
flutter build web --release --no-tree-shake-icons
```

`--no-tree-shake-icons` keeps every `Icons.*` glyph available — without it,
icons not statically detected render as tofu boxes in some builds.

### 3. Patch the bootstrap to use the *bundled* CanvasKit, not the CDN

`build/web/flutter_bootstrap.js` ends with a `_flutter.loader.load({...})` call
that, by default, fetches CanvasKit from `https://www.gstatic.com/flutter-canvaskit/...`
even though the exact files are already sitting in `build/web/canvaskit/`. Force
the local path:

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("build/web/flutter_bootstrap.js")
src = p.read_text()
patched = re.sub(
    r"_flutter\.loader\.load\(\{.*?\}\);",
    '_flutter.loader.load({config: {canvasKitBaseUrl: "canvaskit/"}});',
    src, flags=re.DOTALL,
)
p.write_text(patched)
PY
```

Re-run this after every rebuild — it regenerates the file.

### 4. Serve it

```bash
cd build/web
python3 -m http.server 8765 --bind 127.0.0.1 &
```

### 5. Drive it with Playwright

The pre-installed Chromium isn't on `$PATH` and Playwright is a global npm
package, not a local one — both need explicit paths:

```bash
NODE_PATH=/opt/node22/lib/node_modules node script.js
```

```js
const { chromium } = require('playwright');
const fs = require('fs');

// CanvasKit needs a real font to shape/paint any text; its default fetch to
// fonts.gstatic.com is blocked here. Intercept and serve a real local font —
// any legible sans-serif .ttf works, it doesn't need to match Roboto.
const fontBuffer = fs.readFileSync('/path/to/some/Font-Regular.ttf');

const browser = await chromium.launch({
  executablePath: '/opt/pw-browsers/chromium',
  headless: true,
  args: [
    '--enable-unsafe-swiftshader',   // headless Chromium needs this for
    '--use-gl=angle',                // software WebGL — CanvasKit renders
    '--use-angle=swiftshader',       // via a WebGL context, and without
    '--ignore-gpu-blocklist',        // these flags it silently gets no
    '--disable-gpu-sandbox',         // context and paints nothing.
  ],
});
const page = await browser.newPage({ viewport: { width: 420, height: 900 } });
await page.route('**://fonts.gstatic.com/**', (route) =>
  route.fulfill({ status: 200, contentType: 'font/ttf', body: fontBuffer })
);

await page.goto('http://127.0.0.1:8765/', { waitUntil: 'load' });
// First paint under software rendering is slow — give it real time before
// the first screenshot. Subsequent interactions can use short waits.
await page.waitForSelector('flt-semantics-placeholder', { timeout: 20000 });
await page.waitForTimeout(3000);
```

### 6. Enable semantics so you can interact by role/text, not pixel guesses

Flutter web paints everything to `<canvas>` — there's no DOM to select against
until you turn semantics on. Do that once per page load, then drive the rest
of the flow like a normal web page:

```js
// The placeholder button is deliberately 1x1px off-screen (for real screen
// readers), so Playwright's actionability-checked .click() refuses it — call
// the DOM API directly instead.
await page.$eval('flt-semantics-placeholder', (el) => el.click());
await page.waitForTimeout(1500);

await page.getByText('Next', { exact: true }).click();
await page.getByLabel('Email').fill('you@example.com');
await page.getByRole('button', { name: 'Log in', exact: true }).click();
await page.getByRole('menuitem', { name: 'Share list' }).click();
```

If a locator can't find something, don't guess coordinates — dump what's
actually on screen and adjust:

```js
console.log(JSON.stringify(await page.accessibility.snapshot(), null, 1));
```

### 7. Capture and verify

```js
await page.screenshot({ path: '/scratchpad/shots/01_step.png' });
```

**Always read each PNG with the Read tool before showing it to the user or
concluding a feature works** — a screenshot that "ran without error" can still
be blank, mid-transition, or showing the wrong state.

## Cleanup

Everything here is scratch tooling, not a product change:

```bash
rm -rf apps/<app>/web apps/<app>/.gitignore apps/<app>/.metadata
git status --short   # should be clean again (or match pre-existing changes)
```

Don't commit `web/` platform scaffolding, the patched `build/` output, or the
driver script unless the user explicitly asks to keep web support.

## Notes

- This generalizes to any app in `apps/`; adjust the `getByText`/`getByLabel`/
  `getByRole` calls to the screen you're driving.
- Missing icon glyphs or a stray empty `pageerror` from the semantics-enable
  click are cosmetic/harmless under this software-rendering setup — don't
  chase them if the actual screen under review reads correctly.
- If a real device/simulator/browser display *is* available in the
  environment, skip all of this and use `run-app` instead — it's simpler and
  more representative.
