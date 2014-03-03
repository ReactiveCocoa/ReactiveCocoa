This folder contains Instruments templates to make it easier to debug
code using ReactiveCocoa.

To get started with a template, simply double-click it.

### Signal Names

The `name` property of `RACSignal` requires that the `RAC_DEBUG_SIGNAL_NAMES`
environment variable be set, which means that you won't have access to
meaningful names in Instruments by default.

To add signal names, open your application's scheme in Xcode, select the Profile
action, and add `RAC_DEBUG_SIGNAL_NAMES` with a value of `1` to the list of
environment variables.
