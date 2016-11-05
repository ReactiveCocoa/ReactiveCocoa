import AppKit
import ReactiveSwift

extension Reactive where Base: NSTableView {
	public var reloadData: BindingTarget<()> {
		return makeBindingTarget { base, _ in base.reloadData() }
	}
}
