# Design Guidelines

This document contains guidelines for projects that want to make use of
ReactiveCocoa. The content here is heavily inspired by the [Rx Design
Guidelines](http://blogs.msdn.com/b/rxteam/archive/2010/10/28/rx-design-guidelines.aspx).

This document assumes basic familiarity
with the features of ReactiveCocoa. The [Framework Overview][] is a better
resource for getting up to speed on the functionality provided by RAC.

**[The `Event` contract](#the-event-contract)**

 1. `Next`s provide values or indicate the occurrence of events
 1. Errors behave like exceptions and propagate immediately
 1. Interruption cancels outstanding work and usually propagates immediately
 1. Completion indicates success
 1. Events are serial
 1. Events cannot be sent recursively
 1. Events are sent synchronously by default

**[The `Signal` contract](#the-signal-contract)**

 1. Signals start work when instantiated
 1. Observing a signal does not have side effects
 1. All observers of a signal see the same events at the same time
 1. Signals are retained until a terminating event occurs
 1. Terminating events dispose of signal resources

**[The `SignalProducer` contract](#the-signalproducer-contract)**

 1. Signal producers start work on demand by creating signals
 1. Each produced signal may send different events at different times
 1. Disposing of a produced signal will interrupt it
 1. Signal operators can be lifted to apply to signal producers

**[Best practices](#best-practices)**

 1. Indent signal and producer chains consistently
 1. Process only as many values as needed
 1. Deliver events onto a known scheduler
 1. Switch schedulers in as few places as possible
 1. Capture side effects within signal producers
 1. Share the side effects of a signal producer by sharing one produced signal
 1. Prefer managing lifetime with operators over explicit disposal
 1. Avoid using buffers when possible

**[Implementing new operators](#implementing-new-operators)**

 1. Prefer writing operators that apply to both signals and producers
 1. Compose existing operators when possible
 1. Avoid introducing concurrency
 1. Cancel work and clean up all resources in a disposable
 1. Forward error and interruption events
 1. Never block in an operator function

## The `Event` contract


## The `Signal` contract


## The `SignalProducer` contract


## Best practices


## Implementing new operators


[Framework Overview]: FrameworkOverview.md

