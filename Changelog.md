# 2.0

For a complete list of changes in ReactiveCocoa 2.0, see [the
milestone](https://github.com/ReactiveCocoa/ReactiveCocoa/issues?milestone=3&state=closed).

## Breaking changes

### Simplified and safer KVO

`RACAble` and `RACAbleWithStart` have been replaced with a single
[RACObserve](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/601) macro.
`RACObserve` always starts with the current value of the property, and will
[notice the
deallocation](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/678) of `weak`
properties (unlike vanilla KVO).

Unlike the previous macros, which only required one argument for key paths on
`self`, `RACObserve` always requires two arguments.

**To update:**

 * Replace uses of `RACAbleWithStart(self.key)` with `RACObserve(self, key)`.
 * Replace uses of `RACAble(self.key)` with `[RACObserve(self, key) skip:1]` (if
   skipping the starting value is necessary).

### Fallback nil values for RAC and RACBind

`RAC` and `RACBind` now [always
require](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/670) two or three
arguments:

 1. The object to bind to.
 1. The key path to bind to.
 1. (Optional) A value to set when `nil` is sent to the binding.

This is necessary to avoid a `-setNilValueForKey:` exception when observing
a primitive property _through_ an intermediate object which gets set to `nil`.

This is not actually a change in key-value observing behavior — it's a caveat
with KVO regardless — but `RACObserve` makes it more prominent, because the
deallocation of `weak` properties will be considered a change to `nil`.

**To update:**

 * Replace uses of `RAC(self.objectProperty)` with `RAC(self, objectProperty)`.
 * Replace uses of `RACBind(self.objectProperty)` with `RACBind(self, objectProperty)`.
 * When binding a signal that might send nil (like a key path observation) to
   a primitive property, provide a default value: `RAC(self, integerProperty, @5)`

### Explicit schedulers for time-based operators

`-bufferWithTime:`, `+interval:`, and `-timeout:` have been unintuitive and
error-prone because of their implicit use of a background scheduler.

All of the aforementioned methods now require [a scheduler
argument](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/588), so that it's
clear how events should be delivered.

**To update:**

 * To match the previous behavior exactly, pass in `[RACScheduler scheduler]`.
   Note that this creates a _new_ background scheduler for events to arrive upon.
 * If you were already using `-deliverOn:` to force one of the above operators
   to deliver onto a specific scheduler, you can eliminate that hop and pass the
   scheduler into the operator directly.

### Commands must only be used on the main thread

Previously, `RACCommand` did not guarantee the thread that KVO notifications
would be generated upon, which could cause UI observers to run in the background
unexpectedly.

Now, `RACCommand` will [generate all notifications on the main
thread](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/540), and must only
be used there.

**To update:**

 * Audit code using `RACCommand` to ensure that it all runs on the main thread.
 * Remove any uses of `deliverOn:RACScheduler.mainThreadScheduler` on
   `RACCommand` properties, as they are now unnecessary.

### Commands automatically catch errors

`-[RACCommand addSignalBlock:]` has been renamed to `-addActionBlock:`, which
will [automatically catch
errors](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/530) sent by the
created signals.

`RACCommand.errors` will continue to send any errors that occur. The only change
is that no errors will be sent by the signals in the signal returned from
`-addActionBlock:`.

**To update:**

 * Remove any explicit `-catch:` or `-catchTo:` on created signals, as they are
   now unnecessary.
 * If you _want_ to receive errors from created signals, use an operator like
   `-materialize`.

### More powerful selector signals

`-rac_signalForSelector:` has been [completely
refactored](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/590) to support
listening for invocations of existing methods, new and existing methods with
multiple arguments, and existing methods with return values.

`+rac_signalForSelector:` (the class method variant) was removed, because
swizzling class methods is dangerous and difficult to do correctly.

**To update:**

 * Most existing uses of `-rac_signalForSelector:` shouldn't require
   any changes. However, the `super` implementation of any targeted selector will
   now be invoked, where it wasn't previously. Verify that existing uses can
   handle this case.
 * No replacement for `+rac_signalForSelector:` exists — override the desired class
   method and send arguments onto a `RACSubject` instead.

### More obvious sequencing operator

To make the sequencing and transformation operators less confusing,
`-sequenceMany:` has been removed, and `-sequenceNext:` has been
[renamed](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/635) to `-then:`.

**To update:**

 * Replace uses of `-sequenceMany:` with `-flattenMap:` and a block that doesn't
   use its argument.
 * Replace uses of `-sequenceNext:` with `-then:`.

### Consistent selector lifting

In the interests of [parametricity](http://en.wikipedia.org/wiki/Parametricity),
`-rac_liftSelector:withObjects:` has been
[replaced](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/609) with
`-rac_liftSelector:withSignals:`, which requires all arguments to be signals.
This makes usage more consistent.

`-rac_liftBlock:withArguments:` has been removed, because it's redundant with
`RACSignal` operators.

The `-rac_lift` proxy has also been removed, because there's no way to [make it
consistent](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/520) in the
same way.

**To update:**

 * Wrap non-signal arguments with `+[RACSignal return:]` and add a nil
   terminator.
 * Replace block lifting with `+combineLatest:reduce:`.
 * Replace uses of `-rac_lift` with `-rac_liftSelector:withSignals:`.

### Renamed scheduled signal constructors

`+start:`, `+startWithScheduler:block`, and `+startWithScheduler:subjectBlock:`
have been combined into a single
[+startEagerlyWithScheduler:block:](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/536)
constructor.

The key improvements here are a more intuitive name, a required `RACScheduler`
to make it clear where the block is executed, and use of `<RACSubscriber>`
instead of `RACSubject` to make it more obvious how to use the block argument.

**To update:**

 * Use `[RACScheduler scheduler]` to match the previous implicit scheduling
   behavior of `+start:`.
 * Refactor blocks that return values, and set `success`/`error`, to send events
   to the given `<RACSubscriber>` instead.

### Notification immediately before object deallocation

`-rac_didDeallocSignal` has been
[removed](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/585) in favor of
[-rac_willDeallocSignal](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/580),
because most teardown should happen _before_ the object becomes invalid.

**To update:**

 * Replace uses of `-rac_didDeallocSignal` with `rac_willDeallocSignal`.

### Extensible queue-based schedulers

`RACQueueScheduler` has been [exposed as a public
class](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/561), so consumers can create
their own scheduler implementations using GCD queues.

The
[RACTargetQueueScheduler](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/561)
subclass replaces the `+schedulerWithQueue:name:` method.

**To update:**

 * Replace uses of `+schedulerWithQueue:name:` with `-[RACTargetQueueScheduler initWithName:targetQueue:]`.

### C string lifting removed

Methods with `char *` and `const char *` arguments can [no longer be
lifted](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/535), because the
memory management semantics make it impossible to do safely.

### NSTask extension removed

`NSTask+RACSupport` has been
[removed](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/556), because it
was buggy and unsupported.

**To update:**

 * Use a vanilla `NSTask`, and send events onto `RACSubject`s instead.

### Better bindings for AppKit

`-rac_bind:toObject:withKeyPath:` and related methods have been
[replaced](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/638) with
`-rac_bind:options:`, which returns a `RACBinding` instance that can be used as
a two-way binding or treated like a one-way signal.

**To update:**

 * If possible, refactor code to use the new `RACBinding` interface. This
   bridges Cocoa Bindings with the full power of ReactiveCocoa.
 * For a direct conversion, use `-bind:toObject:withKeyPath:options:` with the
   following options:
    1. `@{ NSContinuouslyUpdatesValueBindingOption: @YES }` for `-rac_bind:toObject:withKeyPath:`
    1. `@{ NSContinuouslyUpdatesValueBindingOption: @YES, NSNullPlaceholderBindingOption: nilValue }` for `-rac_bind:toObject:withKeyPath:nilValue:`
    1. `@{ NSContinuouslyUpdatesValueBindingOption: @YES, NSValueTransformerBindingOption: valueTransformer }` for `-rac_bind:toObject:withKeyPath:transform:`
    1. `@{ NSContinuouslyUpdatesValueBindingOption: @YES, NSValueTransformerBindingOption: NSNegateBooleanTransformerName }` for `-rac_bind:toObject:withNegatedKeyPath:`

**To update:**

 * Invoke such methods manually in a `-subscribeNext:` block.
