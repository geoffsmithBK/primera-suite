# Primera Suite

## What This Is

A suite of four DaVinci Resolve DCTL color grading tools, built from shared fragments via `make`.

## Tools

- **Primera** — Primary grading: exposure, black point, temp/tint, contrast, shadows/highlights, roll-off, saturation, chart
- **PrimeraHue** — Standalone tetrahedral hue/density with Cinecolor (2-strip Technicolor simulation) and skintone protection
- **PrimeraSkin** — OKLCH-based skintone sculpting: hue, saturation, density, range, compression, with soft-squeeze gamut containment
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
Primera:      header + luminance + hsv + tf_encode + tf_decode + chart + tone + body
PrimeraHue:   header + luminance + hsv + skintone + tetra + soft_squeeze + body
PrimeraSkin:   header + hsv + skintone + soft_squeeze + body
PrimeraSplit:  header + luminance + tf_encode + chart + body
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
- **Transfer functions**: LogC3, LogC4, REDLog3G10, S-Log3, ACEScct, DaVinci Intermediate, Cineon, F-Log2
