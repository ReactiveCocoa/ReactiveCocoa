import ReactiveSwift
import UIKit

extension Reactive where Base: UIButton {
	/// The action to be triggered when the button is pressed. It also controls
	/// the enabled state of the button.
	public var pressed: CocoaAction<Base>? {
		get {
			return associatedAction.withValue { info in
				return info.flatMap { info in
					return info.controlEvents == .touchUpInside ? info.action : nil
				}
			}
		}

		nonmutating set {
			setAction(newValue, for: .touchUpInside)
		}
	}

	/// Sets the title of the button for its normal state.
	public var title: BindingTarget<String> {
		return makeBindingTarget { $0.setTitle($1, for: .normal) }
	}

	/// Sets the title of the button for the specified state.
	public func title(for state: UIControlState) -> BindingTarget<String> {
		return makeBindingTarget { $0.setTitle($1, for: state) }
	}

	/// Sets the image of the button for the specified state.
	public func image(for state: UIControlState) -> BindingTarget<UIImage?> {
		return makeBindingTarget { $0.setImage($1, for: state) }
	}

	public var image: BindingTarget<UIImage?> {
		return image(for: .normal)
	}
}
