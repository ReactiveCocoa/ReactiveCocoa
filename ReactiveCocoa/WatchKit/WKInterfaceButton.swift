import ReactiveSwift
import WatchKit

extension Reactive where Base: WKInterfaceButton {
	/// Sets the title of the button.
	public var text: BindingTarget<String?> {
		return makeBindingTarget { $0.setTitle($1) }
	}
	
	/// Sets the attributed title of the button.
	public var attributedTitle: BindingTarget<NSAttributedString?> {
		return makeBindingTarget { $0.setAttributedTitle($1) }
	}
	
	/// Sets the background color of the button.
	public var backgroundColor: BindingTarget<UIColor?> {
		return makeBindingTarget { $0.setBackgroundColor($1) }
	}
	
	/// Sets the background image of the button.
	public var backgroundImage: BindingTarget<UIImage?> {
		return makeBindingTarget { $0.setBackgroundImage($1) }
	}
	
	/// Sets the background image data of the button.
	public var backgroundImageData: BindingTarget<Data?> {
		return makeBindingTarget { $0.setBackgroundImageData($1) }
	}
	
	/// Sets the background named image of the button.
	public var backgroundImageNamed: BindingTarget<String?> {
		return makeBindingTarget { $0.setBackgroundImageNamed($1) }
	}
	
	/// Sets whether the button is enabled.
	public var isEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.setEnabled($1) }
	}
}
