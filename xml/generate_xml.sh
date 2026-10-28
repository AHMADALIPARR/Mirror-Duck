#!/bin/sh
# generate_xml.sh: scratchpad.txt + evidence.txt -> scratchpad.xml
# Usage: generate_xml.sh <scratchpad.txt> <evidence.txt> <output.xml>
# Values come from the C generator and checker, not from free
# text, so they contain only letters, digits, underscores and
# dots, and need no XML escaping beyond that controlled set.
# Exit non-zero if any required field is missing.
set -e
SCRATCH="$1"
EVIDENCE="$2"
OUT="$3"
val() {
    awk -F= -v k="$1" '$1 == k { gsub(/\r/, "", $2); print $2; exit }' "$2"
}
TRANSFORM=$(val transform "$SCRATCH")
PRESERVE_ROWS=$(val preserve_row_count "$SCRATCH")
PRESERVE_TS=$(val preserve_timestamps "$SCRATCH")
MISSING_OK=$(val missing_stays_missing "$SCRATCH")
SENSORS=$(val sensor_count "$SCRATCH")
FIRST_TS=$(val first_timestamp "$SCRATCH")
LAST_TS=$(val last_timestamp "$SCRATCH")
ROWS=$(val row_count "$SCRATCH")
ENTROPY_SOURCE=$(val entropy_source "$SCRATCH")
ENTROPY_SENSOR=$(val entropy_sensor_id "$SCRATCH")
ENTROPY_BITS=$(val entropy_bits "$SCRATCH")
STATUS=$(val status "$SCRATCH")
EVIDENCE_STATUS=$(head -n 1 "$EVIDENCE" | tr -d '\r')
EVIDENCE_ROWS=$(val rows "$EVIDENCE")
EVIDENCE_ONES=$(val entropy_ones "$EVIDENCE")
for v in "$TRANSFORM" "$PRESERVE_ROWS" "$PRESERVE_TS" "$MISSING_OK" "$SENSORS" "$FIRST_TS" "$LAST_TS" "$ROWS" "$ENTROPY_SOURCE" "$ENTROPY_SENSOR" "$ENTROPY_BITS" "$STATUS" "$EVIDENCE_STATUS"; do
    if [ -z "$v" ]; then
        echo "generate_xml: missing field" >&2
        exit 1
    fi
done
cat > "$OUT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<mirror-duck>
  <contract>
    <transform>$TRANSFORM</transform>
    <preserve_row_count>$PRESERVE_ROWS</preserve_row_count>
    <preserve_timestamps>$PRESERVE_TS</preserve_timestamps>
    <missing_stays_missing>$MISSING_OK</missing_stays_missing>
    <sensor_count>$SENSORS</sensor_count>
    <first_timestamp>$FIRST_TS</first_timestamp>
    <last_timestamp>$LAST_TS</last_timestamp>
    <row_count>$ROWS</row_count>
    <status>$STATUS</status>
  </contract>
  <entropy>
    <source>$ENTROPY_SOURCE</source>
    <sensor_id>$ENTROPY_SENSOR</sensor_id>
    <bits>$ENTROPY_BITS</bits>
    <ones>$EVIDENCE_ONES</ones>
  </entropy>
  <evidence>
    <status>$EVIDENCE_STATUS</status>
    <rows>$EVIDENCE_ROWS</rows>
  </evidence>
</mirror-duck>
EOF
