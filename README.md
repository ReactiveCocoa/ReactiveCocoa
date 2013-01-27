# ReactiveCocoa
ReactiveCocoa (RAC) is an Objective-C framework for [Functional Reactive Programming][]. It provides APIs for **composing and transforming streams of values**.

[Functional Reactive Programming]: http://en.wikipedia.org/wiki/Functional_reactive_programming

## Getting Started
RAC uses some submodules. Once you've cloned the repository, be sure to run `git submodule update --recursive --init` to pull them all down.

## Functional Reactive Programming
Functional Reactive Programming (FRP) is a programming paradigm for writing software that reacts to change.

FRP is built on the abstraction of values over time. Rather than capturing a value at a particular time, FRP provides signals that capture the past, present, and future value. These signals can be reasoned about, chained, composed, and reacted to.

By combining signals, software can be written declaratively, without the need for code that continually observes and updates values. A text field can be directly set to always show the current timestamp, for example, instead of using additional code that watches the clock and updates the text field every second.

Signals can also represent asynchronous operations, much like [futures and promises][]. This greatly simplifies asynchronous software, including networking code.

[futures and promises]: http://en.wikipedia.org/wiki/Futures_and_promises

One of the major advantages of FRP is that it provides a single, unified approach to dealing with different types of reactive, asynchronous behaviors.

Resources for learning more about FRP:

* [What is FRP? - Elm Language](http://elm-lang.org/learn/What-is-FRP.elm)
* [What is Functional Reactive Programming - Stack Overflow](http://stackoverflow.com/questions/1028250/what-is-functional-reactive-programming/1030631#1030631)

## FRP with ReactiveCocoa
ReactiveCocoa (RAC) provides `RACSignal`, which represents the signal concept from Functional Reactive Programming that was introduced above. Signals are streams of values that can be observed.

Applications that are built with RAC use signals to propagate change. It works much like KVO, but using blocks instead of overriding `-observeValueForKeyPath:ofObject:change:context:`. Here's a simple example:
```objc
// When self.username changes, log the new name to the console.
// RACAble(self.username) creates a new RACSignal that sends
// a new value whenever the username changes.
[RACAble(self.username) subscribeNext:^(NSString *newName) {
    NSLog(@"%@", newName);
}];
```

But unlike KVO notifications, signals can be chained together and operated on:
```objc
// Only log names that start with "j".
// -filter returns a new RACSignal that only sends a new
// value when its block returns YES.
[[RACAble(self.username)
  filter:^(NSString *newName) {
      return [newUsername hasPrefix:@"j"];
  }]
  subscribeNext:^(NSString *newName) {
      NSLog(@"%@", newName);
  }];
```

Unlike KVO, Signals aren't limited to notifications that a property has changed. They can represent button presses:
```objc
// Log a message whenever the button is pressed.
// RACCommand is a RACSignal subclass that makes it easy to
// write custom signals. -rac_command is an addition to
// NSButton; the button will send itself on that command 
// whenever it's pressed.
self.button.rac_command = [RACCommand command];
[self.button.rac_command subscribeNext:^(id _) {
    NSLog(@"button was pressed!");
}];
```

Or asynchronous network operations:
```objc
// Hook up a "Log in" button to log in over the network and
// log a message when it was successful.
// self.loginCommand does the actual work of logging in.
// self.loginResult sends a value whenever the async work is done.
self.loginCommand = [RACAsyncCommand command];
self.loginResult  = [[[self.loginCommand 
    addAsyncBlock:^(id _) {
        // returns YES when logging in was successful
        return [client login];
    }]
    asMaybes] // Wrap up errors so they don't close the signal
    repeat];  // Continue listening to the loginCommand after failures
[[self.loginResult 
    // Filter out failed login attempts
    filter:^(id x) { return [x hasObject]; }]
    subscribeNext:^(id _) {
        NSLog(@"Logged in successfully!");
    }];
// Execute the login command when the button is pressed
self.loginButton.rac_command = self.loginCommand;
```

Or UI events, timers, or anything else that changes over time.

That demonstrates some of what RAC can do, but it doesn't demonstrate why RAC is so powerful. It's hard to appreciate RAC from README-sized examples, but it makes it possible to write code with less state, less boilerplate, better code locality, and better expression of intent.

For more information, check out the other examples below or the [Mac][GHAPIDemo] or [iOS][RACiOSDemo] demos.

[GHAPIDemo]: https://github.com/github/ReactiveCocoa/tree/master/GHAPIDemo
[RACiOSDemo]: https://github.com/github/ReactiveCocoa/tree/master/RACiOSDemo

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

You can find them in [RACExtensions][]. To use them, simply add them directly to your project as needed.

[RACExtensions]: https://github.com/github/ReactiveCocoa/tree/master/RACExtensions

## License
ReactiveCocoa is available under the MIT License.

## More Info
ReactiveCocoa is based on .NET's [Reactive Extensions][] (Rx). Most of the principles of Rx apply to RAC as well. There are some really good Rx resources out there:

* [Reactive Extensions MSDN entry](http://msdn.microsoft.com/en-us/library/hh242985.aspx)
* [Reactive Extensions for .NET Introduction](http://leecampbell.blogspot.com/2010/08/reactive-extensions-for-net.html)
* [Rx - Channel 9 videos](http://channel9.msdn.com/tags/Rx/)
* [Reactive Extensions wiki](http://rxwiki.wikidot.com/)
* [101 Rx Samples](http://rxwiki.wikidot.com/101samples)
* [Programming Reactive Extensions and LINQ](http://www.amazon.com/Programming-Reactive-Extensions-Jesse-Liberty/dp/1430237473)

[Reactive Extensions]: http://msdn.microsoft.com/en-us/data/gg577609
