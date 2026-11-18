SCRIPT_DIR := $(CURDIR)
RDL_FILE := $(SCRIPT_DIR)/sha256_csr.rdl
OUT_DIR := $(SCRIPT_DIR)/output

.PHONY: all regblock html uvm c_header ip_xact clean

all: uvm

regblock:
	mkdir -p "$(OUT_DIR)/rtl"
	peakrdl regblock "$(RDL_FILE)" -o "$(OUT_DIR)/rtl" --cpuif axi4-lite

html:
	mkdir -p "$(OUT_DIR)/docs"
	peakrdl html "$(RDL_FILE)" -o "$(OUT_DIR)/docs"

uvm:
	mkdir -p "$(OUT_DIR)/uvm"
	peakrdl uvm "$(RDL_FILE)" -o "$(OUT_DIR)/uvm/sha256_reg_pkg.sv"

c_header:
	mkdir -p "$(OUT_DIR)/header"
	peakrdl c-header "$(RDL_FILE)" -o "$(OUT_DIR)/header/sha256_csr.h"

ip_xact:
	mkdir -p "$(OUT_DIR)/ipxact"
	peakrdl ip-xact "$(RDL_FILE)" -o "$(OUT_DIR)/ipxact/sha256_csr.xml"

clean:
	rm -rf "$(OUT_DIR)"
