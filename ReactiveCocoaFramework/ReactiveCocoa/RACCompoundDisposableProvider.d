provider RACCompoundDisposable {
    probe added(char *compoundDisposable, char *disposable, long newTotal);
    probe removed(char *compoundDisposable, char *disposable, long newTotal);
};
