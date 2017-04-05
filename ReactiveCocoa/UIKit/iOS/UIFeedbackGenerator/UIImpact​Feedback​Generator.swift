import ReactiveSwift
import UIKit

@available(iOS 10.0, *)
extension Reactive where Base: UIImpactFeedbackGenerator {
	/// Prepares the feedback generator.
	public var impactOccurred: BindingTarget<Void> {
		return makeBindingTarget { generator, _ in
			generator.impactOccurred()
		}
	}
}
