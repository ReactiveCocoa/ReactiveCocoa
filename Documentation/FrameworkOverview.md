# Framework Overview

This document contains a high-level description of the different components
within the ReactiveCocoa framework, and an attempt to explain how they work
together and divide responsibilities. This is meant to be a starting point for
learning about new modules and finding more specific documentation.

For examples and help understanding how to use RAC, see the [README][] or
the [Design Guidelines][].

## Events

An **event**, represented by the [Event][] class, is the formalized representation
of the fact that _something has happened_. In Reactive Cocoa, events are the center
piece of communication. An event might represent the press of a button, a piece 
of information received from an API, the occurrence of an error or the completion 
of a long running operation. A source generates events and sends them over a 
[signal](#signals) to any number of [observers](#observers).

An event has two types associated with it: the type of the value it holds when 
everyting goes right, and the type of error it may hold in the case of a failure. 
Additional to the _normal_ and the _failure_ case, an event can also represent 
_completion_ and _interruption_.

## Signals

A **signal**, represented by the [Signal][] class, is any series of [events](#events)
over time that can be observed.

Signals are generally used to represent event streams that are already “in progress”,
like notifications, user input, etc. As work is performed or data is received, 
events are _sent_ on the signal, which pushes them out to any observers. 
All observers see the events at the same time. 

Users must [observe](#observers) a signal in order to access its events. 
Observing a signal does not trigger any side effects. In other words, 
signals are entirely producer-driven and push-based, and consumers (observers) 
cannot have any effect on their lifetime. While observing a signal, the user 
can only evaluate the events in the same order as they are sent on the signal -
there is no random access to values of the stream.

 * The **next** event provides a new value from the stream. [Signal][]
   methods only operate on events of this type.
 * The **error** event indicates that an error occurred before the signal could
   finish. The event may include an signal specific `ErrorType` object that 
   indicates what went wrong. If no error can happen, the `NoError` type can 
   be specified. Errors must be handled specially – they are not included in 
   the stream's values.
 * The **completed** event indicates that the signal finished successfully, and
   that no more values will be added to the stream. Completion must be handled
   specially – it is not included in the stream of values.
 * The **interrupted** event indicates that the signal has terminated 
   non-erroneous, yet unsuccessful e.g. when the corresponding request has been
   cancelled before the signal could finish. Interruptions must be handeled 
   specially - they are not included in the stream's values.


Signals can be manipulated by appying [primitives][Operators] to them. 
Typical primitives to manipulate a single signal like `filter`, `map` and
`reduce` are available as well as primitives to manipulate multiple signals
at once (`zip`).
The `|>` operator is used to apply primitives to a signal. It can also be used
to compose basic primitives into more complex ones.

The lifetime of a signal consists of any number of `next` events, followed by
one `error`, `completed` or `interrupted` event (but no combination of those).

### Pipes

A **Pipe**, created by `Signal.pipe()`, is a [signal](#signals)
that can be manually controlled.

The method returns a [Signal](#signals) and an [Event Sink](#observers). 
This signal can be controlled by sending events to the sink. This 
can be extremely useful for bridging non-RAC code into the world of signals.

For example, instead of handling application logic in block callbacks, the
blocks can simply send events to a shared observer instead. The signal 
can be returned, hiding the implementation detail of the callbacks.

## Signal Producers

A **signal producer**, represented by the [SignalProducer][] class, creates 
Signals and performs side effects.

They can be used to represent operations or tasks, like network 
requests, where each invocation of `start()` will create a new underlying 
operation. The produced signal is returned to the caller, who can observe
the result of the task by observing the signal.

Because of the behavior of `start()`, different Signals created from the 
producer may see a different version of events, the events may arrive in a 
different order between signals, or the stream might be completely different!
However, this behavior ensures that consumers will receive the results, 
in contrast to a plain signal that might send results befor any observers 
are attached.

Starting a signal returns a [disposable](#disposables) which can be used to 
interrupt/cancel the work associated Signal.

Just like signals, signal Producers can also be manipulated via primitives 
like `map`, `filter`, etc. 
Every signal primitive can be `lift`ed to operate upon Signal Producers instead. 
In other words, `lift` creates a new Signal Producer which will apply the given 
signal primitive to __every__ signal created from the producer. 
Furthermore, there are additional primitives that control _when_ and _how_ work
is started, for example `times`.
Again, the `|>` operator can be used to apply primitives to a signal
producer which implicitly lifts the primitive.

### Buffers

A **Buffer**, created by `SignalProducer.buffer()`, is a (optionally bounded)
queue for [Events](#events) and replays those events when new 
[Signals](#signals) are created from the producer.

Similar to a [Pipe](#pipes), the method returns an [Observer](#observers). 
Events sent to this observer will be added to the queue. If the buffer is already
at capacity, the earliest (oldest) event will be dropped to make room for the 
new event. 

This can be usefull to buffer events for future observers, like when a network 
request finishes before anything is ready to handle the result.

## Observers

An **Observer** is anything that is waiting or capable of waiting for events
from a [signal](#signals). Within RAC, an observer is represented as an instance
of the [SinkOf][] struct with an input type of Event.

A signal can be observed by calling its `observe` method, providing either a
sink or callbacks for the different types of events as a parameter.

## Action

An **Action**, represented by the [Action][] class, will do some work when
executed with an _Input_. During or after execution, zero or more _Output_
values are generated. Alternatively, an _Error_ may be generated.

Actions are suited to perform side-effecting work as the user interacts with
the app.

Usually the trigger for an Action is UI-driven, like when a button is
clicked. Actions can also be automatically disabled based on a signal, and this
disabled state can be represented in a UI by disabling any controls associated
with the action.

For interaction with UIKit or AppKit GUI controls such as `NSControl` or 
`UIControl`, RAC provides [CocoaAction][] to wrap Action with KVO or 
Cocoa Bindings.

## Property

A **Property**, represented by the [PropertyType][Property] protocol, allows
observation of its changes.

The current value of a property can be obtained from the `value` getter. The
`producer` getter returns a [SignalProducer](#signal-producers) that will send
the property's current value, followed by all changes over time.

The `<~` operator can be used to bind properties in different ways. Note that in 
all cases, the target has to be a `MutablePropertyType`.

* `Property <~ Signal` binds the signal to the property, updating the property's 
value to the latest value sent by the signal.
* `Property <~ SignalProducer` creates a signal from the given producer, which will 
immediately bind to the given property, updating the property's value to the latest 
value sent by the signal
* `Property <~ Property` binds the _destination_ property to the latest values 
the _source_ property.

When bridging to Objective C code (like UIKit or AppKit), `DynamicProperty` can be used to
wrap a `dynamic` property using Key-Value-Coding and Key-Value-Observing. `DynamicProperty`
should only be used when KVO/KVC is required by the API used (e.g. `NSOperation`), 
`MutableProperty` should be preferred whenever possible! 

## Disposables

A **Disposable**, represented by the [Disposable][] protocol, is a a mechanism
for memory management and cancellation. 

When starting a [SignalProducer](#signal-producers), a disposable will be returned.
This disposable can be used by the caller to cancel the work that has been started
(e.g. background processing, network requests, etc.). Additionally, all temporary 
resources should be cleaned up and an `Interrupted` event is sent.

Observing a [Signal](#signals) may also return a disposable. Disposing it will 
prevent the observer from receiving any future events from that signal, it will
however not have any effect on the signal itself.

For more information about cancellation, see the RAC [Design Guidelines][].

## Schedulers

A **scheduler**, represented by the [SchedulerType][] protocol, is a serial
execution queue to perform work or deliver results upon.

[Signals](#signals) can be ordered to deliver events a a specific scheduler or
[SignalProducers](#signal-producers) can be ordered to start their work on 
a specific scheduler.

Schedulers are similar to Grand Central Dispatch queues, but schedulers support
cancellation (via [disposables](#disposables)), and always execute serially.
With the exception of the [ImmediateScheduler][Scheduler], schedulers do not
offer synchronous execution. This helps avoid deadlocks, and encourages the use
of [signal operators][BasicOperators] instead of blocking work.

[Schedulers][Scheduler] are also somewhat similar to `NSOperationQueue`, but schedulers
do not allow tasks to be reordered or depend on one another.


[Design Guidelines]: DesignGuidelines.md
[Memory Management]: MemoryManagement.md
[BasicOperators]: BasicOperators.md
[README]: ../README.md
[Signal]: ../ReactiveCocoa/Swift/Signal.swift
[SignalProducer]: ../ReactiveCocoa/Swift/SignalProducer.swift
[Action]: ../ReactiveCocoa/Swift/Action.swift
[CocoaAction]: ../ReactiveCocoa/Swift/Action.swift
[Disposable]: ../ReactiveCocoa/Swift/Disposable.swift
[Scheduler]: ../ReactiveCocoa/Swift/Scheduler.swift
[Property]: ../ReactiveCocoa/Swift/Property.swift
[Event]: ../ReactiveCocoa/Swift/Event.swift
[SinkOf]: http://swiftdoc.org/type/SinkOf/
