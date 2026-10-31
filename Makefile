# Simulators: icarus OR verilator, default == icarus
TOOL ?= icarus
VFLAGS = --binary --timing --trace --timescale 1ns/1ps -Wall -Wno-fatal -j 0 # Verilator flags

# Declaring variables
TOP ?= tb_counter
SRCS = $(wildcard $(RTL_DIR)/*.sv) $(TB_DIR)/$(TOP).sv # wildcard gives all qualifying files (.sv in this case) into a space-separated list
BUILD_DIR := build
SW_DIR := sw
TB_DIR := tb
RTL_DIR := rtl

# Condition to prevent unsuppported simulator
ifeq ($(TOOL),icarus)
COMPILE = iverilog -g2012 -Wall -s $(TOP) -o $(BUILD_DIR)/$(TOP).vvp $(SRCS)
RUN     = vvp -n $(BUILD_DIR)/$(TOP).vvp
else ifeq ($(TOOL),verilator)
COMPILE = verilator $(VFLAGS) --top-module $(TOP) -Mdir $(BUILD_DIR)/obj_dir $(SRCS)
RUN     = ./$(BUILD_DIR)/obj_dir/V$(TOP)
else
$(error Unsupported TOOL='$(TOOL)', use icarus or verilator)
endif

# -----------------COMMAND LINES------------------
.PHONY: sim compile wave clean

sim: compile
	$(RUN) | tee $(BUILD_DIR)/$(TOP).log && grep -q '^PASS' $(BUILD_DIR)/$(TOP).log
	
compile:
	mkdir -p $(BUILD_DIR) && $(COMPILE)

wave:
	surfer $(BUILD_DIR)/$(TOP).vcd

clean:
	rm -rf $(BUILD_DIR)

