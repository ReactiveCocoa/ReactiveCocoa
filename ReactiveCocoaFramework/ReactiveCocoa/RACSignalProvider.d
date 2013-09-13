provider RACSignal {
    probe activated(void *signal, char *signalName);
    probe deactivated(void *signal, char *signalName);

    probe next(char *signal, char *subscriber, char *signalName, char *valueDescription);
    probe completed(char *signal, char *subscriber, char *signalName);
    probe error(char *signal, char *subscriber, char *signalName, char *errorDescription);
};
