import UIKit
import ReactiveSwift
import enum Result.NoError

/// The context of an upcoming change in the frame of the system keyboard.
public struct KeyboardChangeContext {
	private let base: [AnyHashable: Any]

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
		return base[UIKeyboardAnimationCurveUserInfoKey] as! UIViewAnimationCurve
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

	fileprivate init(_ userInfo: [AnyHashable: Any]) {
		base = userInfo
	}
}

extension Reactive where Base: NotificationCenter {
	/// Create a `Signal` that notifies whenever the system keyboard announces an
	/// upcoming change in its frame.
	///
	/// - returns: A `Signal` that emits the context of every change in the
	///            system keyboard's frame.
	public var keyboardChange: Signal<KeyboardChangeContext, NoError> {
		return notifications(forName: .UIKeyboardWillChangeFrame)
			.map { notification in KeyboardChangeContext(notification.userInfo!) }
	}
}
