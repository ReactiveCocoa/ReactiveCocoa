/*:
 > # IMPORTANT: To use `ReactiveCocoa.playground`, please:
 
 1. Retrieve the project dependencies using one of the following terminal commands from the ReactiveCocoa project root directory:
    - `script/bootstrap`
    **OR**, if you have [Carthage](https://github.com/Carthage/Carthage) installed
    - `carthage checkout`
 1. Open `ReactiveCocoa.xcworkspace`
 1. Build `Result-Mac` scheme 
 1. Build `ReactiveCocoa-Mac` scheme
 1. Finally open the `ReactiveCocoa.playground`
 1. Choose `View > Show Debug Area`
 */

import Result
import ReactiveCocoa
import Foundation

/*:
 ## Signal
 
 A **signal**, represented by the [`Signal`](https://github.com/ReactiveCocoa/ReactiveCocoa/blob/master/ReactiveCocoa/Swift/Signal.swift) type, is any series of [`Event`](https://github.com/ReactiveCocoa/ReactiveCocoa/blob/master/ReactiveCocoa/Swift/Event.swift) values
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
 
 Signals can be manipulated by applying [primitives](https://github.com/ReactiveCocoa/ReactiveCocoa/blob/master/Documentation/BasicOperators.md) to them.
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
 ### `Subscription`
 A Signal represents and event stream that is already "in progress", sometimes also called "hot". This means, that a subscriber may miss events that have been sent before the subscription.
 Furthermore, the subscription to a signal does not trigger any side effects
 */
scopedExample("Subscription") {
    // Signal.pipe is a way to manually control a signal. the returned observer can be used to send values to the signal
    let (signal, observer) = Signal<Int, NoError>.pipe()
    
    let subscriber1 = Observer<Int, NoError>(next: { print("Subscriber 1 received \($0)") } )
    let subscriber2 = Observer<Int, NoError>(next: { print("Subscriber 2 received \($0)") } )
    
    print("Subscriber 1 subscribes to the signal")
    signal.observe(subscriber1)
    
    print("Send value `10` on the signal")
    // subscriber1 will receive the value
    observer.sendNext(10)
    
    print("Subscriber 2 subscribes to the signal")
    // Notice how nothing happens at this moment, i.e. subscriber2 does not receive the previously sent value
    signal.observe(subscriber2)
    
    print("Send value `20` on the signal")
    // Notice that now, subscriber1 and subscriber2 will receive the value
    observer.sendNext(20)
}

/*:
 ### `empty`
 A Signal that completes immediately without emitting any value.
 */
scopedExample("`empty`") {
    let emptySignal = Signal<Int, NoError>.empty
    
    let observer = Observer<Int, NoError>(
        failed: { _ in print("error not called") },
        completed: { print("completed not called") },
        interrupted: { print("interrupted called") },
        next: { _ in print("next not called") }
    )
    
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
        completed: { print("completed not called") },
        interrupted: { print("interrupted not called") },
        next: { _ in print("next not called") }
    )
    
    neverSignal.observe(observer)
}

/*:
 ## `Operators`
 ### `uniqueValues`
 Forwards only those values from `self` that are unique across the set of
 all values that have been seen.
 
 Note: This causes the values to be retained to check for uniqueness. Providing
 a function that returns a unique value for each sent value can help you reduce
 the memory footprint.
 */
scopedExample("`uniqueValues`") {
    let (signal, observer) = Signal<Int, NoError>.pipe()
    let subscriber = Observer<Int, NoError>(next: { print("Subscriber received \($0)") } )
    let uniqueSignal = signal.uniqueValues()

    uniqueSignal.observe(subscriber)
    observer.sendNext(1)
    observer.sendNext(2)
    observer.sendNext(3)
    observer.sendNext(4)
    observer.sendNext(3)
    observer.sendNext(3)
    observer.sendNext(5)
}

/*:
 ### `map`
 Maps each value in the signal to a new value.
 */
scopedExample("`map`") {
    let (signal, observer) = Signal<Int, NoError>.pipe()
    let subscriber = Observer<Int, NoError>(next: { print("Subscriber received \($0)") } )
    let mappedSignal = signal.map { $0 * 2 }

    mappedSignal.observe(subscriber)
    print("Send value `10` on the signal")
    observer.sendNext(10)
}

/*:
 ### `mapError`
 Maps errors in the signal to a new error.
 */
scopedExample("`mapError`") {    
    let (signal, observer) = Signal<Int, NSError>.pipe()
    let subscriber = Observer<Int, NSError>(failed: { print("Subscriber received error: \($0)") } )
    let mappedErrorSignal = signal.mapError { (error:NSError) -> NSError in
        let userInfo = [NSLocalizedDescriptionKey: "🔥"]
        let code = error.code + 10000
        let mappedError = NSError(domain: "com.reactivecocoa.errordomain", code: code, userInfo: userInfo)
        return mappedError
    }

    mappedErrorSignal.observe(subscriber)
    print("Send error `NSError(domain: \"com.reactivecocoa.errordomain\", code: 4815, userInfo: nil)` on the signal")
    observer.sendFailed(NSError(domain: "com.reactivecocoa.errordomain", code: 4815, userInfo: nil))
}

/*:
 ### `filter`
 Preserves only the values of the signal that pass the given predicate.
 */
scopedExample("`filter`") {
    let (signal, observer) = Signal<Int, NoError>.pipe()
    let subscriber = Observer<Int, NoError>(next: { print("Subscriber received \($0)") } )
    // subscriber will only receive events with values greater than 12
    let filteredSignal = signal.filter { $0 > 12 ? true : false }

    filteredSignal.observe(subscriber)
    observer.sendNext(10)
    observer.sendNext(11)
    observer.sendNext(12)
    observer.sendNext(13)
    observer.sendNext(14)
}

/*:
 ### `ignoreNil`
 Unwraps non-`nil` values and forwards them on the returned signal, `nil`
 values are dropped.
 */
scopedExample("`ignoreNil`") {
    let (signal, observer) = Signal<Int?, NoError>.pipe()
    // note that the signal is of type `Int?` and observer is of type `Int`, given we're unwrapping
    // non-`nil` values
    let subscriber = Observer<Int, NoError>(next: { print("Subscriber received \($0)") } )
    let ignoreNilSignal = signal.ignoreNil()

    ignoreNilSignal.observe(subscriber)
    observer.sendNext(1)
    observer.sendNext(nil)
    observer.sendNext(3)
}

/*:
 ### `take`
 Returns a signal that will yield the first `count` values from `self`
 */
scopedExample("`take`") {
    let (signal, observer) = Signal<Int, NoError>.pipe()
    let subscriber = Observer<Int, NoError>(next: { print("Subscriber received \($0)") } )
    let takeSignal = signal.take(2)

    takeSignal.observe(subscriber)
    observer.sendNext(1)
    observer.sendNext(2)
    observer.sendNext(3)
    observer.sendNext(4)
}

/*:
 ### `collect`
 Returns a signal that will yield an array of values when `self` completes.
 - Note: When `self` completes without collecting any value, it will send
 an empty array of values.
 */
scopedExample("`collect`") {
    let (signal, observer) = Signal<Int, NoError>.pipe()
    // note that the signal is of type `Int` and observer is of type `[Int]` given we're "collecting"
    // `Int` values for the lifetime of the signal
    let subscriber = Observer<[Int], NoError>(next: { print("Subscriber received \($0)") } )
    let collectSignal = signal.collect()

    collectSignal.observe(subscriber)
    observer.sendNext(1)
    observer.sendNext(2)
    observer.sendNext(3)
    observer.sendNext(4)
    observer.sendCompleted()
}

