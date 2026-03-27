SRC     := src
FRAG    := $(SRC)/frag

TOOLS   := Primera PrimeraPlus PrimeraHue PrimeraSat PrimeraSplit

# Fragment ordering per tool
Primera_FRAGS      := luminance hsv tf_encode tf_decode chart tone
PrimeraPlus_FRAGS  := luminance hsv tf_encode tf_decode chart tone tetra
PrimeraHue_FRAGS   := luminance hsv skintone tetra soft_squeeze
PrimeraSat_FRAGS   := oklab soft_squeeze
PrimeraSplit_FRAGS := luminance tf_encode chart

LUT_DIR := /Library/Application Support/Blackmagic Design/DaVinci Resolve/LUT

.PHONY: all dev clean install install-dev

all: OUTDIR := Primera
all: $(TOOLS)

dev: OUTDIR := 0_Primera
dev: $(TOOLS)

define TOOL_RULE
.PHONY: $(1)
$(1):
	@mkdir -p $$(OUTDIR)
	cat $(SRC)/$(1)/header.dctlc $(foreach f,$($(1)_FRAGS),$(FRAG)/$(f).dctlf) $(SRC)/$(1)/body.dctlc > $$(OUTDIR)/$(1).dctl
endef

$(foreach t,$(TOOLS),$(eval $(call TOOL_RULE,$(t))))

install: all
	cp -r Primera "$(LUT_DIR)/"

install-dev: dev
	cp -r 0_Primera "$(LUT_DIR)/"

clean:
	rm -rf Primera 0_Primera
