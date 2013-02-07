# Design Guidelines

This document contains guidelines for projects that want to make use of
ReactiveCocoa. The content here is heavily inspired by the [Rx Design
Guidelines](http://blogs.msdn.com/b/rxteam/archive/2010/10/28/rx-design-guidelines.aspx).

Most of this document (except for the first section) assumes basic familiarity
with the features of ReactiveCocoa. The [Framework Overview][] is a better
resource for getting up to speed on the functionality provided by RAC.

**[When to use RAC](#when-to-use-rac)**

 1. [Handling asynchronous or event-driven data sources](#handling-asynchronous-or-event-driven-data-sources)
 1. [Chaining dependent operations](#chaining-dependent-operations)
 1. [Parallelizing independent work](#parallelizing-independent-work)
 1. [Simplifying collection transformations](#simplifying-collection-transformations)

**[The RACSequence contract](#the-racsequence-contract)**

 1. [Evaluation occurs lazily by default](#evaluation-occurs-lazily-by-default)
 1. [Evaluation blocks the caller](#evaluation-blocks-the-caller)
 1. [Side effects occur only once](#side-effects-occur-only-once)

**[The RACSignal contract](#the-racsignal-contract)**

 1. [Signal events are serialized](#signal-events-are-serialized)
 1. [Subscription will always occur on a scheduler](#subscription-will-always-occur-on-a-scheduler)
 1. [Errors are propagated immediately](#errors-are-propagated-immediately)
 1. [Side effects occur for each subscription](#side-effects-occur-for-each-subscription)
 1. [Subscriptions are automatically disposed upon completion or error](#subscriptions-are-automatically-disposed-upon-completion-or-error)
 1. [Disposal cancels in-progress work and cleans up resources](#disposal-cancels-in-progress-work-and-cleans-up-resources)

**[Best practices](#best-practices)**

 1. [Use descriptive declarations for methods and properties that return a signal](#use-descriptive-declarations-for-methods-and-properties-that-return-a-signal)
 1. [Use the same type for all the values of a stream](#use-the-same-type-for-all-the-values-of-a-stream)
 1. [Avoid retaining streams and disposables directly](#avoid-retaining-streams-and-disposables-directly)
 1. [Process only as much of a stream as needed](#process-only-as-much-of-a-stream-as-needed)
 1. [Deliver signal events onto a known scheduler](#deliver-signal-events-onto-a-known-scheduler)
 1. [Switch schedulers in as few places as possible](#switch-schedulers-in-as-few-places-as-possible)
 1. [Make the side effects of a signal explicit](#make-the-side-effects-of-a-signal-explicit)
 1. [Share the side effects of a signal by multicasting](#share-the-side-effects-of-a-signal-by-multicasting)
 1. [Debug streams by giving them names](#debug-streams-by-giving-them-names)

**[Implementing new operators](#implementing-new-operators)**

 1. [Prefer building on RACStream methods](#prefer-building-on-racstream-methods)
 1. [Compose existing operators when possible](#compose-existing-operators-when-possible)
 1. [Avoid introducing concurrency](#avoid-introducing-concurrency)
 1. [Cancel work and clean up all resources in a disposable](#cancel-work-and-clean-up-all-resources-in-a-disposable)
 1. [Do not block in an operator](#do-not-block-in-an-operator)
 1. [Avoid stack overflow from deep recursion](#avoid-stack-overflow-from-deep-recursion)

## When to use RAC

Upon first glance, ReactiveCocoa is very abstract, and it can be difficult to
understand how to apply it to concrete problems.

Here are some of the use cases that RAC excels at.

### Handling asynchronous or event-driven data sources

Much of Cocoa programming is focused on reacting to user events or changes in
application state. Code that deals with such events can quickly become very
complex and spaghetti-like, with lots of callbacks and state variables to handle
ordering issues.

Patterns that seem superficially different, like UI callbacks, network
responses, and KVO notifications, actually have a lot in common. [RACSignal][]
unifies all these different APIs so that they can be composed together and
manipulated in the same way.

For example, the following pseudo-code:

```objc
- (void)viewDidLoad {
    [super viewDidLoad];

    [self.usernameTextField addTarget:self action:@selector(updateLogInButton) forControlEvents:UIControlEventEditingChanged];
    [self.passwordTextField addTarget:self action:@selector(updateLogInButton) forControlEvents:UIControlEventEditingChanged];
    [self.logInButton addTarget:self action:@selector(logInPressed:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)updateLogInButton {
    BOOL textFieldsNonEmpty = self.usernameTextField.text.length > 0 && self.passwordTextField.text.length > 0;
    BOOL readyToLogIn = ![[LoginManager sharedManager] isLoggingIn] && !self.loggedIn;
    self.logInButton.enabled = textFieldsNonEmpty && readyToLogIn;
}

- (IBAction)logInPressed:(UIButton *)sender {
    [[LoginManager sharedManager]
        logInWithUsername:self.usernameTextField.text
        password:self.passwordTextField.text
        success:^{
            self.loggedIn = YES;
        } failure:^(NSError *error) {
            [self presentError:error];
        }];
}

- (void)loggedOut:(NSNotification *)notification {
    self.loggedIn = NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isEqual:[LoginManager sharedManager]] && [keyPath isEqualToString:@"loggingIn"]) {
        [self updateLogInButton];
    }
}
```

… could be expressed in RAC like so:

```objc
- (void)viewDidLoad {
    [super viewDidLoad];

    @weakify(self);

    RAC(self.logInButton.enabled) = [RACSignal
        combineLatest:@[
            self.usernameTextField.rac_textSignal,
            self.passwordTextField.rac_textSignal,
            RACAbleWithStart(LoginManager.sharedManager, loggingIn),
            RACAbleWithStart(self.loggedIn)
        ] reduce:^(NSString *username, NSString *password, NSNumber *loggingIn, NSNumber *loggedIn) {
            return @(username.length > 0 && password.length > 0 && !loggingIn.boolValue && !loggedIn.boolValue);
        }];

    [[self.logInButton rac_signalForControlEvents:UIControlEventTouchUpInside] subscribeNext:^(UIButton *sender) {
        RACSignal *loginSignal = [[LoginManager sharedManager]
            logInWithUsername:self.usernameTextField.text
            password:self.passwordTextField.text];

        [loginSignal subscribeError:^(NSError *error) {
            @strongify(self);
            [self presentError:error];
        } completed:{
            @strongify(self);
            self.loggedIn = YES;
        }];
    }];
}
```

### Chaining dependent operations

Dependencies are most often found in network requests, where a previous request
to the server needs to complete before the next one can be constructed, and so
on:

```objc
[client logInWithSuccess:^{
    [client loadCachedMessagesWithSuccess:^(NSArray *messages) {
        [client fetchMessagesAfterMessage:messages.lastObject success:^(NSArray *nextMessages) {
            NSLog(@"Fetched all messages.");
        } failure:^(NSError *error) {
            [self presentError:error];
        }];
    } failure:^(NSError *error) {
        [self presentError:error];
    }];
} failure:^(NSError *error) {
    [self presentError:error];
}];
```

ReactiveCocoa makes this pattern particularly easy:

```objc
[[[[client logIn]
    sequenceNext:^{
        return [client loadCachedMessages];
    }]
    flattenMap:^(NSArray *messages) {
        return [client fetchMessagesAfterMessage:messages.lastObject];
    }]
    subscribeError:^(NSError *error) {
        [self presentError:error];
    } completed:^{
        NSLog(@"Fetched all messages.");
    }];
```

### Parallelizing independent work

Working with independent data sets in parallel and then combining them into
a final result is non-trivial in Cocoa, and often involves a lot of
synchronization:

```objc
__block NSArray *databaseObjects;
__block NSArray *fileContents;

dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @synchronized (self) {
        databaseObjects = [databaseClient fetchObjectsMatchingPredicate:predicate];
        if (fileContents != nil) {
            [self finishProcessingDatabaseObjects:databaseObjects fileContents:fileContents];
            NSLog(@"Done processing");
        }
    }
});

dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSMutableArray *filesInProgress = [NSMutableArray array];
    for (NSString *path in files) {
        [filesInProgress addObject:[NSData dataWithContentsOfFile:path]];
    }
    
    @synchronized (self) {
        fileContents = [filesInProgress copy];
        if (databaseObjects != nil) {
            [self finishProcessingDatabaseObjects:databaseObjects fileContents:fileContents];
            NSLog(@"Done processing");
        }
    }
});
```

The above code can be cleaned up and optimized by simply composing signals:

```objc
RACSignal *databaseSignal = [[databaseClient
    fetchObjectsMatchingPredicate:predicate]
    subscribeOn:[RACScheduler schedulerWithPriority:RACSchedulerPriorityDefault]];

RACSignal *fileSignal = [RACSignal start:^(BOOL *success, NSError **error) {
    NSMutableArray *filesInProgress = [NSMutableArray array];
    for (NSString *path in files) {
        [filesInProgress addObject:[NSData dataWithContentsOfFile:path]];
    }

    return [filesInProgress copy];
}];

[[RACSignal
    combineLatest:@[ databaseSignal, fileSignal ]
    reduce:^(NSArray *databaseObjects, NSArray *fileContents) {
        [self finishProcessingDatabaseObjects:databaseObjects fileContents:fileContents];
    }]
    subscribeCompleted:^{
        NSLog(@"Done processing");
    }];
```

### Simplifying collection transformations

Higher-order functions like `map`, `filter`, `fold`/`reduce` are sorely missing
from Foundation, leading to loop-focused code like this:

```objc
NSMutableArray *results = [NSMutableArray array];
for (NSString *str in strings) {
    if (str.length < 2) {
        continue;
    }

    NSString *newString = [str stringByAppendingString:@"foobar"];
    [results addObject:newString];
}
```

[RACSequence][] allows any Cocoa collection to be manipulated in a uniform and
declarative way:

```objc
RACSequence *results = [[strings.rac_sequence
    filter:^ BOOL (NSString *str) {
        return str.length >= 2;
    }]
    map:^(NSString *str) {
        return [str stringByAppendingString:@"foobar"];
    }];
```

## The RACSequence contract

[RACSequence][] is a _pull-driven_ stream. Sequences behave similarly to
built-in collections, but with a few unique twists.

### Evaluation occurs lazily by default

Sequences are evaluated lazily by default. For example, in this sequence:

```objc
NSArray *strings = @[ @"A", @"B", @"C" ];
RACSequence *sequence = [strings.rac_sequence map:^(NSString *str) {
    return [str stringByAppendingString:@"_"];
}];
```

… no string appending is actually performed until the values of the sequence are
needed. Accessing `sequence.head` will perform the concatenation of `A_`,
accessing `sequence.tail.head` will perform the concatenation of `B_`, and so
on.

This generally avoids performing unnecessary work (since values that are never
used are never calculated), but means that sequence processing [should be
limited only to what's actually
needed](#process-only-as-much-of-a-stream-as-needed).

Once evaluated, the values in a sequence are memoized and do not need to be
recalculated. Accessing `sequence.head` multiple times will only do the work of
one string concatenation.

If lazy evaluation is undesirable – for instance, because limiting memory usage
is more important than avoiding unnecessary work – the
[eagerSequence][RACSequence] property can be used to force a sequence (and any
sequences derived from it afterward) to evaluate eagerly.

### Evaluation blocks the caller

Regardless of whether a sequence is lazy or eager, evaluation of any part of
a sequence will block the calling thread until completed. This is necessary
because values must be synchronously retrieved from a sequence.

If evaluating a sequence is expensive enough that it might block the thread for
a significant amount of time, consider creating a signal with
[-signalWithScheduler:][RACSequence] and using that instead.

### Side effects occur only once

When the block passed to a sequence operator involves side effects, it is
important to realize that those side effects will only occur once per value
– namely, when the value is evaluated:

```objc
NSArray *strings = @[ @"A", @"B", @"C" ];
RACSequence *sequence = [strings.rac_sequence map:^(NSString *str) {
    NSLog(@"%@", str);
    return [str stringByAppendingString:@"_"];
}];

// Logs "A" during this call.
NSString *concatA = sequence.head;

// Logs "B" during this call.
NSString *concatB = sequence.tail.head;

// Does not log anything.
NSString *concatB2 = sequence.tail.head;

RACSequence *derivedSequence = [sequence map:^(NSString *str) {
    return [@"_" stringByAppendingString:str];
}];

// Still does not log anything, because "B_" was already evaluated, and the log
// statement associated with it will never be re-executed.
NSString *concatB3 = derivedSequence.tail.head;
```

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

### Subscription will always occur on a scheduler

To ensure consistent behavior for the `+createSignal:` and `-subscribe:`
methods, each [RACSignal][] subscription is guaranteed to take place on
a valid [RACScheduler][].

If the subscriber's thread already has a [+currentScheduler][RACScheduler],
scheduling takes place immediately; otherwise, scheduling occurs as soon as
possible on a background scheduler. Note that the main thread is always
associated with the [+mainThreadScheduler][RACScheduler], so subscription will
always be immediate there.

See the documentation for [-subscribe:][RACSignal] for more information.

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

Side effects are repeated for each subscription. The same applies to
[stream][RACStream] and [signal][RACSignal+Operations] operators:

```objc
__block int missilesToLaunch = 0;

// Signal that will have the side effect of changing `missilesToLaunch` on
// subscription.
RACSignal *processedSignal = [[RACSignal return:@"missiles"]
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

To suppress this behavior and have multiple subscriptions to a signal execute
its side effects only once, a signal can be 
[multicasted](#share-the-side-effects-of-a-signal-by-multicasting).

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

### Use the same type for all the values of a stream

[RACStream][] (and, by extension, [RACSignal][] and [RACSequence][]) allows
streams to be composed of heterogenous objects, just like Cocoa collections do.
However, using different object types within the same stream complicates the use
of operators (because they must be careful to only invoke supported methods) and
puts an additional burden on any consumers of that stream.

Whenever possible, streams should only contain objects of the same type.

### Avoid retaining streams and disposables directly

Retaining any [RACStream][] longer than it's needed will cause any dependencies
to be retained as well, potentially keeping memory usage much higher than it
would be otherwise.

A [RACSequence][] should be retained only for as long as the `head` of the
sequence is needed. If the head will no longer be used, retain the `tail` of the
node instead of the node itself.

It's usually unnecessary to directly retain a [RACDisposable][] or
a [RACSignal][], because there are often higher-level patterns that can be used
instead of manual lifetime management. For instance,
[-rac_liftSelector:withObjects:][NSObject+RACLifting] or the [RAC()][RAC] macro
can often replace [-subscribeNext:error:completed:][RACSignal].

See the [Memory Management][] guide for more information.

### Process only as much of a stream as needed

As well as [consuming additional
memory](#avoid-retaining-streams-and-disposables-directly), unnecessarily
keeping a stream or [RACSignal][] subscription alive can result in increased CPU
usage, as unnecessary work is performed for results that will never be used.

If only a certain number of values are needed from a stream, the
[-take:][RACStream] operator can be used to retrieve only that many values, and
then automatically terminate the stream immediately thereafter.

Similarly, [-takeUntil:][RACSignal+Operations] can be used to automatically
dispose of a [RACSignal][] subscription when an event occurs (like a "Cancel"
button being pressed in the UI).

Operators like `-take:` and `-takeUntil:` automatically propagate cancellation
up the stack as well. If nothing else needs the rest of the values, any
dependencies will be terminated too, potentially saving a significant amount of
work.

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
perform side effects when signal events occur. Although most [RACStream][] and
[RACSignal][RACSignal+Operations] operators accept arbitrary blocks (which can
contain side effects), the use of `-doNext:`, `-doError:`, and `-doCompleted:`
will make side effects more explicit and self-documenting:

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

RAC(self.value) = bookkeepingSignal;
```

### Share the side effects of a signal by multicasting

[Side effects occur for each
subscription](#side-effects-occur-for-each-subscription) by default, but there
are certain situations where side effects should only occur once – for example,
a network request typically should not be repeated when a new subscriber is
added.

The `-publish` and `-multicast:` operators of [RACSignal][RACSignal+Operations]
allow a single subscription to be shared to any number of subscribers by using
a [RACMulticastConnection][]:

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

// Starts a single request, no matter how many subscriptions `connection.signal`
// gets. This is equivalent to the -replay operator.
RACMulticastConnection *connection = [networkRequest multicast:[RACReplaySubject subject]];
[connection connect];

[connection.signal subscribeNext:^(id response) {
    NSLog(@"subscriber one: %@", response);
}];

[connection.signal subscribeNext:^(id response) {
    NSLog(@"subscriber two: %@", response);
}];
```

### Debug streams by giving them names

Every [RACStream][] has a `name` property to assist with debugging. A stream's
`-description` includes its name, and all operators provided by RAC will
automatically add to the name. This usually makes it possible to identify
a stream from its default name alone.

For example, this snippet:

```objc
RACSignal *signal = [[[RACAble(self.username) 
    distinctUntilChanged] 
    take:3] 
    filter:^(NSString *newUsername) {
        return [newUsername isEqualToString:@"joshaber"];
    }];

NSLog(@"%@", signal);
```

… would log a name similar to `[[[RACAble(self.username)] -distinctUntilChanged]
-take: 3] -filter:`.

Names can also be manually applied by using [-setNameWithFormat:][RACStream].

For named signals in particular, [RACSignal][] offers `-logNext`, `-logError`,
`-logCompleted`, and `-logAll` methods, which will automatically log signal
events as they occur, and include the name of the signal in the messages. This
can be used to conveniently inspect a signal in real-time.

## Implementing new operators

RAC provides a long list of built-in operators for [streams][RACStream] and
[signals][RACSignal+Operations] that should cover most use cases; however, RAC
is not a closed system. It's entirely valid to implement additional operators
for specialized uses, or for consideration in ReactiveCocoa itself.

Implementing a new operator requires a careful attention to detail and a focus
on simplicity, to avoid introducing bugs into the calling code.

These guidelines cover some of the common pitfalls and help preserve the
expected API contracts.

### Prefer building on RACStream methods

[RACStream][] offers a simpler interface than [RACSequence][] and [RACSignal][],
and all stream operators are automatically applicable to sequences and signals
as well.

For these reasons, new operators should be implemented using only [RACStream][]
methods whenever possible. The minimal required methods of the class, including
`-bind:`, `+zip:reduce:`, and `-concat:`, are quite powerful, and many tasks can
be accomplished without needing anything else.

If a new [RACSignal][] operator needs to handle `error` and `completed` events,
consider using the [-materialize][RACSignal+Operations] method to bring the
events into the stream. All of the events of a materialized signal can be
manipulated by stream operators, which helps minimize the use of non-stream
operators.

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
work](#parallelizing-independent-work) without making operators unnecessarily
complex.

### Cancel work and clean up all resources in a disposable

When implementing a signal with the [+createSignal:][RACSignal] method, the
provided block is expected to return a [RACDisposable][]. This disposable
should:

 * As soon as it is convenient, gracefully cancel any in-progress work that was
   started by the signal.
 * Immediately dispose of any subscriptions to other signals, thus triggering
   their cancellation and cleanup code as well.
 * Release any memory or other resources that were allocated by the signal.

This helps fulfill [the RACSignal
contract](#disposal-cancels-in-progress-work-and-cleans-up-resources).

### Do not block in an operator

Stream operators should return a new stream more-or-less immediately. Any work
that the operator needs to perform should be part of evaluating the new stream,
_not_ part of the operator invocation itself.

```objc
// WRONG!
- (RACSequence *)map:(id (^)(id))block {
    RACSequence *result = [RACSequence empty];
    for (id obj in self) {
        id mappedObj = block(obj);
        result = [result concat:[RACSequence return:mappedObj]];
    }

    return result;
}

// Right!
- (RACSequence *)map:(id (^)(id))block {
    return [self flattenMap:^(id obj) {
        id mappedObj = block(obj);
        return [RACSequence return:mappedObj];
    }];
}
```

This guideline can be safely ignored when the purpose of an operator is to
synchronously retrieve one or more values from a stream (like
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

            if (disposable != nil) [compoundDisposable addDisposable:disposable];
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

            if (disposable != nil) [compoundDisposable addDisposable:disposable];
        }];

        if (disposable != nil) [compoundDisposable addDisposable:disposable];
        return compoundDisposable;
    }];
}
```

[Framework Overview]: FrameworkOverview.md
[Memory Management]: MemoryManagement.md
[NSObject+RACLifting]: ../ReactiveCocoaFramework/ReactiveCocoa/NSObject+RACLifting.h
[RAC]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSubscriptingAssignmentTrampoline.h
[RACAble]: ../ReactiveCocoaFramework/ReactiveCocoa/NSObject+RACPropertySubscribing.h
[RACDisposable]: ../ReactiveCocoaFramework/ReactiveCocoa/RACDisposable.h
[RACEvent]: ../ReactiveCocoaFramework/ReactiveCocoa/RACEvent.h
[RACMulticastConnection]: ../ReactiveCocoaFramework/ReactiveCocoa/RACMulticastConnection.h
[RACScheduler]: ../ReactiveCocoaFramework/ReactiveCocoa/RACScheduler.h
[RACSequence]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSequence.h
[RACSignal]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSignal.h
[RACSignal+Operations]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSignal+Operations.h
[RACStream]: ../ReactiveCocoaFramework/ReactiveCocoa/RACStream.h
[RACSubscriber]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSubscriber.h
