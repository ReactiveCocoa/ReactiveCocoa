import Foundation
import ReactiveSwift

internal protocol NSObjectBindingTargetProtocol: class {
	var rac_lifetime: Lifetime { get }
}

extension NSObjectBindingTargetProtocol {
	/// Creates a binding target which uses the lifetime of `self`, and weakly
	/// references `self` so that the supplied `action` is triggered only if
	/// `self` has not deinitialized.
	///
	/// - important: The resulting binding target is bound to the main queue.
	///
	/// - parameters:
	///   - action: The action to consume values from the bindings.
	///
	/// - returns:
	///   A binding target that holds no strong references to `self`.
	internal func bindingTarget<U>(action: @escaping (Self, U) -> Void) -> BindingTarget<U> {
		return BindingTarget(on: .main, lifetime: rac_lifetime) { [weak self] value in
			if let strongSelf = self {
				action(strongSelf, value)
			}
		}
	}
}

extension NSObject: NSObjectBindingTargetProtocol {}
