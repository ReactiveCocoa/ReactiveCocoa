/*:
 > # IMPORTANT: To use `ReactiveCocoa.playground`, please:
 
 1. Open `ReactiveCocoa.xcworkspace`
 2. Build `ReactiveCocoa-Mac` scheme
 3. Build `Result-Mac` scheme
 3. Finally open the `ReactiveCocoa.playground`
 4. Choose `View > Show Debug Area`
 */

import Result
import ReactiveCocoa
import Foundation

/*:
 ## Signal
 
 A **signal**, represented by the [`Signal`](https://github.com/ReactiveCocoa/ReactiveCocoa/blob/master/ReactiveCocoa/Swift/Signal.swift) type, is any series of [events](https://github.com/ReactiveCocoa/ReactiveCocoa/blob/master/ReactiveCocoa/Swift/Event.swift)
 over time that can be observed.
 
 Signals are generally used to represent event streams that are already “in progress”,
 like notifications, user input, etc. As work is performed or data is received,
 events are _sent_ on the signal, which pushes them out to any observers.
 All observers see the events at the same time.
 
 Users must observe a signal in order to access its events.
 Observing a signal does not trigger any side effects. In other words,
 signals are entirely producer-driven and push-based, and consumers (observers)
 cannot have any effect on their lifetime. While observing a signal, the user
 can only evaluate the events in the same order as they are sent on the signal. There
 is no random access to values of a signal.
 
 Signals can be manipulated by applying [primitives][BasicOperators] to them.
 Typical primitives to manipulate a single signal like `filter`, `map` and
 `reduce` are available, as well as primitives to manipulate multiple signals
 at once (`zip`). Primitives operate only on the `Next` events of a signal.
 
 The lifetime of a signal consists of any number of `Next` events, followed by
 one terminating event, which may be any one of `Failed`, `Completed`, or
 `Interrupted` (but not a combination).
 Terminating events are not included in the signal’s values—they must be
 handled specially.
 */

/*:
 ### `empty`
 A Signal that completes immediately without emitting any value.
 */
scopedExample("`empty`") {
    
    let emptySignal = Signal<Int, NoError>.empty
    
    let observer = Observer<Int, NoError>(
        failed: { _ in print("error not called") },
        completed: { print("completed not called")},
        next: { _ in print("next not called")},
        interrupted: { print("interrupted called")})
    
    emptySignal.observe(observer)
}

/*:
 ### `never`
 A Signal that never sends any events to its observers.
 */
scopedExample("`never`") {
    
    let neverSignal = Signal<Int, NoError>.never
    
    let observer = Observer<Int, NoError>(
        failed: { _ in print("error not called") },
        completed: { print("completed not called")},
        next: { _ in print("next not called")},
        interrupted: { print("interrupted not called")})
    
    neverSignal.observe(observer)
}
