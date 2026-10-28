/* temp_entropy.h: entropy sourced from temperature fluctuations.
 * A bit is the parity of the change between two successive
 * readings from the same physical sensor. No pseudo-random
 * generator is used anywhere in this module: no rand, no
 * srand, no time seed, no seeded PRNG. If either reading is
 * missing, no bit is produced for that step, so missing data
 * can never be silently filled with generated bits.
 * This module makes no claim that the bits are cryptographically
 * strong or NIST-tested; it claims only their source, which is
 * the physical variation in the supplied temperature file.
 */
#ifndef MIRROR_DUCK_TEMP_ENTROPY_H
#define MIRROR_DUCK_TEMP_ENTROPY_H

/* Return 0 or 1: parity of the absolute change. */
int md_temp_entropy_bit(long prev_reading, long curr_reading);

#endif
