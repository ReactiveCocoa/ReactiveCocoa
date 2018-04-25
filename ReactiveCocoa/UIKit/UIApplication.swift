import ReactiveSwift
import UIKit

extension Reactive where Base: UIApplication {
	/// Sets the number as the badge of the app icon in Springboard.
	public var applicationIconBadgeNumber: BindingTarget<Int> {
		return makeBindingTarget({ $0.applicationIconBadgeNumber = $1 })
	}
}
