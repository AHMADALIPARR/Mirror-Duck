/* csv.h: streaming reader for basketdata-style CSV.
 * Row types:
 *   10, 11 : metadata, ignored by the reader except for counting
 *   12     : sensor header, fields[3..] are sensor ids
 *   13     : data, fields[1] is a unix timestamp, fields[3..] are
 *            integer-valued readings, empty means missing.
 * The file itself carries no unit label, so readings are treated
 * as raw sensor values, never assumed to be degrees F or C.
 * This parser preserves empty fields; strtok-style splitting
 * would collapse them and corrupt the missing-value accounting.
 */
#ifndef MIRROR_DUCK_CSV_H
#define MIRROR_DUCK_CSV_H

#include <stdio.h>

#define MD_MAX_SENSORS 64
#define MD_MAX_FIELDS 80
#define MD_LINE_LEN 4096

typedef struct {
    long timestamp;
    long values[MD_MAX_SENSORS];
    int present[MD_MAX_SENSORS];
    int nsensors;
} MdDataRow;

typedef struct {
    FILE *fp;
    char line[MD_LINE_LEN];
    long sensor_ids[MD_MAX_SENSORS];
    int nsensors;
    int header_seen;
    long rows_seen;
} MdReader;

/* Split one CSV line into fields, preserving empty fields.
 * Returns the number of fields, or -1 if the line is too long. */
int md_split(char *line, char *fields[], int max_fields);

/* Open a reader. Returns 0 on success, -1 on failure. */
int md_reader_open(MdReader *r, const char *path);

/* Read the next data (type 13) row. Returns 1 for a row,
 * 0 at end of file, -1 on a malformed row. Metadata rows
 * and the sensor header are consumed internally. */
int md_reader_next(MdReader *r, MdDataRow *out);

void md_reader_close(MdReader *r);

#endif
