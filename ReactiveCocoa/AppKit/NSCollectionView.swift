import AppKit
import ReactiveSwift

extension Reactive where Base: NSCollectionView {
	@available(macOS 10.11, *)
	public var reloadData: BindingTarget<()> {
		return makeBindingTarget { base, _ in base.reloadData() }
	}
}
