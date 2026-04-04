// Primera Suite — Mathematical Reference
// Compile: typst compile primera-math.typ

#set document(title: "Primera Suite — Mathematical Reference", author: "Primera Suite")
#set page(margin: (x: 1.2in, y: 1in), numbering: "1")
#set text(font: "New Computer Modern", size: 10.5pt)
#set heading(numbering: "1.1")
#set par(justify: true)
#show link: set text(fill: eastern)

#align(center)[
  #text(size: 20pt, weight: "bold")[Primera Suite]
  #v(0.3em)
  #text(size: 13pt, fill: luma(100))[Mathematical Reference]
  #v(0.5em)
  #text(size: 10pt, fill: luma(140))[v0.5.0]
]

#v(1em)

#outline(indent: 1.5em, depth: 2)

#pagebreak()

= Shared Primitives

The following operations are shared across multiple tools via code fragments.

== Luminance <luminance>

Two luminance functions are used throughout. Rec. 709 (BT.709) is the default; Rec. 2020 (BT.2020) is used in PrimeraSplit where DaVinci Wide Gamut is assumed.

$ Y_"709" = 0.2126 r + 0.7152 g + 0.0722 b $

$ Y_"2020" = 0.2627 r + 0.6780 g + 0.0593 b $

== HSV Conversion <hsv>

Standard hexagonal-model conversion between RGB and HSV. Given $C_"max" = max(r,g,b)$, $C_"min" = min(r,g,b)$, and $Delta = C_"max" - C_"min"$:

$ H = cases(
  0 &"if" Delta = 0,
  1/6 dot (g - b) / Delta &"if" C_"max" = r,
  1/6 dot ((b - r) / Delta + 2) &"if" C_"max" = g,
  1/6 dot ((r - g) / Delta + 4) &"if" C_"max" = b,
) $

with $H$ wrapped to $[0, 1)$, then:

$ S = cases(Delta slash C_"max" &"if" C_"max" > 0, 0 &"otherwise") , quad V = C_"max" $

The inverse follows the standard piecewise chroma/secondary construction.

== Soft Gamut Squeeze <soft-squeeze>

Applied per-channel. A piecewise function that compresses the shoulder via $tanh$ and the toe via exponential roll-off, keeping the mid-range on the identity. With knee $k = 0.9$ and range $r = 0.1$ for the shoulder, and toe threshold $t_0 = 0.1$:

$ f(x) = cases(
  k + r dot tanh((x - k) / r) &"if" x > k,
  t_0 dot e^(x slash t_0 - 1) &"if" x < t_0,
  x &"otherwise",
) $

The shoulder asymptotically approaches $k + r = 1.0$; the toe asymptotically approaches $0$.

== Smoothstep <smoothstep>

The Hermite basis used for all smooth interpolation (shadow/highlight blends, skintone masks, split-toning crossfade):

$ "smoothstep"(a, b, x) = t^2 (3 - 2t), quad t = "clamp"((x - a) / (b - a), 0, 1) $

== Skintone Mask <skin-mask>

Detects skin-colored pixels via an HSV-domain hue gate centered at $H_0 = 28 degree / 360 degree approx 0.0778$ with half-width $w = H_0 dot rho$ (where $rho$ is the range parameter, default 1.0):

$ d(h) = min(|h - H_0|, 1 - |h - H_0|) $

$ M_"hue"(h) = 1 - "smoothstep"(0, w, d(h)) $

$ M_"sat"(s) = "smoothstep"(0.08, 0.35, s) $

$ M_"skin"(r,g,b) = M_"hue"(H) dot M_"sat"(S) $

where $H$ and $S$ come from the HSV conversion of $(r,g,b)$.

=== Value-Gated Variant <skin-mask-gated>

PrimeraSkin uses an extended mask with additional low/high value gates that exclude very dark or very bright pixels:

$ M_"lo"(v) = cases("smoothstep"(l slash 2, l, v) &"if" l > 0.001, 1 &"otherwise") $

$ M_"hi"(v) = cases(1 - "smoothstep"(h - (1 - h)/2, h, v) &"if" h < 0.999, 1 &"otherwise") $

$ M_"gated"(r,g,b) = M_"hue"(H) dot M_"sat"(S) dot M_"lo"(V) dot M_"hi"(V) $

where $l$ and $h$ are the Low Gate and High Gate parameters, and $H$, $S$, $V$ come from the HSV conversion of $(r,g,b)$. When gates are at their defaults ($l = 0$, $h = 1$), the gated mask reduces to the standard $M_"skin"$.

#pagebreak()

= Transfer Functions <tf>

All tools that operate in log-space use a common set of encode/decode functions mapping between scene-linear and the selected log encoding. Mid-grey ($0.18$ linear) is the reference exposure throughout.

Each function below is the _encode_ direction (linear $arrow.r$ log). The decode is the algebraic inverse.

== ARRI LogC3

$ f(x) = cases(
  c dot log_10(a x + b) + d &"if" x > "cut",
  e x + f &"otherwise",
) $

with $a = 5.5556$, $b = 0.0523$, $c = 0.2472$, $d = 0.3855$, $e = 5.3677$, $f = 0.0928$, $"cut" = 0.01059$.

== ARRI LogC4

Let $a = (262144 - 16) / 117.45$, $b = (1023 - 95) / 1023$, $c = 95/1023$.

$ s = (7 ln 2 dot 2^(7 - 14c slash b)) / (a b), quad t = (2^(14(-c slash b) + 6) - 64) / a $

$ f(x) = cases(
  display((log_2(a x + 64) - 6) / 14 dot b + c) &"if" x >= t,
  (x - t) / s &"otherwise",
) $

== RED Log3G10

$ f(x) = cases(
  0.2243 dot log_10(155.9753(x + 0.01) + 1) &"if" x + 0.01 >= 0,
  15.1927(x + 0.01) &"otherwise",
) $

== Sony S-Log3

$ f(x) = cases(
  display((420 + 261.5 log_10((x + 0.01)/0.19)) / 1023) &"if" x >= 0.01125,
  display((171.21 x slash 0.01125 quad [#text(size: 8pt)[linear segment]]) / 1023) &"otherwise",
) $

#text(size: 9pt, fill: luma(120))[(The linear segment is simplified here; see source for exact coefficients.)]

== ACEScct

$ f(x) = cases(
  (log_2(x) + 9.72) / 17.52 &"if" x > 2^(-7) = 0.0078125,
  10.5402 x + 0.0729 &"otherwise",
) $

== DaVinci Intermediate

$ f(x) = cases(
  C (log_2(x + A) + B) &"if" x > "cut"_"lin",
  M x &"otherwise",
) $

with $A = 0.0075$, $B = 7$, $C = 0.07329$, $M = 10.4443$, $"cut"_"lin" = 0.002624$.

== Kodak Cineon

$ f(x) = (300 log_10(x(1 - delta) + delta) + 685) / 1023, quad delta = 0.0108 $

== Fuji F-Log2

$ f(x) = cases(
  c dot log_10(a x + b) + d &"if" x >= "cut",
  e x + f &"otherwise",
) $

with $a = 5.555556$, $b = 0.064829$, $c = 0.245281$, $d = 0.384316$, $e = 8.799461$, $f = 0.092864$, $"cut" = 0.000889$.

#pagebreak()

= Primera — Primary Grading <primera>

The primary tool applies a chain of per-channel operations in a defined order. Let $(r, g, b)$ denote the working pixel value (initially in the selected log encoding).

== Exposure

Scene-linear gain in photographic stops. The pixel is first decoded to linear, scaled, then operations continue in linear through Temp/Tint before re-encoding:

$ (r, g, b)_"lin" = 2^n dot "decode"(r, g, b) $

where $n$ is the exposure parameter in stops.

== Black Point

Smooth compression of the toe region of each channel (in linear), using an exponential roll-off below a knee:

$ "bp"(x) = cases(
  x - beta &"if" x - beta >= kappa,
  kappa dot e^((x - beta) slash kappa - 1) &"if" x > 0,
  x &"otherwise",
) $

where $beta = -p_"bp"$ (the user's Black Point slider) and $kappa = 0.005$.

== Temperature and Tint

Per-channel linear-light gains. Temperature shifts along the blue--amber axis; tint along green--magenta:

$ r' = r dot 2^(tau), quad g' = g dot 2^(phi), quad b' = b dot 2^(-tau) $

where $tau$ is the temperature parameter and $phi$ is the tint parameter. The pixel is then re-encoded to the working log space.

== Contrast <contrast>

A pivoted power function that preserves 0, 1, and the pivot point $p$. The pivot defaults to $"encode"(0.18)$ (the transfer function's mid-grey) plus a user offset. For input $x in [0, 1]$:

$ "contrast"(x) = cases(
  display(p dot (x / p)^gamma) &"if" x <= p,
  display(1 - (1 - p) dot ((1 - x) / (1 - p))^gamma) &"if" x > p,
) $

where $gamma$ is the contrast parameter. This is symmetric about the pivot: shadows and highlights are stretched/compressed equally.

== Shadow Fill

Below mid-grey $m = "encode"(0.18)$, a gain is blended from full effect at black to no effect at mid-grey, using the smoothstep basis as the crossfade:

$ t = x / m, quad s(t) = t^2(3 - 2t) $

$ "shadow"(x) = x dot (G + (1 - G) dot s(t)), quad x < m $

where $G = 2^(p_"shadows")$. Pixels at or above mid-grey pass through unchanged.

== Highlight Gain

The mirror of Shadow Fill, operating between mid-grey and 1.0:

$ t = (x - m) / (1 - m), quad s(t) = t^2(3 - 2t) $

$ "highlight"(x) = x dot (1 + (G - 1) dot s(t)), quad x > m $

where $G = 2^(p_"highlights")$.

== Roll Off (Soft Highlight)

A $tanh$-based shoulder compression above a variable knee point. The knee descends from 1.0 toward mid-grey as the amount increases; beyond amount = 1.0, a strength multiplier steepens the compression:

$ kappa = 1 - min(alpha, 1) dot (1 - m), quad sigma = 1 + max(alpha - 1, 0) dot 2 $

$ "rolloff"(x) = cases(
  kappa + (1 - kappa) dot display(tanh(sigma(x - kappa) / (1 - kappa))) / sigma &"if" x > kappa,
  x &"otherwise",
) $

where $alpha$ is the Roll Off amount and $m = "encode"(0.18)$.

== Negative Saturation

Multiplicative desaturation toward Rec. 709 luminance (log-encoded domain). With saturation factor $s in [0, 1]$:

$ c' = Y + s(c - Y), quad c in {r, g, b} $

where $Y = 0.2126 r + 0.7152 g + 0.0722 b$. At $s = 0$ the image is monochrome.

== Positive Saturation

Operates in HSV space. The S channel is boosted by a power-of-two scale:

$ S' = min(S dot 2^(p_"sat"), 1) $

then converted back to RGB.

== Luminance Preservation

An optional post-step applied after either saturation operation. Scales all channels uniformly to restore pre-adjustment luminance:

$ (r', g', b') = Y_"before" / Y_"after" dot (r, g, b) $

#pagebreak()

= PrimeraHue — Tetrahedral Hue/Density <hue>

Performs per-channel hue rotation and density adjustment via tetrahedral interpolation.

== Corner Computation (Rodrigues Rotation) <rodrigues>

Each of the six cube corners (R, G, B, C, M, Y) is rotated around the achromatic axis by a hue angle $theta = h dot 60degree$ (where $h in [-1, 1]$ is the slider value, so $plus.minus 1$ covers $plus.minus 60degree$). The rotation uses a simplified Rodrigues formula. For a corner with identity color $bold(v) = (v_r, v_g, v_b)$:

$ mu = (v_r + v_g + v_b) / 3 $

$ bold(c) = bold(v) - mu dot bold(1) $

The centred vector is rotated around the $(1,1,1)$ axis (with unit direction $bold(k) = 1/sqrt(3) dot bold(1)$):

$ bold(c') = bold(c) cos theta + 1/sqrt(3) (bold(k) times bold(c)) sin theta $

where the cross-product components reduce to:

$ c'_r = c_r cos theta + k(c_z - c_y) sin theta $
$ c'_g = c_g cos theta + k(c_x - c_z) sin theta $
$ c'_b = c_b cos theta + k(c_y - c_x) sin theta $

with $k = 1/sqrt(3) approx 0.57735$. The density offset $d$ is then added uniformly:

$ bold(v') = bold(c') + mu dot bold(1) + d dot bold(1) $

Density makes the shifted color subjectively more "colorful" without adding energy — it uniformly offsets all three channels at the given corner.

== Tetrahedral Interpolation <tetra-interp>

The RGB unit cube is decomposed into six tetrahedra by sorting the channel values. Each tetrahedron shares the black corner $(0,0,0)$ and white corner $(1,1,1)$ and includes two of the six chromatic corners. For a pixel with $r >= g >= b$ (the R--Y tetrahedron):

$ bold(o) = r dot bold(R)_c + g dot (bold(Y)_c - bold(R)_c) + b dot (bold(1) - bold(Y)_c) $

The five other sort orderings produce analogous expressions using the corresponding pair of adjacent corners. This is the same interpolation structure used in 3D LUT evaluation and described by Yedlin's DisplayPrep approach.

== Cinecolor <cinecolor>

A fixed tetrahedral remap that emulates the two-color subtractive process of Cinecolor (c. late 1930s--early 1950s). With blend parameter $t in [0, 1]$, the chromatic corners are set to:

$ bold(R)_c = (1, 0, 0), quad bold(G)_c = (0, 1, t), quad bold(B)_c = (0, 0, 1 - t) $
$ bold(C)_c = (0, 1, 1), quad bold(M)_c = (1, 0, 1 - t), quad bold(Y)_c = (1, 1, t) $

At $t = 0$ the mapping is identity; at $t = 1$ the blue channel is fully redistributed toward green and away from magenta, emulating orthochromatic film's insensitivity to red light and the resulting blue--orange palette of the duplitized print process.

== Skintone Protection

When Cinecolor is active, an optional holdout matte centered on the skin hue ($approx 28degree$) protects the blue channel from the Cinecolor remap:

$ b_"out" = b_"cinecolor" (1 - M_"skin") + b_"in" dot M_"skin" $

where $M_"skin"$ is the mask defined in @skin-mask.

#pagebreak()

= PrimeraSkin — Skintone Sculpting <skin>

Dedicated skintone adjustments operating entirely in HSV. Because HSV is a purely geometric decomposition of RGB, PrimeraSkin is encoding-agnostic — it works identically on any log-encoded timeline without requiring linearisation.

== Evenness (Hue Compression)

Before the main adjustments, an optional hue compression step pulls skin-adjacent hues toward the median skin hue $H_0$. This uses a broader mask than the other adjustments (range $+ 0.4$) to catch outlier hues at the edges:

$ d = H - H_0 quad (#text[wrapped to $(-0.5, 0.5]$]) $

$ d' = d dot (1 - alpha dot M_"gated"^*) $

$ H' = H_0 + d' $

where $alpha in [0, 1]$ is the Evenness parameter and $M_"gated"^*$ is the value-gated skin mask (@skin-mask-gated) evaluated with the broadened range.

== HSV Adjustments

All adjustments are applied in HSV within the value-gated skin mask $M$ (@skin-mask-gated):

- *Hue rotation:* $H' = H + M dot Delta H slash 360$ #h(1em) ($Delta H in [minus 20 degree, 20 degree]$)
- *Saturation:* $S' = max(S dot (1 + M dot sigma), 0)$ #h(1em) ($sigma in [-0.5, 0.5]$)
- *Density:* $V' = max(V dot (1 - M dot delta), 0)$ #h(1em) ($delta in [-0.2, 0.2]$; positive = darker)

The modified $(H', S', V')$ are converted back to RGB. A final per-channel soft squeeze (@soft-squeeze) contains the gamut.

== Show Mask Overlay

When enabled, a three-zone false-color overlay replaces the image. The signed hue distance from skin center is normalised to $[-1, 1]$:

$ z = "clamp"((H - H_0) / w, -1, 1) $

where $w = H_0 dot rho$ is the mask width. Three color zones are interpolated over a grey base:

- $z < 0$ (clockwise overshoot): red tint, intensifying with $|z|$
- $z = 0$ (in zone): gold tint
- $z > 0$ (counterclockwise overshoot): cyan tint, intensifying with $z$

An optional legend strip occupying the bottom 7.5% of the frame shows the three zone colors with labels (Gr, Sk, Rm).

#pagebreak()

= PrimeraSplit — Subtractive Split-Toning <split>

Applies zone-weighted subtractive color adjustments to shadows and highlights independently.

== Shadow/Highlight Weighting

The image luminance ($Y_"2020"$, @luminance) determines the blend between shadow and highlight zones via the smoothstep crossfade:

$ w_"shd"(x) = 1 - "smoothstep"(p - tau/2, thin p + tau/2, thin x) $

$ w_"hi"(x) = "smoothstep"(p - tau/2, thin p + tau/2, thin x) $

where $p = "encode"(0.18) + "offset"$ is the effective pivot and $tau$ is the transition softness. The two weights are complementary: $w_"shd" + w_"hi" = 1$.

== Subtractive Color Model

Each zone has six adjustment sliders: R, G, B (additive primaries) and C, M, Y (subtractive primaries). The combined adjustment vectors are:

$ bold(a)_"rgb" = w_"shd" dot bold(a)_"shd,rgb" + w_"hi" dot bold(a)_"hi,rgb" $

$ bold(a)_"cmy" = w_"shd" dot bold(a)_"shd,cmy" + w_"hi" dot bold(a)_"hi,cmy" $

For each primary, a _positive_ slider value subtracts the complementary channels (adding the color by removing its complement), while a _negative_ value subtracts the primary itself:

#align(center, table(
  columns: 3,
  stroke: 0.5pt + luma(180),
  inset: 6pt,
  align: (center, center, center),
  table.header[*Slider*][*Positive ($> 0$)*][*Negative ($< 0$)*],
  [Red $a_r$], [$g' = g(1 - a_r), quad b' = b(1 - a_r)$], [$r' = r(1 + a_r)$],
  [Green $a_g$], [$r' = r(1 - a_g), quad b' = b(1 - a_g)$], [$g' = g(1 + a_g)$],
  [Blue $a_b$], [$r' = r(1 - a_b), quad g' = g(1 - a_b)$], [$b' = b(1 + a_b)$],
  [Cyan $a_c$], [$r' = r(1 - a_c)$], [$g' = g(1 + a_c), quad b' = b(1 + a_c)$],
  [Magenta $a_m$], [$g' = g(1 - a_m)$], [$r' = r(1 + a_m), quad b' = b(1 + a_m)$],
  [Yellow $a_y$], [$b' = b(1 - a_y)$], [$r' = r(1 + a_y), quad g' = g(1 + a_y)$],
))

All six adjustments are applied multiplicatively in sequence.

== Luminance Compensation

Subtractive adjustments inherently darken the image. An estimated "subtractive impact" is computed from the adjustment magnitudes (with asymmetric weights: $0.5$ for the darkening direction, $0.33$ for the complementary), and a compensation gain is derived:

$ kappa = 1 + min(2 I, 1) $

$ (r, g, b)_"out" = (r, g, b) dot (1 + (kappa - 1) dot lambda) $

where $I$ is the total subtractive impact and $lambda in [0, 1]$ is the Preserve Luminance slider.
