/* generator.c: the Generator side of Mirror Duck.
 * It proposes a transform and an executable contract, but it
 * can never mark its own work verified. Only the separate
 * checker binary may write a VERIFIED record.
 *
 * Proposed transform, stated in the scratchpad it writes:
 *   per-second mean over present sensors only.
 * Contract, also in the scratchpad:
 *   row count is preserved, timestamps are preserved in
 *   order, missing readings stay missing (they are never
 *   filled, and a missing reading contributes nothing to
 *   the mean), and entropy bits come from temperature
 *   delta parity for the first listed sensor, never from
 *   a PRNG.
 *
 * Usage: generator <input.csv> <mean.csv> <scratchpad.txt> <entropy_bits.txt>
 */
#include "csv.h"
#include "temp_entropy.h"

#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    if (argc != 5) {
        fprintf(stderr, "usage: generator <input.csv> <mean.csv> <scratchpad.txt> <entropy_bits.txt>\n");
        return 2;
    }
    MdReader r;
    if (md_reader_open(&r, argv[1]) != 0) {
        fprintf(stderr, "generator: cannot open input %s\n", argv[1]);
        return 2;
    }
    FILE *mean_fp = fopen(argv[2], "w");
    FILE *bits_fp = fopen(argv[4], "w");
    if (mean_fp == NULL || bits_fp == NULL) {
        fprintf(stderr, "generator: cannot open output\n");
        md_reader_close(&r);
        return 2;
    }
    fprintf(mean_fp, "timestamp,mean,present_count\n");

    MdDataRow row;
    long first_ts = 0;
    long last_ts = 0;
    long row_count = 0;
    long entropy_bits = 0;
    int have_prev = 0;
    long prev_sensor0 = 0;

    int rc;
    while ((rc = md_reader_next(&r, &row)) == 1) {
        if (row_count == 0) {
            first_ts = row.timestamp;
        }
        last_ts = row.timestamp;
        row_count++;

        long sum = 0;
        int present = 0;
        for (int i = 0; i < row.nsensors; i++) {
            if (row.present[i]) {
                sum += row.values[i];
                present++;
            }
        }
        double mean = present > 0 ? (double)sum / (double)present : 0.0;
        fprintf(mean_fp, "%ld,%.6f,%d\n", row.timestamp, mean, present);

        if (row.present[0]) {
            if (have_prev) {
                int bit = md_temp_entropy_bit(prev_sensor0, row.values[0]);
                fputc(bit ? '1' : '0', bits_fp);
                entropy_bits++;
            }
            prev_sensor0 = row.values[0];
            have_prev = 1;
        }
    }
    if (rc != 0) {
        fprintf(stderr, "generator: malformed input row\n");
        fclose(mean_fp);
        fclose(bits_fp);
        md_reader_close(&r);
        return 1;
    }
    fputc('\n', bits_fp);
    fclose(mean_fp);
    fclose(bits_fp);

    FILE *scratch = fopen(argv[3], "w");
    if (scratch == NULL) {
        fprintf(stderr, "generator: cannot open scratchpad\n");
        md_reader_close(&r);
        return 2;
    }
    fprintf(scratch, "transform=per_second_mean_over_present_sensors\n");
    fprintf(scratch, "preserve_row_count=1\n");
    fprintf(scratch, "preserve_timestamps=1\n");
    fprintf(scratch, "missing_stays_missing=1\n");
    fprintf(scratch, "sensor_count=%d\n", r.nsensors);
    fprintf(scratch, "first_timestamp=%ld\n", first_ts);
    fprintf(scratch, "last_timestamp=%ld\n", last_ts);
    fprintf(scratch, "row_count=%ld\n", row_count);
    fprintf(scratch, "entropy_source=temperature_delta_parity\n");
    fprintf(scratch, "entropy_sensor_id=%ld\n", r.nsensors > 0 ? r.sensor_ids[0] : -1);
    fprintf(scratch, "entropy_bits=%ld\n", entropy_bits);
    fprintf(scratch, "status=proposed\n");
    fclose(scratch);
    md_reader_close(&r);
    printf("generator: %ld rows, sensors=%d, entropy_bits=%ld, status=proposed (not verified)\n",
           row_count, r.nsensors, entropy_bits);
    return 0;
}
