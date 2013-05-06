BEGIN {
    FS = "\n";
}

/Targets:/ {
    while (getline && $0 != "") {
        if ($0 ~ /Tests/) continue;

        sub(/^ +/, "");
        print "'" $0 "'";
    }
}
