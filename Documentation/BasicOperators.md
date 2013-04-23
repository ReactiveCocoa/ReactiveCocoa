# Basic operators

This post may be useful if you cannot immediately understand all the magic behind operators like `flattenMap:` and `merge:`. Example by example, we will overview the most popular functions in RAC.

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

The first group of operators is used to merge and transform linear streams of values.

### Merge

```objective-c
RACSignal *mergeSignal = [RACSignal merge:@[ letterSignal, numberSignal ]];

// Output 1: A 1 2 B 3 C 4 5 D 6 7 E 8 9 F G H I
// Output 2: A 1 B 2 3 C 4 D E 5 F 6 7 G 8 H I 9
// ...
//
[mergeSignal subscribeNext:^(NSString *x) {
    NSLog(@"%@", x);
}];
```

As you can see, `merge:` “redirects” values from many streams into the single stream. Please note that the order of values in the merged stream is totally unpredictable. Here is another example of `merge:` in action:

```objective-c
RACSubject *letterStream = [RACSubject subject];
RACSubject *numberStream = [RACSubject subject];
RACSignal *mergedStream = [RACSignal merge:@[ letterStream, numberStream ]];

// Output: A 1 B C 2
//
[mergedStream subscribeNext:^(NSString *x) {
    NSLog(@"%@", x);
}];

[letterStream sendNext:@"A"];
[numberStream sendNext:@"1"];
[letterStream sendNext:@"B"];
[letterStream sendNext:@"C"];
[numberStream sendNext:@"2"];
```

### Map

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

The method `map:` is used to transform stream values and “redirect” them to another stream.

### Filter

```objective-c
RACSignal *filterSignal = [letterSignal filter:^BOOL(NSString *value) {
    return ![value isEqualToString:@"A"];
}];

// Output: B C D E F G H I
//
[filterSignal subscribeNext:^(NSString *x) {
    NSLog(@"%@", x);
}];
```

The `filter:` method uses a block to test each value and only then “redirect” it to another stream.

### Concat

```objective-c
RACSignal *concatSignal = [RACSignal concat:@[ letterSignal, numberSignal ]];

// Output: A B C D E F G H I 1 2 3 4 5 6 7 8 9
//
[concatSignal subscribeNext:^(NSString *x) {
    NSLog(@"%@", x);
}];
```

The method `concat:` allows to combine many streams into one while preserving the order.

## Stream of Streams

In some cases, you have to deal with a signal of signals:

```objective-c
NSArray *signals = @[ letterSignal, numberSignal ];
RACSignal *signalsSignal = signals.rac_sequence.signal;
```

ReactiveCocoa has more advanced operators for this.

### Flatten

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

The `flatten` operator will “redirect” all values from many streams into the new “flattened” stream.

### Flatten Map

```objective-c
RACSignal *flattenMapSignal = [signalsSignal flattenMap:^RACStream *(RACStream *s) {
    return [s map:^NSString *(NSString *value) {
        return [value stringByAppendingString:value];
    }];
}];

// Output 1: 11 22 AA BB CC 33 44 55 DD 66 EE 77 88 FF GG HH II 99
// Output 2: 11 AA 22 33 BB 44 CC 55 66 DD 77 EE 88 99 FF GG HH II
// ...
//
[flattenMapSignal subscribeNext:^(NSString *x) {
    NSLog(@"%@", x);
}];
```

The method `flattenMap:` allows to transform values passed from the “flattened” stream. Consider it a shorthand for `-map:` followed by `-flatten`.

### Combine Latest

```objective-c
RACSignal *combineSignal = [RACSignal combineLatest:@[ letterSignal, numberSignal ]];

// Output 1: A7 A8 B8 B9 C9 D9 E9 F9 G9 H9 I9
// Output 2: A4 A5 A6 B6 B7 C7 C8 C9 D9 E9 F9 G9 H9 I9
// …
[combineSignal subscribeNext:^(RACTuple *tuple) {
    NSLog(@"%@", [tuple.allObjects componentsJoinedByString:@""]);
}];
```

With help of the function `combineLatest:` you can keep track of the latest changes in the number of streams.

### Combine Reduce

```objective-c
RACSignal *combineReduceSignal = [RACSignal combineLatest:@[ letterSignal, numberSignal ] reduce:^(NSString *letter, NSString *number) {
    return [letter stringByAppendingString:number];
}];

// Output 1: A3 A4 B4 B5 C5 C6 D6 D7 E7 E8 E9 F9 G9 H9 I9
// Output 2: A4 A5 B5 B6 C6 C7 C8 D8 D9 E9 F9 G9 H9 I9
// …
[combineReduceSignal subscribeNext:^(NSString *x) {
    NSLog(@"%@", x);
}];
```

Functionally this is just a syntactic sugar for `-combineLatest:` followed by `-map:`. However, it is `combineLatest:reduce:` that you use most of the time.
