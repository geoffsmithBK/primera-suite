# Primera Suite

## What This Is

A suite of four DaVinci Resolve DCTL color grading tools, built from shared fragments via `make`.

## Tools

- **Primera** — Primary grading: exposure, black point, temp/tint, contrast, shadows/highlights, roll-off, saturation, chart
- **PrimeraHue** — Standalone tetrahedral hue/density with Cinecolor (2-strip Technicolor simulation) and skintone protection
- **PrimeraSkin** — HSV-based skintone sculpting: hue, saturation, density, range, evenness, low/high gate, with soft-squeeze gamut containment
- **PrimeraSplit** — Subtractive split toning with TF-aware mid-grey pivot

## Build System

Standalone `.dctl` files are assembled by `cat`-concatenating fragments. No `#include` — Resolve's `#include` caching is unreliable.

```
make              # Build into ./Primera/
make dev          # Build into ./0_Primera/ (sorts first in Resolve's DCTL dropdown)
make install      # Build + copy Primera/ to Resolve LUT folder
make install-dev  # Build + copy 0_Primera/ to Resolve LUT folder
make clean        # Remove both output dirs
```

### File conventions

- `.dctl` — Final Resolve-ready executables (build output only, never committed)
- `.dctlf` — Shared fragments in `src/frag/` (not independently runnable)
- `.dctlc` — Per-tool core files in `src/<Tool>/` (header + body, not independently runnable)

### Fragment dependency map

```
Primera:      header + luminance + hsv + tf_encode + tf_decode + glyphs + chart + tone + body
PrimeraHue:   header + luminance + hsv + skintone + tetra + soft_squeeze + body
PrimeraSkin:  header + hsv + skintone + soft_squeeze + glyphs + body
PrimeraSplit: header + luminance + tf_encode + glyphs + chart + body
```

## DCTL Constraints (Resolve / Metal)

These are hard-won lessons from debugging Resolve's DCTL compiler on macOS Metal:

1. **Never return a user-defined function call from `transform()`.**
   Resolve's parser rejects `return my_func(...)` in the main `transform()` entry point — it only recognizes `return make_float3(...)` or `return variable;`. Always assign to a `float3` variable first:
   ```c
   // BAD — Resolve error: "return value must be float3"
   return render_chart(p_Width, p_Height, p_X, p_Y, p_tf);

   // GOOD
   float3 chart = render_chart(p_Width, p_Height, p_X, p_Y, p_tf);
   return chart;
   ```

2. **Use float3 returns, not pointer parameters.**
   Metal device functions don't support bare pointers. Use `__DEVICE__ float3 func(...)` return style, never `__DEVICE__ void func(..., float *out)`.

3. **DEFINE_UI_PARAMS combo boxes can't dynamically update other widgets.**
   Selecting a transfer function can't change an adjacent slider's displayed value. Use offset models (slider defaults to 0.0) with Show Chart for visual verification.

## Code Patterns

- **Tetrahedral interpolation**: 6 tetrahedra along RGB cube diagonal. Used in PrimeraHue for hue/density shifts.
- **Cinecolor**: 2-strip Technicolor via tetra interpolation — blends B toward G: `B_out = (1-t)*B + t*G`
- **Skintone mask**: HSV-based soft mask (hue gate 28° center, 28° width × saturation smoothstep 0.1→0.25). Used as protection in PrimeraHue and as a chroma weight in PrimeraSkin's Saturation slider
- **Soft squeeze**: tanh shoulder at 0.9 + exponential toe at 0.1 for gamut containment
- **Transfer functions**: LogC3, LogC4, REDLog3G10, S-Log3, ACEScct, DaVinci Intermediate, Cineon, F-Log2, V-Log

## Vercel Landing Page

A static landing page (`index.html` + `favicon.svg`) lives in the repo root and is deployed via Vercel, which watches `main`. Pushing to `main` triggers an automatic redeploy.

- **Preview URL**: `https://primera-git-main-geoff-smiths-projects-4ad51103.vercel.app`
- **Target domain**: `primera.geoff-smith.net` — domain transfer from Squarespace initiated 2026-05-02, waiting on auth code. OG/Twitter meta tags already reference this domain.
- **Images**: served from `/img/` (committed to repo, deployed with the page — no external CDN dependency)
- **Download button**: links directly to `https://github.com/geoffsmithBK/primera-suite/releases/latest/download/Primera.zip` (evergreen via GitHub's `/releases/latest/download/` pattern)
- **Version number** (`v0.5.0`) is hardcoded in the version strip and footer — update manually on each release, or automate via a GitHub Actions workflow triggered on `release.published`
- **Pushing from a worktree**: if `main` is checked out in the primary worktree, use `git push origin <branch>:main` rather than checking out main

## Uncommitted WIP (as of 2026-05-02)

The main worktree (`/Users/gsmith/work/primera-suite`) has unstaged modifications to `src/frag/skintone.dctlf`, `Primera/PrimeraSkin.dctl`, and `Primera/PrimeraHue.dctl` — pending a Resolve test before commit:

1. **Chromaticity-based skin detection** — `skin_mask_gated` replaces the HSV saturation gate with rg-chromaticity ratios (`rn = r/sum`, `gn = g/sum`, `bn = b/sum`). Motivation: HSV saturation collapses on dark/overexposed log pixels; chromaticity is brightness-invariant. Hue gate and Low/High Gate sliders are preserved.
2. **Hue slider direction fix** (PrimeraSkin only) — flips sign on hue rotation so slider direction matches the Show Mask legend (left = cyan, right = magenta).
