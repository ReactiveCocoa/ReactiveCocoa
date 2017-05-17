import Foundation
import ReactiveSwift
import enum Result.NoError

/// CocoaAction wraps an `Action` for use by a UI control (such as `NSControl` or
/// `UIControl`).
public final class CocoaAction<Sender>: NSObject {
	/// The selector for message senders.
	public static var selector: Selector {
		return #selector(CocoaAction<Sender>.execute(_:))
	}

	/// Whether the action is enabled.
	///
	/// This property will only change on the main thread.
	public let isEnabled: Property<Bool>
	
	/// Whether the action is executing.
	///
	/// This property will only change on the main thread.
	public let isExecuting: Property<Bool>

	private let _execute: (Sender) -> Void

	/// Initialize a CocoaAction that invokes the given Action by mapping the
	/// sender to the input type of the Action.
	///
	/// - parameters:
	///   - action: The Action.
	///   - inputTransform: A closure that maps Sender to the input type of the
	///                     Action.
	public init<Input, Output, Error>(_ action: Action<Input, Output, Error>, _ inputTransform: @escaping (Sender) -> Input) {
		_execute = { sender in
			let producer = action.apply(inputTransform(sender))
			producer.start()
		}

		isEnabled = Property(initial: action.isEnabled.value,
		                     then: action.isEnabled.producer.observe(on: UIScheduler()))
		isExecuting = Property(initial: action.isExecuting.value,
		                       then: action.isExecuting.producer.observe(on: UIScheduler()))

		super.init()
	}

	/// Initialize a CocoaAction that invokes the given Action.
	///
	/// - parameters:
	///   - action: The Action.
	public convenience init<Output, Error>(_ action: Action<(), Output, Error>) {
		self.init(action, { _ in })
	}
	
	/// Initialize a CocoaAction that invokes the given Action with the given
	/// constant.
	///
	/// - parameters:
	///   - action: The Action.
	///   - input: The constant value as the input to the action.
	public convenience init<Input, Output, Error>(_ action: Action<Input, Output, Error>, input: Input) {
		self.init(action, { _ in input })
	}

	/// Attempt to execute the underlying action with the given input, subject
	/// to the behavior described by the initializer that was used.
	///
	/// - parameters:
	///   - sender: The sender which initiates the attempt.
	@IBAction public func execute(_ sender: Any) {
		_execute(sender as! Sender)
	}
}
