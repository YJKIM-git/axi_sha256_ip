PROJECT_NAME ?= prj_sha256
FPGA_PROJECT_NAME ?= fpga_sha256_bd
PART ?= xc7z020clg400-1
VIVADO ?= vivado

SRC_ROOT ?= $(CURDIR)
BUILD_ROOT ?= $(CURDIR)/build
IP_PKG_TMP=$(CURDIR)/ip_packager_prj
PROJECT_DIR ?= $(BUILD_ROOT)/$(PROJECT_NAME)
FPGA_PROJECT_DIR ?= $(BUILD_ROOT)/$(FPGA_PROJECT_NAME)
RTL_DIR ?= $(abspath ../design)
FIRMWARE_DIR ?= $(SRC_ROOT)/firmware
SCRIPTS_DIR ?= $(SRC_ROOT)/script
SYNTH_DIR ?= $(SRC_ROOT)/synth
IP_DIR ?= $(SRC_ROOT)/ip_repo
BD_DIR ?= $(SRC_ROOT)/bd
IP_REPO_DIR ?= $(SRC_ROOT)/ip_repo
CREATE_SCRIPT ?= $(SCRIPTS_DIR)/create_prj.tcl
CREATE_FPGA_SCRIPT ?= $(SCRIPTS_DIR)/create_fpga.tcl
PACKAGE_IP_SCRIPT ?= $(SCRIPTS_DIR)/package_ip.tcl
XPR_FILE ?= $(PROJECT_DIR)/$(PROJECT_NAME).xpr
FPGA_XPR_FILE ?= $(FPGA_PROJECT_DIR)/$(FPGA_PROJECT_NAME).xpr

.PHONY: all create open run bd open_bd package_ip clean recreate

all: open_bd

create:
	mkdir -p "$(BUILD_ROOT)"
	cd "$(BUILD_ROOT)" && \
	PROJECT_NAME="$(PROJECT_NAME)" \
	PART="$(PART)" \
	PROJECT_DIR="$(PROJECT_DIR)" \
	RTL_DIR="$(RTL_DIR)" \
	SYNTH_DIR="$(SYNTH_DIR)" \
	IP_DIR="$(IP_DIR)" \
	FIRMWARE_DIR="$(FIRMWARE_DIR)" \
	$(VIVADO) -mode batch -source $(CREATE_SCRIPT)

open: create
	$(VIVADO) $(XPR_FILE)

run: open

bd: package_ip
	mkdir -p "$(BUILD_ROOT)"
	cd "$(BUILD_ROOT)" && \
	FPGA_PROJECT_NAME="$(FPGA_PROJECT_NAME)" \
	PART="$(PART)" \
	FPGA_PROJECT_DIR="$(FPGA_PROJECT_DIR)" \
	BD_DIR="$(BD_DIR)" \
	IP_REPO_DIR="$(IP_REPO_DIR)" \
	$(VIVADO) -mode batch -source $(CREATE_FPGA_SCRIPT)

open_bd: bd
	$(VIVADO) "$(FPGA_XPR_FILE)"

package_ip:
	$(VIVADO) -mode batch -source "$(PACKAGE_IP_SCRIPT)"
	rm -rf ip_packager_prj
clean:
	rm -rf "$(BUILD_ROOT)"
	rm -rf "$(IP_DIR)"
	rm -rf "$(IP_PKG_TMP)"
	rm -rf "$(abspath ..)/$(PROJECT_NAME).gen"

recreate: clean create

