#!/bin/sh
# equivalent_check.sh: handrolled Why3 equivalent check.
# Usage: equivalent_check.sh <evidence.txt> <haskell_report.txt> <output.txt>
# Exit 0 only if the C evidence says VERIFIED_BY_CHECKER
# and the Haskell report says PASS. Lean, Prolog and XML
# are checked separately by run-stack.sh; this script
# records the Why3-equivalent status honestly: the
# Why3 tool did NOT run.
set -e
EVIDENCE="$1"
HASKELL_REPORT="$2"
OUT="$3"
if ! grep -q "^VERIFIED_BY_CHECKER" "$EVIDENCE"; then
    echo "why3 equivalent: C evidence is not VERIFIED_BY_CHECKER" >&2
    exit 1
fi
if ! grep -q "^result=PASS" "$HASKELL_REPORT"; then
    echo "why3 equivalent: Haskell report is not PASS" >&2
    exit 1
fi
cat > "$OUT" <<EOF
WHY3_TOOL_NOT_RUN
why3_equivalent=PASS
discharge_c_checker=VERIFIED_BY_CHECKER
discharge_haskell=PASS
note=See why3/OBLIGATIONS.md for the goal mapping. This is not a Why3 proof.
EOF
