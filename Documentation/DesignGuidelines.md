# Design Guidelines

This document contains guidelines for projects that want to make use of
ReactiveCocoa. The content here is heavily inspired by the [Rx Design
Guidelines](http://blogs.msdn.com/b/rxteam/archive/2010/10/28/rx-design-guidelines.aspx).

This document assumes basic familiarity
with the features of ReactiveCocoa. The [Framework Overview][] is a better
resource for getting up to speed on the functionality provided by RAC.

**[The RACSignal contract](#the-racsignal-contract)**

 1. [Signal events are serialized](#signal-events-are-serialized)
 1. [Errors are propagated immediately](#errors-are-propagated-immediately)
 1. [Side effects occur for each subscription](#side-effects-occur-for-each-subscription)
 1. [Subscriptions are automatically disposed upon completion or error](#subscriptions-are-automatically-disposed-upon-completion-or-error)
 1. [Disposal cancels in-progress work and cleans up resources](#disposal-cancels-in-progress-work-and-cleans-up-resources)

**[Best practices](#best-practices)**

 1. [Use descriptive declarations for methods and properties that return a signal](#use-descriptive-declarations-for-methods-and-properties-that-return-a-signal)
 1. [Indent signal operations consistently](#indent-signal-operations-consistently)
 1. [Use the same type for all the values of a signal](#use-the-same-type-for-all-the-values-of-a-signal)
 1. [Process only as much of a signal as needed](#process-only-as-much-of-a-signal-as-needed)
 1. [Deliver signal events onto a known scheduler](#deliver-signal-events-onto-a-known-scheduler)
 1. [Switch schedulers in as few places as possible](#switch-schedulers-in-as-few-places-as-possible)
 1. [Make the side effects of a signal explicit](#make-the-side-effects-of-a-signal-explicit)
 1. [Share the side effects of a signal with a subject](#share-the-side-effects-of-a-signal-with-a-subject)
 1. [Debug signals by giving them names](#debug-signals-by-giving-them-names)
 1. [Avoid explicit subscriptions and disposal](#avoid-explicit-subscriptions-and-disposal)
 1. [Avoid manipulating subjects directly](#avoid-manipulating-subjects-directly)

**[Implementing new operators](#implementing-new-operators)**

 1. [Compose existing operators when possible](#compose-existing-operators-when-possible)
 1. [Avoid introducing concurrency](#avoid-introducing-concurrency)
 1. [Cancel work and clean up all resources in a disposable](#cancel-work-and-clean-up-all-resources-in-a-disposable)
 1. [Do not block in an operator](#do-not-block-in-an-operator)
 1. [Avoid stack overflow from deep recursion](#avoid-stack-overflow-from-deep-recursion)

## The RACSignal contract

[RACSignal][] is a _push-driven_ stream with a focus on asynchronous event
delivery through _subscriptions_. For more information about signals and
subscriptions, see the [Framework Overview][].

### Signal events are serialized

A signal may choose to deliver its events on any thread. Consecutive events are
even allowed to arrive on different threads or schedulers, unless explicitly
[delivered onto a particular
scheduler](#deliver-signal-events-onto-a-known-scheduler).

However, RAC guarantees that no two signal events will ever arrive concurrently.
While an event is being processed, no other events will be delivered. The
senders of any other events will be forced to wait until the current event has
been handled.

Most notably, this means that the blocks passed to
[-subscribeNext:error:completed:][RACSignal] do not need to be synchronized with
respect to each other, because they will never be invoked simultaneously.

### Errors are propagated immediately

In RAC, `error` events have exception semantics. When an error is sent on
a signal, it will be immediately forwarded to all dependent signals, causing the
entire chain to terminate.

[Operators][RACSignal+Operations] whose primary purpose is to change
error-handling behavior – like `-catch:`, `-catchTo:`, or `-materialize` – are
obviously not subject to this rule.

### Side effects occur for each subscription

Each new subscription to a [RACSignal][] will trigger its side effects. This
means that any side effects will happen as many times as subscriptions to the
signal itself.

Consider this example:
```objc
__block int aNumber = 0;

// Signal that will have the side effect of incrementing `aNumber` block 
// variable for each subscription before sending it.
RACSignal *aSignal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
	aNumber++;
	[subscriber sendNext:@(aNumber)];
	[subscriber sendCompleted];
	return nil;
}];

// This will print "subscriber one: 1"
[aSignal subscribeNext:^(id x) {
	NSLog(@"subscriber one: %@", x);
}];

// This will print "subscriber two: 2"
[aSignal subscribeNext:^(id x) {
	NSLog(@"subscriber two: %@", x);
}];
```

Side effects are repeated for each subscription. The same behavior applies to
most [operators][RACSignal+Operations]:

```objc
__block int missilesToLaunch = 0;

// Signal that will have the side effect of changing `missilesToLaunch` on
// subscription.
RACSignal *processedSignal = [[RACSignal
    return:@"missiles"]
	map:^(id x) {
		missilesToLaunch++;
		return [NSString stringWithFormat:@"will launch %d %@", missilesToLaunch, x];
	}];

// This will print "First will launch 1 missiles"
[processedSignal subscribeNext:^(id x) {
	NSLog(@"First %@", x);
}];

// This will print "Second will launch 2 missiles"
[processedSignal subscribeNext:^(id x) {
	NSLog(@"Second %@", x);
}];
```

To suppress this behavior and execute a signal's side effects only once, send
its events to a [subject](#share-the-side-effects-of-a-signal-with-a-subject).

Side effects can be insidious and produce problems that are difficult to
diagnose. For this reason it is suggested to 
[make side effects explicit](#make-the-side-effects-of-a-signal-explicit) when 
possible.

### Subscriptions are automatically disposed upon completion or error

When a [subscriber][RACSubscriber] is sent a `completed` or `error` event, the
associated subscription will automatically be disposed. This behavior usually
eliminates the need to manually dispose of subscriptions.

See the [Memory Management][] document for more information about signal
lifetime.

### Disposal cancels in-progress work and cleans up resources

When a subscription is disposed, manually or automatically, any in-progress or
outstanding work associated with that subscription is gracefully cancelled as
soon as possible, and any resources associated with the subscription are cleaned
up.

Disposing of the subscription to a signal representing a file upload, for
example, would cancel any in-flight network request, and free the file data from
memory.

## Best practices

The following recommendations are intended to help keep RAC-based code
predictable, understandable, and performant.

They are, however, only guidelines. Use best judgement when determining whether
to apply the recommendations here to a given piece of code.

### Use descriptive declarations for methods and properties that return a signal

When a method or property has a return type of [RACSignal][], it can be
difficult to understand the signal's semantics at a glance.

There are three key questions that can inform a declaration:

 1. Is the signal _hot_ (already activated by the time it's returned to the
    caller) or _cold_ (activated when subscribed to)?
 1. Will the signal include zero, one, or more values?
 1. Does the signal have side effects?

**Hot signals without side effects** should typically be properties instead of
methods. The use of a property indicates that no initialization is needed before
subscribing to the signal's events, and that additional subscribers will not
change the semantics. Signal properties should usually be named after events
(e.g., `textChanged`).

**Cold signals without side effects** should be returned from methods that have
noun-like names (e.g., `-currentText`). A method declaration indicates that the
signal might not be kept around, hinting that work is performed at the time of
subscription. If the signal sends multiple values, the noun should be pluralized
(e.g., `-currentModels`).

**Signals with side effects** should be returned from methods that have
verb-like names (e.g., `-logIn`). The verb indicates that the method is not
idempotent and that callers must be careful to call it only when the side
effects are desired. If the signal will send one or more values, include a noun
that describes them (e.g., `-loadConfiguration`, `-fetchLatestEvents`).

### Indent signal operations consistently

It's easy for RAC-heavy code to become very dense and confusing if not
properly formatted. Use consistent indentation to highlight where chains of
signals begin and end.

When invoking a single method upon a signal, no additional indentation is
necessary (block arguments aside):

```objc
RACSignal *result = [signal startWith:@0];

RACSignal *result2 = [signal map:^(NSNumber *value) {
    return @(value.integerValue + 1);
}];
```

When transforming the same signal multiple times, ensure that all of the
steps are aligned. Complex operators like [+zip:reduce:][RACSignal+Operations]
or [+combineLatest:reduce:][RACSignal+Operations] may be split over multiple
lines for readability:

```objc
RACSignal *result = [[[RACSignal
    zip:@[ firstSignal, secondSignal ]
    reduce:^(NSNumber *first, NSNumber *second) {
        return @(first.integerValue + second.integerValue);
    }]
    filter:^ BOOL (NSNumber *value) {
        return value.integerValue >= 0;
    }]
    map:^(NSNumber *value) {
        return @(value.integerValue + 1);
    }];
```

Of course, signals nested within block arguments should start at the natural
indentation of the block:

```objc
[[signal
    then:^{
        @strongify(self);

        return [[self
            doSomethingElse]
            catch:^(NSError *error) {
                @strongify(self);
                [self presentError:error];

                return [RACSignal empty];
            }];
    }]
    subscribeCompleted:^{
        NSLog(@"All done.");
    }];
```

### Use the same type for all the values of a signal

[RACSignal][] allows signals to be composed of heterogenous objects, just like
Cocoa collections do. However, using different object types within the same
signal complicates the use of operators and puts an additional burden on any
consumers, who must be careful to only invoke supported methods.

Whenever possible, signals should only contain objects of the same type.

### Process only as much of a signal as needed

Unnecessarily keeping a [RACSignal][] subscription alive can result in increased
memory and CPU usage, as unnecessary work is performed for results that will
never be used.

If only a certain number of values are needed from a signal, the
[-take:][RACSignal+Operations] operator can be used to retrieve only that many
values, and then automatically [dispose of the
subscription](#disposal-cancels-in-progress-work-and-cleans-up-resources)
immediately thereafter.

Operators like `-take:` and [-takeUntil:][RACSignal+Operations] automatically
propagate cancellation up the stack as well. If nothing else needs the rest of
the values, any dependencies will be terminated too, potentially saving a
significant amount of work.

### Deliver signal events onto a known scheduler

When a signal is returned from a method, or combined with such a signal, it can
be difficult to know which thread events will be delivered upon. Although
events are [guaranteed to be serial](#signal-events-are-serialized), sometimes
stronger guarantees are needed, like when performing UI updates (which must
occur on the main thread).

Whenever such a guarantee is important, the [-deliverOn:][RACSignal+Operations]
operator should be used to force a signal's events to arrive on a specific
[RACScheduler][].

### Switch schedulers in as few places as possible

Notwithstanding the above, events should only be delivered to a specific
[scheduler][RACScheduler] when absolutely necessary. Switching schedulers can
introduce unnecessary delays and cause an increase in CPU load.

Generally, the use of [-deliverOn:][RACSignal+Operations] should be restricted
to the end of a signal chain – e.g., before subscription, or before the values
are bound to a property.

### Make the side effects of a signal explicit

As much as possible, [RACSignal][] side effects should be avoided, because
subscribers may find the [behavior of side
effects](#side-effects-occur-for-each-subscription) unexpected.

However, because Cocoa is predominantly imperative, it is sometimes useful to
perform side effects when signal events occur. Although most
[operators][RACSignal+Operations] accept arbitrary blocks (which can contain
side effects), the use of `-doNext:`, `-doError:`, and `-doCompleted:` will make
side effects more explicit and self-documenting:

```objc
NSMutableArray *nexts = [NSMutableArray array];
__block NSError *receivedError = nil;
__block BOOL success = NO;

RACSignal *bookkeepingSignal = [[[valueSignal
    doNext:^(id x) {
        [nexts addObject:x];
    }]
    doError:^(NSError *error) {
        receivedError = error;
    }]
    doCompleted:^{
        success = YES;
    }];

RAC(self, value) = bookkeepingSignal;
```

### Share the side effects of a signal with a subject

[Side effects occur for each
subscription](#side-effects-occur-for-each-subscription) by default, but there
are certain situations where side effects should only occur once – for example,
a network request typically should not be repeated when a new subscriber is
added.

Instead of subscribing to the signal multiple times, forward the signal events
to a [RACSubject][], and subscribe to the subject as many times as desired:

```objc
// This signal starts a new request on each subscription.
RACSignal *networkRequest = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
    AFHTTPRequestOperation *operation = [client
        HTTPRequestOperationWithRequest:request
        success:^(AFHTTPRequestOperation *operation, id response) {
            [subscriber sendNext:response];
            [subscriber sendCompleted];
        }
        failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            [subscriber sendError:error];
        }];

    [client enqueueHTTPRequestOperation:operation];
    return [RACDisposable disposableWithBlock:^{
        [operation cancel];
    }];
}];

// This subject will distribute the events of the `networkRequest` signal.
RACSubject *results = [RACSubject subject];

// Set up any number of subscriptions to the subject.
[results subscribeNext:^(id response) {
    NSLog(@"subscriber one: %@", response);
}];

[results subscribeNext:^(id response) {
    NSLog(@"subscriber two: %@", response);
}];

// Then, actually begin the request (by subscribing once to the request signal),
// and both subscribers will receive the same events.
[networkRequest subscribe:results];
```

### Debug signals by giving them names

Every [RACSignal][] has a `name` property to assist with debugging. A signal's
`-description` includes its name, and all operators provided by RAC will
automatically add to the name. This usually makes it possible to identify
a signal from its default name alone.

For example, this snippet:

```objc
RACSignal *signal = [[[RACObserve(self, username) 
    distinctUntilChanged] 
    take:3] 
    filter:^(NSString *newUsername) {
        return [newUsername isEqualToString:@"joshaber"];
    }];

NSLog(@"%@", signal);
```

… would log a name similar to `[[[RACObserve(self, username)] -distinctUntilChanged]
-take: 3] -filter:`.

Names can also be manually applied by using [-setNameWithFormat:][RACSignal].

`RACSignal` also offers `-logNext`, `-logError`, `-logCompleted`, and `-logAll`
methods, which will automatically log signal events as they occur, and include
the name of the signal in the messages. This can be used to conveniently inspect
a signal in real-time.

### Avoid explicit subscriptions and disposal

Although [-subscribeNext:error:completed:][RACSignal] and its variants are the
most basic way to process a signal, their use can complicate code by
being less declarative, encouraging the use of side effects, and potentially
duplicating built-in functionality.

Likewise, explicit use of the [RACDisposable][] class can quickly lead to
a rat's nest of resource management and cleanup code.

There are almost always higher-level patterns that can be used instead of manual
subscriptions and disposal:

 * The [RAC()][RAC] or [RACChannelTo()][RACChannelTo] macros can be used to bind
   a signal to a property, instead of performing manual updates when changes
   occur.
 * The [-rac_liftSelector:withSignals:][NSObject+RACLifting] method can be used
   to automatically invoke a selector when one or more signals fire.
 * Operators like [-takeUntil:][RACSignal+Operations] can be used to
   automatically dispose of a subscription when an event occurs (like a "Cancel"
   button being pressed in the UI).

Generally, the use of built-in [operators][RACSignal+Operations] will lead to
simpler and less error-prone code than replicating the same behaviors in
a subscription callback.

### Avoid manipulating subjects directly

[Subjects][] are a powerful tool for bridging imperative code
into the world of signals and [sharing side
effects](#share-the-side-effects-of-a-signal-with-a-subject), but, as the
"mutable variables" of RAC, they can quickly lead to complexity when overused.

Since they can be manipulated from anywhere, at any time, subjects often break
the linear flow of stream processing and make logic much harder to follow. They
also don't support meaningful
[disposal](#disposal-cancels-in-progress-work-and-cleans-up-resources), which
can result in unnecessary work.

Subjects can usually be replaced with other patterns from ReactiveCocoa:

 * Instead of feeding initial values into a subject, consider generating the
   values in a [+createSignal:][RACSignal] block instead.
 * Instead of delivering intermediate results to a subject, try combining the
   output of multiple signals with operators like
   [+combineLatest:][RACSignal+Operations] or [+zip:][RACSignal+Operations].
 * Instead of implementing a control action that sends values on a subject, use
   [RACAction][] or [-rac_signalForSelector:][NSObject+RACSelectorSignal]
   instead.

However, subjects _are_ often necessary to [share the side effects of
a signal](#share-the-side-effects-of-a-signal-with-a-subject). In that case, use
`-subscribe:`, and avoid directly manipulating the subject with `-sendNext:`,
`-sendError:`, and `-sendCompleted`.

## Implementing new operators

RAC provides a long list of built-in operators for
[RACSignal][RACSignal+Operations] that should cover most use cases; however, RAC
is not a closed system. It's entirely valid to implement additional operators
for specialized uses, or for consideration in ReactiveCocoa itself.

Implementing a new operator requires a careful attention to detail and a focus
on simplicity, to avoid introducing bugs into the calling code.

These guidelines cover some of the common pitfalls and help preserve the
expected API contracts.

### Compose existing operators when possible

Considerable thought has been put into the operators provided by RAC, and they
have been validated through automated tests and through their real world use in
other projects. An operator that has been written from scratch may not be as
robust, or might not handle a special case that the built-in operators are aware
of.

To minimize duplication and possible bugs, use the provided operators as much as
possible in a custom operator implementation. Generally, there should be very
little code written from scratch.

### Avoid introducing concurrency

Concurrency is an extremely common source of bugs in programming. To minimize
the potential for deadlocks and race conditions, operators should not
concurrently perform their work.

Callers always have the ability to subscribe or deliver events on a specific
[RACScheduler][], and RAC offers powerful ways to [parallelize
work][Parallelizing Independent Work] without making operators unnecessarily
complex.

### Cancel work and clean up all resources in a disposable

When implementing a signal with the [+create:][RACSignal] method, you can add
disposables to the subscriber's [disposable][RACSubscriber] property. Taking
advantage of this you should:

 * As soon as it is convenient, gracefully cancel any in-progress work that was
   started by the signal.
 * Immediately dispose of any subscriptions by other subscribers, thus
   triggering their cancellation and cleanup code as well.
 * Release any memory or other resources that were allocated by the signal.

This helps fulfill [the RACSignal
contract](#disposal-cancels-in-progress-work-and-cleans-up-resources).

### Do not block in an operator

Signal operators should return a new signal immediately. Any work that the
operator needs to perform should be part of subscribing to the new signal, _not_
part of the operator invocation itself.

```objc
// WRONG!
- (RACSignal *)map:(id (^)(id))block {
    RACSignal *result = [RACSignal empty];
    for (id obj in self) {
        id mappedObj = block(obj);
        result = [result concat:[RACSignal return:mappedObj]];
    }

    return result;
}

// Right!
- (RACSignal *)map:(id (^)(id))block {
    return [self flattenMap:^(id obj) {
        id mappedObj = block(obj);
        return [RACSignal return:mappedObj];
    }];
}
```

This guideline can be safely ignored when the purpose of an operator is to
synchronously retrieve one or more values from a signal (like
[-first][RACSignal+Operations]).

### Avoid stack overflow from deep recursion

Any operator that might recurse indefinitely should use the
`-scheduleRecursiveBlock:` method of [RACScheduler][]. This method will
transform recursion into iteration instead, preventing a stack overflow.

For example, this would be an incorrect implementation of
[-repeat][RACSignal+Operations], due to its potential to overflow the call stack
and cause a crash:

```objc
- (RACSignal *)repeat {
    return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACCompoundDisposable *compoundDisposable = [RACCompoundDisposable compoundDisposable];

        __block void (^resubscribe)(void) = ^{
            RACDisposable *disposable = [self subscribeNext:^(id x) {
                [subscriber sendNext:x];
            } error:^(NSError *error) {
                [subscriber sendError:error];
            } completed:^{
                resubscribe();
            }];

            [compoundDisposable addDisposable:disposable];
        };

        return compoundDisposable;
    }];
}
```

By contrast, this version will avoid a stack overflow:

```objc
- (RACSignal *)repeat {
    return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
        RACCompoundDisposable *compoundDisposable = [RACCompoundDisposable compoundDisposable];

        RACScheduler *scheduler = RACScheduler.currentScheduler ?: [RACScheduler scheduler];
        RACDisposable *disposable = [scheduler scheduleRecursiveBlock:^(void (^reschedule)(void)) {
            RACDisposable *disposable = [self subscribeNext:^(id x) {
                [subscriber sendNext:x];
            } error:^(NSError *error) {
                [subscriber sendError:error];
            } completed:^{
                reschedule();
            }];

            [compoundDisposable addDisposable:disposable];
        }];

        [compoundDisposable addDisposable:disposable];
        return compoundDisposable;
    }];
}
```

[Framework Overview]: FrameworkOverview.md
[Memory Management]: MemoryManagement.md
[NSObject+RACLifting]: ../ReactiveCocoaFramework/ReactiveCocoa/NSObject+RACLifting.h
[NSObject+RACSelectorSignal]: ../ReactiveCocoaFramework/ReactiveCocoa/NSObject+RACSelectorSignal.h
[RAC]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSubscriptingAssignmentTrampoline.h
[RACAction]: ../ReactiveCocoaFramework/ReactiveCocoa/RACAction.h
[RACChannelTo]: ../ReactiveCocoaFramework/ReactiveCocoa/RACKVOChannel.h
[RACDisposable]: ../ReactiveCocoaFramework/ReactiveCocoa/RACDisposable.h
[RACEvent]: ../ReactiveCocoaFramework/ReactiveCocoa/RACEvent.h
[RACMulticastConnection]: ../ReactiveCocoaFramework/ReactiveCocoa/RACMulticastConnection.h
[RACObserve]: ../ReactiveCocoaFramework/ReactiveCocoa/NSObject+RACPropertySubscribing.h
[RACScheduler]: ../ReactiveCocoaFramework/ReactiveCocoa/RACScheduler.h
[RACSignal]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSignal.h
[RACSignal+Operations]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSignal+Operations.h
[RACSubject]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSubject.h
[RACSubscriber]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSubscriber.h
[Subjects]: FrameworkOverview.md#subjects
[Parallelizing Independent Work]: ../README.md#parallelizing-independent-work
