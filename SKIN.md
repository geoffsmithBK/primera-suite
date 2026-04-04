# PrimeraSkin Design Spec

**Date:** 2026-04-03
**Status:** Approved, pending implementation

## Purpose

PrimeraSkin is a dedicated skintone sculpting tool for DaVinci Resolve. It allows a colorist to isolate and manipulate skin tones in an image in order to:

- Even out a subject's skin tones
- Bring disparate skin tones of multiple subjects closer together (or push them apart)
- Adjust skin saturation, lightness/darkness, and hue

The tool operates at the clip level (last node, log-encoded camera footage) and at the group/timeline level (in a working space such as DaVinci Intermediate or ACEScct), typically placed after global luminance adjustments and chroma look-development, and before spatial/texture operations and the DRT.

## Architecture Decision: Pure HSV

### Problem with the previous implementation

The previous PrimeraSkin used OKLab/OKLCH for adjustments. OKLab's matrix math and cube-root transfer assume **linear-light input**, but PrimeraSkin always receives **log-encoded data** (camera log at clip level, DaVinci Intermediate or ACEScct at timeline level). This domain mismatch was the root cause of four reported problems:

1. **Graininess / blotchiness** — OKLab on log values produces L/a/b numbers with no perceptual meaning. Small pixel-to-pixel variations in log space get amplified non-linearly, so neighboring skin pixels that should receive near-identical adjustments don't.
2. **Weak sliders** — Chroma (C) values computed from incorrect a/b are tiny and don't map to visible colorfulness. Scaling them does almost nothing.
3. **Density overshooting** — L from log-fed OKLab doesn't track perceived lightness, so even the narrowed ±0.050 range produces wild swings.
4. **Compression barely visible** — Hue distances within skin are already tiny (~a few degrees in HSV), so the offset-based compression produced sub-pixel shifts.

### Why HSV

HSV hue is encoding-agnostic. Log encoding is a per-channel monotonic transform that preserves relative R/G/B ordering, so HSV hue angles are the same in log and linear. For the small, targeted adjustments PrimeraSkin makes (±20° hue, subtle density/saturation), HSV's lack of perceptual uniformity is invisible. PrimeraHue already demonstrates successful HSV-based hue shifting on log-encoded data.

Pure HSV eliminates the need for a Transfer Function selector, removes all domain-conversion artifacts, and ensures the mask and the adjustments operate in the same space.

### Alternatives considered

**Hybrid (HSV mask + RGB-ratio compression + HSV adjustments):** More sophisticated compression via chromatic-component lerp (explored in PrimeraSkin-2.dctl), but added complexity and the PrimeraSkin-2 experiment showed the extra controls (Strength, Chroma Limit, Width) were hard to tune. For typical compression magnitudes, the difference from simple hue-distance scaling is negligible.

**OKLab with linearization via TF selector:** Perceptually uniform but requires the user to set TF correctly, round-trip through linear amplifies noise in dark tones, and for small targeted adjustments perceptual uniformity buys almost nothing.

## Mask / Qualification

The mask qualifies pixels as "skin" via three multiplicative gates in HSV:

### Hue gate
- Center: 28° (SKIN_HUE_CENTER, normalized to 0-1 HSV)
- Half-width: 28° × Range slider value
- Falloff: smoothstep from 0 (at half-width boundary) to 1 (at center)

### Saturation gate
- Smoothstep from 0.08 to 0.35 (widened from previous 0.1→0.25)
- The wider ramp is the single biggest fix for graininess — pixels on the edge of the skin volume fade in gradually rather than snapping in/out

### Value gates (new, user-adjustable)
- **Low Gate:** slider 0.0→0.3, default 0.0. Smoothstep fades out pixels with V below this value. At default (0.0), no exclusion — all dark tones qualify.
- **High Gate:** slider 0.7→1.0, default 1.0. Smoothstep fades out pixels with V above this value. At default (1.0), no exclusion — all bright tones qualify.
- Both gates are off by default: zero baked-in assumptions about what luminance range constitutes "skin." The user decides how much to narrow. This is a deliberate design choice — many skin-targeting tools embed fixed luminance assumptions that amount to preferential treatment for certain skin tones.

### Range slider
- Range 0.25→2.0, default 1.0
- Scales the hue gate half-width: 0.25 = tight ±7°, 1.0 = default ±28°, 2.0 = broad ±56°

### Final mask
```
mask = hue_gate * sat_gate * low_gate * high_gate
```

## Adjustments

All operations in HSV, blended by mask strength. Applied to the post-mask HSV values, converted back to RGB via `hsv_to_rgb()`.

### Hue
- Rotate H: `H_new = H + mask * p_hue * (1.0/360.0)`
- Range: ±20°, step 0.1°
- Covers the full "too red" ↔ "too yellow" span with fine default sensitivity

### Saturation
- Scale S: `S_new = S * (1.0 + mask * p_saturation)`
- Range: ±0.5, step 0.001
- Positive adds color energy, negative pulls toward monochrome

### Density
- Scale V: `V_new = V * (1.0 - mask * p_density)`
- Range: ±0.2, step 0.001
- Positive = darker (denser), negative = lighter — matches photographic convention

### Evenness (compression)
- Compress hue distance from center: `H_new = center + (H - center) * (1.0 - cmask * p_evenness)`
- Range: 0.0→1.0, default 0.0, step 0.001
- At 0.0, no compression. At 1.0, all qualifying hues collapse to the center line.
- Uses a **broader mask** than the other adjustments: `skin_mask_range(r, g, b, p_range + COMPRESS_EXTRA)` where COMPRESS_EXTRA starts at 0.4 (to be tuned by eye). The broader mask catches outlier hues just outside the main skin region and pulls them in.
- The label "Evenness" is borrowed from ecology (how evenly distributed a population is across types), which maps to the control's intent: evening out the distribution of skin hues across subjects.

## Show Mask Visualization

False-color overlay rather than monochrome. The original image renders desaturated, then the masked region receives a **muted teal-sage tint** with opacity proportional to mask strength.

```
grey = desaturated pixel value (HSV with S=0)
show_r = grey * (1.0 - mask * 0.3)
show_g = grey + mask * 0.07
show_b = grey + mask * 0.05
```

### Design rationale
- Desaturated base lets the user see the image in context, not just a binary mask
- Continuous tint opacity reveals falloff behavior (how the mask fades at boundaries)
- Muted teal-sage palette inspired by the desaturated earth-tone aesthetic of *Joker* (2019, dir. Todd Phillips, DP Lawrence Sher) — sophisticated rather than diagnostic
- Deliberately distinct from PixelTools' bright green/magenta/yellow checker palette
- Favors cohesive presentation over absolute accuracy (per design requirements)
- Exact coefficients to be tuned during implementation

## UI Parameters

```
Hue              [-20.0 ... 20.0]    default 0.0   step 0.1
Saturation       [-0.5  ... 0.5]     default 0.0   step 0.001
Density          [-0.2  ... 0.2]     default 0.0   step 0.001
Range            [0.25  ... 2.0]     default 1.0   step 0.01
Evenness         [0.0   ... 1.0]     default 0.0   step 0.001
Low Gate         [0.0   ... 0.3]     default 0.0   step 0.001
High Gate        [0.7   ... 1.0]     default 1.0   step 0.001
Show Mask        [checkbox]          default off
```

### Label philosophy
Labels are expository of what the user is trying to accomplish rather than technically precise:
- **Density** — photographic vernacular the audience understands
- **Evenness** — describes the intent (evening out skin tones) rather than the mechanism (hue compression)
- **Range** — clear and concise
- **Low Gate / High Gate** — self-explanatory in context

## Build Integration

### Fragment dependency
```
PrimeraSkin: header + hsv + skintone + soft_squeeze + body
```

### Changes from current build
- **Drops:** `oklab.dctlf` (no longer needed)
- **Keeps:** `soft_squeeze.dctlf` (cheap gamut containment insurance — aggressive saturation boosts or hue rotations near gamut boundaries can push RGB out of range after HSV→RGB conversion)

### Makefile
```makefile
PrimeraSkin_FRAGS := hsv skintone soft_squeeze
```

### skintone.dctlf changes
- Widen saturation gate smoothstep from (0.1, 0.25) to (0.08, 0.35)
- Add value gate support to `skin_mask_range()` or add a new mask function that accepts low/high gate parameters
- Note: `skin_mask()` and `skin_mask_range()` are also used by PrimeraHue for skintone protection. Changes must not break that usage. The value gates should be added via a new function or optional parameters, leaving the existing functions intact.

## Constants to Tune

These values are starting points, expected to be refined through visual testing:

| Constant | Starting value | Purpose |
|---|---|---|
| Saturation gate low | 0.08 | Smoothstep lower bound |
| Saturation gate high | 0.35 | Smoothstep upper bound |
| COMPRESS_EXTRA | 0.4 | How much broader the evenness mask is vs. the adjustment mask |
| Mask tint RGB | (0.3, 0.07, 0.05) | False-color overlay coefficients |
