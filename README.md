# ReactiveCocoa

ReactiveCocoa (RAC) is an Objective-C framework inspired by [Functional Reactive
Programming][]. It provides APIs for **composing and transforming streams of
values**.

If you're already familiar with functional reactive programming or know the basic
premise of ReactiveCocoa, check out the [Documentation][] folder for a framework
overview and more in-depth information about how it all works in practice.

## New to ReactiveCocoa?

ReactiveCocoa is documented like crazy, and there's a wealth of introductory
material available to explain what RAC is and how you can use it.

If you want to learn more, we recommend these resources, roughly in order:

 1. [Introduction](#introduction)
 1. [When to use ReactiveCocoa](#when-to-use-reactivecocoa)
 1. [Framework Overview][]
 1. [Basic Operators][]
 1. [Header documentation](ReactiveCocoa)
 1. Previously answered [Stack Overflow](https://github.com/ReactiveCocoa/ReactiveCocoa/wiki)
    questions and [GitHub issues](https://github.com/ReactiveCocoa/ReactiveCocoa/issues?labels=question&state=closed)
 1. The rest of the [Documentation][] folder
 1. [Functional Reactive Programming on iOS](https://leanpub.com/iosfrp/) 
    (eBook)
 
If you have any further questions, please feel free to [file an issue](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/new). 

## Introduction

ReactiveCocoa is inspired by [functional reactive
programming](http://blog.maybeapps.com/post/42894317939/input-and-output).
Rather than using mutable variables which are replaced and modified in-place,
RAC provides signals (represented by `RACSignal`) that capture present and
future values.

By chaining, combining, and reacting to signals, software can be written
declaratively, without the need for code that continually observes and updates
values.

For example, a text field can be bound to the latest time, even as it changes,
instead of using additional code that watches the clock and updates the
text field every second.  It works much like KVO, but with blocks instead of
overriding `-observeValueForKeyPath:ofObject:change:context:`.

Signals can also represent asynchronous operations, much like [futures and
promises][]. This greatly simplifies asynchronous software, including networking
code.

One of the major advantages of RAC is that it provides a single, unified
approach to dealing with asynchronous behaviors, including delegate methods,
callback blocks, target-action mechanisms, notifications, and KVO.

Here's a simple example:

```objc
// When self.username changes, logs the new name to the console.
//
// RACObserve(self, username) creates a new RACSignal that sends the current
// value of self.username, then the new value whenever it changes.
// -subscribeNext: will execute the block whenever the signal sends a value.
[RACObserve(self, username) subscribeNext:^(NSString *newName) {
	NSLog(@"%@", newName);
}];
```

But unlike KVO notifications, signals can be chained together and operated on:

```objc
// Only logs names that starts with "j".
//
// -filter returns a new RACSignal that only sends a new value when its block
// returns YES.
[[RACObserve(self, username)
	filter:^(NSString *newName) {
		return [newName hasPrefix:@"j"];
	}]
	subscribeNext:^(NSString *newName) {
		NSLog(@"%@", newName);
	}];
```

Signals can also be used to derive state. Instead of observing properties and
setting other properties in response to the new values, RAC makes it possible to
express properties in terms of signals and operations:

```objc
// Creates a one-way binding so that self.createEnabled will be
// true whenever self.password and self.passwordConfirmation
// are equal.
//
// RAC() is a macro that makes the binding look nicer.
// 
// +combineLatest:reduce: takes an array of signals, executes the block with the
// latest value from each signal whenever any of them changes, and returns a new
// RACSignal that sends the return value of that block as values.
RAC(self, createEnabled) = [RACSignal 
	combineLatest:@[ RACObserve(self, password), RACObserve(self, passwordConfirmation) ] 
	reduce:^(NSString *password, NSString *passwordConfirm) {
		return @([passwordConfirm isEqualToString:password]);
	}];
```

Signals can be built on any stream of values over time, not just KVO. For
example, they can also represent button presses:

```objc
// Logs a message whenever the button is pressed.
//
// RACCommand creates signals to represent UI actions. Each signal can
// represent a button press, for example, and have additional work associated
// with it.
//
// -rac_command is an addition to NSButton. The button will send itself on that
// command whenever it's pressed.
self.button.rac_command = [[RACCommand alloc] initWithSignalBlock:^(id _) {
	NSLog(@"button was pressed!");
	return [RACSignal empty];
}];
```

Or asynchronous network operations:

```objc
// Hooks up a "Log in" button to log in over the network.
//
// This block will be run whenever the login command is executed, starting
// the login process.
self.loginCommand = [[RACCommand alloc] initWithSignalBlock:^(id sender) {
	// The hypothetical -logIn method returns a signal that sends a value when
	// the network request finishes.
	return [client logIn];
}];

// -executionSignals returns a signal that includes the signals returned from
// the above block, one for each time the command is executed.
[self.loginCommand.executionSignals subscribeNext:^(RACSignal *loginSignal) {
	// Log a message whenever we log in successfully.
	[loginSignal subscribeCompleted:^{
		NSLog(@"Logged in successfully!");
	}];
}];

// Executes the login command when the button is pressed.
self.loginButton.rac_command = self.loginCommand;
```

Signals can also represent timers, other UI events, or anything else that
changes over time.

Using signals for asynchronous operations makes it possible to build up more
complex behavior by chaining and transforming those signals. Work can easily be
triggered after a group of operations completes:

```objc
// Performs 2 network operations and logs a message to the console when they are
// both completed.
//
// +merge: takes an array of signals and returns a new RACSignal that passes
// through the values of all of the signals and completes when all of the
// signals complete.
//
// -subscribeCompleted: will execute the block when the signal completes.
[[RACSignal 
	merge:@[ [client fetchUserRepos], [client fetchOrgRepos] ]] 
	subscribeCompleted:^{
		NSLog(@"They're both done!");
	}];
```

Signals can be chained to sequentially execute asynchronous operations, instead
of nesting callbacks with blocks. This is similar to how [futures and promises][]
are usually used:

```objc
// Logs in the user, then loads any cached messages, then fetches the remaining
// messages from the server. After that's all done, logs a message to the
// console.
//
// The hypothetical -logInUser methods returns a signal that completes after
// logging in.
//
// -flattenMap: will execute its block whenever the signal sends a value, and
// returns a new RACSignal that merges all of the signals returned from the block
// into a single signal.
[[[[client 
	logInUser] 
	flattenMap:^(User *user) {
		// Return a signal that loads cached messages for the user.
		return [client loadCachedMessagesForUser:user];
	}]
	flattenMap:^(NSArray *messages) {
		// Return a signal that fetches any remaining messages.
		return [client fetchMessagesAfterMessage:messages.lastObject];
	}]
	subscribeNext:^(NSArray *newMessages) {
		NSLog(@"New messages: %@", newMessages);
	} completed:^{
		NSLog(@"Fetched all messages.");
	}];
```

RAC even makes it easy to bind to the result of an asynchronous operation:

```objc
// Creates a one-way binding so that self.imageView.image will be set the user's
// avatar as soon as it's downloaded.
//
// The hypothetical -fetchUserWithUsername: method returns a signal which sends
// the user.
//
// -deliverOn: creates new signals that will do their work on other queues. In
// this example, it's used to move work to a background queue and then back to the main thread.
//
// -map: calls its block with each user that's fetched and returns a new
// RACSignal that sends values returned from the block.
RAC(self.imageView, image) = [[[[client 
	fetchUserWithUsername:@"joshaber"]
	deliverOn:[RACScheduler scheduler]]
	map:^(User *user) {
		// Download the avatar (this is done on a background queue).
		return [[NSImage alloc] initWithContentsOfURL:user.avatarURL];
	}]
	// Now the assignment will be done on the main thread.
	deliverOn:RACScheduler.mainThreadScheduler];
```

That demonstrates some of what RAC can do, but it doesn't demonstrate why RAC is
so powerful. It's hard to appreciate RAC from README-sized examples, but it
makes it possible to write code with less state, less boilerplate, better code
locality, and better expression of intent.

For more sample code, check out [C-41][] or [GroceryList][], which are real iOS
apps written using ReactiveCocoa. Additional information about RAC can be found
in the [Documentation][] folder.

## When to use ReactiveCocoa

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

For example, the following code:

```objc

static void *ObservationContext = &ObservationContext;

- (void)viewDidLoad {
	[super viewDidLoad];

	[LoginManager.sharedManager addObserver:self forKeyPath:@"loggingIn" options:NSKeyValueObservingOptionInitial context:&ObservationContext];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(loggedOut:) name:UserDidLogOutNotification object:LoginManager.sharedManager];

	[self.usernameTextField addTarget:self action:@selector(updateLogInButton) forControlEvents:UIControlEventEditingChanged];
	[self.passwordTextField addTarget:self action:@selector(updateLogInButton) forControlEvents:UIControlEventEditingChanged];
	[self.logInButton addTarget:self action:@selector(logInPressed:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)dealloc {
	[LoginManager.sharedManager removeObserver:self forKeyPath:@"loggingIn" context:ObservationContext];
	[NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)updateLogInButton {
	BOOL textFieldsNonEmpty = self.usernameTextField.text.length > 0 && self.passwordTextField.text.length > 0;
	BOOL readyToLogIn = !LoginManager.sharedManager.isLoggingIn && !self.loggedIn;
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
	if (context == ObservationContext) {
		[self updateLogInButton];
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}
```

… could be expressed in RAC like so:

```objc
- (void)viewDidLoad {
	[super viewDidLoad];

	@weakify(self);

	RAC(self.logInButton, enabled) = [RACSignal
		combineLatest:@[
			self.usernameTextField.rac_textSignal,
			self.passwordTextField.rac_textSignal,
			RACObserve(LoginManager.sharedManager, loggingIn),
			RACObserve(self, loggedIn)
		] reduce:^(NSString *username, NSString *password, NSNumber *loggingIn, NSNumber *loggedIn) {
			return @(username.length > 0 && password.length > 0 && !loggingIn.boolValue && !loggedIn.boolValue);
		}];

	[[self.logInButton rac_signalForControlEvents:UIControlEventTouchUpInside] subscribeNext:^(UIButton *sender) {
		@strongify(self);

		RACSignal *loginSignal = [LoginManager.sharedManager
			logInWithUsername:self.usernameTextField.text
			password:self.passwordTextField.text];

			[loginSignal subscribeError:^(NSError *error) {
				@strongify(self);
				[self presentError:error];
			} completed:^{
				@strongify(self);
				self.loggedIn = YES;
			}];
	}];

	RAC(self, loggedIn) = [[NSNotificationCenter.defaultCenter
		rac_addObserverForName:UserDidLogOutNotification object:nil]
		mapReplace:@NO];
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
	then:^{
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
 
NSOperationQueue *backgroundQueue = [[NSOperationQueue alloc] init];
NSBlockOperation *databaseOperation = [NSBlockOperation blockOperationWithBlock:^{
	databaseObjects = [databaseClient fetchObjectsMatchingPredicate:predicate];
}];

NSBlockOperation *filesOperation = [NSBlockOperation blockOperationWithBlock:^{
	NSMutableArray *filesInProgress = [NSMutableArray array];
	for (NSString *path in files) {
		[filesInProgress addObject:[NSData dataWithContentsOfFile:path]];
	}

	fileContents = [filesInProgress copy];
}];
 
NSBlockOperation *finishOperation = [NSBlockOperation blockOperationWithBlock:^{
	[self finishProcessingDatabaseObjects:databaseObjects fileContents:fileContents];
	NSLog(@"Done processing");
}];
 
[finishOperation addDependency:databaseOperation];
[finishOperation addDependency:filesOperation];
[backgroundQueue addOperation:databaseOperation];
[backgroundQueue addOperation:filesOperation];
[backgroundQueue addOperation:finishOperation];
```

The above code can be cleaned up and optimized by simply composing signals:

```objc
RACSignal *databaseSignal = [[databaseClient
	fetchObjectsMatchingPredicate:predicate]
	subscribeOn:[RACScheduler scheduler]];

RACSignal *fileSignal = [RACSignal startEagerlyWithScheduler:[RACScheduler scheduler] block:^(id<RACSubscriber> subscriber) {
	NSMutableArray *filesInProgress = [NSMutableArray array];
	for (NSString *path in files) {
		[filesInProgress addObject:[NSData dataWithContentsOfFile:path]];
	}

	[subscriber sendNext:[filesInProgress copy]];
	[subscriber sendCompleted];
}];

[[RACSignal
	combineLatest:@[ databaseSignal, fileSignal ]
	reduce:^ id (NSArray *databaseObjects, NSArray *fileContents) {
		[self finishProcessingDatabaseObjects:databaseObjects fileContents:fileContents];
		return nil;
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

## System Requirements

ReactiveCocoa supports OS X 10.8+ and iOS 8.0+.

## Importing ReactiveCocoa

To add RAC to your application:

 1. Add the ReactiveCocoa repository as a submodule of your application's
    repository.
 1. Run `script/bootstrap` from within the ReactiveCocoa folder.
 1. Drag and drop `ReactiveCocoa.xcodeproj` into your
    application's Xcode project or workspace.
 1. On the "Build Phases" tab of your application target, add RAC to the "Link
    Binary With Libraries" phase.
    * **On iOS**, add `libReactiveCocoa-iOS.a`.
    * **On OS X**, add `ReactiveCocoa.framework`. RAC must also be added to any
      "Copy Frameworks" build phase. If you don't already have one, simply add
      a "Copy Files" build phase and target the "Frameworks" destination.
 1. Add `"$(BUILD_ROOT)/../IntermediateBuildFilesPath/UninstalledProducts/include"
    $(inherited)` to the "Header Search Paths" build setting (this is only
    necessary for archive builds, but it has no negative effect otherwise).
 1. **For iOS targets**, add `-ObjC` to the "Other Linker Flags" build setting.
 1. **If you added RAC to a project (not a workspace)**, you will also need to
    add the appropriate RAC target to the "Target Dependencies" of your
    application.

If you would prefer to use [CocoaPods](http://cocoapods.org), there are some
[ReactiveCocoa
podspecs](https://github.com/CocoaPods/Specs/tree/master/Specs/ReactiveCocoa) that
have been generously contributed by third parties.

To see a project already set up with RAC, check out [C-41][] or [GroceryList][],
which are real iOS apps written using ReactiveCocoa.

## Standalone Development

If you’re working on RAC in isolation instead of integrating it into another project, you’ll want to open `ReactiveCocoa.xcworkspace` and not the `.xcodeproj`.

## More Info

ReactiveCocoa is based on .NET's [Reactive
Extensions](http://msdn.microsoft.com/en-us/data/gg577609) (Rx). Most of the
principles of Rx apply to RAC as well. There are some really good Rx resources
out there:

* [Reactive Extensions MSDN entry](http://msdn.microsoft.com/en-us/library/hh242985.aspx)
* [Reactive Extensions for .NET Introduction](http://leecampbell.blogspot.com/2010/08/reactive-extensions-for-net.html)
* [Rx - Channel 9 videos](http://channel9.msdn.com/tags/Rx/)
* [Reactive Extensions wiki](http://rxwiki.wikidot.com/)
* [101 Rx Samples](http://rxwiki.wikidot.com/101samples)
* [Programming Reactive Extensions and LINQ](http://www.amazon.com/Programming-Reactive-Extensions-Jesse-Liberty/dp/1430237473)

RAC and Rx are both frameworks inspired by functional reactive programming. Here 
are some resources related to FRP:

* [What is FRP? - Elm Language](http://elm-lang.org/learn/What-is-FRP.elm)
* [What is Functional Reactive Programming - Stack Overflow](http://stackoverflow.com/questions/1028250/what-is-functional-reactive-programming/1030631#1030631)
* [Specification for a Functional Reactive Language - Stack Overflow](http://stackoverflow.com/questions/5875929/specification-for-a-functional-reactive-programming-language#5878525)
* [Escape from Callback Hell](http://elm-lang.org/learn/Escape-from-Callback-Hell.elm)
* [Principles of Reactive Programming on Coursera](https://www.coursera.org/course/reactive)

[Basic Operators]: Documentation/BasicOperators.md
[Documentation]: Documentation
[Framework Overview]: Documentation/FrameworkOverview.md
[Functional Reactive Programming]: http://en.wikipedia.org/wiki/Functional_reactive_programming
[GroceryList]:  https://github.com/jspahrsummers/GroceryList
[RACSequence]: ReactiveCocoa/RACSequence.h
[RACSignal]: ReactiveCocoa/RACSignal.h
[futures and promises]: http://en.wikipedia.org/wiki/Futures_and_promises
[C-41]: https://github.com/AshFurrow/C-41
