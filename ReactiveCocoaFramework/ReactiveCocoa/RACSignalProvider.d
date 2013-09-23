provider RACSignal {
    probe next(char *signal, char *subscriber, char *valueDescription);
    probe completed(char *signal, char *subscriber);
    probe error(char *signal, char *subscriber, char *errorDescription);
};
