/* mirror.pl: Prolog structural queries for Mirror Duck.
   This layer checks structure, not recomputation.
   Recomputation of means and entropy bits is done by
   the C checker and the Haskell layer; this layer asks:
   does the contract, as stated in the facts file, have
   the shape a verified result is allowed to have?
   Facts are generated from scratchpad.txt and evidence.txt
   by generate_facts.awk, not hand-written here, so a
   weakened scratchpad produces weakened facts and the
   verified query fails.
   Main query: verified.
   Supporting queries: contract_not_weakened,
   generator_proposed, transform_ok, entropy_ok.
*/

verified :-
    contract_not_weakened,
    generator_proposed,
    checker_passed,
    transform_ok,
    entropy_ok,
    sensor_count_positive,
    row_count_positive,
    timestamps_ordered.

contract_not_weakened :-
    preserve_row_count(1),
    preserve_timestamps(1),
    missing_stays_missing(1).

generator_proposed :-
    status(proposed).

transform_ok :-
    transform(per_second_mean_over_present_sensors).

entropy_ok :-
    entropy_source(temperature_delta_parity).

sensor_count_positive :-
    sensor_count(N),
    N > 0.

row_count_positive :-
    row_count(N),
    N > 0.

timestamps_ordered :-
    first_timestamp(A),
    last_timestamp(B),
    A < B.
