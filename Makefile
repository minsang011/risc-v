# Simulators: icarus OR verilator, default == icarus
TOOL ?= icarus
VFLAGS = --binary --timing --trace --timescale 1ns/1ps -Wall -Wno-fatal -j 0 # Verilator flags


# Declaring variables
TB ?= tb_counter
SRCS = $(or $($(TB)_SRCS),$(PKG_DIR) $(filter-out $(PKG_DIR),$(wildcard $(RTL_DIR)/*.sv)) $(TB_DIR)/$(TB).sv) # wildcard lists all qualifying files (.sv in this case) into a space-separated list
BUILD_DIR := build
SW_DIR := sw
TB_DIR := tb
RTL_DIR := rtl
PKG_DIR := $(RTL_DIR)/rv32i_pkg.sv


# One line per unit test: <name>_SRCS, package first
# EX) alu_tb_SRCS   := $(PKG_DIR) rtl/alu.sv tb/alu_tb.sv 
pkg_test_SRCS := $(PKG_DIR) tb/pkg_test.sv
alu_SRCS := $(PKG_DIR) $(RTL_DIR)/alu.sv
alu_tb_SRCS := $(PKG_DIR) $(RTL_DIR)/alu.sv $(TB_DIR)/alu_tb.sv


# Condition to prevent unsuppported simulator
ifeq ($(TOOL),icarus)
COMPILE = iverilog -g2012 -Wall -s $(TB) -o $(BUILD_DIR)/$(TB).vvp $(SRCS)
RUN     = vvp -n $(BUILD_DIR)/$(TB).vvp
else ifeq ($(TOOL),verilator)
COMPILE = verilator $(VFLAGS) --top-module $(TB) -Mdir $(BUILD_DIR)/obj_dir $(SRCS)
RUN     = ./$(BUILD_DIR)/obj_dir/V$(TB)
else
$(error Unsupported TOOL='$(TOOL)', use icarus or verilator)
endif

# -----------------COMMAND LINES------------------
.PHONY: sim compile wave clean lint

sim: compile
	$(RUN) | tee $(BUILD_DIR)/$(TB).log && grep -q '^PASS $(TB)$$' $(BUILD_DIR)/$(TB).log

compile:
	mkdir -p $(BUILD_DIR) && $(COMPILE)

wave:
	surfer $(BUILD_DIR)/$(TB).vcd

clean:
	rm -rf $(BUILD_DIR)

lint:
	verilator --lint-only -Wall --timing --top-module $(TB) $(SRCS)