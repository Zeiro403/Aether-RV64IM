#include "Vsoc_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <cstdint>
#include <cstdio>

static constexpr vluint64_t MAX_SIM_TIME = 20'000'000;

double sc_time_stamp() { return 0; }

static void print_perf(const Vsoc_top* top) {
    const uint64_t cycles =
        static_cast<uint64_t>(top->perf_cycles_o);

    const uint64_t instructions =
        static_cast<uint64_t>(top->perf_instructions_o);

    const double cpi =
        (instructions != 0)
            ? static_cast<double>(cycles) /
              static_cast<double>(instructions)
            : 0.0;

    printf(
        "[AETHER PERF] "
        "cycles=%llu "
        "instructions=%llu "
        "cpi=%.4f "
        "branches=%llu "
        "taken=%llu "
        "redirects=%llu "
        "loads=%llu "
        "stores=%llu "
        "muldiv=%llu "
        "ex_stall=%llu "
        "mem_stall=%llu\n",

        static_cast<unsigned long long>(top->perf_cycles_o),
        static_cast<unsigned long long>(top->perf_instructions_o),
        cpi,

        static_cast<unsigned long long>(top->perf_branches_o),
        static_cast<unsigned long long>(top->perf_branches_taken_o),
        static_cast<unsigned long long>(top->perf_redirects_o),

        static_cast<unsigned long long>(top->perf_loads_o),
        static_cast<unsigned long long>(top->perf_stores_o),
        static_cast<unsigned long long>(top->perf_muldiv_o),

        static_cast<unsigned long long>(top->perf_ex_stall_cycles_o),
        static_cast<unsigned long long>(top->perf_mem_stall_cycles_o)
    );
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    
    Vsoc_top* top = new Vsoc_top;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("trace.vcd");

    top->clk = 0;
    top->rst_n = 0;
    
    vluint64_t main_time = 0;
    bool test_passed = false;

    while (!Verilated::gotFinish() && main_time < MAX_SIM_TIME ) {
        if (main_time % 10 == 0) top->clk = !top->clk;
        if (main_time > 50) top->rst_n = 1;

        top->eval();

        // Check Hardware Snoop Pins
        if (top->sim_exit_o) {
            if (top->sim_pass_o) {
                printf("[SIM] EXIT DETECTED at %llu ns\n",
                    static_cast<unsigned long long>(main_time));
                printf("[SIM] TEST PASSED!\n");
                test_passed = true;
            } else {
                printf("[SIM] EXIT DETECTED at %llu ns\n",
                    static_cast<unsigned long long>(main_time));
                printf("[SIM] TEST FAILED (Exit Code != 1)\n");
                test_passed = false;
            }

            print_perf(top);
            break;
        }
        if (main_time >= MAX_SIM_TIME ) {
            printf("[SIM] ERROR: TEST TIMEOUT!\n");
            print_perf(top);
        }

        tfp->dump(main_time);
        main_time++;
    }

    if (main_time >= MAX_SIM_TIME ) {
        printf("[SIM] ERROR: TEST TIMEOUT!\n");
    }

    top->final();
    tfp->close();
    delete top;
    
    return test_passed ? 0 : 1;
}