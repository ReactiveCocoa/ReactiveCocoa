import UIKit
import ReactiveSwift

@objc public protocol Reusable: class {
	func prepareForReuse()
}

extension Reactive where Base: NSObject, Base: Reusable {
	public var prepareForReuse: Signal<(), Never> {
		return trigger(for: #selector(base.prepareForReuse))
	}
}

extension UITableViewCell: Reusable {}
extension UITableViewHeaderFooterView: Reusable {}
extension UICollectionReusableView: Reusable {}
