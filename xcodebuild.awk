# Exit statuses:
#
# 0 - No errors found.
# 1 - Build or test failure. Errors will be logged automatically.
# 2 - Untestable target. Retry with the `build` action.
# 3 - Wrong SDK. Retry with SDK `iphonesimulator`.

BEGIN {
    status = 0;
}

{
    print;
    fflush(stdout);
}

/[0-9]+: (error|warning):/ {
    errors = errors $0 "\n";
}

/is not testable/ {
    status = 2;
}

/(TEST|BUILD) FAILED/ {
    status = 1;
}

/does not contain a scheme named/ {
    status = 1;
}

/cannot run using the selected device/ {
    status = 3;
}

END {
    if (length(errors) > 0) {
        print "\n*** All errors:\n" errors;
    }

    fflush(stdout);
    exit status;
}
