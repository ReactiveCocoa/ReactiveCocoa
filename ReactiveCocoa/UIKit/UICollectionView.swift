import ReactiveSwift
import UIKit

extension Reactive where Base: UICollectionView {
	public var reloadData: BindingTarget<()> {
		return makeBindingTarget { base, _ in base.reloadData() }
	}
}
