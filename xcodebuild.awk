{
    print
    fflush(stdout)
}

/[0-9]+: error:/ {
    errors = errors $0 "\n"
}

/(TEST|BUILD) FAILED/ {
    print "\n", errors
    fflush(stdout)

    # SYS_SOFTWARE
    exit 70
}
