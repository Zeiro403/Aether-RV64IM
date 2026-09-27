# =============================================================================
# Aether RV64IM — Sky130HD ORFS Configuration
# =============================================================================

export DESIGN_NICKNAME = aether
export DESIGN_NAME     = core_top
export PLATFORM        = sky130hd


# -----------------------------------------------------------------------------
# RTL
# -----------------------------------------------------------------------------
#
# AETHER_HOME is supplied by the invocation environment.
#
# Slang must receive the complete SystemVerilog design together because Aether
# uses riscv_pkg across multiple source files.
# -----------------------------------------------------------------------------

export VERILOG_FILES = \
	$(AETHER_HOME)/rtl/include/riscv_pkg.sv \
	$(AETHER_HOME)/rtl/core/core_top.sv \
	$(sort $(wildcard $(AETHER_HOME)/rtl/core/fetch/*.sv)) \
	$(sort $(wildcard $(AETHER_HOME)/rtl/core/decode/*.sv)) \
	$(sort $(wildcard $(AETHER_HOME)/rtl/core/pipeline/*.sv)) \
	$(sort $(wildcard $(AETHER_HOME)/rtl/core/exec/*.sv)) \
	$(sort $(wildcard $(AETHER_HOME)/rtl/core/mem/*.sv)) \
	$(sort $(wildcard $(AETHER_HOME)/rtl/core/perf/*.sv)) \
	$(sort $(wildcard $(AETHER_HOME)/rtl/core/sys/*.sv))


# -----------------------------------------------------------------------------
# SystemVerilog frontend
# -----------------------------------------------------------------------------

export SYNTH_HDL_FRONTEND = slang

export SYNTH_SLANG_ARGS = \
	--std 1800-2017 \
	--single-unit \
	-I$(AETHER_HOME)/rtl/include \
	-DSYNTHESIS


# -----------------------------------------------------------------------------
# Timing constraints
# -----------------------------------------------------------------------------

export SDC_FILE = $(AETHER_HOME)/syn/sky130hd/constraint.sdc


# -----------------------------------------------------------------------------
# Physical implementation targets
# -----------------------------------------------------------------------------
#
# Baseline physical targets used for the final Sky130HD implementation.
# -----------------------------------------------------------------------------

export CORE_UTILIZATION = 45
export PLACE_DENSITY_LB_ADDON = 0.20
export TNS_END_PERCENT = 100

# -----------------------------------------------------------------------------
# Formal equivalence checking
# -----------------------------------------------------------------------------
#
# ORFS automatically enables Kepler Formal when its executable is present.
# The prebuilt Docker Kepler binary currently terminates with SIGILL in this
# WSL/Docker environment, so disable ORFS's optional LEC stage.
#
# Functional correctness is covered separately by Aether's architectural,
# regression, Spike differential, and stress-test flows.
#
export LEC_CHECK = 0

# -----------------------------------------------------------------------------
# Post-placement / routing electrical margins
# -----------------------------------------------------------------------------
#
# Final extracted RC exposed a small number of max-slew and max-capacitance
# violations that were not visible before detailed routing.
#
# Ask repair_design to over-fix these constraints by 20% before detailed
# routing, providing margin for routed wire RC and antenna-diode loading.
#
export SLEW_MARGIN = 20
export CAP_MARGIN  = 20
