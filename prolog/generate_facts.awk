# generate_facts.awk: scratchpad.txt (key=value) -> Prolog facts.
# Usage: awk -f generate_facts.awk scratchpad.txt > facts.pl
# Each line becomes key(value).  Values in this scratchpad are
# either integers or lowercase underscore atoms, both valid
# Prolog terms, so no quoting is needed.  Carriage returns
# from CRLF files are stripped.
{
    sub(/\r$/, "", $0)
    if ($0 == "") next
    eq = index($0, "=")
    if (eq == 0) next
    key = substr($0, 1, eq - 1)
    val = substr($0, eq + 1)
    print key "(" val ")."
}
