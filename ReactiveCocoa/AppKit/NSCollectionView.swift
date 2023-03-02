#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import ReactiveSwift

extension Reactive where Base: NSCollectionView {
	public var reloadData: BindingTarget<()> {
		return makeBindingTarget { base, _ in base.reloadData() }
	}
}
#endif
