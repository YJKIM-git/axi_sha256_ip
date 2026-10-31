# ---------------------------------------------------------
# Path Configuration (Safe for both Symlink and Real paths)
# ---------------------------------------------------------
REAL_MK_PATH    := $(realpath $(lastword $(MAKEFILE_LIST)))
REAL_MK_DIR     := $(dir $(REAL_MK_PATH))

# Project root for this tree is: uvm_sha256
# sim -> bl_tb -> dv -> uvm_sha256
PRJ_DIR         ?= $(abspath $(REAL_MK_DIR)../../..)
TB_ROOT         ?= $(abspath $(REAL_MK_DIR)..)
DUT_NAME        ?= sha256

RTL_ROOT        ?= $(PRJ_DIR)/design
INTR_DIR        ?= $(PRJ_DIR)/dv/utils/interrupt
RST_DIR		 	?= $(PRJ_DIR)/dv/utils/reset
DUT_DIR         ?= $(RTL_ROOT)

# Explicit DUT RTL files included in code coverage.
RTL_COVERAGE_FILES ?= $(RTL_ROOT)/sha256_axi_wrapper.sv \
	                  $(RTL_ROOT)/sha256_core/sha256_add32.sv \
	                  $(RTL_ROOT)/sha256_core/sha256_ch.sv \
	                  $(RTL_ROOT)/sha256_core/sha256_controller.sv \
	                  $(RTL_ROOT)/sha256_core/sha256_core.sv \
	                  $(RTL_ROOT)/sha256_core/sha256_datapath.sv \
	                  $(RTL_ROOT)/sha256_core/sha256_ep0.sv \
	                  $(RTL_ROOT)/sha256_core/sha256_ep1.sv \
	                  $(RTL_ROOT)/sha256_core/sha256_k_rom.sv \
	                  $(RTL_ROOT)/sha256_core/sha256_maj.sv \
	                  $(RTL_ROOT)/sha256_core/sha256_message_schedule.sv \
	                  $(RTL_ROOT)/sha256_core/sha256_rotr.sv \
	                  $(RTL_ROOT)/sha256_core/sha256_round_logic.sv \
	                  $(RTL_ROOT)/sha256_core/sha256_sig0.sv \
	                  $(RTL_ROOT)/sha256_core/sha256_sig1.sv

# Agent directories
AXI4LITE_DIR     ?= $(PRJ_DIR)/dv/agents/axi4lite_agent
AXIS_DIR         ?= $(PRJ_DIR)/dv/agents/axis_agent
CORE_DIR         ?= $(PRJ_DIR)/dv/agents/core_agent

# bl_tb directories
REF_DIR         ?= $(TB_ROOT)/ref_model
REG_DIR         ?= $(TB_ROOT)/register_model
ENV_DIR         ?= $(TB_ROOT)/env
SEQ_DIR         ?= $(TB_ROOT)/sequences
TEST_DIR        ?= $(TB_ROOT)/test

VERBOSITY       ?= UVM_LOW

# ---------------------------------------------------------
# File & Target Definitions
# ---------------------------------------------------------
TOP_HDL         ?= hdl_top
TOP_HVL         ?= hvl_top
SNAPSHOT        ?= top_sim

TEST_NAME       ?= sha256_core_test

#TEST_LIST       ?= sha256_overall_test


TEST_LIST       ?= 	sha256_sanity_test \
					sha256_axil_test \
					sha256_axis_test \
				   	sha256_csr_test \
					sha256_core_test \
					sha256_overall_test \

C_SRCS          ?= $(REF_DIR)/sha256_ref_model.cpp

INCDIRS         ?= $(AXI4LITE_DIR) \
                   $(AXIS_DIR) \
                   $(CORE_DIR) \
                   $(REG_DIR) \
                   $(ENV_DIR) \
                   $(SEQ_DIR) \
                   $(TEST_DIR) \
                   $(INTR_DIR) \
				   $(RST_DIR) \

SV_SRCS         ?= $(RTL_COVERAGE_FILES) \
                   $(INTR_DIR)/intr_pkg.svh \
                   $(INTR_DIR)/intr_bfm.sv \
                   $(RST_DIR)/rst_pkg.svh \
                   $(RST_DIR)/rst_bfm.sv \
                   $(AXI4LITE_DIR)/axi4lite_agent_pkg.sv \
                   $(AXI4LITE_DIR)/axi4lite_if.sv \
                   $(AXI4LITE_DIR)/axi4lite_monitor_bfm.sv \
                   $(AXI4LITE_DIR)/axi4lite_driver_bfm.sv \
                   $(AXIS_DIR)/axis_if.sv \
                   $(AXIS_DIR)/axis_agent_pkg.svh \
                   $(AXIS_DIR)/axis_monitor_bfm.sv \
                   $(AXIS_DIR)/axis_m_driver_bfm.sv \
                   $(CORE_DIR)/core_if.sv \
                   $(CORE_DIR)/core_agent_pkg.sv \
                   $(CORE_DIR)/core_monitor_bfm.sv \
				   $(REG_DIR)/sha256_reg_pkg.sv \
                   $(ENV_DIR)/sha256_env_pkg.sv \
                   $(SEQ_DIR)/sha256_vseq_pkg.sv \
                   $(TEST_DIR)/sha256_test_pkg.sv \
                   $(TB_ROOT)/tb/sha256_core_sva.sv \
                   $(TB_ROOT)/tb/sha256_wrapper_sva.sv \
                   $(TB_ROOT)/tb/hvl_top.sv \
                   $(TB_ROOT)/tb/hdl_top.sv

INCDIR_FLAGS     = $(addprefix -i , $(INCDIRS))
ALL_TARGETS      = clean build elab run_all covreport rpt_log


.PHONY: all build elab run run_all clean tree covreport rpt_log

CLR_RESET   := \033[0m
CLR_RUNNING := \033[33m
CLR_PASS    := \033[32m
CLR_FAIL    := \033[31m

# ---------------------------------------------------------
# Make Rules
# ---------------------------------------------------------
all: $(ALL_TARGETS)

tree:
	@clear
	@(cd -P $(PRJ_DIR) && pwd)
	@(cd -P $(PRJ_DIR) && tree)

build:
	@clear
	@echo "========================================="
	@echo " Starting Build & Elab: $$(date +"%Y-%m-%d %H:%M:%S")"
	@echo "========================================="
	@start_time=$$(date +"%H:%M:%S"); \
	printf "$(CLR_RUNNING)[RUNNING ]: [$${start_time}] --> [...     ]      Compiling C and SV sources$(CLR_RESET)"; \
	if xsc $(C_SRCS) > xsc.log 2>&1 && xvlog -sv -L uvm $(INCDIR_FLAGS) $(SV_SRCS) > xvlog.log 2>&1; then \
		end_time=$$(date +"%H:%M:%S"); \
		printf "\r\033[K$(CLR_PASS)[  PASS  ]: [$${start_time}] --> [$${end_time}]      Compiling C and SV sources \t(xsc.log / xvlog.log)$(CLR_RESET)\n"; \
	else \
		end_time=$$(date +"%H:%M:%S"); \
		printf "\r\033[K$(CLR_FAIL)[  FAIL  ]: [$${start_time}] --> [$${end_time}]      Compiling C and SV sources (Check xsc.log or xvlog.log)$(CLR_RESET)\n"; \
		exit 1; \
	fi

elab:
	@start_time=$$(date +"%H:%M:%S"); \
	printf "$(CLR_RUNNING)[RUNNING ]: [$${start_time}] --> [...     ]      Elaborating design$(CLR_RESET)"; \
	rm -f cc_exclude.txt; \
	echo "dir +*design*" >> cc_exclude.txt; \
	for m in \
		sha256_axi_wrapper \
		sha256_axi_wrapper_0 \
		sha256_add32 \
		sha256_ch \
		sha256_controller \
		sha256_core \
		sha256_core_0 \
		sha256_datapath \
		sha256_ep0 \
		sha256_ep1 \
		sha256_k_rom \
		sha256_maj \
		sha256_message_schedule \
		sha256_rotr \
		sha256_round_logic \
		sha256_sig0 \
		sha256_sig1; do echo "module +$$m" >> cc_exclude.txt; done; \
	if xelab -L uvm -timescale 1ns/10ps -debug typical -cc_type line,tgl,branch -sv_lib dpi -top $(TOP_HDL) -top $(TOP_HVL) -snapshot $(SNAPSHOT) -ccExclusionFile ./cc_exclude.txt > xelab.log 2>&1; then \
		end_time=$$(date +"%H:%M:%S"); \
		printf "\r\033[K$(CLR_PASS)[  PASS  ]: [$${start_time}] --> [$${end_time}]      Elaborating design \t\t(xelab.log)$(CLR_RESET)\n"; \
	else \
		end_time=$$(date +"%H:%M:%S"); \
		printf "\r\033[K$(CLR_FAIL)[  FAIL  ]: [$${start_time}] --> [$${end_time}]      Elaborating design (Check xelab.log)$(CLR_RESET)\n"; \
		exit 1; \
	fi

run:
	@xsim $(SNAPSHOT) -R -cov_db_dir ./ -testplusarg UVM_TESTNAME=$(TEST_NAME) \
	-testplusarg UVM_VERBOSITY=$(VERBOSITY) \
	-testplusarg uvm_set_config_int="*",recording_detail,UVM_FULL > xsim_$(TEST_NAME).log 2>&1
	@mkdir -p xsim.covdb
	@rm -rf xsim.covdb/$(TEST_NAME)
	@if [ -d xsim.covdb/$(SNAPSHOT) ]; then mv xsim.covdb/$(SNAPSHOT) xsim.covdb/$(TEST_NAME); fi

run_all:
	@echo "========================================="
	@echo " Starting Basic Tests: $$(date +"%Y-%m-%d %H:%M:%S")"
	@echo "========================================="
	@for t in $(TEST_LIST); do \
		start_time=$$(date +"%H:%M:%S"); \
		printf "$(CLR_RUNNING)[RUNNING ]: [$${start_time}] --> [...     ]      TEST: $$t\t(xsim_$$t.log)$(CLR_RESET)" >&2; \
		$(MAKE) -s run TEST_NAME=$$t > /dev/null 2>&1; \
		end_time=$$(date +"%H:%M:%S"); \
		if grep -q "UVM_FATAL :    0" xsim_$$t.log && grep -q "UVM_ERROR :    0" xsim_$$t.log && ! grep -q "ERROR: Assertion failed\." xsim_$$t.log; then \
			printf "\r\033[K$(CLR_PASS)[  PASS  ]: [$${start_time}] --> [$${end_time}]      TEST: $$t\t(xsim_$$t.log)\n$(CLR_RESET)" >&2; \
		else \
			printf "\r\033[K$(CLR_FAIL)[  FAIL  ]: [$${start_time}] --> [$${end_time}]      TEST: $$t\t(xsim_$$t.log)\n$(CLR_RESET)" >&2; \
		fi \
	done

covreport:
	@mkdir -p cov_report
	@start_time=$$(date +"%H:%M:%S"); \
	printf "$(CLR_RUNNING)[RUNNING ]: [$${start_time}] --> [...     ]      Generating coverage report$(CLR_RESET)"; \
	if xcrg -cov_db_dir ./ -report_dir ./cov_report -ccExclusionFile ./cc_exclude.txt > xcrg.log 2>&1; then \
		end_time=$$(date +"%H:%M:%S"); \
		printf "\r\033[K$(CLR_PASS)[  PASS  ]: [$${start_time}] --> [$${end_time}]      Generating coverage report$(CLR_RESET)\n"; \
	else \
		end_time=$$(date +"%H:%M:%S"); \
		printf "\r\033[K$(CLR_FAIL)[  FAIL  ]: [$${start_time}] --> [$${end_time}]      Generating coverage report (Check xcrg.log)$(CLR_RESET)\n"; \
		exit 1; \
	fi

clean:
	@find . -mindepth 1 ! -name 'Makefile' -exec rm -rf {} +

rpt_log:
	@printf "%-40s %8s %8s %8s %8s %8s\n" "TEST_NAME" "INFO" "WARNING" "ERROR" "SVA" "FATAL"
	@for t in $(TEST_LIST); do \
		f="xsim_$$t.log"; \
		if [ -f "$$f" ]; then \
			info=$$(awk '/^UVM_INFO[[:space:]]*:/ {print $$3; exit}' "$$f"); \
			warn=$$(awk '/^UVM_WARNING[[:space:]]*:/ {print $$3; exit}' "$$f"); \
			err=$$(awk '/^UVM_ERROR[[:space:]]*:/ {print $$3; exit}' "$$f"); \
			fatal=$$(awk '/^UVM_FATAL[[:space:]]*:/ {print $$3; exit}' "$$f"); \
			sva_err=$$(grep -c 'ERROR: Assertion failed\.' "$$f" || true); \
			[ -n "$$info" ] || info=0; \
			[ -n "$$warn" ] || warn=0; \
			[ -n "$$err" ] || err=0; \
			[ -n "$$fatal" ] || fatal=0; \
		else \
			info="N/A"; \
			warn="N/A"; \
			err="N/A"; \
			sva_err="N/A"; \
			fatal="N/A"; \
		fi; \
		printf "%-40s %8s %8s %8s %8s %8s\n" "$$t" "$$info" "$$warn" "$$err" "$$sva_err" "$$fatal"; \
	done

xvlog: 
	cat xvlog.log

xelab: 
	cat xelab.log