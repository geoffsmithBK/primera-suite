## Primera Suite

My personal suite of DaVinci Resolve DCTL color grading tools for clip-level grading and look development. Built from shared code fragments via `make`.

Most of the underlying math comes from tried-and-tested open-source DCTLs by generous members of the color grading community (see bottom). Primera consolidates the approaches I reach for most often into one place, under one name, and with only the controls I actually use.

Mu aesthetic lodestar is a "film look," in the broad sense, but I'm generally not emulating any specific stock or process, more chasing my personal "sense memories" of projected film. However, these tools are (hopefully) flexible enough to go well beyond that.


### Primera (`Primera.dctl`)

The foundation. Primary grading controls for shot-to-shot balancing:

- **Exposure** — Linear gain in photographic stops (`2^n`) applied before the selected transfer function
- **Black Point** — Smooth compression of the darkest tones approaching black (sometimes called "flare," e.g. in Baselight)
- **Temp / Tint** — White balance: Temp swings warm/cool along the black body curve, Tint swings green/magenta
- **Contrast** — Log-space stretch/squash of the tonal range around a variable **Pivot** (defaults to the transfer function's mid-grey)
- **Shadows / Highlights** — Linear gain constrained below/above mid-grey; no spatial operations so can be encoded in a 3D LUT
- **Roll Off** — `tanh` highlight compression controlling where the brightest values top out; works with Highlights to shape the shoulder
- **Neg. Saturation** — Multiplicative negative RGB gain on chroma (only darkens)
- **Pos. Saturation** — HSV saturation boost, positive only; adds "density" (darkness)
- **Preserve Luma** — weighted offset of the darkening effect from the saturation controls
- **Show Chart** — Draws a per-transfer-function curve chart a là [Walter Volpatto's example] (https://youtu.be/ymr4wyo7GcA?t=3670)
- **Transfer Function** — LogC3, LogC4, REDLog3G10, S-Log3, ACEScct, DaVinci Intermediate, Cineon (these are the ones I encounter most often day-to-day)

### Primera Hue

Per-channel hue and density control via tetrahedral interpolation, based on [hotgluebanjo]'s (https://github.com/hotgluebanjo/TetraInterp-DCTL) DCTL implementation of the approach described by Steve Yedlin ([DisplayPrep] (https://www.yedlin.net/DisplayPrepDemo/index.html), 2018).

- **6 Hue sliders** (R/Y/G/C/B/M) — Each pushes a color toward its neighbors via Rodrigues rotation around the achromatic axis. +/-60° per channel covers the full 360°.
- **6 Density sliders** — Makes the shifted color darker and subjectively more "colorful" without adding energy.
- **Preserve Luma** — Scales output to nominal level before density adjustment. Runs before Cinecolor.
- **Hard Clamp** — Clips to [0,1] before interpolation.
- **Soft Clamp** — tanh shoulder + exponential toe after interpolation for gentle gamut containment.
- **Cinecolor** — 2-strip Technicolor-like simulation via bipack-style blue-to-green blending. Named after a [budget color process] (https://www.youtube.com/watch?v=dnNeKxt0urk) (~late '30s to early '50s) that used duplitized print stock.
- **Protect Skintones** — Applies only to Cinecolor. Creates a holdout matte centered on the skin tone line (~28° on an HSV disc) with smooth falloff.

### Primera Plus (`PrimeraPlus.dctl`)
 
Primera's full control set plus PrimeraHue's tetrahedral hue/density interpolation in a single DCTL. Intended for look development (Group/Timeline nodes) or when hue shifts are needed alongside primary corrections at the clip level.

### Primera Skin

Dedicated skintone correction tool operating in the OKLCH color model. Targets a soft region of the HSV disc centered on the nominal skin tone hue (~28°) and applies perceptually uniform adjustments only within that region. Everything outside the mask passes through untouched.

- **Hue** — Rotates skin hue in OKLCH (+/-30°)
- **Saturation** — Scales chroma symmetrically; both positive and negative directions stay in OKLCH for consistent behavior with no hue shift
- **Density** — Adjusts lightness (positive = darker)
- **Range** — Widens or narrows the skin mask (0.25 = tight +/-7°, 1.0 = default +/-28°, 2.0 = broad +/-56°)

Gamut containment is done via a "soft squeeze" (`tanh` in the shoulder and exponential compression in the toe).

### Primera Split

Subtractive split-toning for imbuing shadows and highlights with independent color casts. Less an "effect" than a fundamental look development control — it defines the chromatic character of the tonal curve.

- **Pivot** — Defaults to the selected transfer function's mid-grey but should be set by eye
- **Transfer Function** — Aligns Pivot to the appropriate mid-grey
- **Show Chart** — Curve/transfer function visualization with positionable greyscale ramp

### Notes

- The Primera tools should play nicely with most DRTs (Display Rendering Transform, the final color managment pipeline stage before outputting a deliverable) but has been used/tested the most with [Jed Smith]'s (https://github.com/jedypod) [OpenDRT] (https://github.com/jedypod/open-display-transform)
- I also regularly use/test the tools with Resolve's CST, Juan-Pablo Zambrano's excellent 2499 DRT, the ACES 2.0 transforms, and occasionally LUTs
- It is possible to produce negative/out-of-range values with the Primera tools. When this happens, I reach for gamut compression first to help contain things over and above the "soft squeeze" being done in the tools themselves
- Kaur Hendriksen made a great, [free standalone DCTL] (https://store.kaurh.com) that implements the ACES 2.0 gamut compression coefficients which I can whole-heartedly recommend

### Inspiration 

There's not much particularly original with the Primera tools, as I said they're more of a curated/opinionated collection of my favorite approaches to primary grading and some aspects of look development. In no particular order, Primera owes 90%+ of its existence to the work of the following individuals:

- [Jed Smith] (https://github.com/jedypod)
- [Juan Pablo Zambrano] (https://github.com/JuanPabloZambrano)
- [Moaz Elgabry] (https://github.com/MoazElgabry)
- [Thatcher Freeman] (https://github.com/thatcherfreeman)
- [Paul Dore] (https://github.com/baldavenger)
- [Kaur Hendrikson] (https://kaurh.com)
