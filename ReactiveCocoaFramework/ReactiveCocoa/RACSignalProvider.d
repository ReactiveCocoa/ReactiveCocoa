provider RACSignal {
    probe next(char *signal, char *subscriber, char *signalName, char *valueDescription);
    probe completed(char *signal, char *subscriber, char *signalName);
    probe error(char *signal, char *subscriber, char *signalName, char *errorDescription);
};
