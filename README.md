# ReactiveCocoa
ReactiveCocoa (RAC) is a framework for **composing and transforming streams of values**.

## No seriously, what is it?
Check out the [announcement blog post](https://github.com/blog/1107-reactivecocoa-is-now-open-source) for a ton more info.

## Getting Started
RAC uses some submodules. Once you've cloned the repository, be sure to run `git submodule update --recursive --init` to pull them all down.

Then checkout the [Mac](https://github.com/github/ReactiveCocoa/tree/master/GHAPIDemo) or [iOS](https://github.com/github/ReactiveCocoa/tree/master/RACiOSDemo) demos.

## Examples
Observe changes to properties:
```objc
[RACAble(self.username) subscribeNext:^(NSString *newName) {
    NSLog(@"%@", newName);
}];
```

Filter changes:
```objc
[[[[RACAble(self.username) 
    distinctUntilChanged] 
    take:3] 
    filter:^(NSString *newUsername) {
        return [newUsername isEqualToString:@"joshaber"];
    }] 
    subscribeNext:^(id _) {
        NSLog(@"Hi me!");
    }];
```

Derive properties:
```objc
RAC(self.createEnabled) = [RACSignal 
    combineLatest:@[ RACAble(self.password), RACAble(self.passwordConfirmation) ] 
    reduce:^(NSString *password, NSString *passwordConfirm) {
        return @([passwordConfirm isEqualToString:password]);
    }];
```

Chain asynchronous calls:
```objc
[[RACSignal 
    flatten:@[ [client fetchUserRepos], [client fetchOrgRepos] ]] 
    subscribeCompleted:^{
        NSLog(@"They're both done!");
    }];
```

```objc
[[[[client 
    loginUser] 
    flattenMap:^(User *user) {
        return [client loadCachedMessagesForUser:user];
    }]
    flattenMap:^(NSArray *messages) {
        return [client fetchMessagesAfterMessage:messages.lastObject];
    }]
    subscribeCompleted:^{
        NSLog(@"Fetched all messages.");
    }];
```

Easily move between different queues:
```objc
RAC(self.imageView.image) = [[[[client 
    fetchUserWithUsername:@"joshaber"] 
    deliverOn:[RACScheduler scheduler]]
    map:^(User *user) {
        // This is on a background queue.
        return [[NSImage alloc] initWithContentsOfURL:user.avatarURL];
    }]
    // Now the assignment will be done on the main thread.
    deliverOn:RACScheduler.mainThreadScheduler]
```

## Foundation Support
There are a number of categories that provide RAC-based bridges to standard Foundation classes. They're not included as part of the framework proper in order to keep the framework size down.

You can find them in [RACExtensions](https://github.com/github/ReactiveCocoa/tree/master/RACExtensions). To use them, simply add them directly to your project as needed.

## License
MIT License
