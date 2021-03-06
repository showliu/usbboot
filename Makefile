##
## Copyright (C) 2010 The Android Open Source Project
## All rights reserved.
##
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions
## are met:
##  * Redistributions of source code must retain the above copyright
##    notice, this list of conditions and the following disclaimer.
##  * Redistributions in binary form must reproduce the above copyright
##    notice, this list of conditions and the following disclaimer in
##    the documentation and/or other materials provided with the 
##    distribution.
##
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
## "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
## LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
## FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
## COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
## INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
## BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
## OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED 
## AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
## OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
## OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
## SUCH DAMAGE.

VERSION = 1
PATCHLEVEL = 0
SUBLEVEL = 0
ABOOT_VERSION = $(VERSION).$(PATCHLEVEL).$(SUBLEVEL)
$(shell echo -n "#define ABOOT_VERSION \"ABOOT " > include/version.h)
$(shell echo -n $(ABOOT_VERSION) >> include/version.h)
$(shell echo "\"" >> include/version.h)

what_to_build:: all

-include local.mk

TOOLCHAIN ?= arm-eabi-

BOARD=omap5evm
ARCH=omap5

TARGET_CC := $(TOOLCHAIN)gcc
TARGET_LD := $(TOOLCHAIN)ld
TARGET_OBJCOPY := $(TOOLCHAIN)objcopy
TARGET_OBJDUMP := $(TOOLCHAIN)objdump

$(shell cat arch/$(ARCH)/configs/config_$(BOARD).h > include/config.h)
TARGET_CFLAGS := -g -Os  -Wall
TARGET_CFLAGS +=  -march=armv7-a -fno-builtin -ffreestanding
TARGET_CFLAGS += -I. -Iinclude
TARGET_CFLAGS += -include include/config.h

TARGET_LIBGCC := $(shell $(TARGET_CC) $(TARGET_CFLAGS) -print-libgcc-file-name)

HOST_CFLAGS := -g -O2 -Wall
HOST_CFLAGS += -Itools
HOST_CFLAGS += -include include/config.h

OUT := out/$(BOARD)
OUT_HOST_OBJ := $(OUT)/host-obj
OUT_TARGET_OBJ := $(OUT)/target-obj

ALL :=

include build/rules.mk

M_NAME := usbboot
M_OBJS := tools/usbboot.o
M_OBJS += tools/usb_linux.o
M_OBJS += 2ndstage.o
M_OBJS += secondstage.o
include build/host-executable.mk

M_NAME := mkheader
M_OBJS := tools/mkheader.o
include build/host-executable.mk

M_NAME := bin2c
M_OBJS := tools/bin2c.o
include build/host-executable.mk

OMAP5_COMMON_OBJS :=	arch/omap5/id.o

OMAP4_COMMON_OBJS :=	arch/omap4/clock.o \
			arch/omap4/sdram.o \
			arch/omap4/gpmc.o \
			arch/omap4/gpio.o \
			arch/omap4/id.o \

COMMON_OBJS :=	arch/common/serial.o \
		arch/common/rom_usb.o \
		arch/$(ARCH)/board/board_$(BOARD).o \
		libc/printf.o \
		libc/raise.o \
		libc/string.o \
		trusted.o \
		boot.o \
		misc.o \

M_NAME := aboot
ifeq ($(ARCH), omap4)
M_BASE := 0x40309000
M_OBJS := arch/common/start_reloc.o
M_OBJS += $(OMAP4_COMMON_OBJS)
endif
ifeq ($(ARCH), omap5)
M_BASE := 0x40309000
M_OBJS := arch/common/start_reloc.o
M_OBJS += $(OMAP5_COMMON_OBJS)
endif
M_OBJS += $(COMMON_OBJS)
M_OBJS += aboot.o
M_LIBS := $(TARGET_LIBGCC)
include build/target-executable.mk

M_NAME := iboot
ifeq ($(ARCH), omap4)
M_BASE := 0x40300200
M_OBJS := iboot/start_reloc.o
M_OBJS += $(OMAP4_COMMON_OBJS)
endif
ifeq ($(ARCH), omap5)
M_BASE := 0x40300200
M_OBJS := iboot/start_reloc.o
M_OBJS += $(OMAP5_COMMON_OBJS)
endif
M_OBJS += $(COMMON_OBJS)
M_OBJS += iboot/iboot.o
M_OBJS += pmic.o
M_OBJS += booti.o
M_OBJS += libc/utils.o
M_OBJS += crc32.o
M_OBJS += fastboot.o
M_OBJS += fastboot_mmc.o
M_OBJS += arch/common/rom_i2c.o
M_OBJS += arch/common/rom_wdtimer.o
M_OBJS += arch/common/rom_mmc.o
M_LIBS := $(TARGET_LIBGCC)
include build/target-executable.mk

M_NAME := agent
M_BASE := 0x82000000
M_OBJS := arch/common/start.o
M_OBJS += agent.o
M_OBJS += arch/common/serial.o

include build/target-executable.mk

$(OUT)/iboot.ift: $(OUT)/iboot.bin $(OUT)/mkheader
	@echo generate $@
	@./$(OUT)/mkheader $(TEXT_BASE) `wc -c $(OUT)/iboot.bin` no_gp_hdr > $@
	@cat $(OUT)/iboot.bin >> $@

$(OUT)/aboot.ift: $(OUT)/aboot.bin $(OUT)/mkheader
	@echo generate $@
	@./$(OUT)/mkheader $(TEXT_BASE) `wc -c $(OUT)/aboot.bin` no_gp_hdr > $@
	@cat $(OUT)/aboot.bin >> $@
ALL += $(OUT)/aboot.ift $(OUT)/iboot.ift

$(OUT_HOST_OBJ)/2ndstage.o: $(OUT)/aboot.bin $(OUT)/bin2c $(OUT)/mkheader
	@echo generate $@
	@./$(OUT)/mkheader $(TEXT_BASE) `wc -c $(OUT)/aboot.bin` no_gp_hdr > $@
	@cat $(OUT)/aboot.bin >> $@
	$(QUIET)./$(OUT)/bin2c aboot < $@ > $(OUT)/2ndstage.c
	gcc -c -o $@ $(OUT)/2ndstage.c

$(OUT_HOST_OBJ)/secondstage.o: $(OUT)/iboot.bin $(OUT)/bin2c $(OUT)/mkheader
	@echo generate $@
	@./$(OUT)/mkheader $(TEXT_BASE) `wc -c $(OUT)/iboot.bin` no_gp_hdr > $@
	@cat $(OUT)/iboot.bin >> $@
	$(QUIET)./$(OUT)/bin2c iboot < $@ > $(OUT)/secondstage.c
	gcc -c -o $@ $(OUT)/secondstage.c
clean::
	@echo clean
	@rm include/config.h
	@rm include/version.h
	@rm -rf $(OUT)

all:: $(ALL)

# we generate .d as a side-effect of compiling. override generic rule:
%.d:
-include $(DEPS)
