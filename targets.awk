BEGIN {
    FS = "\n"
}

/Targets:/ {
    while (getline && $0 != "") {
        sub(/^ +/, "");
        print;
    }
}
