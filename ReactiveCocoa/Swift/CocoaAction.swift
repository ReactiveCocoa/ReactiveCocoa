import Foundation

/// Wraps an Action for use by a GUI control (such as `NSControl` or
/// `UIControl`), with KVO, or with Cocoa Bindings.
public final class CocoaAction: NSObject {
	/// The selector that a caller should invoke upon a CocoaAction in order to
	/// execute it.
	public static let selector: Selector = #selector(CocoaAction.execute(_:))
	
	/// Whether the action is enabled.
	///
	/// This property will only change on the main thread, and will generate a
	/// KVO notification for every change.
	public private(set) var enabled: Bool = false
	
	/// Whether the action is executing.
	///
	/// This property will only change on the main thread, and will generate a
	/// KVO notification for every change.
	public private(set) var executing: Bool = false
	
	private let _execute: AnyObject? -> Void
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
				self?.enabled = value
				self?.didChangeValueForKey("enabled")
		}
		
		disposable += action.executing.producer
			.observeOn(UIScheduler())
			.startWithNext { [weak self] value in
				self?.willChangeValueForKey("executing")
				self?.executing = value
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

extension Action {
	/// A UI bindable `CocoaAction`. The default behavior force casts the
	/// AnyObject? input to match the action's `Input` type. This makes it
	/// unsafe for use when the action is parameterized for something like
	/// `Void` input. In those cases, explicitly assign a value to this property
	/// that transforms the input to suit your needs.
	public var unsafeCocoaAction: CocoaAction {
		return CocoaAction(self) { $0 as! Input }
	}
}
