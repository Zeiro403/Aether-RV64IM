import sys
import re


# ============================================================================
# Regular expressions
# ============================================================================

# RTL retirement format:
#
#   core   0: 0x0000000080000000 (0x00020117) x2  0x80020000
#   core   0: 0x0000000080000010 (0x30529073)
#
RTL_RE = re.compile(
    r"core\s+0:\s+"
    r"0x([0-9a-fA-F]+)\s+"
    r"\(0x([0-9a-fA-F]{8})\)"
    r"(?:\s+x(\d+)\s+0x([0-9a-fA-F]+))?"
)


# Spike instruction line:
#
#   core   0: 0x0000000080000000 (0x00020117) auipc sp, 0x20
#
# Important:
# Do NOT match Spike's architectural-effect line:
#
#   core   0: 3 0x0000000080000000 ...
#
SPIKE_INSTR_RE = re.compile(
    r"core\s+0:\s+"
    r"0x([0-9a-fA-F]+)\s+"
    r"\(0x([0-9a-fA-F]{8})\)"
)


# Spike architectural effect line:
#
#   core   0: 3 0x0000000080000000 (0x00020117) x2 0x...
#
SPIKE_COMMIT_RE = re.compile(
    r"core\s+0:\s+\d+\s+"
    r"0x([0-9a-fA-F]+)\s+"
    r"\(0x([0-9a-fA-F]{8})\)"
    r"(?:\s+x(\d+)\s+0x([0-9a-fA-F]+))?"
)


PROGRAM_START = 0x80000000


# ============================================================================
# Event representation
# ============================================================================

def make_event(pc, instr, rd=None, rd_value=None):
    return {
        "pc": pc,
        "instr": instr,
        "rd": rd,
        "rd_value": rd_value,
    }


# ============================================================================
# RTL parser
# ============================================================================

def parse_rtl_log(filepath):
    events = []

    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            match = RTL_RE.search(line)

            if not match:
                continue

            pc = int(match.group(1), 16)
            instr = int(match.group(2), 16)

            rd = None
            rd_value = None

            if match.group(3) is not None:
                rd = int(match.group(3), 10)
                rd_value = int(match.group(4), 16)

                # x0 writes have no architectural effect.
                if rd == 0:
                    rd = None
                    rd_value = None

            events.append(
                make_event(
                    pc,
                    instr,
                    rd,
                    rd_value
                )
            )

    return events


# ============================================================================
# Spike parser
# ============================================================================

def parse_spike_log(filepath):
    events = []

    current_event = None
    found_program = False

    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        for line in f:

            # ----------------------------------------------------------------
            # First look for the instruction execution line.
            # ----------------------------------------------------------------

            instr_match = SPIKE_INSTR_RE.search(line)

            if instr_match:
                pc = int(instr_match.group(1), 16)
                instr = int(instr_match.group(2), 16)

                # Skip Spike's boot ROM.
                if not found_program:
                    if pc < PROGRAM_START:
                        continue

                    found_program = True

                current_event = make_event(
                    pc,
                    instr
                )

                events.append(current_event)

                continue


            # ----------------------------------------------------------------
            # Then associate Spike's architectural-effect line with the most
            # recently parsed instruction.
            # ----------------------------------------------------------------

            commit_match = SPIKE_COMMIT_RE.search(line)

            if commit_match and current_event is not None:
                pc = int(commit_match.group(1), 16)
                instr = int(commit_match.group(2), 16)

                # Only attach effects belonging to this instruction.
                if (
                    pc == current_event["pc"]
                    and instr == current_event["instr"]
                ):
                    if commit_match.group(3) is not None:
                        rd = int(commit_match.group(3), 10)
                        rd_value = int(commit_match.group(4), 16)

                        if rd != 0:
                            current_event["rd"] = rd
                            current_event["rd_value"] = rd_value

    return events


# ============================================================================
# Formatting
# ============================================================================

def format_event(event):
    text = (
        f"PC=0x{event['pc']:016x} | "
        f"Instr=0x{event['instr']:08x}"
    )

    if event["rd"] is not None:
        text += (
            f" | x{event['rd']:<2} = "
            f"0x{event['rd_value']:016x}"
        )

    return text


# ============================================================================
# Comparison
# ============================================================================

def compare_events(rtl_events, spike_events):

    compare_count = min(
        len(rtl_events),
        len(spike_events)
    )

    for i in range(compare_count):

        rtl = rtl_events[i]
        spike = spike_events[i]

        # --------------------------------------------------------------------
        # Every retired instruction must agree on PC and instruction.
        # --------------------------------------------------------------------

        if (
            rtl["pc"] != spike["pc"]
            or rtl["instr"] != spike["instr"]
        ):
            print(f"\n❌ RETIREMENT MISMATCH at #{i + 1}")

            print(
                "   RTL   : "
                + format_event(rtl)
            )

            print(
                "   SPIKE : "
                + format_event(spike)
            )

            return False


        # --------------------------------------------------------------------
        # GPR architectural effect must also agree.
        # --------------------------------------------------------------------

        if rtl["rd"] != spike["rd"]:
            print(f"\n❌ REGISTER-WRITE MISMATCH at retirement #{i + 1}")

            print(
                "   RTL   : "
                + format_event(rtl)
            )

            print(
                "   SPIKE : "
                + format_event(spike)
            )

            return False


        if (
            rtl["rd"] is not None
            and rtl["rd_value"] != spike["rd_value"]
        ):
            print(f"\n❌ REGISTER-DATA MISMATCH at retirement #{i + 1}")

            print(
                "   RTL   : "
                + format_event(rtl)
            )

            print(
                "   SPIKE : "
                + format_event(spike)
            )

            return False


    # ------------------------------------------------------------------------
    # RTL may stop earlier because the simulation testbench terminates when
    # the test signals completion. Spike can continue beyond that point.
    #
    # Therefore:
    #
    #     RTL prefix == Spike prefix
    #
    # is acceptable.
    # ------------------------------------------------------------------------

    if len(rtl_events) > len(spike_events):
        print(
            "\n❌ RTL retired more instructions than were available "
            "in the Spike reference."
        )

        print(
            f"   RTL   : {len(rtl_events)}"
        )

        print(
            f"   Spike : {len(spike_events)}"
        )

        return False

    return True


# ============================================================================
# Main
# ============================================================================

def main():

    if len(sys.argv) != 3:
        print(
            "Usage: python3 spike_cmp.py "
            "<rtl_log_file> <spike_log_file>"
        )
        sys.exit(1)

    rtl_log = sys.argv[1]
    spike_log = sys.argv[2]

    print(f"🔍 Parsing RTL retirement log: {rtl_log}")
    rtl_events = parse_rtl_log(rtl_log)

    print(f"🔍 Parsing Spike log:          {spike_log}")
    spike_events = parse_spike_log(spike_log)

    print()
    print(
        f"📊 Extracted {len(rtl_events)} RTL retirements "
        f"and {len(spike_events)} Spike instructions."
    )

    if len(rtl_events) == 0:
        print("\n❌ No RTL retirement events found.")
        sys.exit(1)

    if len(spike_events) == 0:
        print("\n❌ No Spike instructions found.")
        sys.exit(1)

    success = compare_events(
        rtl_events,
        spike_events
    )

    if not success:
        sys.exit(1)

    print()
    print(
        f"✅ SUCCESS: {len(rtl_events)} RTL retirements "
        "match the Spike architectural trace."
    )

    if len(spike_events) > len(rtl_events):
        print(
            f"   Spike contains "
            f"{len(spike_events) - len(rtl_events)} "
            "additional instructions after RTL termination."
        )

    sys.exit(0)


if __name__ == "__main__":
    main()