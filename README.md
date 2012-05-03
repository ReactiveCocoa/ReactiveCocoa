# ReactiveCocoa
ReactiveCocoa is a framework for **composing and transforming sequences of values**.

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

# How does it work?
RAC is fundamentally pretty simple. It's all subscribables all the way down. _([Until you reach turtles.](http://www.cvaieee.org/html/humor/programming_history.html))_

Subscribers subscribe to subscribables. Subscribables send their subscribers 'next', 'error', and 'completed' events. So if it's all just subscribables sending events, the key question becomes **when do those events get sent?**

## Subscribables
Subscribables define their own behavior with respect to if and when events are sent.

Not all subscribables are created equal. There are fundamentally two different kinds of subscribables: hot and cold.

Hot subscribables always send events regardless of whether anyone's subscribed. For example, a subscribable of the text of a text field will always send the new text value even if no one has subscribed to it.

Hot subscribables also always send the same values to all their subscribers, regardless of when they subscribed. To return to our previous example, the text subscribable always sends the same text to all its subscribers. It'd be pretty baffling if it didn't.

Cold subscribables—as you might guess—are the opposite. They only send events once they are subscribed to.

Also in contrast to hot subscribables, cold subscribables send a different stream of events to each subscriber.

## Creating cold subscribables
We can create our own cold subscribables using `+[RACSubscribable createSubscribable:]`:

``` obj-c
RACSubscribable *helloWorld = [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
	[subscriber sendNext:@"Hello, "];
	[subscriber sendNext:@"world!"];
	[subscriber sendCompleted];
	return nil;
}];
```

That block we gave to `+[RACSubscribable createSubscribable:]` will be called whenever the subscribable gets a new subscriber. This is why it's a cold subscribable; it sends events only when it gets a new subscriber and it treats each subscriber separately. The new subscriber is passed into the block so that we can then send it events. In the above example, we created a subscribable that sends "Hello, ", and then "world!", and then completes.

Note that none of the work in the block given to `+[RACSubscribable createSubscribable:]` is performed until someone subscribes. In that sense, cold subscribables are lazy.

You might notice the block is returning nil. We'll come back to what that means in a minute.

### Nesting subscribables
We could create another subscribable based off our `helloWorld` subscribable:

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

Now we have a `joiner` subscribable. When someone subscribes to `joiner`, it subscribes to our `helloWorld` subscribable. It adds all the values it receives from `helloWorld` to an array and then when `helloWorld` completes, it joins all the strings it received into a single string, sends that, and completes.

There are a couple cool things to note about this.

The semantics changed so that `joiner` only sends a value once `helloWorld` completes. That's the simple beauty of RAC. We can transform one subscribable with another.

The nested subscriptions are lazy. Since `joiner`'s block is only called when someone subscribes to it, it only subscribes to `helloWorld` when someone subscribes to `joiner`. The subscriptions cascade up.

`joiner`'s block is returning the value of `-[RACSubscribable subscribeNext:error:completed]`. If you look at the definition for `+[RACSubscribable createSubscribable:]`, you'll notice that return value is a `RACDisposable`.

Disposables are in charge of cleaning up the subscription for the subscribable. In this case, by returning our subscription to `helloWorld`, we're making sure that when the subscription to `joiner` is disposed of, the underlying subscription to `helloWorld` also gets disposed. This is a pattern you should follow whenever you make a subscribable based off another.

## Creating hot subscribables
The easiest way to create hot subscribables is by using [RACSubject](https://github.com/github/ReactiveCocoa/blob/master/ReactiveCocoaFramework/ReactiveCocoa/RACSubject.h). Subjects are subscribables you can manually control with `-sendNext:`, `-sendError:`, `-sendCompleted`. Those will send the corresponding events to the subject's subscribers.

Remember that hot subscribables send events regardless of whether anyone's listening. Sometimes that's fine, but often we'd actually like to avoid missing any events.

Suppose that we're using RAC to interact with a web API. (In fact, that's exactly what the [GHAPIDemo](https://github.com/github/ReactiveCocoa/blob/master/GHAPIDemo/GHAPIDemo/GHGitHubClient.m) does.) We'd probably return a subject from our request method and the subject would send the value of the API call.

But there's a race condition here. If the API call sends its result and completes before I have a chance to subscribe, then I completely missed the whole point of the API call and I'd never know it.

Because of this, RAC has a few `RACSubject` subclasses:

1. [RACAsyncSubject](https://github.com/github/ReactiveCocoa/blob/master/ReactiveCocoaFramework/ReactiveCocoa/RACAsyncSubject.h). It doesn't send any value until it completes and if anyone subscribes after it has completed, it resends the last value it received to that new subscriber and tells the subscriber it's completed.
1. [RACReplaySubject](https://github.com/github/ReactiveCocoa/blob/master/ReactiveCocoaFramework/ReactiveCocoa/RACReplaySubject.h). It remembers every value it sends (or some pre-defined cut-off you give it) and replays those to any subscriber that misses them.
1. [RACBehaviorSubject](https://github.com/github/ReactiveCocoa/blob/master/ReactiveCocoaFramework/ReactiveCocoa/RACBehaviorSubject.h). It remembers the last value it received and sends that to any new subscribers that missed it.

## Operations
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

## Disposables
The `-[RACSubscribable subscribe:]` method returns a `RACDisposable`. That disposable encapsulates the tasks necessary to stop and clean up the subscription. You can call `-dispose` on a disposable to end your subscription manually. Typically you won't need to manually track or dispose of disposables. They're automatically called by RAC as part of the subscribable's lifecycle.

## More info
[ReactiveCocoa](https://github.com/github/ReactiveCocoa) works on both Mac and iOS. Check out the [Mac](https://github.com/github/ReactiveCocoa/tree/master/GHAPIDemo) demo project for some practical examples.

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