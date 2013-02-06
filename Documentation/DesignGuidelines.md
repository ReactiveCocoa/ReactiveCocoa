# Design Guidelines

This document contains guidelines for projects that want to make use of
ReactiveCocoa. The content here is heavily inspired by the [Rx Design
Guidelines](http://blogs.msdn.com/b/rxteam/archive/2010/10/28/rx-design-guidelines.aspx).

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
### Side effects occur only once

## The RACSignal contract
### Signal events are serialized
### Subscription will always occur on a scheduler
### Errors are propagated immediately
### Side effects occur for each subscription
### Subscriptions are automatically disposed upon completion or error
### Outstanding work is cancelled on disposal
### Resources are cleaned up on disposal

## Best practices

The following recommendations are intended to help keep RAC-based code
predictable, understandable, and performant.

They are, however, only guidelines. Use best judgement when determining whether
to apply the recommendations here to a given piece of code.

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

### Deliver signal results onto a known scheduler

When a signal is returned from a method, or combined with such a signal, it can
be difficult to know which thread results will be delivered upon. Although
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

This helps fulfill [the RACSignal contract](#the-racsignal-contract).

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
