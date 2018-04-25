import ReactiveSwift
import UIKit

extension Reactive where Base: UIViewController {
	/// Set's the title of the view controller.
	public var title: BindingTarget<String?> {
		return makeBindingTarget({ $0.title = $1 })
	}
}
