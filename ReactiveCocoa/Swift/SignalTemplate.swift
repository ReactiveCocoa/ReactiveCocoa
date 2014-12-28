struct SignalTemplate<T> {
	init(_ generator: (SinkOf<Event<T>>, CompositeDisposable) -> ())

	init(value: T)
	init(error: NSError)
	init(result: Result<T>)
	init<S: SequenceType where S.Generator.Element == T>(values: S)
	init<S: SequenceType where S.Generator.Element == Event<T>>(events: S)

	static let empty: SignalTemplate
	static let never: SignalTemplate
	static func buffer(capacity: Int) -> (SignalTemplate, SinkOf<Event<T>>)

	func start(setUp: Signal<T> -> Disposable?) -> Disposable
	func lift<U>(transform: Signal<T> -> Signal<U>) -> SignalTemplate<U>
}

func |> <T, U>(template: SignalTemplate<T>, transform: Signal<T> -> Signal<U>) -> SignalTemplate<U>
func |> <T, U>(template: SignalTemplate<T>, transform: SignalTemplate<T> -> U) -> U

func timer(interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> SignalTemplate<NSDate>
func timer(interval: NSTimeInterval, onScheduler scheduler: DateScheduler, withLeeway leeway: NSTimeInterval) -> SignalTemplate<NSDate>

func retry<T>(count: Int)(template: SignalTemplate<T>) -> SignalTemplate<T>
func repeat<T>(count: Int)(template: SignalTemplate<T>) -> SignalTemplate<T>
func catch<T>(handler: NSError -> SignalTemplate<T>)(template: SignalTemplate<T>) -> SignalTemplate<T>
func startOn<T>(scheduler: Scheduler)(template: SignalTemplate<T>) -> SignalTemplate<T>
