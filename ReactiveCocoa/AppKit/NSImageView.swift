import ReactiveSwift
import enum Result.NoError
import AppKit

extension Reactive where Base: NSImageView {
	/// Sets the currently displayed image
	public var image: BindingTarget<NSImage?> {
		return makeBindingTarget { $0.image = $1 }
	}
}
