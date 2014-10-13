struct ColdSignal<T> {
	init(_ generator: SinkOf<Event<T>> -> ()) {}
	
	static func defer(action: () -> ColdSignal) -> ColdSignal {}
	static func single(value: T) -> ColdSignal {}
	static func error(error: NSError) -> ColdSignal {}
	static func empty() -> ColdSignal {}
	static func never() -> ColdSignal {}
	static func fromValues<S: SequenceType where S.Generator.Element == T>(values: S) -> ColdSignal {}
	static func fromEvents<S: SequenceType where S.Generator.Element == Event<T>>(events: S) -> ColdSignal {}
	
	func subscribe(next: T -> () = doNothing, error: NSError -> () = doNothing, completed: () -> () = doNothing) -> Disposable {}
	func subscribe(handler: Event<T> -> ()) -> Disposable {}
	
	func first() -> Result<T> {}
	func last() -> Result<T> {}
	func single() -> Result<T> {}
	func wait() -> Result<()> {}
	
	func map<U>(f: T -> U) -> ColdSignal<U> {}
	func filter(predicate: T -> Bool) -> ColdSignal {}
	func take(count: Int) -> ColdSignal {}
	func takeLast(count: Int) -> ColdSignal {}
	func takeUntil(trigger: HotSignal<()>) -> ColdSignal {}
	func takeUntilReplacement(replacement: ColdSignal) -> ColdSignal {}
	func takeWhile(predicate: T -> Bool) -> ColdSignal {}
	func skip(count: Int) -> ColdSignal {}
	func skipRepeats<U: Equatable>(evidence: ColdSignal -> ColdSignal<U>) -> ColdSignal<U> {}
	func skipWhile(predicate: T -> Bool) -> ColdSignal {}
	func sampleOn(sampler: HotSignal<()>) -> ColdSignal {}
	func deliverOn(scheduler: Scheduler) -> ColdSignal {}
	func subscribeOn(scheduler: Scheduler) -> ColdSignal {}
	func catch(handler: NSError -> ColdSignal) -> ColdSignal {}
	func throttle(interval: NSTimeInterval, onScheduler: DateScheduler) -> ColdSignal {}
	func delay(interval: NSTimeInterval, onScheduler: DateScheduler) -> ColdSignal {}
	func materialize() -> ColdSignal<Event<T>> {}
	func dematerialize<U>(evidence: ColdSignal -> ColdSignal<Event<U>>) -> ColdSignal<U> {}
	func scan<U>(#initial: U, _ f: (U, T) -> U) -> ColdSignal<U> {}
	func reduce<U>(#initial: U, _ f: (U, T) -> U) -> ColdSignal<U> {}
	func try(f: (T, NSErrorPointer) -> Bool) -> ColdSignal {}
	func tryMap<U>(f: (T, NSErrorPointer) -> U?) -> ColdSignal<U> {}
	func tryMap<U>(f: T -> Result<U>) -> ColdSignal<U> {}
	func timeout(interval: NSTimeInterval, onScheduler: DateScheduler) -> ColdSignal {}
	func on(next: T -> () = doNothing, error: NSError -> () = doNothing, completed: () -> () = doNothing, subscribed: () -> () = doNothing, terminated: () -> () = doNothing, disposed: () -> () = doNothing) -> ColdSignal {}
	
	func merge<U>(evidence: ColdSignal -> ColdSignal<ColdSignal<U>>) -> ColdSignal<U> {}
	func concat<U>(evidence: ColdSignal -> ColdSignal<ColdSignal<U>>) -> ColdSignal<U> {}
	func switchToLatest<U>(evidence: ColdSignal -> ColdSignal<ColdSignal<U>>) -> ColdSignal<U> {}
	func amb<U>(evidence: ColdSignal -> ColdSignal<ColdSignal<U>>) -> ColdSignal<U> {}
	func then<U>(signal: ColdSignal<U>) -> ColdSignal<U> {}
	
	func zipWith<U>(signal: ColdSignal<U>) -> ColdSignal<(T, U)> {}
	func zipWith<U>(signal: HotSignal<U>) -> ColdSignal<(T, U)> {}
	func combineLatestWith<U>(signal: ColdSignal<U>) -> ColdSignal<(T, U)> {}
	func combineLatestWith<U>(signal: HotSignal<U>) -> ColdSignal<(T, U)> {}
	
	func start(errorHandler: (NSError -> ())?, completionHandler: () -> () = doNothing) -> HotSignal<T> {}
}

final class HotSignal<T> {
	init(_ generator: SinkOf<T> -> ()) {}
	
	class func interval(interval: NSTimeInterval, onScheduler: DateScheduler) -> HotSignal<NSDate> {}
	class func pipe() -> (HotSignal, SinkOf<T>) {}
	
	func subscribe(next: T -> ()) -> Disposable {}
	func first() -> T {}
	
	func map<U>(f: T -> U) -> HotSignal<U> {}
	func filter(predicate: T -> Bool) -> HotSignal {}
	func take(count: Int) -> HotSignal {}
	func takeUntil(trigger: HotSignal<()>) -> HotSignal {}
	func takeUntilReplacement(replacement: HotSignal) -> HotSignal {}
	func takeWhile(predicate: T -> Bool) -> HotSignal {}
	func skip(count: Int) -> HotSignal {}
	func skipRepeats<U: Equatable>(evidence: HotSignal -> HotSignal<U>) -> HotSignal<U> {}
	func skipWhile(predicate: T -> Bool) -> HotSignal {}
	func sampleOn(sampler: HotSignal<()>) -> HotSignal {}
	func deliverOn(scheduler: Scheduler) -> HotSignal {}
	func throttle(interval: NSTimeInterval, onScheduler: DateScheduler) -> HotSignal {}
	func delay(interval: NSTimeInterval, onScheduler: DateScheduler) -> HotSignal {}
	func scan<U>(#initial: U, _ f: (U, T) -> U) -> HotSignal<U> {}
	
	func merge<U>(evidence: HotSignal -> HotSignal<HotSignal<U>>) -> HotSignal<U> {}
	func switchToLatest<U>(evidence: HotSignal -> HotSignal<HotSignal<U>>) -> HotSignal<U> {}
	func amb<U>(evidence: HotSignal -> HotSignal<HotSignal<U>>) -> HotSignal<U> {}
	
	func zipWith<U>(signal: HotSignal<U>) -> HotSignal<(T, U)> {}
	func combineLatestWith<U>(signal: HotSignal<U>) -> HotSignal<(T, U)> {}
	
	func buffer(capacity: Int) -> ColdSignal<T> {}
	func replay(capacity: Int) -> ColdSignal<T> {}
}