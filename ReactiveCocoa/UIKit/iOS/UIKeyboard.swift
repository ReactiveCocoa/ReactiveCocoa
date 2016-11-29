import UIKit
import ReactiveSwift
import enum Result.NoError

public struct KeyboardChangeContext {
	private let base: [AnyHashable: Any]

	public var beginFrame: CGRect {
		return base[UIKeyboardFrameBeginUserInfoKey] as! CGRect
	}

	public var endFrame: CGRect {
		return base[UIKeyboardFrameEndUserInfoKey] as! CGRect
	}

	public var animationCurve: UIViewAnimationCurve {
		return base[UIKeyboardAnimationCurveUserInfoKey] as! UIViewAnimationCurve
	}

	public var animationDuration: Double {
		return base[UIKeyboardAnimationDurationUserInfoKey] as! Double
	}

	@available(iOS 9.0, *)
	public var isLocal: Bool {
		return base[UIKeyboardIsLocalUserInfoKey] as! Bool
	}

	fileprivate init(_ userInfo: [AnyHashable: Any]) {
		base = userInfo
	}
}

extension Reactive where Base: UIView {
	public static var keyboardChange: Signal<KeyboardChangeContext, NoError> {
		return NotificationCenter.default.reactive
			.notifications(forName: .UIKeyboardWillChangeFrame)
			.map { notification in KeyboardChangeContext(notification.userInfo!) }
	}
}
