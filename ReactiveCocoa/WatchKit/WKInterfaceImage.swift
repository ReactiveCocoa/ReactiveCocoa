import ReactiveSwift
import WatchKit

extension Reactive where Base: WKInterfaceImage {
	/// Sets the image.
	public var image: BindingTarget<UIImage?> {
		return makeBindingTarget { $0.setImage($1) }
	}
	
	/// Sets the data of the image.
	public var imageData: BindingTarget<Data?> {
		return makeBindingTarget { $0.setImageData($1) }
	}
	
	/// Sets the name of the image.
	public var imageNamed: BindingTarget<String?> {
		return makeBindingTarget { $0.setImageNamed($1) }
	}
	
	/// Sets the tint color of the template image.
	public var tintColor: BindingTarget<UIColor?> {
		return makeBindingTarget { $0.setTintColor($1) }
	}
}
