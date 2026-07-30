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
  #text(size: 10pt, fill: luma(140))[v0.6.0]
]

#v(1em)

#align(center)[
  #block(width: 85%, inset: 8pt, stroke: 0.5pt + luma(200), radius: 3pt)[
    #set text(size: 9pt, fill: luma(80))
    #set par(justify: false)
    This document describes what the code does, not what it ought to do. Where a
    formulation is a deliberate approximation or carries a known artefact, that is
    stated rather than smoothed over.
  ]
]

#v(1em)

#outline(indent: 1.5em, depth: 2)

#pagebreak()

= Shared Primitives

The following operations are shared across multiple tools via code fragments.
Each tool is assembled by concatenating the fragments it needs, so a tool only
carries the primitives it actually uses.

== Luminance <luminance>

Two luminance functions are used throughout. Rec. 709 (BT.709) is the default;
Rec. 2020 (BT.2020) is used in PrimeraSplit where DaVinci Wide Gamut is assumed.

$ Y_"709" = 0.2126 r + 0.7152 g + 0.0722 b $

$ Y_"2020" = 0.2627 r + 0.6780 g + 0.0593 b $

== HSV Conversion <hsv>

Standard hexagonal-model conversion between RGB and HSV. Given $C_"max" =
max(r,g,b)$, $C_"min" = min(r,g,b)$, and $Delta = C_"max" - C_"min"$:

$ H = cases(
  0 &"if" Delta = 0,
  1/6 dot (g - b) / Delta &"if" C_"max" = r,
  1/6 dot ((b - r) / Delta + 2) &"if" C_"max" = g,
  1/6 dot ((r - g) / Delta + 4) &"if" C_"max" = b,
) $

with $H$ wrapped to $[0, 1)$, then:

$ S = cases(Delta slash C_"max" &"if" C_"max" > 0, 0 &"otherwise") , quad V = C_"max" $

The inverse follows the standard piecewise chroma/secondary construction.

No clamping is applied in either direction. For a pixel with $C_"min" < 0 <
C_"max"$ — possible in a wide-gamut working space — this yields $S > 1$, and the
inverse reconstructs the original triple exactly, since the achromatic offset
$m = V - V S = C_"min"$ carries the negative part through. Hue rotations
performed in this extended space therefore stay bounded within
$[C_"min", C_"max"]$ rather than diverging. A pixel with $C_"max" <= 0$ has no
recoverable hue and is treated as achromatic.

== Soft Gamut Squeeze <soft-squeeze>

Applied per-channel. A piecewise function that compresses the shoulder via
$tanh$ and the toe via exponential roll-off, keeping the mid-range on the
identity. With knee $k = 0.9$ and range $r = 0.1$ for the shoulder, and toe
threshold $t_0 = 0.1$:

$ f(x) = cases(
  k + r dot tanh((x - k) / r) &"if" x > k,
  t_0 dot e^(x slash t_0 - 1) &"if" x < t_0,
  x &"otherwise",
) $

The shoulder asymptotically approaches $k + r = 1.0$; the toe asymptotically
approaches $0$. PrimeraSkin applies a mask-scaled variant (@masked-squeeze).

== Smoothstep <smoothstep>

The Hermite basis used for all smooth interpolation (shadow/highlight blends,
skintone masks, split-toning crossfade):

$ "smoothstep"(a, b, x) = t^2 (3 - 2t), quad t = "clamp"((x - a) / (b - a), 0, 1) $

== Skintone Masks <skin-mask>

Two distinct masks exist, and they do not share a detection strategy. The
HSV-domain mask (@skin-mask-hsv) is used by PrimeraHue for Cinecolor holdout;
the chromaticity-domain mask (@skin-mask-gated) is used throughout PrimeraSkin.
Both are anchored at the nominal skin hue

$ H_0 = 28 degree slash 360 degree approx 0.0778, quad
  W_0 = 28 degree slash 360 degree, quad
  w = W_0 dot rho $

where $rho$ is the user's Range parameter (default $1.0$), and both use the
wrapped hue distance

$ d(h) = min(|h - H_0|, 1 - |h - H_0|) . $

=== HSV Mask <skin-mask-hsv>

A hue gate multiplied by an HSV saturation gate:

$ M_"hue"(h) = 1 - "smoothstep"(0, w, d(h)) $

$ M_"sat"(s) = "smoothstep"(0.08, 0.35, s) $

$ M_"hsv"(r,g,b) = M_"hue"(H) dot M_"sat"(S) $

with $M_"hsv" = 0$ where $S < 10^(-6)$ or $V < 10^(-6)$. PrimeraHue calls this
with $rho = 1$.

=== Chromaticity Mask, Value-Gated <skin-mask-gated>

PrimeraSkin detects skin in *rg-chromaticity* rather than by HSV saturation.
Normalising by the channel sum removes overall brightness, so the surviving
ratios describe the reflectance rather than the exposure — which is what makes a
single gate work across fair and dark skin instead of tracking lightness. In
log-space, skin clusters tightly around $g_n approx 0.33$ with red leading blue.
With $Sigma = r + g + b$ (and the mask defined as $0$ when $Sigma < 0.01$):

$ r_n = r / Sigma, quad g_n = g / Sigma, quad b_n = b / Sigma $

$ M_(g_n) = "smoothstep"(0.22, 0.33, g_n) dot
            (1 - "smoothstep"(0.37, 0.48, g_n)) $

$ M_(r b) = "smoothstep"(0, 0.04, r_n - b_n) $

$ M_"chroma" = M_(g_n) dot M_(r b) $

The ramp widths above are deliberately wide. Narrow ramps sharpen the mask edge,
which sounds desirable but makes the Density slider blotchy: the gate then
resolves grain as structure.

Two value gates give the user Low Gate ($l$) and High Gate ($h$) control, for
holding off crushed shadows and specular highlights:

$ M_"lo"(v) = cases("smoothstep"(l slash 2, thin l, thin v) &"if" l > 0.001, 1 &"otherwise") $

$ M_"hi"(v) = cases(1 - "smoothstep"(h - (1 - h)/2, thin h, thin v) &"if" h < 0.999, 1 &"otherwise") $

The hue gate is retained on top of the chromaticity gate so that Range remains a
meaningful user control:

$ M_"gated"(r,g,b) = M_"hue"(H) dot M_"chroma" dot M_"lo"(V) dot M_"hi"(V) $

where $H$ and $V$ come from the HSV conversion of $(r,g,b)$.

#pagebreak()

= Transfer Functions <tf>

All tools that operate in log-space use a common set of encode/decode functions
mapping between scene-linear and the selected log encoding. Mid-grey ($0.18$
linear) is the reference exposure throughout.

Each function below is the _encode_ direction (linear $arrow.r$ log). The decode
is the algebraic inverse.

== ARRI LogC3

$ f(x) = cases(
  c dot log_10(a x + b) + d &"if" x > "cut",
  e x + f &"otherwise",
) $

with $a = 5.555556$, $b = 0.052272$, $c = 0.247190$, $d = 0.385537$,
$e = 5.367655$, $f = 0.092809$, $"cut" = 0.010591$.

== ARRI LogC4

Let $a = (262144 - 16) / 117.45$, $b = (1023 - 95) / 1023$, $c = 95/1023$.

$ s = (7 ln 2 dot 2^(7 - 14c slash b)) / (a b), quad t = (2^(14(-c slash b) + 6) - 64) / a $

$ f(x) = cases(
  display((log_2(a x + 64) - 6) / 14 dot b + c) &"if" x >= t,
  (x - t) / s &"otherwise",
) $

== RED Log3G10

$ f(x) = cases(
  0.224282 dot log_10(155.975327(x + 0.01) + 1) &"if" x + 0.01 >= 0,
  15.1927(x + 0.01) &"otherwise",
) $

== Sony S-Log3

$ f(x) = cases(
  display((420 + 261.5 log_10((x + 0.01) slash 0.19)) / 1023) &"if" x >= 0.01125,
  display((x (171.2102946929 - 95) slash 0.01125 + 95) / 1023) &"otherwise",
) $

== ACEScct

$ f(x) = cases(
  (log_2(x) + 9.72) / 17.52 &"if" x > 2^(-7) = 0.0078125,
  10.5402377 x + 0.0729055 &"otherwise",
) $

== DaVinci Intermediate

$ f(x) = cases(
  C (log_2(x + A) + B) &"if" x > "cut"_"lin",
  M x &"otherwise",
) $

with $A = 0.0075$, $B = 7$, $C = 0.07329248$, $M = 10.44426855$,
$"cut"_"lin" = 0.00262409$.

== Kodak Cineon

$ f(x) = (300 log_10(x(1 - delta) + delta) + 685) / 1023, quad delta = 0.0108 $

== Fuji F-Log2

$ f(x) = cases(
  c dot log_10(a x + b) + d &"if" x >= "cut",
  e x + f &"otherwise",
) $

with $a = 5.555556$, $b = 0.064829$, $c = 0.245281$, $d = 0.384316$,
$e = 8.799461$, $f = 0.092864$, $"cut" = 0.000889$.

== Panasonic V-Log

$ f(x) = cases(
  c dot log_10(x + b) + d &"if" x >= 0.01,
  5.6 x + 0.125 &"otherwise",
) $

with $b = 0.00873$, $c = 0.241514$, $d = 0.598206$.

#pagebreak()

= Primera — Primary Grading <primera>

The primary tool applies a chain of per-channel operations in a fixed order. Let
$(r, g, b)$ denote the working pixel value, initially in the selected log
encoding. The chain is: decode $arrow.r$ exposure $arrow.r$ black point
$arrow.r$ temp/tint $arrow.r$ encode $arrow.r$ contrast $arrow.r$ shadows
$arrow.r$ highlights $arrow.r$ roll-off $arrow.r$ negative saturation $arrow.r$
positive saturation. Exposure through temp/tint are therefore linear-light
operations; everything after the re-encode is a log-domain operation.

== Exposure

Scene-linear gain in photographic stops:

$ (r, g, b)_"lin" = 2^n dot "decode"(r, g, b) $

where $n in [-6, 6]$ is the exposure parameter in stops.

== Black Point

Smooth compression of the toe region of each channel (in linear), using an
exponential roll-off below a knee:

$ "bp"(x) = cases(
  x - beta &"if" x - beta >= kappa,
  kappa dot e^((x - beta) slash kappa - 1) &"if" x > 0,
  x &"otherwise",
) $

where $beta = -p_"bp"$ (the user's Black Point slider, $plus.minus 0.05$) and
$kappa = 0.005$.

== Temperature and Tint

Per-channel linear-light gains. Temperature shifts along the blue--amber axis;
tint along green--magenta:

$ r' = r dot 2^(tau), quad g' = g dot 2^(phi), quad b' = b dot 2^(-tau) $

where $tau$ is the temperature parameter and $phi$ is the tint parameter. The
pixel is then re-encoded to the working log space.

== Contrast <contrast>

A pivoted power function that preserves $0$, $1$, and the pivot point $p$. The
pivot defaults to $"encode"(0.18)$ (the transfer function's mid-grey) plus a user
offset, clamped to $[0.01, 0.99]$. For input $x in [0, 1]$:

$ "contrast"(x) = cases(
  display(p dot (x / p)^gamma) &"if" x <= p,
  display(1 - (1 - p) dot ((1 - x) / (1 - p))^gamma) &"if" x > p,
) $

where $gamma in [0.5, 2]$ is the contrast parameter. This is symmetric about the
pivot: shadows and highlights are stretched or compressed equally. Values outside
$[0,1]$ pass through unchanged.

== Shadow Fill

Below mid-grey $m = "encode"(0.18)$, a gain is blended from full effect at black
to no effect at mid-grey, using the smoothstep basis as the crossfade:

$ t = x / m, quad s(t) = t^2(3 - 2t) $

$ "shadow"(x) = x dot (G + (1 - G) dot s(t)), quad 0 < x < m $

where $G = 2^(p_"shadows")$. Pixels at or above mid-grey pass through unchanged.

== Highlight Gain

The mirror of Shadow Fill, operating between mid-grey and $1.0$:

$ t = (x - m) / (1 - m), quad s(t) = t^2(3 - 2t) $

$ "highlight"(x) = x dot (1 + (G - 1) dot s(t)), quad m < x < 1 $

where $G = 2^(p_"highlights")$.

== Roll Off (Soft Highlight)

A $tanh$-based shoulder compression above a variable knee point. The knee
descends from $1.0$ toward mid-grey as the amount increases; beyond amount
$= 1.0$, a strength multiplier steepens the compression:

$ kappa = 1 - min(alpha, 1) dot (1 - m), quad sigma = 1 + max(alpha - 1, 0) dot 2 $

$ "rolloff"(x) = cases(
  kappa + (1 - kappa) dot display(tanh(sigma(x - kappa) / (1 - kappa))) / sigma &"if" x > kappa,
  x &"otherwise",
) $

where $alpha in [0, 2]$ is the Roll Off amount and $m = "encode"(0.18)$.

== Negative Saturation

Multiplicative desaturation toward Rec. 709 luminance, in the log-encoded
domain. With saturation factor $s in [0, 1]$ (default $1$, i.e. no change):

$ c' = Y + s(c - Y), quad c in {r, g, b} $

where $Y = Y_"709"(r,g,b)$. At $s = 0$ the image is monochrome. The operation is
skipped entirely if any channel is negative, since the luminance reference is not
meaningful there.

== Positive Saturation

Operates in HSV space. The S channel is boosted by a power-of-two scale and
clipped:

$ S' = min(S dot 2^(p_"sat"), 1) $

then converted back to RGB. As above, skipped if any channel is negative.

== Luminance Preservation

An optional post-step (checkbox) applied after either saturation operation.
Scales all channels uniformly to restore pre-adjustment luminance:

$ (r', g', b') = Y_"before" / Y_"after" dot (r, g, b) $

applied only where both luminances are positive.

#pagebreak()

= PrimeraHue — Tetrahedral Hue/Density <hue>

Performs per-channel hue rotation and density adjustment via tetrahedral
interpolation. The order of operations is: corner computation $arrow.r$ optional
hard squeeze of the corners $arrow.r$ interpolation $arrow.r$ luminance
preservation $arrow.r$ Cinecolor $arrow.r$ optional soft squeeze.

Tetrahedral interpolation is only defined on the unit cube, so *any pixel with a
channel outside $[0,1]$ is returned unmodified*. The tool expects a log-encoded
signal, not scene-linear.

== Corner Computation (Rodrigues Rotation) <rodrigues>

Each of the six cube corners (R, G, B, C, M, Y) is rotated around the achromatic
axis by a hue angle $theta = h dot 60degree$ (where $h in [-1, 1]$ is the slider
value, so $plus.minus 1$ covers $plus.minus 60degree$). For a corner with
identity color $bold(v) = (v_r, v_g, v_b)$:

$ mu = (v_r + v_g + v_b) / 3, quad bold(c) = bold(v) - mu bold(1) $

The centred vector is rotated around the $(1,1,1)$ axis. Because $bold(c)$ is
already perpendicular to that axis, the general Rodrigues formula collapses to
its first two terms, with the cross product reducing to differences of
components:

$ c'_r = c_r cos theta + k(c_b - c_g) sin theta $
$ c'_g = c_g cos theta + k(c_r - c_b) sin theta $
$ c'_b = c_b cos theta + k(c_g - c_r) sin theta $

with $k = 1 slash sqrt(3) approx 0.57735$. The density offset $d$ is then added
uniformly:

$ bold(v') = bold(c') + (mu + d) bold(1) $

Density makes the shifted color subjectively more "colorful" without adding
energy — it uniformly offsets all three channels at the given corner.

The *hard squeeze* option clamps each rotated corner to $[0,1]$ at this point,
before interpolation. It acts on the corner definitions, not on the pixel.

== Tetrahedral Interpolation <tetra-interp>

The RGB unit cube is decomposed into six tetrahedra by sorting the channel
values. Each tetrahedron shares the black corner $(0,0,0)$ and white corner
$(1,1,1)$ and includes two of the six chromatic corners. For a pixel with
$r >= g >= b$ (the R--Y tetrahedron):

$ bold(o) = r bold(R)_c + g (bold(Y)_c - bold(R)_c) + b (bold(1) - bold(Y)_c) $

The five other sort orderings produce analogous expressions using the
corresponding pair of adjacent corners. This is the same interpolation structure
used in 3D LUT evaluation and described by Yedlin's DisplayPrep approach.

== Cinecolor <cinecolor>

A fixed tetrahedral remap that emulates the two-color subtractive process of
Cinecolor (c. late 1930s--early 1950s). With blend parameter $t in [0, 1]$, the
chromatic corners are set to:

$ bold(R)_c = (1, 0, 0), quad bold(G)_c = (0, 1, t), quad bold(B)_c = (0, 0, 1 - t) $
$ bold(C)_c = (0, 1, 1), quad bold(M)_c = (1, 0, 1 - t), quad bold(Y)_c = (1, 1, t) $

At $t = 0$ the mapping is identity; at $t = 1$ the blue channel is fully
redistributed toward green and away from magenta, emulating orthochromatic film's
insensitivity to red light and the resulting blue--orange palette of the
duplitized print process. The pixel is hard-clamped to $[0,1]$ for this stage
regardless of the hard squeeze setting.

== Skintone Protection

When Cinecolor is active, an optional holdout matte centered on the skin hue
protects the blue channel — and only the blue channel, since that is the only one
Cinecolor redistributes:

$ b_"out" = b_"cinecolor" (1 - M_"hsv") + b_"in" dot M_"hsv" $

where $M_"hsv"$ is the HSV mask of @skin-mask-hsv, evaluated on the clamped
pixel.

#pagebreak()

= PrimeraSkin — Skintone Sculpting <skin>

Dedicated skintone adjustments operating in HSV, gated by the chromaticity mask
of @skin-mask-gated. Because both HSV and rg-chromaticity are purely geometric
decompositions of RGB, PrimeraSkin is encoding-agnostic in form — but the gate
thresholds were tuned against log-encoded material, so it expects a log timeline
in practice.

Unlike the other three tools, PrimeraSkin uses the *texture* variant of the DCTL
entry point, giving it access to neighbouring pixels. That access exists for one
reason: the mask is otherwise a pure function of a single pixel's RGB, which is
the root of the graininess discussed in @pooling.

The order of operations is:

+ Evenness hue compression (unpooled, broadened mask)
+ Own mask $m_"own" = M_"gated"$ on the possibly-Evenness-adjusted pixel
+ Spatial pooling $arrow.r$ effective mask $m$ (@pooling)
+ Separation gate mask $m_"sep"$ (@separation)
+ Hue / Saturation / Density adjustments, scaled by $m$
+ Legend strip, then Show Mask overlay (either returns early)
+ Separation hue field
+ Mask-scaled soft squeeze

== Evenness (Hue Compression)

An optional hue compression step pulls skin-adjacent hues toward the median skin
hue $H_0$, emulating the evening-out of skintones done by hair and makeup on set.
It uses a broadened mask (range $rho + 0.4$) to catch outlier hues at the edges:

$ d = H - H_0 quad (#text[wrapped to $(-0.5, 0.5]$]) $

$ d' = d (1 - alpha dot M_"gated"^*), quad H' = H_0 + d' $

where $alpha in [0, 1]$ is the Evenness parameter and $M_"gated"^*$ is the mask of
@skin-mask-gated evaluated with the broadened range. This step is deliberately
*not* pooled: it is hue compression rather than a level adjustment, so it does not
exhibit the artefact that motivates pooling, and pooling it would double the tap
cost for no benefit.

== Spatial Mask Pooling (Soften) <pooling>

The per-pixel mask is a pure function of one pixel's RGB. Sensor grain therefore
dithers borderline skin pixels back and forth across the gate edges, leaving a
stochastic salt of under-adjusted pixels inside otherwise solid skin — visible as
a pointillist texture when Density is pushed. The artefact is spatial, so the fix
must be spatial.

Let $R = p_"soften" dot W dot 0.004$ be the pooling radius in pixels ($W$ = frame
width, giving $approx 15$px at UHD and full strength — resolution-independent by
construction). The mask is sampled over a sparse pattern of the centre plus three
concentric rings of $N_i = (8, 12, 16)$ taps at radii $rho_i = (1/3, 2/3, 1) dot R$.
Each ring's starting phase is offset by the golden angle
$Phi approx 2.39996$ rad so that taps never align on image axes, which would
produce directional banding:

$ (x_(i j), y_(i j)) = (X + rho_i cos(i Phi + (2 pi j) / N_i),
                        thin Y + rho_i sin(i Phi + (2 pi j) / N_i)) $

Each tap carries a spatial Gaussian weight and a loose bilateral term in
rg-chromaticity, so that pooling does not drag in a background of a different
colour. With $sigma_s = R slash 2$, $sigma_c = 0.06$, and chromaticity
coordinates $g_n = g slash Sigma$, $delta_n = (r - b) slash Sigma$:

$ w_"spatial"(i) = e^(-rho_i^2 slash 2 sigma_s^2) $

$ w_"sim" = exp(-((g_n^"tap" - g_n^"ctr")^2 + (delta_n^"tap" - delta_n^"ctr")^2)
                 slash 2 sigma_c^2) $

The centre tap enters with weight $1$ and the pooled estimate is the weighted
mean

$ m_"pool" = (m_"own" + sum_(i,j) w_(i j) thin M_"gated" (bold(p)_(i j)))
             / (1 + sum_(i,j) w_(i j)) $

which is then combined with the pixel's own mask by a *soft union* rather than a
replacement:

$ m = 1 - (1 - m_"own")(1 - m_"pool") $

This is the load-bearing choice. Because $m >= max(m_"own", m_"pool")$, pooling
can only *raise* the mask: it fills the grain holes it was introduced to fix and
can never erode a confident edge. At $p_"soften" = 0$ no taps are made at all and
the tool is bit-identical to its per-pixel form.

== HSV Adjustments

All three adjustments are applied in HSV, scaled by the effective mask $m$:

- *Hue rotation:* $H' = H - m dot Delta H slash 360$ #h(1em) ($Delta H in [minus 20degree, 20degree]$)
- *Saturation:* $S' = max(S (1 + m sigma), 0)$ #h(1em) ($sigma in [-0.5, 0.5]$)
- *Density:* $V' = max(V (1 - m delta), 0)$ #h(1em) ($delta in [-0.2, 0.2]$; positive = darker)

The sign of the hue rotation matches the legend and overlay convention: negative
slider values move toward green, positive toward magenta.

== Separation (Inverse-Mask Colour Contrast) <separation>

Separation acts on everything the rest of the tool ignores. It defines a smooth
vector field on the hue circle with a stable attractor at the complement of the
skin vector and an unstable equilibrium at the skin hue itself:

$ h_c = H_0 + 1/2 quad (approx 208degree, "the cyan/teal band") $

$ Delta h = -omega dot K dot sin(2 pi (h - h_c)), quad K = 0.075 $

The sinusoidal form is chosen over a naive "rotate toward the target by the
shortest path" for two reasons. First, skin sits at the field's zero, so
skin-hued pixels receive no push *before* any mask is applied. Second, naive
rotation tears the hue circle at the target's antipode — which is precisely the
skin hue — sending adjacent pixels in opposite directions around the circle; the
sinusoidal field is smooth there instead. The field reaches its maximum
$K = 0.075$ (a $27degree$ shift, capping migration at roughly $30%$) at the
$90degree$ flanks, $118degree$ and $298degree$.

The gate weight is

$ omega = p_"sep" dot (1 - m_"sep") dot "smoothstep"(0.08, 0.35, S)
          dot "smoothstep"(0.01, 0.05, V) $

Each factor answers a specific failure of the naive inverse mask:

/ $(1 - m_"sep")$: $m_"sep"$ must be a *pooled* mask. Inverting the raw per-pixel
  mask would not merely skip grain-dithered borderline skin pixels — it would
  actively push them toward teal, producing cyan stippling inside faces. Since
  the soft union of @pooling can only raise the mask, it can only lower its
  inverse, so pooling can never let the push leak inward. Accordingly the gate
  pools at $max(p_"soften", 0.5)$, independently of whether Soften itself is in
  use, and never writes back to $m$.

/ Chroma weight: $1 - m$ includes neutrals, which have no business migrating to
  teal. Weighting by saturation makes the operation *redistribute* colour that is
  already present rather than inventing it.

/ Value ramp: $M_"gated"$ returns $0$ for $Sigma < 0.01$, which inverts to a full
  push on near-blacks. Since $Sigma < 0.01$ implies $V <= 0.01$, this ramp closes
  that hole exactly.

The field is evaluated on the pixel's *native* hue — its value before the Hue and
Evenness adjustments — so that the repeller stays anchored to real skin even when
those controls have rotated masked pixels away from $H_0$.

Because the operation is a pure hue rotation at constant $S$ and $V$, it cannot
leave the range spanned by the original channels and needs no containment of its
own.

*Known artefact.* Reds sit on the magenta flank of the repeller and drift the
long way round: crimson at $355degree$ takes $-14.7degree$ on an unmasked
saturated pixel at full strength, landing near $340degree$. This is the classic
teal-and-orange casualty and it arrives at roughly half the available dose. No
protection notch is applied, since one would also flatten the field for the warm
practicals and skin-adjacent wood and beige that the effect exists to move.

== Mask-Scaled Gamut Squeeze <masked-squeeze>

The final squeeze is scaled by the mask rather than applied flat:

$ c_"out" = c + min(4m, 1) dot (f(c) - c), quad c in {r,g,b} $

with $f$ the soft squeeze of @soft-squeeze. The reasoning: the squeeze exists to
contain adjustment overshoot, and adjustment magnitude already scales with $m$,
so a pixel only faintly pooled into the mask should not receive the full shoulder
and toe. Without this, Soften paints a visible squeeze halo around subjects
against bright or dark backgrounds. The gain of $4$ reaches full squeeze by
$m = 0.25$, leaving core-skin behaviour unchanged.

== Show Mask Overlay and Legend

Both the overlay and the legend are renderings of a single zone function, so the
strip is a closed-form key to what the overlay does. The signed hue distance from
skin centre is normalised by the mask width:

$ z = "clamp"(d_"signed" (H) / w, -1, 1) $

Zone colour is a per-channel gain applied to a base colour, continuous at
$z = 0$:

$ bold(g)(z) = cases(
  (1.4, thin 1.3 - 0.8|z|, thin 0.5 + 0.8|z|) &"if" z <= 0,
  (1.4 - 0.9z, thin 1.3, thin 0.5 + 0.8z) &"if" z > 0,
) $

$ "zone"(z, bold(v))_c = v_c dot g_c (z), quad c in {r, g, b} $

so $z < 0$ (hue clockwise of skin centre) reads magenta, $z = 0$ gold, and
$z > 0$ (counter-clockwise) reads green/cyan.

For the *overlay*, the base is the pixel's own value $bold(v) = (V, V, V)$, so
the false colour rides on image luminance, and the blend uses the squared mask:

$ bold(c)_"out" = V bold(1) + m^2 ("zone"(z, V bold(1)) - V bold(1)) $

Squaring compresses marginal matches toward grey while keeping confident skin
vivid. Zone classification uses the *original* pixel hue so that the overlay
stays stable as the Hue slider moves, while the mask strength is taken from the
adjusted pixel so the overlay still responds to the sliders.

For the *legend*, the base is a fixed representative skin value $(0.55, 0.42,
0.25)$ and $z$ is swept linearly across the bottom $7.5%$ of frame,
$z = 1 - 2 x_n$, so the strip reads GREEN $arrow.r$ SKIN $arrow.r$ MAG. from left
to right — matching the direction of the Hue slider.

Show Mask returns before Separation is applied: it is a readout of the skin mask,
not a preview of the graded result.

#pagebreak()

= PrimeraSplit — Subtractive Split-Toning <split>

Applies zone-weighted subtractive colour adjustments to shadows and highlights
independently, operating directly on the log-encoded signal.

== Shadow/Highlight Weighting

The image luminance ($Y_"2020"$, @luminance) determines the blend between shadow
and highlight zones via the smoothstep crossfade:

$ w_"hi"(x) = "smoothstep"(p - tau/2, thin p + tau/2, thin x), quad
  w_"shd"(x) = 1 - w_"hi"(x) $

where $p = "encode"(0.18) + "offset"$ is the effective pivot and $tau$ is the
transition softness. The two weights are complementary by construction:
$w_"shd" + w_"hi" = 1$.

Each zone's six slider values are scaled by that zone's weight and summed, giving
a single pair of adjustment vectors per pixel:

$ bold(a)_"rgb" = w_"shd" bold(a)_"shd,rgb" + w_"hi" bold(a)_"hi,rgb", quad
  bold(a)_"cmy" = w_"shd" bold(a)_"shd,cmy" + w_"hi" bold(a)_"hi,cmy" $

== Subtractive Colour Model

For each primary, a _positive_ slider value subtracts the complementary channels
(adding the colour by removing its complement), while a _negative_ value subtracts
the primary itself. This is what makes the model subtractive: colour is only ever
added by taking something away.

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

All six adjustments are applied multiplicatively in sequence, so they compose
rather than average.

== Luminance Compensation

Subtractive adjustments inherently darken the image. An estimated "subtractive
impact" is accumulated from the adjustment magnitudes, weighted by how much each
direction actually removes — $0.5$ where the adjustment subtracts from two
channels, $0.33$ where it subtracts from one:

$ I = 0.5 sum_c (max(a_(c,"rgb"), 0) + max(-a_(c,"cmy"), 0))
    + 0.33 sum_c (max(-a_(c,"rgb"), 0) + max(a_(c,"cmy"), 0)) $

A compensation gain is derived from it and clamped, then applied in proportion to
the Preserve Luminance slider:

$ kappa = "clamp"(1 + 2I, thin 1, thin 2) $

$ (r, g, b)_"out" = (r, g, b) dot (1 + (kappa - 1) lambda) $

where $lambda in [0, 1]$ is the Preserve Luminance slider (default $0.8$). Note
this is an open-loop estimate from the slider values, not a measured luminance
ratio as in @primera — it compensates the adjustment, not the pixel.

== Overlays

Three optional overlays share the toning maths rather than approximating it:

/ Show Ramp: a horizontal greyscale ramp $x_n$ is pushed through the *identical*
  pipeline — weighting, subtractive adjustment, and luminance compensation — and
  drawn as a band at a user-positioned height. It therefore shows exactly what
  the tool does at every tonal position, not a model of it.

/ Show Curve: the same processed ramp is plotted per channel as three curves, by
  marking pixels where the channel value crosses the row's normalised height.

/ Show Pivot: draws the shadow and highlight weighting curves and a vertical
  marker at the effective pivot, visualising $tau$ directly.

Show Chart draws the shared per-transfer-function step chart, graduated in stops.
