# =============================================================================
# Aether RV64IM Core
# =============================================================================


# =============================================================================
# Configuration
# =============================================================================

TOP      := soc_top
CORE_TOP := core_top

OBJ_DIR := obj_dir

RTL_DIR := rtl
DV_DIR  := dv
SIM_DIR := sim
SW_DIR  := sw
SYN_DIR := syn

TB_DIR  := $(DV_DIR)/tb
INC_DIR := $(RTL_DIR)/include

TEST ?= add



# -----------------------------------------------------------------------------
# Tools
# -----------------------------------------------------------------------------

OSS_CAD_HOME ?= $(HOME)/oss-cad-suite

YOSYS     ?= $(OSS_CAD_HOME)/bin/yosys
VERILATOR ?= verilator
EXTRA_VERILATOR_FLAGS ?=

RISCV_GCC     ?= riscv64-unknown-elf-gcc
RISCV_OBJCOPY ?= riscv64-unknown-elf-objcopy
SPIKE         ?= spike
PYTHON        ?= python3


# =============================================================================
# Source Sets
# =============================================================================


# -----------------------------------------------------------------------------
# Synthesizable core RTL
# -----------------------------------------------------------------------------

CORE_SRCS := \
	$(RTL_DIR)/include/riscv_pkg.sv \
	$(RTL_DIR)/core/core_top.sv \
	$(wildcard $(RTL_DIR)/core/fetch/*.sv) \
	$(wildcard $(RTL_DIR)/core/decode/*.sv) \
	$(wildcard $(RTL_DIR)/core/pipeline/*.sv) \
	$(wildcard $(RTL_DIR)/core/exec/*.sv) \
	$(wildcard $(RTL_DIR)/core/mem/*.sv) \
	$(wildcard $(RTL_DIR)/core/perf/*.sv) \
	$(wildcard $(RTL_DIR)/core/sys/*.sv)


# -----------------------------------------------------------------------------
# Synthesizable bus / integration RTL
# -----------------------------------------------------------------------------

BUS_SRCS := \
	$(wildcard $(RTL_DIR)/bus/*.sv)


# All synthesizable RTL used by the simulation SoC.
RTL_SRCS := \
	$(CORE_SRCS) \
	$(BUS_SRCS)


# -----------------------------------------------------------------------------
# Verification-only SystemVerilog
# -----------------------------------------------------------------------------

DV_SRCS := \
	$(wildcard $(DV_DIR)/rtl/*.sv)


# -----------------------------------------------------------------------------
# Simulation-only SoC components
# -----------------------------------------------------------------------------

SIM_SRCS := \
	$(wildcard $(SIM_DIR)/soc/*.sv)


# -----------------------------------------------------------------------------
# Complete simulation source set
# -----------------------------------------------------------------------------

SRCS := \
	$(RTL_SRCS) \
	$(DV_SRCS) \
	$(SIM_SRCS)

CPP_TB := $(TB_DIR)/sim_main.cpp


# =============================================================================
# Common Verilator Configuration
# =============================================================================

VERILATOR_COMMON_FLAGS := \
	-Wall \
	-I$(INC_DIR)

VERILATOR_BUILD_FLAGS := \
	$(VERILATOR_COMMON_FLAGS) \
	$(EXTRA_VERILATOR_FLAGS) \
	--cc \
	--exe \
	--trace \
	--top-module $(TOP)


# =============================================================================
# Hardware Simulation Build
# =============================================================================

hw:
	$(VERILATOR) \
		$(VERILATOR_BUILD_FLAGS) \
		$(SRCS) \
		$(CPP_TB)

	$(MAKE) -C $(OBJ_DIR) -f V$(TOP).mk


# =============================================================================
# Software
# =============================================================================

sw:
	$(MAKE) -C $(SW_DIR)


# =============================================================================
# Simulation
# =============================================================================

sim: sw hw
	./$(OBJ_DIR)/V$(TOP)


# =============================================================================
# Sanity Test
# =============================================================================

SANITY_ELF := $(DV_DIR)/tests/bin/sanity.elf
SANITY_BIN := $(DV_DIR)/tests/bin/sanity.bin


sanity: hw
	@echo "Running Aether sanity test..."

	mkdir -p $(DV_DIR)/tests/bin

	$(RISCV_GCC) \
		-mcmodel=medany \
		-march=rv64im \
		-mabi=lp64 \
		-nostdlib \
		-T $(SW_DIR)/link.ld \
		-o $(SANITY_ELF) \
		$(SW_DIR)/crt0.s \
		$(DV_DIR)/tests/src/sanity_check.c

	$(RISCV_OBJCOPY) \
		-O binary \
		$(SANITY_ELF) \
		$(SANITY_BIN)

	hexdump -v -e '1/4 "%08x\n"' \
		$(SANITY_BIN) \
		> $(SW_DIR)/program.hex

	./$(OBJ_DIR)/V$(TOP)


# =============================================================================
# Architectural Regression
# =============================================================================

regression: hw
	$(PYTHON) $(DV_DIR)/tests/scripts/run_regression.py

regression-axi-stress:
	@echo
	@echo "============================================================"
	@echo "AETHER AXI BACKPRESSURE REGRESSION"
	@echo "============================================================"
	@echo

	$(MAKE) clean-hw

	$(MAKE) hw \
		EXTRA_VERILATOR_FLAGS=-DAXI_STRESS

	$(PYTHON) \
		$(DV_DIR)/tests/scripts/run_regression.py

	@echo
	@echo "============================================================"
	@echo "AXI BACKPRESSURE REGRESSION PASSED"
	@echo "============================================================"


# =============================================================================
# Spike Differential Testing
# =============================================================================

TEST_ELF := $(DV_DIR)/tests/bin/$(TEST).elf
TEST_BIN := $(DV_DIR)/tests/bin/$(TEST).bin


spike: hw
	@test -f $(TEST_ELF) || { \
		echo "ERROR: $(TEST_ELF) does not exist."; \
		echo "Run 'make regression' first, or choose an existing TEST."; \
		exit 1; \
	}

	@test -f $(TEST_BIN) || { \
		echo "ERROR: $(TEST_BIN) does not exist."; \
		exit 1; \
	}

	@echo "Running Spike differential test: $(TEST)"

	hexdump -v -e '1/4 "%08x\n"' \
		$(TEST_BIN) \
		> $(SW_DIR)/program.hex

	@echo "Running RTL simulation..."

	./$(OBJ_DIR)/V$(TOP) > rtl.log

	@COMMITS=$$(grep -c "^core.*:" rtl.log); \
	echo "RTL retired $$COMMITS instructions"; \
	SPIKE_LINES=$$(($$COMMITS * 4 + 500)); \
	echo "Capturing up to $$SPIKE_LINES Spike trace lines"; \
	( \
		$(SPIKE) \
			--isa=rv64im \
			-m0x80000000:0x100000,0xf0000000:0x1000 \
			-l \
			--log-commits \
			$(TEST_ELF) \
			2>&1 > /dev/null \
	) | head -n $$SPIKE_LINES > spike.log || true

	$(PYTHON) \
		$(DV_DIR)/tests/scripts/spike_cmp.py \
		rtl.log \
		spike.log

# =============================================================================
# Spike Differential Regression
# =============================================================================

spike-regression: regression
	$(PYTHON) \
		$(DV_DIR)/tests/scripts/run_spike_regression.py


# =============================================================================
# Lint
# =============================================================================


# -----------------------------------------------------------------------------
# Core lint
#
# Checks core_top in its normal simulation configuration.
#
# core_top contains the tracer when SYNTHESIS is not defined, therefore the
# verification tracer source is included here.
# -----------------------------------------------------------------------------

lint-core:
	$(VERILATOR) \
		--lint-only \
		$(VERILATOR_COMMON_FLAGS) \
		--top-module $(CORE_TOP) \
		$(CORE_SRCS) \
		$(DV_SRCS)


# Backward-compatible alias.
lint: lint-core


# -----------------------------------------------------------------------------
# Synthesizable core lint
#
# SYNTHESIS removes verification-only instrumentation such as the tracer.
#
# This target intentionally checks core_top rather than soc_top. The simulation
# RAM and test SoC are not part of the synthesizable CPU core.
# -----------------------------------------------------------------------------

lint-synth:
	$(VERILATOR) \
		--lint-only \
		$(VERILATOR_COMMON_FLAGS) \
		-DSYNTHESIS \
		--top-module $(CORE_TOP) \
		$(CORE_SRCS)


# -----------------------------------------------------------------------------
# Full simulation SoC lint
#
# This is what the old lint-all was missing. It checks:
#
#   core
#   AXI wrapper
#   tracer
#   soc_top
#   AXI RAM model
#
# Therefore warnings in simulation-only files are caught before make hw.
# -----------------------------------------------------------------------------

lint-soc:
	$(VERILATOR) \
		--lint-only \
		$(VERILATOR_COMMON_FLAGS) \
		--top-module $(TOP) \
		$(RTL_SRCS) \
		$(DV_SRCS) \
		$(SIM_SRCS)


# -----------------------------------------------------------------------------
# Complete lint gate
# -----------------------------------------------------------------------------

lint-all: lint-core lint-synth lint-soc


# =============================================================================
# Performance Benchmarks
# =============================================================================

benchmarks: hw
	$(PYTHON) \
		$(DV_DIR)/benchmarks/scripts/run_benchmarks.py


# =============================================================================
# Generic Synthesis
# =============================================================================

synth:
	mkdir -p $(SYN_DIR)/reports

	$(YOSYS) \
		-s $(SYN_DIR)/yosys/synth.ys \
		2>&1 | tee $(SYN_DIR)/reports/yosys.log


# =============================================================================
# Tool Check
# =============================================================================

toolcheck:
	@echo "============================================================"
	@echo "Aether Toolchain"
	@echo "============================================================"

	@echo
	@echo "Verilator:"
	@$(VERILATOR) --version

	@echo
	@echo "Yosys:"
	@$(YOSYS) -V

	@echo
	@echo "RISC-V GCC:"
	@$(RISCV_GCC) --version | head -n 1

	@echo
	@echo "Spike:"
	@$(SPIKE) --help 2>&1 | head -n 1

	@echo
	@echo "Python:"
	@$(PYTHON) --version


# =============================================================================
# Complete RTL Verification Gate
# =============================================================================
#
# This is the command to run before declaring the RTL clean.
#
# Sequence:
#
#   1. Verify tools
#   2. Lint every relevant configuration
#   3. Run basic sanity program
#   4. Run complete architectural regression
#   5. Compare one representative program against Spike
#   6. Run performance benchmarks
#
# regression generates the ELF/BIN files required by spike.
# =============================================================================

verify:
	@echo
	@echo "============================================================"
	@echo "AETHER RTL VERIFICATION"
	@echo "============================================================"
	@echo

	$(MAKE) toolcheck

	@echo
	@echo "------------------------------------------------------------"
	@echo "Lint"
	@echo "------------------------------------------------------------"
	$(MAKE) lint-all

	@echo
	@echo "------------------------------------------------------------"
	@echo "Sanity"
	@echo "------------------------------------------------------------"
	$(MAKE) sanity

	@echo
	@echo "------------------------------------------------------------"
	@echo "Architectural Regression"
	@echo "------------------------------------------------------------"
	$(MAKE) regression

	@echo
	@echo "------------------------------------------------------------"
	@echo "Spike Differential Test"
	@echo "------------------------------------------------------------"
	$(MAKE) spike-regression

	@echo
	@echo "------------------------------------------------------------"
	@echo "Performance Benchmarks"
	@echo "------------------------------------------------------------"
	$(MAKE) benchmarks

	@echo
	@echo "============================================================"
	@echo "AETHER RTL VERIFICATION PASSED"
	@echo "============================================================"


# =============================================================================
# Cleanup
# =============================================================================

clean:
	rm -rf $(OBJ_DIR)

	rm -f \
		*.vcd \
		rtl.log \
		spike.log \
		spike_cmd.txt \
		regression.log

	$(MAKE) -C $(SW_DIR) clean

	rm -f $(SW_DIR)/program.hex

	rm -rf $(DV_DIR)/tests/bin
	rm -rf $(DV_DIR)/benchmarks/bin
	rm -rf $(DV_DIR)/benchmarks/results

	rm -rf $(SYN_DIR)/reports

clean-hw:
	rm -rf $(OBJ_DIR)
	rm -f *.vcd


# =============================================================================
# Clean Verification
# =============================================================================
#
# Useful final release check:
#
#     make clean-verify
#
# This proves the project does not depend on stale obj_dir contents or
# previously compiled test binaries.
# =============================================================================

clean-verify:
	$(MAKE) clean
	$(MAKE) verify


# =============================================================================
# Phony Targets
# =============================================================================

.PHONY: \
	hw \
	sw \
	sim \
	sanity \
	regression \
	regression-axi-stress \
	spike \
	spike-regression \
	lint \
	lint-core \
	lint-synth \
	lint-soc \
	lint-all \
	benchmarks \
	synth \
	toolcheck \
	verify \
	clean \	
	clean-hw \
	clean-verify