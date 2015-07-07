# Design Guidelines

This document contains guidelines for projects that want to make use of
ReactiveCocoa. The content here is heavily inspired by the [Rx Design
Guidelines](http://blogs.msdn.com/b/rxteam/archive/2010/10/28/rx-design-guidelines.aspx).

This document assumes basic familiarity
with the features of ReactiveCocoa. The [Framework Overview][] is a better
resource for getting up to speed on the functionality provided by RAC.

1. [The `Event` contract](#the-event-contract)
1. [The `Signal` contract](#the-signal-contract)
1. [The `SignalProducer` contract](#the-signalproducer-contract)
1. [Best practices](#best-practices)
1. [Implementing new operators](#implementing-new-operators)

## The `Event` contract


### `Next`s provide values or indicate the occurrence of events
### Errors behave like exceptions and propagate immediately
### Interruption cancels outstanding work and usually propagates immediately
### Completion indicates success
### Events are serial
### Events cannot be sent recursively
### Events are sent synchronously by default

## The `Signal` contract

### Signals start work when instantiated
### Observing a signal does not have side effects
### All observers of a signal see the same events at the same time
### Signals are retained until a terminating event occurs
### Terminating events dispose of signal resources

## The `SignalProducer` contract

### Signal producers start work on demand by creating signals
### Each produced signal may send different events at different times
### Disposing of a produced signal will interrupt it
### Signal operators can be lifted to apply to signal producers

## Best practices

### Indent signal and producer chains consistently
### Process only as many values as needed
### Deliver events onto a known scheduler
### Switch schedulers in as few places as possible
### Capture side effects within signal producers
### Share the side effects of a signal producer by sharing one produced signal
### Prefer managing lifetime with operators over explicit disposal
### Avoid using buffers when possible

## Implementing new operators

### Prefer writing operators that apply to both signals and producers
### Compose existing operators when possible
### Avoid introducing concurrency
### Cancel work and clean up all resources in a disposable
### Forward error and interruption events
### Never block in an operator function

[Framework Overview]: FrameworkOverview.md

