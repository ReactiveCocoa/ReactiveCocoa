# Basic operators

This post may be useful if you cannot immediately understand all the magic behind operators like `-flattenMap:` and `+merge:`. Example by example, we will overview the most popular functions in RAC.

## Sample Signals

To explain all basic methods we will need two streams of values. Here they are:

```objective-c
NSArray *letters = [@"A B C D E F G H I" componentsSeparatedByString:@" "];
NSArray *numbers = [@"1 2 3 4 5 6 7 8 9" componentsSeparatedByString:@" "];

RACSignal *letterSignal = letters.rac_sequence.signal;
RACSignal *numberSignal = numbers.rac_sequence.signal;
```

To iterate through the values in any stream we can use code like this:

```objective-c
// Output: A B C D E F G H I
//
[letters subscribeNext:^(NSString *x) {
    NSLog(@"%@", x);
}];
```

## Linear operators

This group of operators is used to merge and transform linear streams of values.

### Map

The `-map:` method is used to transform the values in a stream, and create a new stream with the results:

```objective-c
RACSignal *mapSignal = [letterSignal map:^NSString *(NSString *value) {
    return [value stringByAppendingString:value];
}];

// Output: AA BB CC DD EE FF GG HH II
//
[mapSignal subscribeNext:^(NSString *x) {
    NSLog(@"%@", x);
}];
```

### Merge

The `+merge:` method will forward the values from many streams into the single stream as soon as those values arrive:

```objective-c
RACSubject *letterSubject = [RACSubject subject];
RACSubject *numberSubject = [RACSubject subject];
RACSignal *mergedSubjects = [RACSignal merge:@[ letterSubject, numberSubject ]];

// Output: A 1 B C 2
//
[mergedSubjects subscribeNext:^(NSString *x) {
    NSLog(@"%@", x);
}];

[letterSubject sendNext:@"A"];
[numberSubject sendNext:@"1"];
[letterSubject sendNext:@"B"];
[letterSubject sendNext:@"C"];
[numberSubject sendNext:@"2"];
```

### Filter

The `-filter:` method uses a block to test each value and only then forwards it into resulting stream:

```objective-c
RACSignal *filterSignal = [numberSignal filter:^BOOL(NSString *value) {
    return (value.intValue % 2) == 0;
}];

// Output: 0 2 4 6 8
//
[filterSignal subscribeNext:^(NSString *x) {
    NSLog(@"%@", x);
}];
```

### Concat

The `-concat:` method allows to combine many streams into one while preserving the order:

```objective-c
RACSignal *concatSignal = [RACSignal concat:@[ letterSignal, numberSignal ]];

// Output: A B C D E F G H I 1 2 3 4 5 6 7 8 9
//
[concatSignal subscribeNext:^(NSString *x) {
    NSLog(@"%@", x);
}];
```

## Signal of Signals

In some cases, you have to handle a signal of multiple signals:

```objective-c
NSArray *signals = @[ letterSignal, numberSignal ];
RACSignal *signalsSignal = signals.rac_sequence.signal;
```

ReactiveCocoa has more advanced operators to help with this.

### Flatten

The `-flatten:` operator will forward all values from many signals into the new flattened signal:

```objective-c
RACSignal *flattenSignal = [signalsSignal flatten];

// Output 1: 1 A 2 3 B 4 C 5 6 D 7 E 8 9 F G H I
// Output 2: 1 2 A B C 3 4 5 D 6 E 7 8 F G H I 9
// ...
//
[flattenSignal subscribeNext:^(NSString *x) {
    NSLog(@"%@", x);
}];
```

Another way to think of this is that `-flatten` behaves like `+merge:` over all of the inside streams.

### Flatten Map

The method `-flattenMap:` is a shortcut for `-map:` followed by `-flatten`. It can be used on any stream. The key is that the block has to return a new stream, usually based on the input value, and all of those results will be flattened:

```objective-c
// Output with one second delay: A... B... C... D... E... F... G... H... I...
//
NSTimeInterval __block delay = 0.0;
[[letterSignal flattenMap:^RACStream *(NSString *letter) {
    delay += 1.0;
    return [[RACSignal return:letter] delay:delay];
}] subscribeNext:^(NSString *letter) {
    NSLog(@"%@", letter);
}];
```

### Combine Latest

With help of the method `+combineLatest:` you can keep track of the latest changes in the number of streams:

```objective-c
RACSubject *letterSubject = [RACSubject subject];
RACSubject *numberSubject = [RACSubject subject];
RACSignal *combineSignal = [RACSignal combineLatest:@[ letterSubject, numberSubject ]];

// Output: A1 B1 C1 C2
//
[combineSignal subscribeNext:^(RACTuple *tuple) {
    NSLog(@"%@", [tuple.allObjects componentsJoinedByString:@""]);
}];

[letterSubject sendNext:@"A"];
[numberSubject sendNext:@"1"];
[letterSubject sendNext:@"B"];
[letterSubject sendNext:@"C"];
[numberSubject sendNext:@"2"];
```

Please note that the signal returned from `+combineLatest:` will only send its first value once all of the inputs have sent at least once, and then will send again whenever any of the inputs send a new value.

### Combine Reduce

```objective-c
RACSubject *letterSubject = [RACSubject subject];
RACSubject *numberSubject = [RACSubject subject];
RACSignal *combineSignal = [RACSignal combineLatest:@[ letterSubject, numberSubject ]
                                             reduce:^(NSString *letter, NSString *number) {
                                                 return [letter stringByAppendingString:number];
                                             }];
// Output: A1 B1 C1 C2
//
[combineSignal subscribeNext:^(id x) {
    NSLog(@"%@", x);
}];

[letterSubject sendNext:@"A"];
[numberSubject sendNext:@"1"];
[letterSubject sendNext:@"B"];
[letterSubject sendNext:@"C"];
[numberSubject sendNext:@"2"];
```

Basically this is just a syntactic sugar for `-combineLatest:` followed by the smarter `-map:`. You can pass a block to combine multiple values into the single one.
