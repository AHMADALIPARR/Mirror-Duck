/* checker.c: the independent checker side of Mirror Duck.
 * This is a separate binary and a separate process from the
 * generator. It trusts nothing the generator wrote except as
 * a claim to be re-proved against the original input:
 *   - it recomputes every per-second mean from the input
 *   - it recomputes every entropy bit from the input
 *   - it rejects a weakened contract (any preserve_* = 0,
 *     a wrong sensor count, a wrong transform name, or a
 *     scratchpad that already claims verified)
 * Only this program may write a VERIFIED_BY_CHECKER record,
 * and it writes one only when every check passes. On any
 * failure it writes FAILED, names the first failing check,
 * and exits non-zero.
 *
 * Usage: checker <input.csv> <mean.csv> <scratchpad.txt> <entropy_bits.txt> <evidence.txt>
 */
#include "csv.h"
#include "temp_entropy.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int read_scratchpad(const char *path, char *status, size_t status_len,
                           long *sensor_count, long *row_count,
                           long *first_ts, long *last_ts, long *entropy_bits,
                           int *preserve_rows, int *preserve_ts, int *missing_ok,
                           char *transform, size_t transform_len,
                           char *entropy_source, size_t entropy_source_len) {
    FILE *fp = fopen(path, "r");
    if (fp == NULL) {
        return -1;
    }
    char line[512];
    int seen_transform = 0;
    int seen_entropy = 0;
    int seen_status = 0;
    while (fgets(line, sizeof(line), fp) != NULL) {
        char *eq = strchr(line, '=');
        if (eq == NULL) {
            continue;
        }
        *eq = '\0';
        char *val = eq + 1;
        size_t vlen = strlen(val);
        while (vlen > 0 && (val[vlen - 1] == '\n' || val[vlen - 1] == '\r')) {
            val[--vlen] = '\0';
        }
        if (strcmp(line, "transform") == 0) {
            snprintf(transform, transform_len, "%s", val);
            seen_transform = 1;
        } else if (strcmp(line, "preserve_row_count") == 0) {
            *preserve_rows = atoi(val);
        } else if (strcmp(line, "preserve_timestamps") == 0) {
            *preserve_ts = atoi(val);
        } else if (strcmp(line, "missing_stays_missing") == 0) {
            *missing_ok = atoi(val);
        } else if (strcmp(line, "sensor_count") == 0) {
            *sensor_count = atol(val);
        } else if (strcmp(line, "row_count") == 0) {
            *row_count = atol(val);
        } else if (strcmp(line, "first_timestamp") == 0) {
            *first_ts = atol(val);
        } else if (strcmp(line, "last_timestamp") == 0) {
            *last_ts = atol(val);
        } else if (strcmp(line, "entropy_bits") == 0) {
            *entropy_bits = atol(val);
        } else if (strcmp(line, "entropy_source") == 0) {
            snprintf(entropy_source, entropy_source_len, "%s", val);
            seen_entropy = 1;
        } else if (strcmp(line, "status") == 0) {
            snprintf(status, status_len, "%s", val);
            seen_status = 1;
        }
    }
    fclose(fp);
    if (!seen_transform || !seen_entropy || !seen_status) {
        return -1;
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 6) {
        fprintf(stderr, "usage: checker <input.csv> <mean.csv> <scratchpad.txt> <entropy_bits.txt> <evidence.txt>\n");
        return 2;
    }
    const char *fail_reason = "unknown failure";
    FILE *evidence = fopen(argv[5], "w");
    if (evidence == NULL) {
        fprintf(stderr, "checker: cannot open evidence output\n");
        return 2;
    }

    char status[64] = "";
    char transform[128] = "";
    char entropy_source[128] = "";
    long sp_sensors = -1, sp_rows = -1, sp_first = 0, sp_last = 0, sp_bits = -1;
    int preserve_rows = 0, preserve_ts = 0, missing_ok = 0;
    if (read_scratchpad(argv[3], status, sizeof(status), &sp_sensors, &sp_rows,
                        &sp_first, &sp_last, &sp_bits, &preserve_rows,
                        &preserve_ts, &missing_ok, transform, sizeof(transform),
                        entropy_source, sizeof(entropy_source)) != 0) {
        fail_reason = "scratchpad unreadable or incomplete";
        goto fail;
    }
    if (strcmp(status, "proposed") != 0) {
        fail_reason = "scratchpad does not say status=proposed; a generator may not pre-verify";
        goto fail;
    }
    if (preserve_rows != 1 || preserve_ts != 1 || missing_ok != 1) {
        fail_reason = "contract weakened: a preserve_* field is not 1";
        goto fail;
    }
    if (strcmp(transform, "per_second_mean_over_present_sensors") != 0) {
        fail_reason = "contract transform name mismatch";
        goto fail;
    }
    if (strcmp(entropy_source, "temperature_delta_parity") != 0) {
        fail_reason = "contract entropy source mismatch";
        goto fail;
    }

    MdReader r;
    if (md_reader_open(&r, argv[1]) != 0) {
        fail_reason = "cannot open input";
        goto fail;
    }
    FILE *mean_fp = fopen(argv[2], "r");
    if (mean_fp == NULL) {
        md_reader_close(&r);
        fail_reason = "cannot open mean output";
        goto fail;
    }
    char header[256];
    if (fgets(header, sizeof(header), mean_fp) == NULL) {
        fclose(mean_fp);
        md_reader_close(&r);
        fail_reason = "mean output has no header";
        goto fail;
    }

    FILE *bits_fp = fopen(argv[4], "r");
    if (bits_fp == NULL) {
        fclose(mean_fp);
        md_reader_close(&r);
        fail_reason = "cannot open entropy bits file";
        goto fail;
    }
    char bits_buf[200000];
    size_t bits_len = 0;
    int ch;
    while ((ch = fgetc(bits_fp)) != EOF) {
        if (ch == '0' || ch == '1') {
            if (bits_len >= sizeof(bits_buf)) {
                fclose(bits_fp);
                fclose(mean_fp);
                md_reader_close(&r);
                fail_reason = "entropy bits file too long";
                goto fail;
            }
            bits_buf[bits_len++] = (char)ch;
        }
    }
    fclose(bits_fp);

    MdDataRow row;
    long out_rows = 0;
    long first_ts = 0;
    long last_ts = 0;
    long prev_ts = 0;
    int have_prev = 0;
    int ok = 1;

    int rc;
    while ((rc = md_reader_next(&r, &row)) == 1) {
        if (out_rows == 0) {
            first_ts = row.timestamp;
            if (sp_sensors != row.nsensors) {
                ok = 0;
                fail_reason = "scratchpad sensor_count does not match input";
                break;
            }
        }
        if (have_prev && row.timestamp != prev_ts + 1) {
            ok = 0;
            fail_reason = "input timestamps are not contiguous";
            break;
        }
        last_ts = row.timestamp;
        prev_ts = row.timestamp;
        have_prev = 1;

        char mline[256];
        if (fgets(mline, sizeof(mline), mean_fp) == NULL) {
            ok = 0;
            fail_reason = "mean output ended before input";
            break;
        }
        long mts = 0;
        double mmean = 0.0;
        int mpresent = 0;
        if (sscanf(mline, "%ld,%lf,%d", &mts, &mmean, &mpresent) != 3) {
            ok = 0;
            fail_reason = "mean output row malformed";
            break;
        }
        if (mts != row.timestamp) {
            ok = 0;
            fail_reason = "mean output timestamp does not match input timestamp";
            break;
        }
        long sum = 0;
        int present = 0;
        for (int i = 0; i < row.nsensors; i++) {
            if (row.present[i]) {
                sum += row.values[i];
                present++;
            }
        }
        if (mpresent != present) {
            ok = 0;
            fail_reason = "mean output present_count does not match recomputed count";
            break;
        }
        double expect = present > 0 ? (double)sum / (double)present : 0.0;
        if (fabs(mmean - expect) > 0.000002) {
            ok = 0;
            fail_reason = "mean output value does not match recomputed mean";
            break;
        }
        out_rows++;
    }
    if (ok && rc != 0) {
        ok = 0;
        fail_reason = "malformed input row during checker pass";
    }
    if (ok) {
        char extra[256];
        if (fgets(extra, sizeof(extra), mean_fp) != NULL) {
            ok = 0;
            fail_reason = "mean output has extra rows beyond input";
        }
    }
    fclose(mean_fp);

    if (ok) {
        if (sp_rows != out_rows) {
            ok = 0;
            fail_reason = "scratchpad row_count does not match recomputed row count";
        } else if (sp_first != first_ts || sp_last != last_ts) {
            ok = 0;
            fail_reason = "scratchpad first/last timestamp does not match input";
        }
    }

    size_t bit_pos = 0;
    long bit_ones = 0;
    if (ok) {
        MdReader r2;
        if (md_reader_open(&r2, argv[1]) != 0) {
            ok = 0;
            fail_reason = "cannot reopen input for entropy pass";
        } else {
            MdDataRow row2;
            int have_prev2 = 0;
            long prev2 = 0;
            int rc2;
            while ((rc2 = md_reader_next(&r2, &row2)) == 1) {
                if (row2.present[0]) {
                    if (have_prev2) {
                        int expect_bit = md_temp_entropy_bit(prev2, row2.values[0]);
                        if (bit_pos >= bits_len || bits_buf[bit_pos] != (expect_bit ? '1' : '0')) {
                            ok = 0;
                            fail_reason = "entropy bit does not match recomputed temperature delta parity";
                            break;
                        }
                        if (expect_bit) {
                            bit_ones++;
                        }
                        bit_pos++;
                    }
                    prev2 = row2.values[0];
                    have_prev2 = 1;
                }
            }
            if (ok && rc2 != 0) {
                ok = 0;
                fail_reason = "malformed input row during entropy pass";
            }
            if (ok && (long)bit_pos != sp_bits) {
                ok = 0;
                fail_reason = "scratchpad entropy_bits does not match recomputed bit count";
            }
            if (ok && bit_pos != bits_len) {
                ok = 0;
                fail_reason = "entropy bits file length does not match recomputed bit count";
            }
            md_reader_close(&r2);
        }
    }
    md_reader_close(&r);

    if (!ok) {
        goto fail;
    }
    fprintf(evidence, "VERIFIED_BY_CHECKER\n");
    fprintf(evidence, "rows=%ld\n", out_rows);
    fprintf(evidence, "sensors=%ld\n", sp_sensors);
    fprintf(evidence, "first_timestamp=%ld\n", first_ts);
    fprintf(evidence, "last_timestamp=%ld\n", last_ts);
    fprintf(evidence, "entropy_bits=%zu\n", bit_pos);
    fprintf(evidence, "entropy_ones=%ld\n", bit_ones);
    fprintf(evidence, "transform=per_second_mean_over_present_sensors\n");
    fprintf(evidence, "entropy_source=temperature_delta_parity\n");
    fclose(evidence);
    printf("checker: PASS rows=%ld entropy_bits=%zu ones=%ld\n", out_rows, bit_pos, bit_ones);
    return 0;

fail:
    fprintf(evidence, "FAILED\n");
    fprintf(evidence, "reason=%s\n", fail_reason);
    fclose(evidence);
    fprintf(stderr, "checker: FAIL %s\n", fail_reason);
    return 1;
}
