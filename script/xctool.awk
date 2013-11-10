# Exit statuses:
#
# 0 - No errors found.
# 1 - Wrong SDK. Retry with SDK `iphonesimulator`.

BEGIN {
    status = 0;
}

{
    print;
}

/Testing with the '(.+)' SDK is not yet supported/ {
    status = 1;
}

END {
    exit status;
}
