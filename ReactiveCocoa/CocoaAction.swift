import Foundation
import ReactiveSwift
import enum Result.NoError

/// Wraps an Action for use by a GUI control (such as `NSControl` or
/// `UIControl`), with KVO, or with Cocoa Bindings.
public final class CocoaAction: NSObject {
	/// Creates an always disabled action that can be used as a default for
	/// things like `rac_pressed`.
	public static var disabled: CocoaAction {
		return CocoaAction(Action<Any?, (), NoError>(enabledIf: Property(value: false)) { _ in .empty },
		                   input: nil)
	}

	/// The selector that a caller should invoke upon a CocoaAction in order to
	/// execute it.
	public static let selector: Selector = #selector(CocoaAction.execute(_:))
	
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

		isEnabled = action.isEnabled
		isExecuting = action.isExecuting
		
		super.init()
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
