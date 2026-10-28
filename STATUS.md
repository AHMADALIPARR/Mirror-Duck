# MIRROR-DUCK — STATUS

Local only. No repo created, nothing pushed, no token used.
This is a separate project from SWELLDRA-200B, built locally
ready for the user to name a destination if he wants one.

## What this is

Mirror Duck, minimal C11 prototype, one language, one
invariant family, one separate checker process. The full
five-toolchain stack (Haskell, Prolog, Why3, Lean, XML) is
not built here; this is the minimal demo the grader pass
recommended first.

Two-level inspection, as specified:
  Generator -> Program -> Behavior
  Generator Specification <-> Generator Implementation
Load-bearing rule, enforced in code, not in prose:
  the generator may propose a correction, but it can
  never mark its own correction verified. Only the
  separate checker binary may write VERIFIED_BY_CHECKER,
  and only after recomputing from the original input.

## Temperature true-entropy case, added 2026-10-27

Input supplied by the user:
  workspace/user/files/6165BA05-2AE5-4EA8-BE9B-EB4A22C7A3E7-basketdata-2000-04-01.csv
  8.5 MB, 86409 lines total
  Metadata: samples per record 10, seconds per record 10,
  records per packet 30, trial size 200, eggs reporting 25,
  start 2000-04-01 00:00:00 UTC (954547200),
  end 2000-04-01 23:59:59 UTC (954633599), 86400 seconds
  Sensor ids: 1, 28, 33, 37, 100-103, 107-112, 114-116, 118,
  1000, 1005, 1021, 1022, 1024, 1025, 1027 (25 sensors)
  Data rows: 86400, timestamps contiguous +1, no gaps
  Values: 2,145,238 present, 14,762 missing, min 62, max 136,
  mean 100.00 overall and about 100.00 per sensor
  Missing is concentrated in sensor 33 (13,810 missing),
  sensor 110 (900), sensor 115 (27), sensor 1000 (25)
  The file carries no unit label, so the code treats
  readings as raw sensor values, never as degrees F or C.
  The user calls this temperature data; the code does not
  invent a unit the file does not state.

Transform proposed by the generator:
  per-second mean over present sensors only.
  Missing readings stay missing: they contribute nothing
  to the mean, and present_count records how many sensors
  were present that second.

Executable contract (out/scratchpad.txt, key=value, not prose):
  preserve_row_count=1, preserve_timestamps=1,
  missing_stays_missing=1, sensor_count=25,
  transform=per_second_mean_over_present_sensors,
  status=proposed

Entropy, sourced from the temperature file itself:
  src/temp_entropy.c, bit = parity of the absolute change
  between two successive readings from the first listed
  sensor (id 1, no missing readings). No rand, no srand,
  no time seed, no seeded PRNG anywhere in the build.
  On the full file this gives 86,399 bits, 43,194 ones,
  ratio 0.500. This is a statement about the source, not
  a claim of cryptographic strength or NIST testing.

Checker, separate binary, separate process:
  recomputes every mean and every entropy bit from the
  original input, checks row count, timestamps, present
  counts, scratchpad first/last timestamps, and rejects
  a weakened contract (any preserve_* = 0, wrong sensor
  count, wrong transform, or a scratchpad that already
  claims verified). On failure it writes FAILED with a
  reason and exits non-zero, and writes no verified record.

## Run it

  make
  ./generator <input.csv> out/mean.csv out/scratchpad.txt out/entropy_bits.txt
  ./checker <input.csv> out/mean.csv out/scratchpad.txt out/entropy_bits.txt out/evidence.txt

Example with the supplied file:
  ./generator ~/workspace/user/files/6165BA05-2AE5-4EA8-BE9B-EB4A22C7A3E7-basketdata-2000-04-01.csv out/mean.csv out/scratchpad.txt out/entropy_bits.txt
  ./checker ~/workspace/user/files/6165BA05-2AE5-4EA8-BE9B-EB4A22C7A3E7-basketdata-2000-04-01.csv out/mean.csv out/scratchpad.txt out/entropy_bits.txt out/evidence.txt

## Verification, 2026-10-27, executed

Positive, full file:
  generator: 86400 rows, sensors=25, entropy_bits=86399
  checker: PASS rows=86400 entropy_bits=86399 ones=43194
  evidence: out/evidence.txt, VERIFIED_BY_CHECKER

Negative, checker correctly fails each one, exit 1, FAILED
with a named reason, no verified record written:
  corrupt mean value -> mean output value does not match recomputed mean
  preserve_row_count=0 -> contract weakened
  status=verified in scratchpad -> generator may not pre-verify
  flipped entropy bit -> entropy bit does not match recomputed temperature delta parity
  Good evidence was re-run after the negative tests and passes again.

## Full stack, finished 2026-10-27

Run it end to end:
  sh run-stack.sh [input.csv]
  Default input is the supplied temperature file above.
  Exit 0 and out/stack_evidence.txt STACK_VERIFIED only
  if every layer below passes. Nothing in run-stack.sh
  pushes or creates a remote repo.

Layers, all executed, not just written:
  1. C11 generator + independent checker
     generator 86400 rows, checker PASS, evidence
     VERIFIED_BY_CHECKER, entropy 86399 bits, 43194 ones
  2. Haskell orchestration / AST, GHC 9.4.7
     haskell/Mirror.hs, compiled to mirror-hs
     PASS rows=86400, mean_rows=86400, sensors=25
     AST point, executed: DropMissingRows would drop
     14653 rows, so a filter transform cannot satisfy
     preserve_row_count on this file. MeanOverPresent
     maps every row to one output row, so it can.
     Bug caught by this layer, fixed, not hidden:
     the supplied file uses CRLF line endings. The C
     reader already treats CR as a terminator, but
     Haskell lines strips only LF, so the last sensor
     value parsed as missing on every row, and the
     first Haskell run failed on all rows with a
     filter drop count of 86399. Fix: strip CR before
     parsing in Haskell. After the fix, PASS, and the
     filter drop count is the correct 14653.
  3. Prolog structural queries, SWI-Prolog 9.0.4
     prolog/mirror.pl + facts generated from the
     scratchpad by prolog/generate_facts.awk
     Query verified -> verified_ok, exit 0
     Negative: weakened facts (preserve_row_count=0)
     -> verified_fail, exit 1
     Note: Prolog checks structure, not recomputation.
     Recomputation is layers 1 and 2. Multiple -l
     flags do not load both files in SWI-Prolog here;
     run-stack.sh uses consult inside the goal, which
     works in both orders.
  4. Lean 4 lemmas, Lean 4.12.0 via elan toolchain
     lean/MirrorDuck.lean, core only, no Mathlib,
     no admitted goals, exit 0
     map_preserves_length, filter_length_le,
     tempBit_eq_zero_or_one, present_le_total
  5. XML scratchpad + XSLT view, xsltproc (libxslt)
     xml/generate_xml.sh -> out/scratchpad.xml
     xsltproc xml/scratchpad.xsl -> out/scratchpad.html
     xmllint is absent on this VM; xsltproc parsing
     the XML successfully is the well-formedness check
     used here, and that limit is stated, not hidden.
  6. Why3 obligations, handrolled equivalent only
     Why3 is NOT installed on this VM (checked
     2026-10-27). why3/mirror.mlw is an obligations
     specification, NOT a Why3 proof, and has NOT
     been typechecked by Why3. why3/OBLIGATIONS.md
     maps each goal G1-G6 to the executed check that
     discharges it, and why3/equivalent_check.sh
     verifies those records and writes
     out/why3_equivalent.txt with WHY3_TOOL_NOT_RUN.
     When Why3 is available, run it on mirror.mlw
     and replace this mapping with its actual output.

Full-stack result, 2026-10-27, run-stack.sh:
  STACK_VERIFIED, exit 0, in about 8 seconds
  C PASS, Haskell PASS, Prolog verified_ok,
  Lean PASS, XML PASS, Why3 equivalent PASS
  (with WHY3_TOOL_NOT_RUN stated in its own record)

## Files

  src/csv.c, src/csv.h       streaming basketdata CSV reader, preserves empty fields
  src/temp_entropy.c/.h      temperature delta parity bits, no PRNG
  src/generator.c            proposes transform + contract, status=proposed only
  src/checker.c              independent verification, only writer of VERIFIED_BY_CHECKER
  Makefile                   gcc -std=c11 -Wall -Wextra -O2
  out/                       generated only, not part of the source tree
