import Foundation
import ReactiveSwift
import enum Result.NoError

/// Wraps an Action for use by a GUI control (such as `NSControl` or
/// `UIControl`), with KVO, or with Cocoa Bindings.
///
/// - important: The `Action` is weakly referenced.
public final class CocoaAction<Control>: NSObject {
	/// The selector for message senders.
	public static var selector: Selector {
		return #selector(CocoaAction<Control>.execute(_:))
	}

	/// Whether the action is enabled.
	///
	/// This property will only change on the main thread, and will generate a
	/// KVO notification for every change.
	public let isEnabled: Property<Bool>
	
	/// Whether the action is executing.
	///
	/// This property will only change on the main thread, and will generate a
	/// KVO notification for every change.
	public let isExecuting: Property<Bool>

	private let _execute: (AnyObject?) -> Void

	/// Initializes a Cocoa action that will invoke the given Action by
	/// transforming the object given to execute().
	///
	/// - important: The `Action` is weakly referenced.
	///
	/// - parameters:
	///   - action: Executable action.
	///   - inputTransform: Closure that accepts the UI control performing the
	///                     action and returns a value (e.g. 
	///                     `(UISwitch) -> (Bool)` to reflect whether a provided
	///                     switch is currently on.
	public init<Input, Output, Error>(_ action: Action<Input, Output, Error>, _ inputTransform: @escaping (Control) -> Input) {
		_execute = { [weak action] input in
			if let action = action {
				let control = input as! Control
				let producer = action.apply(inputTransform(control))
				producer.start()
			}
		}

		isEnabled = action.isEnabled
		isExecuting = action.isExecuting
		
		super.init()
	}

	/// Initializes a Cocoa action that will invoke the given Action.
	///
	/// - parameters:
	///   - action: Executable action.
	public convenience init<Output, Error>(_ action: Action<(), Output, Error>) {
		self.init(action, { _ in })
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

	/// Attempts to execute the underlying action with the given input, subject
	/// to the behavior described by the initializer that was used.
	///
	/// - parameters:
	///   - input: A value for the action passed during initialization.
	@IBAction public func execute(_ input: AnyObject?) {
		_execute(input)
	}
}
