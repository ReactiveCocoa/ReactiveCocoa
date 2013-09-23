This folder contains Instruments templates to make it easier to debug
code using ReactiveCocoa.

To get started with a template, simply double-click it.

### Signal Names

The `name` property of `RACSignal` is currently only functional in `DEBUG`
builds, which means that you won't have access to meaningful names in
Instruments if you're profiling a Release build.

As a workaround, you can do one of the following:

 1. Run your application (instead of using the Profile action), then ask
    Instruments to attach to the running process.
 2. In your application's scheme, set the Profile action to use the "Debug"
    configuration, then profile normally.
