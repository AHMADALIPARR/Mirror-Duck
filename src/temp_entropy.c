/* temp_entropy.c: entropy sourced from temperature fluctuations. */
#include "temp_entropy.h"

#include <stdlib.h>

int md_temp_entropy_bit(long prev_reading, long curr_reading) {
    long diff = curr_reading - prev_reading;
    if (diff < 0) {
        diff = -diff;
    }
    return (int)(diff & 1L);
}
