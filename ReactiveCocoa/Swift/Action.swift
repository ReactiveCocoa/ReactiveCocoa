/// Represents an action that will do some work when executed with a value of
/// type `Input`, then return zero or more values of type `Output` and/or error
/// out with an error of type `Error`. If no errors should be possible, NoError
/// can be specified for the `Error` parameter.
///
/// Actions enforce serial execution. Any attempt to execute an action multiple
/// times concurrently will return an error.
public final class Action<Input, Output, Error: ErrorType> {
	private let executeClosure: Input -> SignalProducer<Output, Error>
	private let eventsObserver: Signal<Event<Output, Error>, NoError>.Observer

	/// A signal of all events generated from applications of the Action.
	///
	/// In other words, this will send every `Event` from every signal generated
	/// by each SignalProducer returned from apply().
	public let events: Signal<Event<Output, Error>, NoError>

	/// A signal of all values generated from applications of the Action.
	///
	/// In other words, this will send every value from every signal generated
	/// by each SignalProducer returned from apply().
	public let values: Signal<Output, NoError>

	/// A signal of all errors generated from applications of the Action.
	///
	/// In other words, this will send errors from every signal generated by
	/// each SignalProducer returned from apply().
	public let errors: Signal<Error, NoError>

	/// Whether the action is currently executing.
	public var executing: PropertyOf<Bool> {
		return PropertyOf(_executing)
	}

	private let _executing: MutableProperty<Bool> = MutableProperty(false)

	/// Whether the action is currently enabled.
	public var enabled: PropertyOf<Bool> {
		return PropertyOf(_enabled)
	}

	private let _enabled: MutableProperty<Bool> = MutableProperty(false)

	/// Whether the instantiator of this action wants it to be enabled.
	private let userEnabled: PropertyOf<Bool>

	/// Lazy creation and storage of a UI bindable `CocoaAction`. The default behavior
	/// force casts the AnyObject? input to match the action's `Input` type. This makes
	/// it unsafe for use when the action is parameterized for something like `Void`
	/// input. In those cases, explicitly assign a value to this property that transforms
	/// the input to suit your needs.
	public lazy var unsafeCocoaAction: CocoaAction = CocoaAction(self) { $0 as! Input }

	/// This queue is used for read-modify-write operations on the `_executing`
	/// property.
	private let executingQueue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.Action.executingQueue", DISPATCH_QUEUE_SERIAL)

	/// Whether the action should be enabled for the given combination of user
	/// enabledness and executing status.
	private static func shouldBeEnabled(userEnabled userEnabled: Bool, executing: Bool) -> Bool {
		return userEnabled && !executing
	}

	/// Initializes an action that will be conditionally enabled, and create a
	/// SignalProducer for each input.
	public init<P: PropertyType where P.Value == Bool>(enabledIf: P, _ execute: Input -> SignalProducer<Output, Error>) {
		executeClosure = execute
		userEnabled = PropertyOf(enabledIf)

		(events, eventsObserver) = Signal<Event<Output, Error>, NoError>.pipe()

		values = events.map { $0.value }.ignoreNil()
		errors = events.map { $0.error }.ignoreNil()

		_enabled <~ enabledIf.producer
			.combineLatestWith(executing.producer)
			.map(Action.shouldBeEnabled)
	}

	/// Initializes an action that will be enabled by default, and create a
	/// SignalProducer for each input.
	public convenience init(_ execute: Input -> SignalProducer<Output, Error>) {
		self.init(enabledIf: ConstantProperty(true), execute)
	}

	deinit {
		sendCompleted(eventsObserver)
	}

	/// Creates a SignalProducer that, when started, will execute the action
	/// with the given input, then forward the results upon the produced Signal.
	///
	/// If the action is disabled when the returned SignalProducer is started,
	/// the produced signal will send `ActionError.NotEnabled`, and nothing will
	/// be sent upon `values` or `errors` for that particular signal.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func apply(input: Input) -> SignalProducer<Output, ActionError<Error>> {
		return SignalProducer { observer, disposable in
			var startedExecuting = false

			dispatch_sync(self.executingQueue) {
				if self._enabled.value {
					self._executing.value = true
					startedExecuting = true
				}
			}

			if !startedExecuting {
				sendError(observer, .NotEnabled)
				return
			}

			self.executeClosure(input).startWithSignal { signal, signalDisposable in
				disposable.addDisposable(signalDisposable)

				signal.observe { event in
					observer(event.mapError { .ProducerError($0) })
					sendNext(self.eventsObserver, event)
				}
			}

			disposable.addDisposable {
				self._executing.value = false
			}
		}
	}
}

/// Wraps an Action for use by a GUI control (such as `NSControl` or
/// `UIControl`), with KVO, or with Cocoa Bindings.
public final class CocoaAction: NSObject {
	/// The selector that a caller should invoke upon a CocoaAction in order to
	/// execute it.
	public static let selector: Selector = "execute:"

	/// Whether the action is enabled.
	///
	/// This property will only change on the main thread, and will generate a
	/// KVO notification for every change.
	public var enabled: Bool {
		return _enabled
	}

	/// Whether the action is executing.
	///
	/// This property will only change on the main thread, and will generate a
	/// KVO notification for every change.
	public var executing: Bool {
		return _executing
	}

	private var _enabled = false
	private var _executing = false
	private let _execute: AnyObject? -> ()
	private let disposable = CompositeDisposable()

	/// Initializes a Cocoa action that will invoke the given Action by
	/// transforming the object given to execute().
	public init<Input, Output, Error>(_ action: Action<Input, Output, Error>, _ inputTransform: AnyObject? -> Input) {
		_execute = { input in
			let producer = action.apply(inputTransform(input))
			producer.start()
		}

		super.init()

		disposable += action.enabled.producer
			.observeOn(UIScheduler())
			.startWithNext { [weak self] value in
				self?.willChangeValueForKey("enabled")
				self?._enabled = value
				self?.didChangeValueForKey("enabled")
		}

		disposable += action.executing.producer
			.observeOn(UIScheduler())
			.startWithNext { [weak self] value in
				self?.willChangeValueForKey("executing")
				self?._executing = value
				self?.didChangeValueForKey("executing")
		}
	}

	/// Initializes a Cocoa action that will invoke the given Action by
	/// always providing the given input.
	public convenience init<Input, Output, Error>(_ action: Action<Input, Output, Error>, input: Input) {
		self.init(action, { _ in input })
	}

	deinit {
		disposable.dispose()
	}

	/// Attempts to execute the underlying action with the given input, subject
	/// to the behavior described by the initializer that was used.
	@IBAction public func execute(input: AnyObject?) {
		_execute(input)
	}

	public override class func automaticallyNotifiesObserversForKey(key: String) -> Bool {
		return false
	}
}

/// The type of error that can occur from Action.apply, where `E` is the type of
/// error that can be generated by the specific Action instance.
public enum ActionError<E: ErrorType>: ErrorType {
	/// The producer returned from apply() was started while the Action was
	/// disabled.
	case NotEnabled

	/// The producer returned from apply() sent the given error.
	case ProducerError(E)
}

public func == <E: Equatable>(lhs: ActionError<E>, rhs: ActionError<E>) -> Bool {
	switch (lhs, rhs) {
	case (.NotEnabled, .NotEnabled):
		return true

	case let (.ProducerError(left), .ProducerError(right)):
		return left == right

	default:
		return false
	}
}
