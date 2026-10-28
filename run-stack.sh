#!/bin/sh
# run-stack.sh: run the full Mirror Duck stack, in order.
# Usage: run-stack.sh [input.csv]
# Default input is the supplied temperature file, if present.
# Layers, in order:
#   1. C11 generator + independent checker
#   2. Haskell orchestration / AST
#   3. Prolog structural queries
#   4. Lean 4 core lemmas (no Mathlib, no admitted goals)
#   5. XML scratchpad + XSLT view (xsltproc; xmllint is absent,
#      xsltproc parsing the XML is the well-formedness check)
#   6. Why3 obligations: Why3 tool NOT run (absent on this VM);
#      handrolled equivalent, see why3/OBLIGATIONS.md
# Exit 0 and write STACK_VERIFIED only if every layer passes.
# Nothing here pushes or creates a remote repo.
set -u
cd "$(dirname "$0")"
INPUT="${1:-$HOME/workspace/user/files/6165BA05-2AE5-4EA8-BE9B-EB4A22C7A3E7-basketdata-2000-04-01.csv}"
if [ ! -f "$INPUT" ]; then
    echo "run-stack: input not found: $INPUT" >&2
    exit 2
fi
fail() {
    echo "STACK_FAILED at $1" > out/stack_evidence.txt
    echo "run-stack: FAILED at $1" >&2
    exit 1
}
mkdir -p out

echo "== layer 1: C11 generator + checker =="
make > out/make.log 2>&1 || fail "make"
./generator "$INPUT" out/mean.csv out/scratchpad.txt out/entropy_bits.txt || fail "generator"
./checker "$INPUT" out/mean.csv out/scratchpad.txt out/entropy_bits.txt out/evidence.txt || fail "c_checker"

echo "== layer 2: Haskell orchestration / AST =="
ghc -O2 -o mirror-hs haskell/Mirror.hs > out/ghc.log 2>&1 || fail "ghc"
./mirror-hs "$INPUT" out/mean.csv out/scratchpad.txt out/haskell_report.txt || fail "haskell"

echo "== layer 3: Prolog structural queries =="
awk -f prolog/generate_facts.awk out/scratchpad.txt > out/prolog_facts.pl || fail "prolog_facts"
if grep -q "^VERIFIED_BY_CHECKER" out/evidence.txt; then
    echo "checker_passed." >> out/prolog_facts.pl
else
    echo "checker_failed." >> out/prolog_facts.pl
fi
timeout 30 swipl -q -g "consult('prolog/mirror.pl'), consult('out/prolog_facts.pl'), (verified -> writeln(verified_ok), halt(0) ; writeln(verified_fail), halt(1))" -t halt < /dev/null > out/prolog_report.txt 2>&1 || fail "prolog_verified"
grep -q "verified_ok" out/prolog_report.txt || fail "prolog_verified_output"

echo "== layer 4: Lean 4 lemmas =="
if [ -x "$HOME/.elan/toolchains/leanprover--lean4---v4.12.0/bin/lean" ]; then
    LEAN_BIN="$HOME/.elan/toolchains/leanprover--lean4---v4.12.0/bin/lean"
elif [ -x "$HOME/.elan/bin/lean" ]; then
    LEAN_BIN="$HOME/.elan/bin/lean"
else
    LEAN_BIN="lean"
fi
"$LEAN_BIN" lean/MirrorDuck.lean > out/lean.log 2>&1 || fail "lean"
if grep -q "sorry" lean/MirrorDuck.lean; then
    fail "lean_sorry_found"
fi
echo "lean: PASS" > out/lean_report.txt

echo "== layer 5: XML scratchpad + XSLT =="
sh xml/generate_xml.sh out/scratchpad.txt out/evidence.txt out/scratchpad.xml || fail "xml_generate"
xsltproc xml/scratchpad.xsl out/scratchpad.xml > out/scratchpad.html 2> out/xslt.log || fail "xsltproc"
echo "xml: PASS" > out/xml_report.txt

echo "== layer 6: Why3 obligations, handrolled equivalent =="
sh why3/equivalent_check.sh out/evidence.txt out/haskell_report.txt out/why3_equivalent.txt || fail "why3_equivalent"

{
    echo "STACK_VERIFIED"
    echo "input=$INPUT"
    echo "--- c_checker ---"
    cat out/evidence.txt
    echo "--- haskell ---"
    cat out/haskell_report.txt
    echo "--- prolog ---"
    cat out/prolog_report.txt
    echo "--- lean ---"
    cat out/lean_report.txt
    echo "--- xml ---"
    cat out/xml_report.txt
    echo "--- why3_equivalent ---"
    cat out/why3_equivalent.txt
} > out/stack_evidence.txt
echo "run-stack: STACK_VERIFIED"
cat out/stack_evidence.txt
