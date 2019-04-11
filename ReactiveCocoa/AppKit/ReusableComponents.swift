import AppKit
import ReactiveSwift

extension Reactive where Base: NSView {
	public var prepareForReuse: Signal<(), Never> {
		return trigger(for: #selector(base.prepareForReuse))
	}
}

extension Reactive where Base: NSObject, Base: NSCollectionViewElement {
	@available(macOS 10.11, *)
	public var prepareForReuse: Signal<(), Never> {
		return trigger(for: #selector(base.prepareForReuse))
	}
}
