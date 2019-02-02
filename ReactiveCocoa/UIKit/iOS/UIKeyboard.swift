import UIKit
import ReactiveSwift
import enum Result.NoError

/// The type of system keyboard events.
public enum KeyboardEvent {
	case willShow
	case didShow
	case willHide
	case didHide
	case willChangeFrame
	case didChangeFrame
	
	/// The name of the notification to observe system keyboard events.
	fileprivate var notificationName: Notification.Name {
		switch self {
		case .willShow:
			return .UIKeyboardWillShow
		case .didShow:
			return .UIKeyboardDidShow
		case .willHide:
			return .UIKeyboardWillHide
		case .didHide:
			return .UIKeyboardDidHide
		case .willChangeFrame:
			return .UIKeyboardWillChangeFrame
		case .didChangeFrame:
			return .UIKeyboardDidChangeFrame
		}
	}
}

/// The context of an upcoming change in the frame of the system keyboard.
public struct KeyboardChangeContext {
	private let base: [AnyHashable: Any]
	
	/// The event type of the system keyboard.
	public let event: KeyboardEvent

	/// The current frame of the system keyboard.
	public var beginFrame: CGRect {
		return base[UIKeyboardFrameBeginUserInfoKey] as! CGRect
	}

	/// The final frame of the system keyboard.
	public var endFrame: CGRect {
		return base[UIKeyboardFrameEndUserInfoKey] as! CGRect
	}

	/// The animation curve which the system keyboard will use to animate the
	/// change in its frame.
	public var animationCurve: UIViewAnimationCurve {
		let value = base[UIKeyboardAnimationCurveUserInfoKey] as! NSNumber
		return UIViewAnimationCurve(rawValue: value.intValue)!
	}

	/// The duration in which the system keyboard expects to animate the change in
	/// its frame.
	public var animationDuration: Double {
		return base[UIKeyboardAnimationDurationUserInfoKey] as! Double
	}

	/// Indicates whether the change is triggered locally. Used in iPad
	/// multitasking, where all foreground apps would be notified of any changes
	/// in the system keyboard's frame.
	@available(iOS 9.0, *)
	public var isLocal: Bool {
		return base[UIKeyboardIsLocalUserInfoKey] as! Bool
	}

	fileprivate init(userInfo: [AnyHashable: Any], event: KeyboardEvent) {
		base = userInfo
		self.event = event
	}
}

extension Reactive where Base: NotificationCenter {
	/// Create a `Signal` that notifies whenever the system keyboard announce specified event.
	///
	/// - parameters:
	///   - event:  The type of system keyboard event to observe.
	///
	/// - returns: A `Signal` that emits the context of system keyboard event.
	public func keyboard(_ event: KeyboardEvent) -> Signal<KeyboardChangeContext, NoError> {
		return notifications(forName: event.notificationName)
			.map { notification in KeyboardChangeContext(userInfo: notification.userInfo!, event: event) }
	}
	
	/// Create a `Signal` that notifies whenever the system keyboard announces specified events.
	///
	/// - parameters:
	///   - first: First type of system keyboard event to observe.
	///   - second: Second type of system keyboard event to observe.
	///   - tail: Rest of the types of system keyboard events to observe.
	///
	/// - returns: A `Signal` that emits the context of system keyboard events.
	public func keyboard(_ first: KeyboardEvent, _ second: KeyboardEvent, _ tail: KeyboardEvent...) -> Signal<KeyboardChangeContext, NoError> {
		let events = [first, second] + tail
		return .merge(events.map(keyboard))
	}
	
	/// Create a `Signal` that notifies whenever the system keyboard announces an
	/// upcoming change in its frame.
	///
	/// - returns: A `Signal` that emits the context of every change in the
	///            system keyboard's frame.
	public var keyboardChange: Signal<KeyboardChangeContext, NoError> {
		return keyboard(.willChangeFrame)
	}
}
