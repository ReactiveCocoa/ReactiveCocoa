import Foundation
import enum Result.NoError

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

	/// Initializes a Cocoa action that will invoke the given Action by
	/// transforming the object given to execute().
	public init<Input, Output, Error>(_ action: Action<Input, Output, Error>, _ inputTransform: (AnyObject?) -> Input) {
		_execute = { input in
			let producer = action.apply(inputTransform(input))
			producer.start()
		}
		
		super.init()

		let willDeinitProducer = rac_willDeallocSignal()
			.toSignalProducer()
			.map { _ in }
			.flatMapError { _ in SignalProducer<(), NoError>.empty }
		
		action.isEnabled.producer
			.takeUntil(willDeinitProducer)
			.observe(on: UIScheduler())
			.startWithNext { [weak self] value in
				self?.willChangeValue(forKey: #keyPath(CocoaAction.isEnabled))
				self?.isEnabled = value
				self?.didChangeValue(forKey: #keyPath(CocoaAction.isEnabled))
		}
		
		action.isExecuting.producer
			.takeUntil(willDeinitProducer)
			.observe(on: UIScheduler())
			.startWithNext { [weak self] value in
				self?.willChangeValue(forKey: #keyPath(CocoaAction.isExecuting))
				self?.isExecuting = value
				self?.didChangeValue(forKey: #keyPath(CocoaAction.isExecuting))
		}
	}
	
	/// Initializes a Cocoa action that will invoke the given Action by
	/// always providing the given input.
	public convenience init<Input, Output, Error>(_ action: Action<Input, Output, Error>, input: Input) {
		self.init(action, { _ in input })
	}

	/// Attempts to execute the underlying action with the given input, subject
	/// to the behavior described by the initializer that was used.
	@IBAction public func execute(_ input: AnyObject?) {
		_execute(input)
	}
	
	public override class func automaticallyNotifiesObservers(forKey key: String) -> Bool {
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
