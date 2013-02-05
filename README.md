# ReactiveCocoa
ReactiveCocoa (RAC) is a framework for **composing and transforming streams of values**.

## No seriously, what is it?
Check out the [announcement blog post](https://github.com/blog/1107-reactivecocoa-is-now-open-source) for a ton more info.

## Getting Started
RAC uses some submodules. Once you've cloned the repository, be sure to run `git
submodule update --recursive --init` to pull them all down.

To add RAC to your application:

 1. Add the ReactiveCocoa repository as a submodule of your application's
    repository.
 1. Drag and drop `ReactiveCocoaFramework/ReactiveCocoa.xcodeproj` into your
    application's Xcode project or workspace.
 1. On the "Build Phases" tab of your application target, add RAC to the "Link
    Binary With Libraries" phase.
    * **On iOS**, add `libReactiveCocoa-iOS.a`.
    * **On OS X**, add `ReactiveCocoa.framework`. RAC must also be added to any
      "Copy Frameworks" build phase. If you don't already have one, simply add
      a "Copy Files" build phase and target the "Frameworks" destination.
 1. **If you added RAC to a project (not a workspace)**, you will also need to
    add the appropriate RAC target to the "Target Dependencies" of your
    application.

If you would prefer to use [CocoaPods](http://cocoapods.org), there are some
[ReactiveCocoa
podspecs](https://github.com/CocoaPods/Specs/tree/master/ReactiveCocoa) that
have been generously contributed by third parties.

To see a project already set up with RAC, check out the
[Mac](https://github.com/ReactiveCocoa/GHAPIDemo) or
[iOS](https://github.com/ReactiveCocoa/RACiOSDemo) demos.

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
    merge:@[ [client fetchUserRepos], [client fetchOrgRepos] ]] 
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

You can find them in [RACExtensions](https://github.com/ReactiveCocoa/ReactiveCocoa/tree/master/RACExtensions). To use them, simply add them directly to your project as needed.

## License
MIT License
