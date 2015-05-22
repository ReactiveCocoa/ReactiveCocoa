# Memory Management

ReactiveCocoa's memory management is quite complex, but the end result is that
**you don't need to retain signals in order to process them**.

If the framework required you to retain every signal, it'd be much more unwieldy
to use, especially for one-shot signals that are used like futures (e.g.,
network requests). You'd have to save any long-lived signal into a property, and
then also make sure to clear it out when you're done with it. Not fun.

## Subscribers

Before going any further, it's worth noting that
`subscribeNext:error:completed:` (and all variants thereof) create an _implicit_
subscriber using the given blocks. Any objects referenced from those blocks will
therefore be retained as part of the subscription. Just like any other object,
`self` won't be retained without a direct or indirect reference to it.

## Finite or Short-Lived Signals

The most important guideline to RAC memory management is that a **subscription
is automatically terminated upon completion or error, and the subscriber
removed**.

For example, if you have some code like this in your view controller:

```objc
self.disposable = [signal subscribeCompleted:^{
    doSomethingPossiblyInvolving(self);
}];
```

… the memory management will look something like the following:

```
view controller -> RACDisposable -> RACSignal -> RACSubscriber -> view controller
```

However, the `RACSignal -> RACSubscriber` relationship is torn down as soon as
`signal` finishes, breaking the retain cycle.

**This is often all you need**, because the lifetime of the `RACSignal` in
memory will naturally match the logical lifetime of the event stream.

## Infinite Signals

Infinite signals (or signals that live so long that they might as well be
infinite), however, will never tear down naturally. This is where disposables
shine.

**Disposing of a subscription will remove the associated subscriber**, and just
generally clean up any resources associated with that subscription. To that one
subscriber, it's just as if the signal had completed or errored, except no final
event is sent on the signal. All other subscribers will remain intact.

However, as a general rule of thumb, if you have to manually manage
a subscription's lifecycle, [there's probably a better way to do what you want][avoid-explicit-subscriptions-and-disposal].

## Signals Derived from `self`

There's still a bit of a tricky middle case here, though. Any time a signal's
lifetime is tied to the calling scope, you'll have a much harder cycle to break.

This commonly occurs when using `RACObserve()` on a key
path that's relative to `self`, and then applying a block that needs to capture
`self`.

The easiest answer here is just to **capture `self` weakly**:

```objc
__weak id weakSelf = self;
[RACObserve(self, username) subscribeNext:^(NSString *username) {
    id strongSelf = weakSelf;
    [strongSelf validateUsername];
}];
```

Or, after importing the included
[EXTScope.h](https://github.com/jspahrsummers/libextobjc/blob/master/extobjc/EXTScope.h)
header:

```objc
@weakify(self);
[RACObserve(self, username) subscribeNext:^(NSString *username) {
    @strongify(self);
    [self validateUsername];
}];
```

*(Replace `__weak` or `@weakify` with `__unsafe_unretained` or `@unsafeify`,
respectively, if the object doesn't support weak references.)*

However, [there's probably a better pattern you could use instead][avoid-explicit-subscriptions-and-disposal]. For
example, the above sample could perhaps be written like:

```objc
[self rac_liftSelector:@selector(validateUsername:) withSignals:RACObserve(self, username), nil];
```

or:

```objc
RACSignal *validated = [RACObserve(self, username) map:^(NSString *username) {
    // Put validation logic here.
    return @YES;
}];
```

As with infinite signals, there are generally ways you can avoid referencing
`self` (or any object) from blocks in a signal chain.

----

The above information is really all you should need in order to use
ReactiveCocoa effectively. However, there's one more point to address, just for
the technically curious or for anyone interested in contributing to RAC.

The design goal of "no retaining necessary" begs the question: how do we know
when a signal should be deallocated? What if it was just created, escaped an
autorelease pool, and hasn't been retained yet?

The real answer is _we don't_, BUT we can usually assume that the caller will
retain the signal within the current run loop iteration if they want to keep it.

Consequently:

 1. A created signal is automatically added to a global set of active signals.
 2. The signal will wait for a single pass of the main run loop, and then remove
    itself from the active set _if it has no subscribers_. Unless the signal was
    retained somehow, it would deallocate at this point.
 3. If something did subscribe in that run loop iteration, the signal stays in
    the set.
 4. Later, when all the subscribers are gone, step 2 is triggered again.

This could backfire if the run loop is spun recursively (like in a modal event
loop on OS X), but it makes the life of the framework consumer much easier for
most or all other cases.

[avoid-explicit-subscriptions-and-disposal]: DesignGuidelines.md#avoid-explicit-subscriptions-and-disposal
