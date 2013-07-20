# 2.0

This release of ReactiveCocoa contains major breaking changes that we were
unable to make after freezing the 1.0 API. All changes are focused on
eliminating bad code and bad usage patterns, reducing confusion, and increasing
flexibility in the framework.

For a complete list of changes in ReactiveCocoa 2.0, see [the
milestone](https://github.com/ReactiveCocoa/ReactiveCocoa/issues?milestone=3&state=closed).

**[Breaking changes](#breaking-changes)**

 1. [Simplified and safer KVO](#simplified-and-safer-kvo)
 1. [Fallback nil values for RAC and RACBind](#fallback-nil-values-for-rac-and-racbind)
 1. [Explicit schedulers for time-based operators](#explicit-schedulers-for-time-based-operators)
 1. [Commands must only be used on the main thread](#commands-must-only-be-used-on-the-main-thread)
 1. [Commands automatically catch errors](#commands-automatically-catch-errors)
 1. [More powerful selector signals](#more-powerful-selector-signals)
 1. [More obvious sequencing operator](#more-obvious-sequencing-operator)
 1. [Renamed signal binding method](#renamed-signal-binding-method)
 1. [Consistent selector lifting](#consistent-selector-lifting)
 1. [Renamed scheduled signal constructors](#renamed-scheduled-signal-constructors)
 1. [Notification immediately before object deallocation](#notification-immediately-before-object-deallocation)
 1. [Extensible queue-based schedulers](#extensible-queue-based-schedulers)
 1. [GCD time values replaced with NSDate](#gcd-time-values-replaced-with-nsdate)
 1. [Better bindings for AppKit](#better-bindings-for-appkit)
 1. [-bindTo: removed](#-bindto-removed)
 1. [Windows and numbered buffers removed](#windows-and-numbered-buffers-removed)
 1. [C string lifting removed](#c-string-lifting-removed)
 1. [NSTask extension removed](#nstask-extension-removed)
 1. [RACSubscriber class now private](#racsubscriber-class-now-private)

**[Additions and improvements](#additions-and-improvements)**

 1. [Commands for UIButton](#commands-for-uibutton)
 1. [Signal for UIActionSheet button clicks](#signal-for-uiactionsheet-button-clicks)
 1. [Better documentation for asynchronous backtraces](#better-documentation-for-asynchronous-backtraces)
 1. [Fixed libextobjc duplicated symbols](#fixed-libextobjc-duplicated-symbols)
 1. [Bindings for UIKit classes](#bindings-for-uikit-classes)

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
   any changes. However, the `super` implementation (if available) of any targeted selector will
   now be invoked, where it wasn't previously. Verify that existing uses can
   handle this case.
 * Replace uses of `+rac_signalForSelector:` by implementing the class method
   and sending arguments onto a `RACSubject` instead.

### More obvious sequencing operator

To make the sequencing and transformation operators less confusing,
`-sequenceMany:` has been removed, and `-sequenceNext:` has been
[renamed](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/635) to `-then:`.

**To update:**

 * Replace uses of `-sequenceMany:` with `-flattenMap:` and a block that doesn't
   use its argument.
 * Replace uses of `-sequenceNext:` with `-then:`.

### Renamed signal binding method

`-toProperty:onObject:` and `-[NSObject rac_deriveProperty:from:]` have been
[combined](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/617) into a new
`-[RACSignal setKeyPath:onObject:nilValue:]` method.

The `nilValue` parameter was added in parallel with [RAC and
RACBind](#fallback-nil-values-for-rac-and-racbind), but the semantics are
otherwise identical.

**To update:**

 * Replace `-toProperty:onObject:` and `-rac_deriveProperty:from:` with
   `-setKeyPath:onObject:`.
 * When binding a signal that might send nil (like a key path observation) to
   a primitive property, provide a default value: `[signal setKeyPath:@"integerProperty" onObject:self nilValue:@5]`

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
 * Refactor blocks that return values and set `success`/`error`, to send events
   to the given `<RACSubscriber>` instead.

### Notification immediately before object deallocation

`-rac_didDeallocSignal` has been
[removed](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/585) in favor of
[-rac_willDeallocSignal](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/580),
because most teardown should happen _before_ the object becomes invalid.

`-rac_addDeallocDisposable:` has also been
[removed](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/586) in favor of
using the object's `rac_deallocDisposable` directly.

**To update:**

 * Replace uses of `-rac_didDeallocSignal` with `rac_willDeallocSignal`.
 * Replace uses of `-rac_addDeallocDisposable:` by invoking `-addDisposable:` on
   the object's `rac_deallocDisposable` instead.

### Extensible queue-based schedulers

`RACQueueScheduler` has been [exposed as a public
class](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/561), so consumers can create
their own scheduler implementations using GCD queues.

The
[RACTargetQueueScheduler](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/561)
subclass replaces the `+schedulerWithQueue:name:` method.

**To update:**

Replace uses of `+schedulerWithQueue:name:` with `-[RACTargetQueueScheduler initWithName:targetQueue:]`.

### GCD time values replaced with NSDate

`NSDate` now [replaces](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/664)
`dispatch_time_t` values in `RACScheduler`, because dates are easier to use, more
convertible to other formats, and can be used to implement a [virtualized time
scheduler](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/171).

**To update:**

Replace `dispatch_time_t` calculations with `NSDate`.

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

### -bindTo: removed

`-[RACBinding bindTo:]` was difficult to understand, so it has been
[removed](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/605). Explicit
subscription is preferred instead.

The special `RACBind(...) = RACBind(...)` syntax will continue to work.

**To update:**

Replace `[binding1 bindTo:binding2]` with:

```objc
[binding2 subscribe:binding1];
[[binding1 skip:1] subscribe:binding2];
```

### Windows and numbered buffers removed

`-windowWithStart:close:` and `-buffer:` have been
[removed](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/616) because
they're not well-tested, and their functionality can be achieved with other
operators.

`-bufferWithTime:` is still supported.

**To update:**

 * Refactor uses of `-windowWithStart:close:` with different patterns.
 * Replace uses of `-buffer:` with [take, collect, and
   repeat](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/587).

### C string lifting removed

Methods with `char *` and `const char *` arguments can [no longer be
lifted](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/535), because the
memory management semantics make it impossible to do safely.

**To update:**

Invoke such methods manually in a `-subscribeNext:` block.

### NSTask extension removed

`NSTask+RACSupport` has been
[removed](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/556), because it
was buggy and unsupported.

**To update:**

Use a vanilla `NSTask`, and send events onto `RACSubject`s instead.

### RACSubscriber class now private

The `RACSubscriber` class (not to be confused with the protocol) should never be
used directly, so it has been
[hidden](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/584).

**To update:**

Replace uses of `RACSubscriber` with `id<RACSubscriber>` or `RACSubject`.

## Additions and improvements

### Commands for UIButton

`UIButton` now has a [rac_command
property](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/558).

Any command set will be executed when the button is tapped, and the button will
be disabled whenever the command is unable to execute.

### Signal for UIActionSheet button clicks

`UIActionSheet` now has a [rac_buttonClickedSignal
property](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/611), which will
fire whenever one of the sheet's buttons is clicked.

### Better documentation for asynchronous backtraces

Documentation has been
[added](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/680) to
`RACBacktrace` explaining how to start collecting backtraces and print them out
in the debugger.

The `+captureBacktrace…` methods have been renamed to `+backtrace…`, and
`+printBacktrace` has been removed in favor of using `po [RACBacktrace backtrace]`
from the debugger.

The `rac_` GCD functions which collect backtraces have also been exposed,
primarily for use on iOS.

### Fixed libextobjc duplicated symbols

If [libextobjc](https://github.com/jspahrsummers/libextobjc) was used in
a project that statically linked ReactiveCocoa, duplicate symbol errors could
result.

To avoid this issue, RAC now
[renames](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/612) the
libextobjc symbols that it uses.

### Bindings for UIKit classes

RACBinding interfaces have been [added](https://github.com/ReactiveCocoa/pull/686)
to many UIKit classes, greatly simplifying glue code between your models and views.

For example, assuming you want to bind a `person` model's `name` property:

```objc
UITextField *nameField = ...;
RACBinding *nameBinding = RACBind(model, name, nil);
RACBinding *nameFieldBinding = [nameField rac_textBindingWithNilValue:@""];
[nameBinding subscribe:nameFieldBinding];
[[nameFieldBinding skip:1] subscribe:nameBinding];
```

You may also bind multiple controls to the same property, for example a UISlider and
a UIStepper for more fine-grained editing.