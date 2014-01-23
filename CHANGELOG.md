# 3.0

The theme of this ReactiveCocoa release is _simplicity_: [getting rid of unused
APIs](#deprecations) and [replacing complicated patterns with simpler
ones](#replacements) where possible. Consequently, the changes are significant
and far-reaching.

However, because migration is hard and time-consuming, 99% of RAC 2.x code will
continue to work under RAC 3.0 without any changes. You'll see deprecation
warnings by default, but even these can be temporarily disabled by defining
[`WE_PROMISE_TO_MIGRATE_TO_REACTIVECOCOA_3_0`](ReactiveCocoaFramework/ReactiveCocoa/RACDeprecated.h)
before any framework headers are imported.

For a complete list of changes in ReactiveCocoa 3.0, see [the
milestone](https://github.com/ReactiveCocoa/ReactiveCocoa/issues?milestone=4&state=closed).

**[Replacements](#replacements)**

 1. [Actions instead of commands](#actions-instead-of-commands)
 1. [Simplified signal creation and disposal](#simplified-signal-creation-and-disposal)
 1. [Generalized throttling](#generalized-throttling)

**[Deprecations](#deprecations)**

 1. [Sequences](#sequences)
 1. [Multicasting](#multicasting)
 1. [Replay subjects](#replay-subjects)
 1. [Behavior subjects](#behavior-subjects)

**[Additions](#additions)**

 1. [Signal generators](#signal-generators)

## Replacements

### Actions instead of commands

Because of its confusing API, `RACCommand` hasn't been used much, despite the
value it offers in responding to UI events. The new `RACAction` class, which
[replaces](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/910)
`RACCommand`, attempts to provide the same value in a less confusing way.

Any [signal generator](#signal-generators) can be directly converted into an
action via the `-action` or `-actionEnabledIf:` methods. Whenever the resulting
action is executed, a signal will be generated and subscribed to, triggering its
side effects. `RACAction` will automatically ensure that only one subscription
is in effect at a time.

The class still provides most of the familiar `RACCommand` conveniences, but
minimizes the use of signal blocks, signals of signals, and concurrent
behaviors, hopefully making it more approachable.

**To update:**

 * Replace uses of `-[RACCommand initWithSignalBlock:]` that _do not use the
   argument_ with a cold signal and `-[RACSignal action]`.
 * Replace uses of `-[RACCommand initWithSignalBlock:]` that _use the argument_
   with `+[RACDynamicSignalGenerator generatorWithBlock:]` and
   `-[RACSignalGenerator action]`.
 * If you were instead using `-[RACCommand initWithEnabled:signalBlock:]`, use
   the `-actionEnabledIf:` variant.
 * Replace uses of `RACCommand.executionSignals` that _only care about values_
   with `RACAction.results`.
 * Replace uses of `RACCommand.executionSignals` that _care about completion and
   error events_ with `RACAction.executionSignals`.
 * Instead of setting `RACCommand.allowsConcurrentExecution` to `YES`, use
   a `RACSignalGenerator` for your behavior instead.
 * Replace `-[RACCommand execute:]` with `-[RACAction signalWithValue:]` when
   you need the results of the execution.
 * Invoke `-[RACAction execute:]` from your UI when the caller does not care
   about the results.
 * Replace `rac_command` bindings with `rac_action`.

For example, this command:

```objc
// View model
_logInCommand = [[RACCommand alloc] initWithEnabled:currentlyOnline signalBlock:^(id _) {
    @strongify(self);
    return [self logInWithUsername:self.username];
}];

// View controller
RAC(self.viewModel, username) = self.usernameField.rac_textSignal;
self.button.rac_command = self.viewModel.logInCommand;
```

Would look more like this, using `RACAction`:

```objc
// View model
_logInAction = [[RACSignal
    defer:^{
        @strongify(self);
        return [self logInWithUsername:self.username];
    }]
    actionEnabledIf:currentlyOnline];

// View controller
RAC(self.viewModel, username) = self.usernameField.rac_textSignal;
self.button.rac_action = self.viewModel.logInAction;
```

To accept input to the action, use a signal generator:

```objc
// View model
_logInAction = [[RACDynamicSignalGenerator
    generatorWithBlock:^(NSString *username) {
        @strongify(self);
        return [RACSignal defer:^{
            return [self logInWithUsername:username];
        }];
    }]
    actionEnabledIf:currentlyOnline];

// View controller
self.button.rac_action = [[[self.usernameField.rac_textSignal
    take:1]
    postcompose:self.viewModel.logInAction]
    actionEnabledIf:self.viewModel.logInAction.enabled];
```

### Simplified signal creation and disposal

`+[RACSignal createSignal:]` has been
[replaced](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/917) with
a simpler `+create:` method that no longer needs to return a disposable.

In conjunction with this new constructor, `<RACSubscriber>` exposes
a `disposable` property, to which any number of disposables can be added or
removed, and whose `disposed` property can also be used as an early termination
flag. Both of these capabilities reduce the need for allocating additional
disposables.

Synchronous signals can also be terminated early now, because they don't have to
_return_ a disposable before the subscriber can act. Instead, the subscriber's
`disposable` can be disposed of at any time.

**To update:**

 * Replace uses of `+createSignal:` with `+create:`.
 * Instead of returning a disposable, attach it to the `disposable` of the
   `<RACSubscriber>`, or figure out how to eliminate the disposable entirely.
 * The `-didSubscribeWithDisposable:` method of `<RACSubscriber>` has been
   removed. If, for some reason, you were using it, refactor the call points to
   add to the subscriber's `disposable` instead.

### Generalized throttling

`-throttle:valuesPassingTest:` and `-flatten:` have been
[replaced](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/920) with the much
more general `-flatten:withPolicy:` operator.

The plain `-throttle:` operator has also been renamed to
`-throttleDiscardingEarliest:`, alongside the new `-throttleDiscardingLatest:`
operator. These new names are intended to reduce confusion about what
"throttling" actually means in a given context.

**To update:**

 * Replace uses of `-flatten:` with `-flatten:withPolicy:` and
   `RACSignalFlattenPolicyQueue`.
 * Replace uses of `-throttle:` with `-throttleDiscardingEarliest:`.
 * Instead of using `-throttle:valuesPassingTest:`, create a signal of signals
   where some have delays, then use `-flatten:withPolicy:` and
   `RACSignalFlattenPolicyDisposeEarliest`.

For example, this partly-throttled signal:

```objc
// Throttles even numbers from the input signal. If an odd number arrives in the
// meantime, any even number that's queued will be discarded.
RACSignal *throttledEvens = [numbers
    throttle:0.2 valuesPassingTest:^ BOOL (NSNumber *number) {
        return number.integerValue % 2 == 0;
    }];
```

Can be replaced with this signal of signals, and then flattened:

```objc
RACSignal *throttledEvens = [[numbers
    map:^(NSNumber *number) {
        if (number.integerValue % 2 == 0) {
            // Delay even numbers.
            return [[RACSignal return:number] delay:0.2];
        } else {
            // Forward odd numbers immediately.
            return [RACSignal return:number];
        }
    }]
    // When a new value arrives, discard any even number waiting to be sent.
    // Limit the queue to 1 even number.
    flatten:1 withPolicy:RACSignalFlattenPolicyDisposeEarliest];
```

## Deprecations

### Sequences

`RACSequence` was created a while ago to provide a _pull-driven_ alternative to
the _push-driven_ signals that RAC is built around. However, it's difficult to
convert between the two, and it leads to a lot of confusion around operator
types, and the purpose of the `RACStream` superclass.

Since most consumers end up using signals far more than sequences, and it's
simpler to only offer one, `RACSequence` has been
[deprecated](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/915), and all
stream operators now appear directly on `RACSignal` for clarity.

Instead of the `rac_sequence` methods that appeared on `NSArray`,
`NSDictionary`, `NSSet`, etc., there's now a `rac_signal` method. When lazy
evaluation is actually algorithmically important, a third-party library (like
[RXCollections](https://github.com/robrix/RXCollections)) can be used instead.

**To update:**

 * Replace uses of `RACStream` and `RACSequence` with `RACSignal`.
 * Replace uses of `rac_sequence` extension methods with `rac_signal` methods.

### Multicasting

Although `RACMulticastConnection` solves an important problem (sharing side
effects between multiple subscribers), it obfuscates what's really happening and
frequently confuses newcomers, so it has been
[deprecated](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/877) in favor of
using subjects directly.

**To update:**

 * Replace `-publish` and `-multicast:` with `-subscribe:` plus a `RACSubject`.
 * Ensure that subscription occurs in the same place that the underlying signal
   was being connected to.

### Replay subjects 

`RACReplaySubject` has been used mostly for memoization: doing
something once, then saving the results. However, this has made it something of
an odd duck next to `RACSignal` and `RACSubject`.

Where `RACSignal` usually represents a "cold" signal (one that performs its side
effects once for each subscription), and `RACSubject` represents a "hot" signal
(one that doesn't perform any side effects upon subscription),
`RACReplaySubject` has occupied a weird "lukewarm" middle ground.

Additionally, replayed signals don't support certain kinds of manipulation, like
`-retry:`, `-repeat`, `-subscribeOn:`, etc. Such operators will have—at best—
surprising behavior, since they don't actually allow the underlying subscription
to be controlled.

For these reasons, `RACReplaySubject` and its corresponding signal operators
have been [deprecated](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/877).
_(Note that the replacement offered in that pull request, `RACPromise`, was later
[removed](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/995) as well.)_

**To update:**

 * Replace `RACReplaySubject`, `-replay`, `-replayLazily`, and `-replayLast` with cold signals or plain `RACSubject` if possible.
 * Replace `+startEagerlyWithScheduler:block:` and `+startLazilyWithScheduler:block:` with `+create:` plus `-subscribeOn:`.

By far, the easiest solution is to adopt cold signals everywhere, and limit the
number of subscriptions to signals that have side effects.

For example, given this replaying signal:

```objc
RACSignal *lazyFetch = [[[self
    fetchUser]
    flattenMap:^(User *user) {
        return [self saveUser:user];
    }]
    replayLazily];
```

Removing the `-replayLazily` doesn't alter the behavior for _one_ subscription.
If _multiple_ subscribers are interested in the results, connect them to a subject,
and then forward the signal to that subject:

```objc
RACSubject *lazyFetchSubject = [RACSubject subject];

[lazyFetchSubject subscribeCompleted:^{
    NSLog(@"First subscriber completed");
}];

[lazyFetchSubject subscribeCompleted:^{
    NSLog(@"Second subscriber completed");
}];

[lazyFetch subscribe:lazyFetchSubject];
```

### Behavior subjects

`RACBehaviorSubject` has never gotten much attention, in implementation or
usage, so it has been
[deprecated](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/878). Most of
its semantics can be implemented with other classes or operators.

**To update:**

Replace uses of `RACBehaviorSubject` with a property or a plain `RACSubject`.

## Additions

### Signal generators

The [new](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/936)
`RACSignalGenerator` class encapsulates the logic for creating a signal from
some input value.

Although similar in principle, a signal generator boasts a couple major
advantages over a plain block of type `RACSignal * (^)(id input)`:

 1. Operators can be added to `RACSignalGenerator`. This can be used for greater
    composability, like the built-in `-postcompose:` method that chains two
    generators together.
 1. A signal generator's algorithm can reference itself using
    `-[RACDynamicSignalGenerator initWithReflexiveBlock:]`, which is extremely
    useful for creating signals of indefinite length, and much less error-prone
    than a recursive block.

See
[RACSignal+Operations.m](ReactiveCocoaFramework/ReactiveCocoa/RACSignal+Operations.m)
for examples of operators that use generators internally.

# 2.0

This release of ReactiveCocoa contains major breaking changes that we were
unable to make after freezing the 1.0 API. All changes are focused on
eliminating bad code and bad usage patterns, reducing confusion, and increasing
flexibility in the framework.

For a complete list of changes in ReactiveCocoa 2.0, see [the
milestone](https://github.com/ReactiveCocoa/ReactiveCocoa/issues?milestone=3&state=closed).

**[Breaking changes](#breaking-changes)**

 1. [Simplified and safer KVO](#simplified-and-safer-kvo)
 1. [Safer commands with less state](#safer-commands-with-less-state)
 1. [Fallback nil value for RAC macro](#fallback-nil-values-for-rac-macro)
 1. [Explicit schedulers for time-based operators](#explicit-schedulers-for-time-based-operators)
 1. [More powerful selector signals](#more-powerful-selector-signals)
 1. [Simpler two-way bindings](#simpler-two-way-bindings)
 1. [Better bindings for AppKit](#better-bindings-for-appkit)
 1. [More obvious sequencing operator](#more-obvious-sequencing-operator)
 1. [Renamed signal binding method](#renamed-signal-binding-method)
 1. [Consistent selector lifting](#consistent-selector-lifting)
 1. [Renamed scheduled signal constructors](#renamed-scheduled-signal-constructors)
 1. [Notification immediately before object deallocation](#notification-immediately-before-object-deallocation)
 1. [Extensible queue-based schedulers](#extensible-queue-based-schedulers)
 1. [GCD time values replaced with NSDate](#gcd-time-values-replaced-with-nsdate)
 1. [Windows and numbered buffers removed](#windows-and-numbered-buffers-removed)
 1. [NSTask extension removed](#nstask-extension-removed)
 1. [RACSubscriber class now private](#racsubscriber-class-now-private)

**[Additions and improvements](#additions-and-improvements)**

 1. [Commands for UIButton](#commands-for-uibutton)
 1. [Signal for UIActionSheet button clicks](#signal-for-uiactionsheet-button-clicks)
 1. [Better documentation for asynchronous backtraces](#better-documentation-for-asynchronous-backtraces)
 1. [Fixed libextobjc duplicated symbols](#fixed-libextobjc-duplicated-symbols)
 1. [Bindings for UIKit classes](#bindings-for-uikit-classes)
 1. [Signal subscription side effects](#signal-subscription-side-effects)
 1. [Test scheduler](#test-scheduler)

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

### Safer commands with less state

`RACCommand` has been [completely
refactored](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/733). It is no
longer a `RACSignal`, and the behavior of `-addSignalBlock:` has been moved to
the initializer, making the class almost entirely immutable.

Reflecting the most common use case, KVO-notifying properties have been changed
into signals instead. During the change, `canExecute` was also renamed to
`enabled`, which should make its purpose more obvious for binding to the UI.

In addition, changes to `executing`, `errors`, and `enabled` are now guaranteed
to fire on the main thread, so UI observers no longer [run in the background
unexpectedly](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/533).

All together, these improvements should make `RACCommand` more composable and
less imperative, so it fits into the framework better.

**To update:**

 * Move execution logic from `-addSignalBlock:` or `-subscribeNext:` into the
   `signalBlock` passed to the initializer.
 * Instead of subscribing to the result of `-addSignalBlock:`, subscribe to
   `executionSignals` or the result of `-execute:` instead.
 * Replace uses of `RACAbleWithStart(command, executing)` with
   `command.executing`.
 * Replace uses of `RACAbleWithStart(command, canExecute)` with
   `command.enabled`.
 * Remove uses of `deliverOn:RACScheduler.mainThreadScheduler` on
   `RACCommand` properties, as they are now unnecessary.

### Fallback nil values for RAC macro

The `RAC` macro now [always
requires](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/670) two or three
arguments:

 1. The object to bind to.
 1. The key path to set when new values are sent.
 1. (Optional) A value to set when `nil` is sent on the signal.

This is necessary to avoid a `-setNilValueForKey:` exception when observing
a primitive property _through_ an intermediate object which gets set to `nil`.

This is not actually a change in key-value observing behavior — it's a caveat
with KVO regardless — but `RACObserve` makes it more prominent, because the
deallocation of `weak` properties will be considered a change to `nil`.

**To update:**

 * Replace uses of `RAC(self.objectProperty)` with `RAC(self, objectProperty)`.
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

### Simpler two-way bindings

`RACPropertySubject` and `RACBinding` have been
[replaced](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/695) with
`RACChannel` and `RACChannelTerminal`. Similarly, `RACObservablePropertySubject`
has been replaced with `RACKVOChannel`.

In addition to slightly better terminology and more obvious usage, channels only
offer two-way bindings by default, which is a simplification over the previous N-way binding
interface.

Because of the sweeping conceptual changes, the old APIs have been completely
removed without deprecation.

**To update:**

 * Instead of creating a `RACPropertySubject`, create a `RACChannel`. Replace
   N-way property subjects (where N is greater than 2) with multiple
   `RACChannel`s.
 * Instead of creating a `RACObservablePropertySubject`, create
   a `RACKVOChannel` or use the `RACChannelTo` macro.
 * Replace uses of `RACBinding` with `RACChannelTerminal`.
 * Replace uses of `RACBind(self.objectProperty)` with `RACChannelTo(self,
   objectProperty)`. Add a default value for primitive properties:
   `RACChannelTo(self, integerProperty, @5)`
 * Replace uses of `-bindTo:` with the explicit subscription of two endpoints:

```objc
[binding1.followingEndpoint subscribe:binding2.leadingEndpoint];
[[binding2.leadingEndpoint skip:1] subscribe:binding1.followingEndpoint];
```

### Better bindings for AppKit

`-rac_bind:toObject:withKeyPath:` and related methods have been
[replaced](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/638) with
`-rac_channelToBinding:options:`, which returns a `RACChannelTerminal` that can be used as
a two-way binding or a one-way signal.

**To update:**

 * If possible, refactor code to use the new `RACChannel` interface. This
   bridges Cocoa Bindings with the full power of ReactiveCocoa.
 * For a direct conversion, use `-bind:toObject:withKeyPath:options:` with the
   following options:
    1. `@{ NSContinuouslyUpdatesValueBindingOption: @YES }` for `-rac_bind:toObject:withKeyPath:`
    1. `@{ NSContinuouslyUpdatesValueBindingOption: @YES, NSNullPlaceholderBindingOption: nilValue }` for `-rac_bind:toObject:withKeyPath:nilValue:`
    1. `@{ NSContinuouslyUpdatesValueBindingOption: @YES, NSValueTransformerBindingOption: valueTransformer }` for `-rac_bind:toObject:withKeyPath:transform:`
    1. `@{ NSContinuouslyUpdatesValueBindingOption: @YES, NSValueTransformerBindingOption: NSNegateBooleanTransformerName }` for `-rac_bind:toObject:withNegatedKeyPath:`

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

The `nilValue` parameter was added in parallel with the
[RAC](#fallback-nil-values-for-rac-macro) macro, but the semantics are otherwise
identical.

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

RACChannel interfaces have been [added](https://github.com/ReactiveCocoa/pull/686)
to many UIKit classes, greatly simplifying glue code between your models and views.

For example, assuming you want to bind a `person` model's `name` property:

```objc
UITextField *nameField = ...;
RACChannelTerminal *nameTerminal = RACChannelTo(model, name);
RACChannelTerminal *nameFieldTerminal = [nameField rac_newTextChannel];
[nameTerminal subscribe:nameFieldTerminal];
[nameFieldTerminal subscribe:nameTerminal];
```

You may also bind multiple controls to the same property, for example a UISlider for
coarse editing and a UIStepper for fine-grained editing.

### Signal subscription side effects

`RACSignal` now has the
[-initially:](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/685)
operator, which executes a given block each time the signal is subscribed to.
This is symmetric to `-finally:`.

### Test scheduler

`RACTestScheduler` is a [new kind](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/716) of scheduler that
virtualizes time. Enqueued blocks can be stepped through at any pace, no matter
how far in the future they're scheduled for, making it easy to test time-based
behavior without actually waiting in unit tests.
