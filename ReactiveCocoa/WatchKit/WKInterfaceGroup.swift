import ReactiveSwift
import WatchKit

extension Reactive where Base: WKInterfaceGroup {
	/// Sets the background color of the group.
	public var backgroundColor: BindingTarget<UIColor?> {
		return makeBindingTarget { $0.setBackgroundColor($1) }
	}
	
	/// Sets the background image of the group.
	public var backgroundImage: BindingTarget<UIImage?> {
		return makeBindingTarget { $0.setBackgroundImage($1) }
	}
	
	/// Sets the background image data of the group.
	public var backgroundImageData: BindingTarget<Data?> {
		return makeBindingTarget { $0.setBackgroundImageData($1) }
	}
	
	/// Sets the background named image of the group.
	public var backgroundImageNamed: BindingTarget<String?> {
		return makeBindingTarget { $0.setBackgroundImageNamed($1) }
	}
	
	/// Sets the corner radius of the group.
	public var cornerRadius: BindingTarget<CGFloat> {
		return makeBindingTarget { $0.setCornerRadius($1) }
	}
	
	/// Sets the content inset of the group.
	public var contentInset: BindingTarget<UIEdgeInsets> {
		return makeBindingTarget { $0.setContentInset($1) }
	}
}
