REAL_MK_PATH    := $(realpath $(lastword $(MAKEFILE_LIST)))

.PHONY: all peakrdl bl_tb static_tb fpga clean clean_peakrdl clean_bl_tb clean_static_tb clean_fpga
all: bl_tb

peakrdl:
	$(MAKE) -C rdl all

bl_tb:
	$(MAKE) -C dv/bl_tb/sim all

static_tb:
	$(MAKE) -C dv/static_tb/sim all

fpga:
	$(MAKE) -C fpga all

clean_peakrdl:
	$(MAKE) -C rdl clean

clean_bl_tb:
	$(MAKE) -C dv/bl_tb/sim clean

clean_static_tb:
	$(MAKE) -C dv/static_tb/sim clean

clean_fpga:
	$(MAKE) -C fpga clean

clean: clean_peakrdl clean_bl_tb clean_fpga clean_static_tb