final class Signal<T> {
	init(_ generator: SinkOf<Event<T>> -> ())

	static let never: Signal
	static func pipe() -> (Signal, SinkOf<Event<T>>)

	func observe<S: SinkType where S.Element == Event<T>>(sink: S) -> Disposable
	func observe(next: T -> () = doNothing, error: NSError -> () = doNothing, completed: () -> () = doNothing) -> Disposable
}

infix operator |> {
	associativity right
	precedence 95
}

func |> <T, U>(signal: Signal<T>, transform: Signal<T> -> U) -> U

func combineLatestWith<T, U>(otherSignal: Signal<U>)(signal: Signal<T>) -> Signal<(T, U)>
func combinePrevious<T>(initial: T)(signal: Signal<T>) -> Signal<(T, T)>
func concat<T>(next: Signal<T>)(signal: Signal<T>) -> Signal<T>
func delay<T>(interval: NSTimeInterval, onScheduler scheduler: DateScheduler)(signal: Signal<T>) -> Signal<T>
func dematerialize<T>(signal: Signal<Event<T>>) -> Signal<T>
func filter<T>(predicate: T -> Bool)(signal: Signal<T>) -> Signal<T>
func map<T, U>(transform: T -> U)(signal: Signal<T>) -> Signal<U>
func mapAccumulate<State, T, U>(initialState: State, _ transform: (State, T) -> (State?, U))(signal: Signal<T>) -> Signal<U> {
func materialize<T>(signal: Signal<T>) -> Signal<Event<T>>
func observeOn<T>(scheduler: Scheduler)(signal: Signal<T>) -> Signal<T>
func reduce<T, U>(initial: U, combine: (U, T) -> U)(signal: Signal<T>) -> Signal<U>
func sampleOn<T>(sampler: Signal<()>)(signal: Signal<T>) -> Signal<T>
func scan<T, U>(initial: U, combine: (U, T) -> U)(signal: Signal<T>) -> Signal<U>
func skip<T>(count: Int)(signal: Signal<T>) -> Signal<T>
func skipRepeats<T: Equatable>(signal: Signal<T>) -> Signal<T>
func skipRepeats<T>(isRepeat: (T, T) -> Bool)(signal: Signal<T>) -> Signal<T>
func skipWhile<T>(predicate: T -> Bool)(signal: Signal<T>) -> Signal<T>
func take<T>(count: Int)(signal: Signal<T>) -> Signal<T>
func takeLast<T>(count: Int)(signal: Signal<T>) -> Signal<T>
func takeUntil<T>(trigger: Signal<()>)(signal: Signal<T>) -> Signal<T>
func takeUntilReplacement<T>(replacement: Signal<T>)(signal: Signal<T>) -> Signal<T>
func takeWhile<T>(predicate: T -> Bool)(signal: Signal<T>) -> Signal<T>
func throttle<T>(interval: NSTimeInterval, onScheduler scheduler: DateScheduler)(signal: Signal<T>) -> Signal<T>
func timeoutWithError<T>(error: NSError, afterInterval interval: NSTimeInterval, onScheduler scheduler: DateScheduler)(signal: Signal<T>) -> Signal<T>
func try<T>(operation: (T, NSErrorPointer) -> Bool)(signal: Signal<T>) -> Signal<T>
func try<T>(operation: T -> Result<()>)(signal: Signal<T>) -> Signal<T>
func tryMap<T, U>(operation: (T, NSErrorPointer) -> U?)(signal: Signal<T>) -> Signal<U>
func tryMap<T, U>(operation: T -> Result<U>)(signal: Signal<T>) -> Signal<U>
func zipWith<T, U>(otherSignal: Signal<U>)(signal: Signal<T>) -> Signal<(T, U)>
