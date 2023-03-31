__KD_MARBLE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
KD_MARBLE_DIR := $(__KD_MARBLE_DIR:/=)

__HDR_KD_MARBLE_FILES = \
	gpio.h \
	config.h
HDR_KD_MARBLE_FILES = $(addprefix $(KD_MARBLE_DIR)/, $(__HDR_KD_MARBLE_FILES))

# For top-level makfile
HDR_FILES += $(HDR_GEN_KD_MARBLE_FILES)
# SRC_FILES +=

# clean::
# 	$(RM) -rf
