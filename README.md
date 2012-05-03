# ReactiveCocoa
Native apps spend a lot of time waiting and reacting. We wait for the user to do something in the UI. Wait for a network call to respond. Wait for an asynchronous operation to complete. Wait for some dependent value to change. And then they react.

But all those things—all that waiting and reacting—is usually handled in many disparate ways. That keeps us from reasoning about them, chaining them, or composing them in any uniform, high-level way. We can do better.

That's why we've open-sourced a piece of the magic behind [GitHub for Mac](http://mac.github.com/): [ReactiveCocoa](https://github.com/github/ReactiveCocoa) (RAC).

RAC is a framework for **composing and transforming sequences of values**.

## No seriously, what is it?
Let's get more concrete. ReactiveCocoa gives us a lot of cool stuff:

1. The ability to compose operations on future data.
1. An approach to minimizing state and mutability.
1. A declarative way to define behaviors and the relationships between properties.
1. A unified, high-level interface for asynchronous operations.
1. A lovely API on top of KVO.

Those all might seem a little random until you realize that RAC is all about handling these cases where we're waiting for some new value and then reacting.

The real beauty of RAC is that it can adapt to a lot of different, commonly-encountered scenarios.

Enough talk. Let's see what it actually looks like.

## Examples
RAC can piggyback on [KVO (key-value observing)](http://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/KeyValueObserving/KeyValueObserving.html) to give us a sequence of values from a [KVO-compliant](http://developer.apple.com/library/mac/#documentation/cocoa/conceptual/KeyValueObserving/Articles/KVOCompliance.html) property. For example, we can watch for changes to our `username` property:

```obj-c
[RACAbleSelf(self.username) subscribeNext:^(NSString *newName) {
	NSLog(@"%@", newName);
}];
```

That's cool, but it's really just a nicer API around KVO. The really cool stuff happens when we **compose sequences to express complex behavior**.

```obj-c
[[[[RACAbleSelf(self.username) 
	distinctUntilChanged] 
	take:3] 
	where:^(NSString *newUsername) {
		return [newUsername isEqualToString:@"joshaber"];
	}] 
	subscribeNext:^(id _) {
		NSLog(@"Hi me!");
	}];
```

Now we're watching `username` for changes, filtering out non-distinct changes, taking only the first three non-distinct values, and then if the new value is "joshaber", we print out a nice welcome.


### So what?
Think about what we'd have to do to implement that without RAC. We'd have to:

* Use KVO to add an observer for `username`.
* Add a property to remember the last value we got through KVO so we could ignore non-distinct changes.
* Add a property to count how many non-distinct values we'd received.
* Increment that property every time we got a non-distinct value
* Do the actual comparison.

RAC lets us do the same thing with **less state, less boilerplate, better code locality, and better expression of our intent**.

## Combining
We can combine sequences:

```obj-c
[[RACSubscribable 
	combineLatest:[NSArray arrayWithObjects:RACAbleSelf(self.password), RACAbleSelf(self.passwordConfirmation), nil] 
	reduce:^(RACTuple *values) {
		NSString *currentPassword = [values objectAtIndex:0];
		NSString *currentConfirmPassword = [values objectAtIndex:1];
		return [NSNumber numberWithBool:[currentConfirmPassword isEqualToString:currentPassword]];
	}] 
	subscribeNext:^(NSNumber *passwordsMatch) {
		self.createEnabled = [passwordsMatch boolValue];
	}];
```

Any time our `password` or `passwordConfirmation` properties change, we combine the latest values from both and reduce them to a BOOL of whether or not they matched. Then we enable or disable the create button with that result.

## Bindings
We can adapt RAC to give us powerful bindings with conditions and transformations:

``` obj-c
[self 
	rac_bind:RAC_KEYPATH_SELF(self.helpLabel.text) 
	to:[[RACAbleSelf(self.help) 
		where:^(NSString *newHelp) {
			return newHelp != nil;
		}] 
		select:^(NSString *newHelp) {
			return [newHelp uppercaseString];
		}]];
```
That will bind our help label's text to our `help` property when the `help` property isn't nil and after uppercasing the string (because users love being YELLED AT).

## Async
RAC also fits quite nicely with async operations.

For example, we can call a block once multiple concurrent operations have completed:

``` obj-c
[[RACSubscribable 
	merge:[NSArray arrayWithObjects:[client fetchUserRepos], [client fetchOrgRepos], nil]] 
	subscribeCompleted:^{
		NSLog(@"They're both done!");
	}];
```

Or chain async operations:

``` obj-c
[[[[client 
	loginUser] 
	selectMany:^(id _) {
		return [client loadCachedMessages];
	}]
	selectMany:^(id _) {
		return [client fetchMessages];
	}]
	subscribeCompleted:^{
		NSLog(@"Fetched all messages.");
	}];
```

That will login, load the cached messages, then fetch the remote messages, and then print "Fetched all messages."

Or we can trivially move work to a background queue:

``` obj-c
[[[[[client 
	fetchUserWithUsername:@"joshaber"] 
	deliverOn:[RACScheduler backgroundScheduler]]
	select:^(User *user) {
		// this is on a background queue
		return [[NSImage alloc] initWithContentsOfURL:user.avatarURL];
	}]
	deliverOn:[RACSheduler mainQueueScheduler]]
	subscribeNext:^(NSImage *image) {
		// now we're back on the main queue
		self.imageView.image = image;
	}];
```

Or easily deal with potential race conditions. For example, we could update a property with the result of an asynchronous call, but only if the property doesn't change before the async call completes:

``` obj-c
[[[self 
	loadDefaultMessageInBackground]
	takeUntil:RACAbleSelf(self.message)]
	toProperty:RAC_KEYPATH_SELF(self.message) onObject:self];
```

## How does it work?
RAC is fundamentally pretty simple. It's all subscribables all the way down. _([Until you reach turtles.](http://www.cvaieee.org/html/humor/programming_history.html))_

Subscribers subscribe to subscribables. Subscribables send their subscribers 'next', 'error', and 'completed' events. So if it's all just subscribables sending events, the key question becomes **when do those events get sent?**

### Creating subscribables
Subscribables define their own behavior with respect to if and when events are sent. We can create our own subscribables using `+[RACSubscribable createSubscribable:]`:

``` obj-c
RACSubscribable *helloWorld = [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
	[subscriber sendNext:@"Hello, "];
	[subscriber sendNext:@"world!"];
	[subscriber sendCompleted];
	return nil;
}];
```

The block we give to `+[RACSubscribable createSubscribable:]` is called whenever the subscribable gets a new subscriber. The new subscriber is passed into the block so that we can then send it events. In the above example, we created a subscribable that sends "Hello, ", and then "world!", and then completes.

### Nesting subscribables
We could then create another subscribable based off our `helloWorld` subscribable:

``` obj-c
RACSubscribable *joiner = [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
	NSMutableArray *strings = [NSMutableArray array];
	return [helloWorld subscribeNext:^(NSString *x) {
		[strings addObject:x];
	} error:^(NSError *error) {
		[subscriber sendError:error];
	} completed:^{
		[subscriber sendNext:[strings componentsJoinedByString:@""]];
		[subscriber sendCompleted];
	}];
}];
```

Now we have a `joiner` subscribable. When someone subscribes to `joiner`, it subscribes to our `helloWorld` subscribable. It adds all the values it receives from `helloWorld` and then when `helloWorld` completes, it joins all the strings it received into a single string, sends that, and completes.

In this way, we can build subscribables on each other to express complex behaviors.

RAC implements a set of [operations](https://github.com/github/ReactiveCocoa/blob/master/ReactiveCocoaFramework/ReactiveCocoa/RACSubscribable%2BOperations.h) on `RACSubscribable` that do exactly that. They take the source subscribable and return a new subscribable with some defined behavior.

## Bindings
Bindings let you use RAC to drive your user interface. See the [Mac sample project](https://github.com/github/ReactiveCocoa/tree/master/GHAPIDemo/GHAPIDemo).

But iOS doesn't have bindings. Thankfully, RAC's KVO wrapping makes it easy to bind to KVC-compliant properties a RAC subscribable. It looks like this:

``` obj-c
[self rac_bind:RAC_KEYPATH_SELF(self.someLabel.text) to:RACAbleSelf(self.someText)];
```

The real beauty of this is that we could also use any RAC operations on the subscribable to which it is bound. For example, to transform the new value before propagating it to the bound object:

``` obj-c
[self rac_bind:RAC_KEYPATH_SELF(self.someLabel.text) to:[RACAbleSelf(self.someText) select:^(NSString *newText) {
	return [newText uppercaseString];
}]];
```

Unfortunately, a lot of UIKit classes don't expose KVO-compliant properties. `UITextField`'s `text` property, for example, isn't KVO-compliant. For cases like that, we added `-[UIControl rac_subscribableForControlEvents:]` which sends a new value every time the control events fire.

To go even one step further, we wrapped that in a property on `UITextField` so you can just use `-[UITextField rac_textSubscribable]` to watch for changes to `text`. Now we can write:

```obj-c
[self rac_bind:RAC_KEYPATH_SELF(self.username) to:self.usernameField.rac_textSubscribable];
```

Our `username` property is now bound to the value of our `usernameField` text field.

See the [iOS sample project](https://github.com/github/ReactiveCocoa/tree/master/RACiOSDemo) for an example.

## Lifetime
The point of RAC is to make your life better as a programmer. To that end, `RACSubscribable`'s lifetime is a little funny.

RAC will keep subscribables alive for as long as they need in order to deliver events to its subscribers. This means you usually don't need to worry about keeping a strong reference to a subscribable. RAC will manage it for you.

RAC cleans up a subscribable when:

1. The subscribable sends an error or is completed, or
1. When all its subscribers have unsubscribed and it receives no new subscribers after one runloop iteration.

If you want to keep a subscribable alive past either of those cases, you need to keep a strong reference to it. But you shouldn't usually need to do that.

### KVO
KVO is a special case when it comes to lifetime. Subscribables created from a KVO-compliant property are kept alive for the lifetime of the source object. As such, they never really 'complete.' Instead, when the source object is dealloc'd, the subscribable removes all its subscribers and gets released.

### Disposables
The `-[RACSubscribable subscribe:]` method returns a `RACDisposable`. That disposable encapsulates the tasks necessary to stop and clean up the subscription. You can call `-dispose` on a disposable to end your subscription manually. Typically you won't need to manually track or dispose of disposables. They're automatically called by RAC as part of the subscribable's lifecycle.

## Subjects
You can think of subjects as being subscribables you can manually control. Because they implement `RACSubscriber`, you can call `-sendNext`, `-sendError:`, or `-sendCompleted` to send events to its subscribers.

Subjects are most often used to bridge the non-RAC world to RAC.

## More info
[ReactiveCocoa](https://github.com/github/ReactiveCocoa) works on both Mac and iOS. See the [README](https://github.com/github/ReactiveCocoa/blob/master/README.md) for more info and check out the [Mac](https://github.com/github/ReactiveCocoa/tree/master/GHAPIDemo) demo project for some practical examples.

For .NET developers, this all might sound eerily familiar. ReactiveCocoa essentially an Objective-C version of .NET's [Reactive Extensions](http://msdn.microsoft.com/en-us/data/gg577609) (Rx).

Most of the principles of Rx apply to RAC as well. There are some really good Rx resources out there:

* [Reactive Extensions MSDN entry](http://msdn.microsoft.com/en-us/library/hh242985\(v=vs.103\).aspx)
* [Reactive Extensions for .NET Introduction](http://leecampbell.blogspot.com/2010/08/reactive-extensions-for-net.html)
* [Rx - Channel 9 videos](http://channel9.msdn.com/tags/Rx/)
* [Reactive Extensions wiki](http://rxwiki.wikidot.com/)
* [101 Rx Samples](http://rxwiki.wikidot.com/101samples)
* [Programming Reactive Extensions and LINQ](http://www.amazon.com/Programming-Reactive-Extensions-Jesse-Liberty/dp/1430237473) _(Co-authored by our own [Paul Betts](https://github.com/xpaulbettsx/)!)_

## License
Simplified BSD License