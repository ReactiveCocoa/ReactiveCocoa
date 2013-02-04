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

    [[self.logInButton rac_signalForControlEvents:UIControlEventTouchUpInside]
        flattenMap:^(UIButton *sender) {
            RACSignal *loginSignal = [[LoginManager sharedManager]
                logInWithUsername:self.usernameTextField.text
                password:self.passwordTextField.text];

            return [[loginSignal
                doCompleted:^{
                    @strongify(self);
                    self.loggedIn = YES;
                }]
                catch:^(NSError *error) {
                    @strongify(self);
                    [self presentError:error];
                }];
        }];
}
```

### Chaining dependent operations

Dependencies are most often found in network requests, where you need a previous
request to the server to complete before you can construct the next one, and so
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

[RACSignal
    combineLatest:@[ databaseSignal, fileSignal ]
    reduce:^(NSArray *databaseObjects, NSArray *fileContents) {
        [self finishProcessingDatabaseObjects:databaseObjects fileContents:fileContents];
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
### Evaluation occurs lazily by default
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
### Use the same type for all the values of a stream
### Avoid retaining streams and disposables directly
### Process only as much of a stream as you need
### Deliver signal results onto a known scheduler
### Switch schedulers in as few places as possible
### Make side effects explicit
### Share the side effects of a signal by multicasting
### Debug streams by giving them names

## Implementing new operators
### Prefer building on RACStream methods
### Compose existing operators when possible
### Avoid introducing concurrency
### Cancel work and clean up all resources in a disposable
### Do not block in an operator
### Avoid stack overflow from deep recursion

[Memory Management]: MemoryManagement.md
[RACDisposable]: ../ReactiveCocoaFramework/ReactiveCocoa/RACDisposable.h
[RACEvent]: ../ReactiveCocoaFramework/ReactiveCocoa/RACEvent.h
[RACScheduler]: ../ReactiveCocoaFramework/ReactiveCocoa/RACScheduler.h
[RACSequence]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSequence.h
[RACSignal]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSignal.h
[RACSignal+Operations]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSignal+Operations.h
