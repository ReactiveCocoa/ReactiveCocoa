# ReactiveCocoa
ReactiveCocoa (RAC) is an Objective-C version of .NET's [Reactive Extensions](http://msdn.microsoft.com/en-us/data/gg577609) (Rx).

# No srsly, what is it
A many splendid thing:

1. Functional, declarative way to describe behaviors and the relationships between properties.
1. Unified, high-level interface for asynchronous operations.
1. A lovely API on top of KVO.
1. Futures, kinda sorta.

# Intro
The fundamental ideas of RAC are pretty straightforward. It's all about subscribables. You can think of them as the evil twin of enumerables. With enumerables, you walk across some collection—item by item—until you manually stop, you hit the end of the collection, or something bad happens.

With subscribables, you subscribe to it and it then feeds you items—one by one—until you manually stop, the subscribable completes, or something bad happens.

This is often described in the Rx world as enumeration being pull while subscribing is push. Instead of asking for items, you're fed items.

Pretty straightforward right? So what's the big deal?

# The Big Deal™
It turns out this subscribable behavior is really useful in a lot of different cases. And it's extraordinarily useful especially once you start composing subscribables.

## Examples
Enough words. Let's see some code:

```obj-c
[RACAbleSelf(self.username) 
	subscribeNext:^(NSString *newName) {
		NSLog(@"%@", newName);
	}];
```

That creates a subscribable from `self`'s KVO-compliant property `username` and logs the new value whenever it changes.

That's nice but the real power comes when we compose subscribables. Like so:

```obj-c
[[RACAbleSelf(self.username) 
	where:^(NSString *newName) {
		return [newName isEqualToString:@"joshaber"];
	}] 
	subscribeNext:^(id _) {
		NSLog(@"Hi me!");
	}];
```

So now we're logging "Hi me!" whenever the username is "joshaber." Cool, but we can do better:

```obj-c
[[[[RACAbleSelf(self.username) 
	distinctUntilChanged] 
	take:3] 
	where:^(NSString *newName) {
		return [newName isEqualToString:@"joshaber"];
	}] 
	subscribeNext:^(id _) {
		NSLog(@"Hi me!");
	} 
	completed:^{
		NSLog(@"Awww too bad you're not me!");
	}];
```

Holy composed subscribables Batman! So we're now only being notified if the new value isn't the same as the old value, we're only giving them 3 tries to be me, and if they're not, we print out a condescending message.

We can even combine subscribables. Suppose we have a view where they create an account, and we want to only enable the "Create" button when the password and password confirmation fields match.

```obj-c
[[RACSubscribable 
	combineLatest:[NSArray arrayWithObjects:RACAbleSelf(self.password), RACAbleSelf(self.passwordConfirmation), nil] 
	reduce:^(NSArray *values) {
		NSString *currentPassword = [values objectAtIndex:0];
		NSString *currentConfirmPassword = [values objectAtIndex:1];
		return [NSNumber numberWithBool:[currentConfirmPassword isEqualToString:currentPassword]];
	}] 
	subscribeNext:^(NSNumber *match) {
		self.createEnabled = [match boolValue];
	}];
```

So any time our `password` or `passwordConfirmation` properties change, we reduce them to a BOOL of whether or not they match. Then we enable or disable the create button with that result.

### Isn't this just KVO?
Only kinda. It's like KVO in that it's a way of being told when things change. But it's really much more general, flexible, and usable than KVO. That said, it **does** leverage KVO. As you can see above, for instance, you can create a subscribable from a KVO-compliant property.

### Yeah but I can already do all that myself
Sure, but by using RAC you get some pretty awesome stuff for free:

1. No state. If we did it ourselves, we'd have to keep and manage quite a bit of state manually. Therein lies bugs.
1. Code locality. If we did it manually, the code would be spread out across many different method calls. This way we define the behavior all in one place.
1. Higher order messaging. RAC allows us to more clearly express our _intent_ rather than worrying about the specific implementation details.

## Async
The subscribable paradigm also fits quite nicely with async operations. Your async calls return subscribables which lets you leverage all the power of composing subscribable operations.

For example, to call a block once multiple async operations have completed:

``` obj-c
[[RACSubscribable 
	merge:[NSArray arrayWithObjects:[client fetchUserRepos], [client fetchOrgRepos], nil]] 
	subscribeCompleted:^{
		NSLog(@"They're both done!");
	}];
```

Or to chain async operations:

``` obj-c
[[[[client 
	loginUser] 
	selectMany:^(id _) {
		return [client fetchMessages];
	}]
	selectMany:^(Message *message) {
		return [client fetchFullMessage:message];
	}]
	subscribeNext:^(Message *fullMessage) {
		NSLog(@"Got message: %@", fullMessage);
	} 
	completed:^{
		NSLog(@"Fetched all messages.");
	}];
```

That will login, then fetch messages, then for each message fetched, fetch the full message, log each full message and then log when it's all done.

## Lifetime
The point of RAC is to make your life better as a programmer. To that end, `RACSubscribable`'s lifetime is a little funny.

RAC will keep subscribables alive for as long as they need in order to deliver events to its subscribers. This means you usually don't need to worry about keeping a strong reference to a subscribable. RAC will manage it for you.

RAC cleans up a subscribable when:

1. The subscribable sends an error or is completed, or
1. When all its subscribers have unsubscribed and it receives no new subscribers after one runloop iteration.

If you want to keep a subscribable alive past either of those cases, you need to keep a strong reference to it. But you shouldn't usually need to do that.

### KVO
KVO is a special case when it comes to lifetime. If the normal rules applied, you'd end up causing retain cycles all over the place.

Instead, sbscribables for a KVO property send the `completed` event when the observing object is deallocated. This falls under case (1) above, so it tears down the subscribable and its subscribers.

### Disposables
The `-[RACSubscribable subscribe:]` method returns a `RACDisposable`. That disposable encapsulates the tasks necessary to clean up the subscription. You can call `-dispose` on a disposable to end your subscription manually.

## It's ugly!
OK I might grant you that. Beauty is in the eye of the beholder and all that. We've played with a lot of different formatting styles to try to find one that's both concise and readable. The examples are in the style we currently use.

That said, it's also a matter of getting used to what a different kind of code looks like. Give it time. It might grow on you.