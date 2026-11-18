REAL_MK_PATH := $(realpath $(lastword $(MAKEFILE_LIST)))
REAL_MK_DIR  := $(dir $(REAL_MK_PATH))

PRJ_DIR      ?= $(abspath $(REAL_MK_DIR)../../..)
TB_DIR       ?= $(abspath $(REAL_MK_DIR)..)
RTL_DIR      ?= $(PRJ_DIR)/design
TOP          ?= tb_sha256_tkeep
SNAPSHOT     ?= static_tb_sim

RTL_SRCS     ?= $(RTL_DIR)/sha256_axi_wrapper.sv \
				$(RTL_DIR)/sha256_core/sha256_pkg.sv \
				$(RTL_DIR)/sha256_core/sha256_controller.sv \
				$(RTL_DIR)/sha256_core/sha256_core.sv \
				$(RTL_DIR)/sha256_core/sha256_datapath.sv \
				$(RTL_DIR)/sha256_core/sha256_message_schedule.sv \
				$(RTL_DIR)/sha256_core/sha256_round_logic.sv

TB_SRCS     ?= $(TB_DIR)/tb_sha256_tkeep.sv
XELAB_FLAGS ?= -timescale 1ns/1ps -debug typical

.PHONY: all build elab run clean

all: clean build elab run

build:
	xvlog -sv -i "$(RTL_DIR)" $(RTL_SRCS) $(TB_SRCS)

elab:
	xelab $(XELAB_FLAGS) -top $(TOP) -snapshot $(SNAPSHOT)

run:
	xsim $(SNAPSHOT) -R

clean:
	rm -rf xsim.dir .Xil *.log *.jou *.pb $(SNAPSHOT).wdb *.vcd
