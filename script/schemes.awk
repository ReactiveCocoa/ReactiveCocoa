BEGIN {
    FS = "\n";
}

/Schemes:/ {
    while (getline && $0 != "") {
        sub(/^ +/, "");
        print "'" $0 "'";
    }
}
