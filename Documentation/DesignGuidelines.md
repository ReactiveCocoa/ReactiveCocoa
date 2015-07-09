# Design Guidelines

This document contains guidelines for projects that want to make use of
ReactiveCocoa. The content here is heavily inspired by the [Rx Design
Guidelines](http://blogs.msdn.com/b/rxteam/archive/2010/10/28/rx-design-guidelines.aspx).

This document assumes basic familiarity
with the features of ReactiveCocoa. The [Framework Overview][] is a better
resource for getting up to speed on the functionality provided by RAC.

1. **[The `Event` contract](#the-event-contract)**
1. **[The `Signal` contract](#the-signal-contract)**
1. **[The `SignalProducer` contract](#the-signalproducer-contract)**
1. **[Best practices](#best-practices)**
1. **[Implementing new operators](#implementing-new-operators)**

## The `Event` contract

Events are fundamental to ReactiveCocoa. Signals and signal producers both send
events, and may be collectively called “event streams.”

Event streams must conform to the following grammar:

```
Next* (Interrupted | Error | Completed)?
```

This states that an event stream consists of:

 1. Any number of `Next` events
 1. Optionally followed by one terminating event, which is any of `Interrupted`, `Error`, or `Completed`

After a terminating event, no other events will be received.

#### `Next`s provide values or indicate the occurrence of events

`Next` events contain a payload known as the “value.” Only `Next` events are
said to have a value. Since an event stream can contain any number of `Next`s,
there are few restrictions on what those values can mean or be used for, except
that they must be of the same type.

As an example, the value might represent an element from a collection, or
a progress update about some long-running operation. The value of a `Next` event
might even represent nothing at all—for example, it’s common to use a value type
of `()` to indicate that something happened, without being more specific about
what that something was.

Most of the event stream operators act upon `Next` events, as they represent the
“meaningful data” of a signal or producer.

#### Errors behave like exceptions and propagate immediately

`Error` events indicate that something went wrong. Errors are fatal, and
propagate as quickly as possible to the consumer for handling.

Errors also behave like exceptions, in that they “skip” operators, terminating
them along the way. In other words, most operators immediately stop doing work
when an error is received, and then propagate the error onward. This even
applies to time-shifted operators, like `delay()`—which, despite its name, will
forward any errors immediately.

Consequently, errors should only be used to represent “abnormal” termination. If
it is important to let operators (or consumers) finish their work, a `Next`
event describing the result might be more appropriate.

#### Completion indicates success

An event stream sends `Completed` when the operation has completed successfully,
or to indicate that the stream has terminated normally.

Many operators manipulate the `Completed` event to shorten or extend the
lifetime of an event stream.

For example, `take()` will complete after the specified number of values have
been received, thereby terminating the stream early. On the other hand, most
operators that accept multiple signals or producers will wait until _all_ of
them have completed before forwarding a `Completed` event, since a successful
outcome will usually depend on all the inputs.

#### Interruption cancels outstanding work and usually propagates immediately

An `Interrupted` event is sent when an event stream should cancel processing.
Interruption is somewhere between [success](#completion-indicates-success)
and [failure](#errors-behave-like-exceptions-and-propagate-immediately)—the
operation was not successful, because it did not get to finish, but it didn’t
necessarily “fail” either.

Most operators will propagate interruption immediately, but there are some
exceptions. For example, the [flattening operators][flatten] will ignore
`Interrupted` events that occur on the _inner_ producers, since the cancellation
of an inner operation should not necessarily cancel the larger unit of work.

RAC will automatically send an `Interrupted` event upon disposal, but it can
also be sent manually if necessary. Additionally, [custom
operators](#implementing-new-operators) must make sure to forward interruption
events to the observer.

#### Events are serial
#### Events cannot be sent recursively
#### Events are sent synchronously by default

## The `Signal` contract

#### Signals start work when instantiated
#### Observing a signal does not have side effects
#### All observers of a signal see the same events at the same time
#### Signals are retained until a terminating event occurs
#### Terminating events dispose of signal resources

## The `SignalProducer` contract

#### Signal producers start work on demand by creating signals
#### Each produced signal may send different events at different times
#### Signal operators can be lifted to apply to signal producers
#### Disposing of a produced signal will interrupt it

## Best practices

#### Indent signal and producer chains consistently
#### Process only as many values as needed
#### Deliver events onto a known scheduler
#### Switch schedulers in as few places as possible
#### Capture side effects within signal producers
#### Share the side effects of a signal producer by sharing one produced signal
#### Prefer managing lifetime with operators over explicit disposal
#### Avoid using buffers when possible

## Implementing new operators

#### Prefer writing operators that apply to both signals and producers
#### Compose existing operators when possible
#### Forward error and interruption events
#### Cancel work and clean up all resources in a disposable
#### Avoid introducing concurrency

#### Avoid blocking in operators

Signal or producer operators should return a new signal or producer
(respectively) as quickly as possible. Any work that the operator needs to
perform should be part of the event handling logic, _not_ part of the operator
invocation itself.

This guideline can be safely ignored when the purpose of an operator is to
synchronously retrieve one or more values from a stream, like `single()` or
`wait()`.

[flatten]: BasicOperators.md#flattening-producers
[Framework Overview]: FrameworkOverview.md

