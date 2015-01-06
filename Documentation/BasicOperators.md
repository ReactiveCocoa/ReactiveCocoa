# Basic Operators

This document explains some of the most common operators used in ReactiveCocoa,
and includes examples demonstrating their use.

Operators that apply to [sequences][Sequences] _and_ [signals][Signals] are
known as [stream][Streams] operators.

**[Performing side effects with signals](#performing-side-effects-with-signals)**

 1. [Subscription](#subscription)
 1. [Injecting effects](#injecting-effects)

**[Transforming streams](#transforming-streams)**

 1. [Mapping](#mapping)
 1. [Filtering](#filtering)

**[Combining streams](#combining-streams)**

 1. [Concatenating](#concatenating)
 1. [Flattening](#flattening)
 1. [Mapping and flattening](#mapping-and-flattening)

**[Combining signals](#combining-signals)**

 1. [Sequencing](#sequencing)
 1. [Merging](#merging)
 1. [Combining latest values](#combining-latest-values)
 1. [Switching](#switching)

## Performing side effects with signals

Most signals start out "cold," which means that they will not do any work until
[subscription](#subscription).

Upon subscription, a signal or its [subscribers][Subscription] can perform _side
effects_, like logging to the console, making a network request, updating the
user interface, etc.

Side effects can also be [injected](#injecting-effects) into a signal, where
they won't be performed immediately, but will instead take effect with each
subscription later.

### Subscription

The [-subscribe…][RACSignal] methods give you access to the current and future values in a signal:

```objc
RACSignal *letters = [@"A B C D E F G H I" componentsSeparatedByString:@" "].rac_sequence.signal;

// Outputs: A B C D E F G H I
[letters subscribeNext:^(NSString *x) {
    NSLog(@"%@", x);
}];
```

For a cold signal, side effects will be performed once _per subscription_:

```objc
__block unsigned subscriptions = 0;

RACSignal *loggingSignal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
    subscriptions++;
    [subscriber sendCompleted];
    return nil;
}];

// Outputs:
// subscription 1
[loggingSignal subscribeCompleted:^{
    NSLog(@"subscription %u", subscriptions);
}];

// Outputs:
// subscription 2
[loggingSignal subscribeCompleted:^{
    NSLog(@"subscription %u", subscriptions);
}];
```

This behavior can be changed using a [connection][Connections].

### Injecting effects

The [-do…][RACSignal+Operations] methods add side effects to a signal without actually
subscribing to it:

```objc
__block unsigned subscriptions = 0;

RACSignal *loggingSignal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
    subscriptions++;
    [subscriber sendCompleted];
    return nil;
}];

// Does not output anything yet
loggingSignal = [loggingSignal doCompleted:^{
    NSLog(@"about to complete subscription %u", subscriptions);
}];

// Outputs:
// about to complete subscription 1
// subscription 1
[loggingSignal subscribeCompleted:^{
    NSLog(@"subscription %u", subscriptions);
}];
```

## Transforming streams

These operators transform a single stream into a new stream.

### Mapping

The [-map:][RACStream] method is used to transform the values in a stream, and
create a new stream with the results:

```objc
RACSequence *letters = [@"A B C D E F G H I" componentsSeparatedByString:@" "].rac_sequence;

// Contains: AA BB CC DD EE FF GG HH II
RACSequence *mapped = [letters map:^(NSString *value) {
    return [value stringByAppendingString:value];
}];
```

### Filtering

The [-filter:][RACStream] method uses a block to test each value, including it
into the resulting stream only if the test passes:

```objc
RACSequence *numbers = [@"1 2 3 4 5 6 7 8 9" componentsSeparatedByString:@" "].rac_sequence;

// Contains: 2 4 6 8
RACSequence *filtered = [numbers filter:^ BOOL (NSString *value) {
    return (value.intValue % 2) == 0;
}];
```

## Combining streams

These operators combine multiple streams into a single new stream.

### Concatenating

The [-concat:][RACStream] method appends one stream's values to another:

```objc
RACSequence *letters = [@"A B C D E F G H I" componentsSeparatedByString:@" "].rac_sequence;
RACSequence *numbers = [@"1 2 3 4 5 6 7 8 9" componentsSeparatedByString:@" "].rac_sequence;

// Contains: A B C D E F G H I 1 2 3 4 5 6 7 8 9
RACSequence *concatenated = [letters concat:numbers];
```

### Flattening

The [-flatten][RACStream] operator is applied to a stream-of-streams, and
combines their values into a single new stream.

Sequences are [concatenated](#concatenating):

```objc
RACSequence *letters = [@"A B C D E F G H I" componentsSeparatedByString:@" "].rac_sequence;
RACSequence *numbers = [@"1 2 3 4 5 6 7 8 9" componentsSeparatedByString:@" "].rac_sequence;
RACSequence *sequenceOfSequences = @[ letters, numbers ].rac_sequence;

// Contains: A B C D E F G H I 1 2 3 4 5 6 7 8 9
RACSequence *flattened = [sequenceOfSequences flatten];
```

Signals are [merged](#merging):

```objc
RACSubject *letters = [RACSubject subject];
RACSubject *numbers = [RACSubject subject];
RACSignal *signalOfSignals = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
    [subscriber sendNext:letters];
    [subscriber sendNext:numbers];
    [subscriber sendCompleted];
    return nil;
}];

RACSignal *flattened = [signalOfSignals flatten];

// Outputs: A 1 B C 2
[flattened subscribeNext:^(NSString *x) {
    NSLog(@"%@", x);
}];

[letters sendNext:@"A"];
[numbers sendNext:@"1"];
[letters sendNext:@"B"];
[letters sendNext:@"C"];
[numbers sendNext:@"2"];
```

### Mapping and flattening

[Flattening](#flattening) isn't that interesting on its own, but understanding
how it works is important for [-flattenMap:][RACStream].

`-flattenMap:` is used to transform each of a stream's values into _a new
stream_. Then, all of the streams returned will be flattened down into a single
stream. In other words, it's [-map:](#mapping) followed by [-flatten](#flattening).

This can be used to extend or edit sequences:

```objc
RACSequence *numbers = [@"1 2 3 4 5 6 7 8 9" componentsSeparatedByString:@" "].rac_sequence;

// Contains: 1 1 2 2 3 3 4 4 5 5 6 6 7 7 8 8 9 9
RACSequence *extended = [numbers flattenMap:^(NSString *num) {
    return @[ num, num ].rac_sequence;
}];

// Contains: 1_ 3_ 5_ 7_ 9_
RACSequence *edited = [numbers flattenMap:^(NSString *num) {
    if (num.intValue % 2 == 0) {
        return [RACSequence empty];
    } else {
        NSString *newNum = [num stringByAppendingString:@"_"];
        return [RACSequence return:newNum]; 
    }
}];
```

Or create multiple signals of work which are automatically recombined:

```objc
RACSignal *letters = [@"A B C D E F G H I" componentsSeparatedByString:@" "].rac_sequence.signal;

[[letters
    flattenMap:^(NSString *letter) {
        return [database saveEntriesForLetter:letter];
    }]
    subscribeCompleted:^{
        NSLog(@"All database entries saved successfully.");
    }];
```

## Combining signals

These operators combine multiple signals into a single new [RACSignal][].

### Sequencing

[-then:][RACSignal+Operations] starts the original signal,
waits for it to complete, and then only forwards the values from a new signal:

```objc
RACSignal *letters = [@"A B C D E F G H I" componentsSeparatedByString:@" "].rac_sequence.signal;

// The new signal only contains: 1 2 3 4 5 6 7 8 9
//
// But when subscribed to, it also outputs: A B C D E F G H I
RACSignal *sequenced = [[letters
    doNext:^(NSString *letter) {
        NSLog(@"%@", letter);
    }]
    then:^{
        return [@"1 2 3 4 5 6 7 8 9" componentsSeparatedByString:@" "].rac_sequence.signal;
    }];
```

This is most useful for executing all the side effects of one signal, then
starting another, and only returning the second signal's values.

### Merging

The [+merge:][RACSignal+Operations] method will forward the values from many
signals into a single stream, as soon as those values arrive:

```objc
RACSubject *letters = [RACSubject subject];
RACSubject *numbers = [RACSubject subject];
RACSignal *merged = [RACSignal merge:@[ letters, numbers ]];

// Outputs: A 1 B C 2
[merged subscribeNext:^(NSString *x) {
    NSLog(@"%@", x);
}];

[letters sendNext:@"A"];
[numbers sendNext:@"1"];
[letters sendNext:@"B"];
[letters sendNext:@"C"];
[numbers sendNext:@"2"];
```

### Combining latest values

The [+combineLatest:][RACSignal+Operations] and `+combineLatest:reduce:` methods
will watch multiple signals for changes, and then send the latest values from
_all_ of them when a change occurs:

```objc
RACSubject *letters = [RACSubject subject];
RACSubject *numbers = [RACSubject subject];
RACSignal *combined = [RACSignal
    combineLatest:@[ letters, numbers ]
    reduce:^(NSString *letter, NSString *number) {
        return [letter stringByAppendingString:number];
    }];

// Outputs: B1 B2 C2 C3
[combined subscribeNext:^(id x) {
    NSLog(@"%@", x);
}];

[letters sendNext:@"A"];
[letters sendNext:@"B"];
[numbers sendNext:@"1"];
[numbers sendNext:@"2"];
[letters sendNext:@"C"];
[numbers sendNext:@"3"];
```

Note that the combined signal will only send its first value when all of the
inputs have sent at least one. In the example above, `@"A"` was never
forwarded because `numbers` had not sent a value yet.

### Switching

The [-switchToLatest][RACSignal+Operations] operator is applied to
a signal-of-signals, and always forwards the values from the latest signal:

```objc
RACSubject *letters = [RACSubject subject];
RACSubject *numbers = [RACSubject subject];
RACSubject *signalOfSignals = [RACSubject subject];

RACSignal *switched = [signalOfSignals switchToLatest];

// Outputs: A B 1 D
[switched subscribeNext:^(NSString *x) {
    NSLog(@"%@", x);
}];

[signalOfSignals sendNext:letters];
[letters sendNext:@"A"];
[letters sendNext:@"B"];

[signalOfSignals sendNext:numbers];
[letters sendNext:@"C"];
[numbers sendNext:@"1"];

[signalOfSignals sendNext:letters];
[numbers sendNext:@"2"];
[letters sendNext:@"D"];
```

[Connections]: FrameworkOverview.md#connections
[RACSequence]: ../ReactiveCocoa/RACSequence.h
[RACSignal]: ../ReactiveCocoa/RACSignal.h
[RACSignal+Operations]: ../ReactiveCocoa/RACSignal+Operations.h
[RACStream]: ../ReactiveCocoa/RACStream.h
[Sequences]: FrameworkOverview.md#sequences
[Signals]: FrameworkOverview.md#signals
[Streams]: FrameworkOverview.md#streams
[Subscription]: FrameworkOverview.md#subscription
