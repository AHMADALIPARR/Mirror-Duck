CC = gcc
CFLAGS = -std=c11 -Wall -Wextra -O2 -Isrc

all: generator checker

generator: src/generator.c src/csv.c src/temp_entropy.c src/csv.h src/temp_entropy.h
	$(CC) $(CFLAGS) src/generator.c src/csv.c src/temp_entropy.c -lm -o generator

checker: src/checker.c src/csv.c src/temp_entropy.c src/csv.h src/temp_entropy.h
	$(CC) $(CFLAGS) src/checker.c src/csv.c src/temp_entropy.c -lm -o checker

check: all
	./generator "$(INPUT)" out/mean.csv out/scratchpad.txt out/entropy_bits.txt
	./checker "$(INPUT)" out/mean.csv out/scratchpad.txt out/entropy_bits.txt out/evidence.txt

clean:
	rm -f generator checker
	rm -f out/mean.csv out/scratchpad.txt out/entropy_bits.txt out/evidence.txt

.PHONY: all check clean
