## Primera Suite

A personal suite of DaVinci Resolve DCTL color grading tools for clip-level grading and look development. Built from shared code fragments via `make`.

Most of the underlying math comes from open-source DCTLs by generous members of the color grading community. Primera consolidates the approaches I reach for most into one place, with one name, and only the controls I actually use.

The aesthetic lodestar is "film look" in the broad sense — not emulating a specific stock or process, but chasing the sense memory of projected film. The tools are flexible enough to go well beyond that.


### Primera

The foundation. Primary grading controls for shot-to-shot balancing:

- **Exposure** — Linear gain in photographic stops (`2^n`) applied before the selected transfer function
- **Black Point** — Smooth compression of the darkest tones approaching black (sometimes called "flare")
- **Temp / Tint** — White balance: Temp swings warm/cool along the black body curve, Tint swings green/magenta
- **Contrast** — Log-space stretch/squash of the tonal range around a configurable **Pivot** (defaults to the transfer function's mid-grey)
- **Shadows / Highlights** — Linear gain constrained below/above mid-grey; no spatial operations, so these are LUT-encodable
- **Roll Off** — tanh highlight compression controlling where the brightest values top out; works with Highlights to shape the shoulder
- **Neg. Saturation** — Multiplicative negative RGB gain on chroma (only darkens)
- **Pos. Saturation** — HSV saturation boost (positive direction only; adds density/darkness)
- **Preserve Luma** — Offsets darkening from the saturation controls
- **Show Chart** — Draws a per-transfer-function curve chart
- **Transfer Function** — LogC3, LogC4, REDLog3G10, S-Log3, ACEScct, DaVinci Intermediate, Cineon


### Primera Plus

Primera's full control set plus PrimeraHue's tetrahedral hue/density interpolation in a single DCTL. Intended for look development (Group/Timeline nodes) or when hue shifts are needed alongside primary corrections at the clip level.


### Primera Hue

Per-channel hue and density control via tetrahedral interpolation, based on hotgluebanjo's DCTL implementation of the approach described by Steve Yedlin (DisplayPrep, 2018).

- **6 Hue sliders** (R/Y/G/C/B/M) — Each pushes a color toward its neighbors via Rodrigues rotation around the achromatic axis. +/-60° per channel covers the full 360°.
- **6 Density sliders** — Makes the shifted color darker and subjectively more "colorful" without adding energy.
- **Preserve Luma** — Scales output to nominal level before density adjustment. Runs before Cinecolor.
- **Hard Clamp** — Clips to [0,1] before interpolation.
- **Soft Clamp** — tanh shoulder + exponential toe after interpolation for gentle gamut containment.
- **Cinecolor** — 2-strip Technicolor simulation via bipack-style blue-to-green blending. Named after the budget color process (1940-1951) that used duplitized print stock.
- **Protect Skintones** — Applies only to Cinecolor. Creates a holdout matte centered on the skin tone line (~28° on an HSV disc) with smooth falloff.


### Primera Skin

Dedicated skintone correction tool operating in OKLCH. Targets a soft region of the HSV disc centered on the nominal skin tone hue (~28°) and applies perceptually uniform adjustments only within that region. Everything outside the mask passes through untouched.

- **Hue** — Rotates skin hue in OKLCH (+/-30°)
- **Saturation** — Scales chroma symmetrically; both positive and negative directions stay in OKLCH for consistent behavior with no hue shift
- **Density** — Adjusts lightness (positive = darker)
- **Range** — Widens or narrows the skin mask (0.25 = tight +/-7°, 1.0 = default +/-28°, 2.0 = broad +/-56°)

Gamut containment via soft squeeze (tanh shoulder, exponential toe).


### Primera Split

Subtractive split-toning for imbuing shadows and highlights with independent color casts. Less an "effect" than a fundamental look development control — it defines the chromatic character of the tonal curve.

- **Pivot** — Defaults to the selected transfer function's mid-grey but should be set by eye
- **Transfer Function** — Aligns Pivot to the appropriate mid-grey
- **Show Chart** — Curve/transfer function visualization with positionable greyscale ramp
