{
    print
    fflush(stdout)
}

/(TEST|BUILD) FAILED/ {
    # SYS_SOFTWARE
    exit 70
}
