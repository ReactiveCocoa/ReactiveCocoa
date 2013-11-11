# Exit statuses:
#
# 0 - No errors found.
# 1 - Wrong SDK. Retry with SDK `iphonesimulator`.
# 2 - Missing target.

BEGIN {
    status = 0;
}

{
    print;
}

/Testing with the '(.+)' SDK is not yet supported/ {
    status = 1;
}

/does not contain a target named/ {
    status = 2;
}

END {
    exit status;
}
