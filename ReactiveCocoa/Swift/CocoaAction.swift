import Foundation
import ReactiveSwift

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
	public private(set) var isEnabled: Bool = false
	
	/// Whether the action is executing.
	///
	/// This property will only change on the main thread, and will generate a
	/// KVO notification for every change.
	public private(set) var isExecuting: Bool = false
	
	private let _execute: (AnyObject?) -> Void
	private let disposable = CompositeDisposable()
	
	/// Initializes a Cocoa action that will invoke the given Action by
	/// transforming the object given to execute().
	///
	/// - note: You must cast the passed in object to the control type you need
	///         since there is no way to know where this cocoa action will be
	///         added as a target.
	///
	/// - parameters:
	///   - action: Executable action.
	///   - inputTransform: Closure that accepts the UI control performing the
	///                     action and returns a value (e.g. 
	///                     `(UISwitch) -> (Bool)` to reflect whether a provided
	///                     switch is currently on.
	public init<Input, Output, Error>(_ action: Action<Input, Output, Error>, _ inputTransform: @escaping (AnyObject?) -> Input) {
		_execute = { input in
			let producer = action.apply(inputTransform(input))
			producer.start()
		}
		
		super.init()
		
		disposable += action.isEnabled.producer
			.observe(on: UIScheduler())
			.startWithValues { [weak self] value in
				self?.willChangeValue(forKey: #keyPath(CocoaAction.isEnabled))
				self?.isEnabled = value
				self?.didChangeValue(forKey: #keyPath(CocoaAction.isEnabled))
		}
		
		disposable += action.isExecuting.producer
			.observe(on: UIScheduler())
			.startWithValues { [weak self] value in
				self?.willChangeValue(forKey: #keyPath(CocoaAction.isExecuting))
				self?.isExecuting = value
				self?.didChangeValue(forKey: #keyPath(CocoaAction.isExecuting))
		}
	}
	
	/// Initializes a Cocoa action that will invoke the given Action by always
	/// providing the given input.
	///
	/// - parameters:
	///   - action: Executable action.
	///   - input: A value given as input to the action.
	public convenience init<Input, Output, Error>(_ action: Action<Input, Output, Error>, input: Input) {
		self.init(action, { _ in input })
	}
	
	deinit {
		disposable.dispose()
	}
	
	/// Attempts to execute the underlying action with the given input, subject
	/// to the behavior described by the initializer that was used.
	///
	/// - parameters:
	///   - input: A value for the action passed during initialization.
	@IBAction public func execute(_ input: AnyObject?) {
		_execute(input)
	}
	
	public override class func automaticallyNotifiesObservers(forKey key: String) -> Bool {
		return false
	}
}

extension Action {
	/// A UI bindable `CocoaAction`.
	///
	/// - warning: The default behavior force casts the `AnyObject?` input to 
	///            match the action's `Input` type. This makes it unsafe for use 
	///            when the action is parameterized for something like `Void` 
	///            input. In those cases, explicitly assign a value to this
	///            property that transforms the input to suit your needs.
	public var unsafeCocoaAction: CocoaAction {
		return CocoaAction(self) { $0 as! Input }
	}
}
