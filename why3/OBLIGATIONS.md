# Why3 obligations — handrolled equivalent

Why3 is NOT installed on this VM (checked 2026-10-27).
The file why3/mirror.mlw is therefore NOT a Why3 proof.
Each goal below is discharged by an executed check,
listed with the file that records it. The script
why3/equivalent_check.sh verifies that all of those
records say PASS or VERIFIED, and only then writes
out/why3_equivalent.txt. If any discharging check
fails, the equivalent fails too.

- G1 row_count_preserved
  Discharged by: C checker out/evidence.txt rows=86400,
  Haskell out/haskell_report.txt rows=86400, mean_rows=86400
  Lean: MirrorDuck.map_preserves_length

- G2 timestamps_preserved
  Discharged by: C checker timestamp match per row,
  Haskell timestamps contiguous check, both PASS
  Lean: timestamps are list indices, not proved separately
  in Lean; the executable checks carry this goal

- G3 mean_correct
  Discharged by: C checker mean recomputation per row,
  tolerance 0.000002, Haskell mean recomputation per row,
  same tolerance, both PASS

- G4 entropy_bit_range
  Discharged by: Lean MirrorDuck.tempBit_eq_zero_or_one,
  C checker entropy bit recomputation, 86399 bits matched
  Haskell does not recompute entropy bits; C carries this goal

- G5 contract_not_weakened
  Discharged by: C checker preserve_* = 1 check and
  status=proposed check, Prolog verified query, both PASS

- G6 present_le_total
  Discharged by: Lean MirrorDuck.present_le_total,
  C checker present_count match per row, Haskell same

What is NOT claimed:
  - Why3 did not run, did not typecheck mirror.mlw,
    did not prove any goal.
  - The handrolled equivalent is a set of executed
    recomputations plus Lean lemmas, not a Why3 proof.
  - When Why3 is available, run it on mirror.mlw and
    replace this mapping with its actual output.
