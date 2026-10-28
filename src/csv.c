/* csv.c: streaming reader for basketdata-style CSV. */
#include "csv.h"

#include <stdlib.h>
#include <string.h>

int md_split(char *line, char *fields[], int max_fields) {
    int n = 0;
    char *p = line;
    char *start = line;
    while (1) {
        if (*p == ',' || *p == '\n' || *p == '\r' || *p == '\0') {
            if (n >= max_fields) {
                return -1;
            }
            char save = *p;
            *p = '\0';
            fields[n++] = start;
            if (save == '\0') {
                break;
            }
            start = p + 1;
            if (save == '\n' || save == '\r') {
                break;
            }
        }
        p++;
    }
    return n;
}

int md_reader_open(MdReader *r, const char *path) {
    memset(r, 0, sizeof(*r));
    r->fp = fopen(path, "r");
    if (r->fp == NULL) {
        return -1;
    }
    return 0;
}

static int parse_long(const char *s, long *out) {
    char *end = NULL;
    if (s == NULL || *s == '\0') {
        return -1;
    }
    *out = strtol(s, &end, 10);
    if (end == s || *end != '\0') {
        return -1;
    }
    return 0;
}

int md_reader_next(MdReader *r, MdDataRow *out) {
    while (fgets(r->line, sizeof(r->line), r->fp) != NULL) {
        size_t len = strlen(r->line);
        if (len > 0 && r->line[len - 1] != '\n' && !feof(r->fp)) {
            return -1;
        }
        char *fields[MD_MAX_FIELDS];
        int nf = md_split(r->line, fields, MD_MAX_FIELDS);
        if (nf < 1) {
            continue;
        }
        if (strcmp(fields[0], "12") == 0) {
            if (nf < 4) {
                return -1;
            }
            r->nsensors = nf - 3;
            if (r->nsensors > MD_MAX_SENSORS) {
                return -1;
            }
            for (int i = 0; i < r->nsensors; i++) {
                if (parse_long(fields[3 + i], &r->sensor_ids[i]) != 0) {
                    return -1;
                }
            }
            r->header_seen = 1;
            continue;
        }
        if (strcmp(fields[0], "13") != 0) {
            continue;
        }
        if (!r->header_seen) {
            return -1;
        }
        if (nf < 3 + r->nsensors) {
            return -1;
        }
        if (parse_long(fields[1], &out->timestamp) != 0) {
            return -1;
        }
        out->nsensors = r->nsensors;
        for (int i = 0; i < r->nsensors; i++) {
            const char *v = fields[3 + i];
            if (v[0] == '\0') {
                out->present[i] = 0;
                out->values[i] = 0;
            } else {
                long val = 0;
                if (parse_long(v, &val) != 0) {
                    return -1;
                }
                out->present[i] = 1;
                out->values[i] = val;
            }
        }
        r->rows_seen++;
        return 1;
    }
    return 0;
}

void md_reader_close(MdReader *r) {
    if (r->fp != NULL) {
        fclose(r->fp);
        r->fp = NULL;
    }
}
