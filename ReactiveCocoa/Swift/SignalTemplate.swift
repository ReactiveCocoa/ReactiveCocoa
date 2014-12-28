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
	static func try(operation: () -> Result<T>) -> SignalTemplate
	static func try(operation: NSErrorPointer -> T?) -> SignalTemplate

	func start(setUp: Signal<T> -> Disposable?) -> Disposable
	func lift<U>(transform: Signal<T> -> Signal<U>) -> SignalTemplate<U>
}

func |> <T, U>(template: SignalTemplate<T>, transform: Signal<T> -> Signal<U>) -> SignalTemplate<U>
func |> <T, U>(template: SignalTemplate<T>, transform: SignalTemplate<T> -> U) -> U

func timer(interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> SignalTemplate<NSDate>
func timer(interval: NSTimeInterval, onScheduler scheduler: DateScheduler, withLeeway leeway: NSTimeInterval) -> SignalTemplate<NSDate>

func concat<T>(template: SignalTemplate<SignalTemplate<T>>) -> SignalTemplate<T>
func concatMap<T, U>(transform: T -> SignalTemplate<U>)(template: SignalTemplate<T>) -> SignalTemplate<U>
func merge<T>(template: SignalTemplate<SignalTemplate<T>>) -> SignalTemplate<T>
func mergeMap<T, U>(transform: T -> SignalTemplate<U>)(template: SignalTemplate<T>) -> SignalTemplate<U>
func switchMap<T, U>(transform: T -> SignalTemplate<U>)(template: SignalTemplate<T>) -> SignalTemplate<U>
func switchToLatest<T>(template: SignalTemplate<SignalTemplate<T>>) -> SignalTemplate<T>

func catch<T>(handler: NSError -> SignalTemplate<T>)(template: SignalTemplate<T>) -> SignalTemplate<T>
func combineLatestWith<T, U>(otherTemplate: SignalTemplate<U>)(template: SignalTemplate<T>) -> SignalTemplate<(T, U)>
func concat<T>(next: SignalTemplate<T>)(template: SignalTemplate<T>) -> SignalTemplate<T>
func on<T>(started: () -> () = doNothing, event: Event<T> -> () = doNothing, next: T -> () = doNothing, error: NSError -> () = doNothing, completed: () -> () = doNothing, terminated: () -> () = doNothing, disposed: () -> () = doNothing)(template: SignalTemplate<T>) -> SignalTemplate<T>
func repeat<T>(count: Int)(template: SignalTemplate<T>) -> SignalTemplate<T>
func retry<T>(count: Int)(template: SignalTemplate<T>) -> SignalTemplate<T>
func startOn<T>(scheduler: Scheduler)(template: SignalTemplate<T>) -> SignalTemplate<T>
func takeUntil<T>(trigger: SignalTemplate<()>)(template: SignalTemplate<T>) -> SignalTemplate<T>
func takeUntilReplacement<T>(replacement: SignalTemplate<T>)(template: SignalTemplate<T>) -> SignalTemplate<T>
func then<T, U>(replacement: SignalTemplate<U>)(template: SignalTemplate<T>) -> SignalTemplate<U>
func zipWith<T, U>(otherTemplate: SignalTemplate<U>)(template: SignalTemplate<T>) -> SignalTemplate<(T, U)>
