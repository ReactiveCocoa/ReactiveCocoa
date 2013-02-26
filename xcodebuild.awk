# Exit statuses:
#
# 0 - No errors found.
# 1 - Build or test failure. Errors will be logged automatically.
# 2 - Untestable target. Retry with the "build" action.

BEGIN {
    status = 0;
}

{
    print;
    fflush(stdout);
}

/is not valid for Testing/ {
    exit 2;
}

/[0-9]+: (error|warning):/ {
    errors = errors $0 "\n";
}

/(TEST|BUILD) FAILED/ {
    status = 1;
}

END {
    if (length(errors) > 0) {
        print "\n*** All errors:\n" errors;
    }

    fflush(stdout);
    exit status;
}
