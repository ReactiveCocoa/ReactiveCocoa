BEGIN {
    FS = "\n";
}

/Targets:/ {
    while (getline && $0 != "") {
        if ($0 ~ /Test/) continue;

        sub(/^ +/, "");
        print "'" $0 "'";
    }
}
