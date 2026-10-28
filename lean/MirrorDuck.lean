/- MirrorDuck.lean: Lean 4 lemmas for Mirror Duck.
   Core Lean 4.12 only. No Mathlib, no admitted goals,
   no axioms beyond Lean's own. These lemmas prove the abstract
   invariants that the C checker and the Haskell layer
   instantiate on the temperature file:
     1. A map transform preserves row count.
     2. A filter transform can only keep or drop rows,
        never add them, so it cannot guarantee the
        preserve_row_count contract on a file with
        missing readings.
     3. A temperature delta parity bit is 0 or 1.
     4. The present-sensor count never exceeds the
        total sensor count.
   This file does not parse CSV and does not claim to
   verify the file by itself; it proves the list-level
   invariants the executable checkers rely on.
-/

namespace MirrorDuck

/-- A map transform preserves length: this is the
    length-preserving invariant for MeanOverPresent. -/
theorem map_preserves_length {α β : Type} (f : α → β) (xs : List α) :
    (xs.map f).length = xs.length :=
  List.length_map xs f

/-- A filter transform never lengthens a list. -/
theorem filter_length_le {α : Type} (p : α → Bool) (xs : List α) :
    (xs.filter p).length ≤ xs.length :=
  List.length_filter_le p xs

/-- Temperature delta parity bit, as used by
    src/temp_entropy.c: parity of the absolute change. -/
def tempBit (prev curr : Int) : Nat :=
  (prev - curr).natAbs % 2

theorem tempBit_lt_two (prev curr : Int) : tempBit prev curr < 2 := by
  unfold tempBit
  exact Nat.mod_lt _ (by decide : 0 < 2)

theorem tempBit_eq_zero_or_one (prev curr : Int) :
    tempBit prev curr = 0 ∨ tempBit prev curr = 1 := by
  have h := tempBit_lt_two prev curr
  omega

/-- Present count for a row of optional readings. -/
def presentCount (xs : List (Option Int)) : Nat :=
  (xs.filter (fun x => x.isSome)).length

theorem present_le_total (xs : List (Option Int)) :
    presentCount xs ≤ xs.length := by
  unfold presentCount
  exact List.length_filter_le (fun x => x.isSome) xs

end MirrorDuck
