## Primera Suite

Primera is my personal suite of color grading tools, made from my experience using a number of widely available tools and approaches. I use it both for clip-level grading (shot-to-shot balancing) as well as for look development.

It's a grab-bag of my favorite approaches to each stage in the toolchain. Most of the code is based on open-source DCTLs created by generous individuals in the color grading community (see list at bottom). Primera is mostly me (and my buddy Claude) bringing everything together in one place, with one name, for the sake of convenience. I make no claim to doing anything truly 'original' for the logic used, only that I like this way of working and this 'suite' allows me to have everything close at hand with all of (and only) the sliders and checkboxes I need/prefer.

It's a preferential (some might say "opinionated") approach, one that uses aspects of the "film look" as a lodestar but that doesn't attempt to replicate or reproduce any specific brand, emulsion, or photochemical process. It's more meant to help me recall my "sense memories" of growing up in the 1970s and 80s and seeing lots of movies in the theater which were all (necessarily) shot and projected on film. Though, hopefully the tools and approaches here are flexible enough to get any number of looks, not just those seen through the rose-colored glasses of nostalgia.

Primera (`Primera.dctl`)

This is the foundation of the suite and provides the basic controls that I would typically use when balancing a shot at the clip level:

 — Exposure - done in linear gain (`Gain = 2^n`, same as photographic stops) before being applied to the currently selected transfer function

 — Black point - also called "flare" in some grading systems (e.g. Baselight); this version tries to smoothly compress the darkest tones at the bottom of the signal as they approach pure black

 — Temp - emulates setting a camera's white balance to account for the dominant SPD of a light fixture (obviously also a creative/interpretive choice)

 — Tint - the 'Temp' control swings across the warm/cool axis of the black body curve (or pretends to) and this control swings between green and magenta (like "phase" in NTSC)

 — Contrast - does what you'd expect: stretches the signal to push lighter and darker picture content further away from one another or squash them closer together (operates in Log space)

 — Pivot - defines the mid-point of the stretch/squash; by default this is set to the mid-grey value of the selected transfer function

 — Shadows - this control is linear gain constrained to operate below a transfer function's mid-grey point

 — Highlights - commensurate to Shadows, this constrains a linear gain operation above mid-grey; note that there are no 'spatial' operations taking place with either, as there are with Resolve's same-named controls in the primaries panel, which means their contributions can be encoded in a 3D LUT

 — Roll Off - this is a Log space function that is more or less the same as Resolve's ganged 'Soft Clip' function (tanh) to allow control of where the brightest highlights "top out"; works with 'Highlights' above to tailor highlight compression/expansion

 — Neg. Saturation - this uses multiplicative negative gain in RGB on the chroma values of all three channels (it never makes the image brighter)

 — Pos. Saturation - this uses linear gain on the 'S' component of an HSV color model and is constrained to only operate in the positive direction; also only makes the image darker, which some refer to as "density" or "subtractive saturation" (this can be accounted for however — see below)

 — Preserve Luma - Sat - this checkbox applies positive luma gain to offset the darkening that may have been introduced via the saturation sliders (I almost never use it though)

 — Show Chart - this draws a chart, per transfer function, like the one Walter Volpatto shows on YouTube here

 — Transfer Function - this dropdown selects from among the Log curves that I encounter most often in my work


Primera Plus

The "plus" version of Primera incorporates the functionality of PrimeraHue.dctl, which does hue warping using tetrahedral interpolation (see below). The "plus" version is meant for use either at the look development level (such as in Resolve's Group or Timeline node graphs) or for those times where you want to shift some hues along with primary moves at the clip level.


Primera Hue

This tool implements Calvin Silly's (aka hotgluebanjo) DCTL implementation of what's generally considered the "modern" approach to hue shifting as described by Steve Yedlin in the follow-up discussion to his DisplayPrep video from 2018. Each color's hue slider pushes it towards the color on the opposite "side," and the density slider makes the resulting color darker and (subjectively) more "saturated" or "colorful feeling" without adding "energy" or "stridency."

It uses Sakamoto et al's method of decomposing the color wheel into sextants (six "pie slices," one for each primary and secondary color) and bending them into cubic corners. It  then uses Rodrigues rotations to rotate the chromatic components around the corner's achromatic (black/white) axis. Each slider gives +/- 60° of rotation, when visualized as a disc in HSV (6*60° = 360°), meaning that it allows for pushing/pulling one color all the way to another.

It's smoothed out by tanh near 1.0 (like the highlights slider in Primera) and the same exponential compression as Primera's shadows slider as things get close to 0 in the toe. Maybe there's a better way (?), but these methods attempt to provide "guardrails" to avoid "breaking" the image when making large adjustments.

At the bottom is a slider named 'Cinecolor', after a color process used on lower budget films between about 1940 and 1951 (the "Datsun" to Technicolor's "Cadillac"). Cinecolor exclusively used a "bipack" approach to color (aka "contact exposure"), similar to 2-Strip Technicolor, but with special "duplitized" print film with emulsion on both sides of the celluloid base. You could maybe think of it as "2.5-strip Technicolor" (-ish). It was generally seen, in Hollywood, as the crappy version of Technicolor and saw some use on B westerns and the like. Anyway, it's here for you now (without the registration nightmares) in 2026 ;).

The "Preserve Luma" checkbox works just like the one in Primera (non-Plus) by scaling the output back to a nominal signal level prior to the density adjustment. This somewhat negates the absolute contribution of the 'density' component, since it's largely a perceptual effect, but it can help keep the image from going unduly dark and requiring compensation. Note that this function runs before the 'Cinecolor' block and so doesn't directly affect that slider's contribution to the image.

"Hard Clamp" fixes values at [0,1] prior to 'terp' (tetrahedral interpolation) and "Soft Clamp" applies the above-mentioned "guardrails" (tanh in the shoulder/highlights, exponential compression in the toe) afterwards to (hopefully) gently keep all values in-range. Can be used separately or together.

NOTE: all of the math explanatia here is for the curious; any and all decisions about how, why, and when to use any tool, or particular aspect of a tool, should be made with eyes on the *image* rather than a GitHub README.

Finally, the *Protect Skintones* checkbox applies *only* to the Cinecolor slider. It creates a "holdout matte" around the pixel values on either side of the "skin tone line," as can be visualized in Resolve's vectorscope (roughly 28° counted counterclockwise on an HSV disc). It's a fuzzy slice of the HSV "pie," centered on the nominal skin tone value and falling off smoothly on either side up to 25° away. I almost never have it checked but it's there if you need it.


Primera Split

Split-toning DCTL that uses subtractive math to imbue the shadows and/or highlights with a color cast. Split-toning can also be seen as less of an "effect," and more of a fundamental look development tool, defining the chromatic side of a look's characteristic curve. The 'Transfer Function' combo box initially aligns the 'Pivot' slider with a given transfer function's mid-grey point (however, as with all tools, the ultimate 'split' here should remain a creative choice). Offers curves and transfer function visualizations as well as a positionable greyscale ramp.


Primera Sat

This is less of a traditional saturation tool and more of a perceptual color shaping tool. It round-trips the image through the OKLab color space and allows colors' perceptual "energies" to  be "tuned" without changing the base hue. It tries to provide a clean way to "calm down" colors that are verging on perceptual stridency. Said another way, it can help counteract the Helmholtz-Kohlrausch effect, the phenomenon where saturated colors appear brighter than less-saturated colors of the same value. I don't always use it but when I do it's typically towards the tail end of my look development stack, as a sort of "limiter."

