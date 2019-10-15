#if canImport(UIKit) && !os(watchOS)
import ReactiveSwift
import UIKit

extension Reactive where Base: UITableView {
	public var reloadData: BindingTarget<()> {
		return makeBindingTarget { base, _ in base.reloadData() }
	}
}
#endif
