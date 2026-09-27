# =============================================================================
# Aether RV64IM — Sky130HD Initial Timing Constraints
# =============================================================================

current_design core_top


# -----------------------------------------------------------------------------
# Clock
# -----------------------------------------------------------------------------

set clk_name      core_clk
set clk_port_name clk
set clk_period    20.0
set clk_io_pct    0.20

set clk_port [get_ports $clk_port_name]

create_clock \
    -name $clk_name \
    -period $clk_period \
    $clk_port


# -----------------------------------------------------------------------------
# Virtual clock for external interface timing
# -----------------------------------------------------------------------------

set io_clk_name vclk_core

create_clock \
    -name $io_clk_name \
    -period $clk_period


# -----------------------------------------------------------------------------
# Input timing
# -----------------------------------------------------------------------------
#
# Explicitly enumerate synchronous inputs instead of trying to manipulate
# OpenSTA collections. rst_n is asynchronous and is excluded here.
# -----------------------------------------------------------------------------

set_input_delay \
    [expr $clk_period * $clk_io_pct] \
    -clock $io_clk_name \
    [get_ports {
        ibus_gnt_i
        ibus_rvalid_i
        ibus_rdata_i
        dbus_gnt_i
        dbus_rvalid_i
        dbus_rdata_i
    }]


# -----------------------------------------------------------------------------
# Output timing
# -----------------------------------------------------------------------------

set_output_delay \
    [expr $clk_period * $clk_io_pct] \
    -clock $io_clk_name \
    [get_ports {
        ibus_req_o
        ibus_addr_o
        dbus_req_o
        dbus_we_o
        dbus_be_o
        dbus_addr_o
        dbus_wdata_o
        perf_cycles_o
        perf_instructions_o
        perf_branches_o
        perf_branches_taken_o
        perf_redirects_o
        perf_loads_o
        perf_stores_o
        perf_muldiv_o
        perf_ex_stall_cycles_o
        perf_mem_stall_cycles_o
    }]


# -----------------------------------------------------------------------------
# Asynchronous reset
# -----------------------------------------------------------------------------

set_false_path -from [get_ports rst_n]
