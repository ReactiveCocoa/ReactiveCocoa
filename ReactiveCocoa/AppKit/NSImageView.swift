#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import ReactiveSwift

extension Reactive where Base: NSImageView {
	/// Sets the currently displayed image
	public var image: BindingTarget<NSImage?> {
		return makeBindingTarget { $0.image = $1 }
	}
}
#endif
