__EVFR_MARBLE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
EVFR_MARBLE_DIR := $(__EVFR_MARBLE_DIR:/=)

__HDR_EVFR_MARBLE_FILES = \
	gpio.h \
	config.h
HDR_EVFR_MARBLE_FILES = $(addprefix $(EVFR_MARBLE_DIR)/, $(__HDR_EVFR_MARBLE_FILES))

# For top-level makfile
HDR_FILES += $(HDR_GEN_EVFR_MARBLE_FILES)
# SRC_FILES +=

# clean::
# 	$(RM) -rf
