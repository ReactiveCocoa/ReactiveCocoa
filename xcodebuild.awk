{
    print;
    fflush(stdout);
}

/[0-9]+: (error|warning):/ {
    errors = errors $0 "\n";
}

/(TEST|BUILD) FAILED/ {
    if (length(errors) > 0) {
        print "\n*** All errors:\n" errors;
    }

    fflush(stdout);

    # SYS_SOFTWARE
    exit 70;
}
