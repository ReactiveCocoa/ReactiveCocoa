import Foundation
import ReactiveSwift

extension Reactive where Base: AnyObject {
	/// Creates a binding target which uses the lifetime of the object, and 
	/// weakly references the object so that the supplied `action` is triggered 
	/// only if the object has not deinitialized.
	///
	/// - parameters:
	///   - scheduler: An optional scheduler that the binding target uses. If it
	///                is not specified, a UI scheduler would be used.
	///   - action: The action to consume values from the bindings.
	///
	/// - returns: A binding target that holds no strong references to the 
	///            object.
	public func makeBindingTarget<U>(on scheduler: Scheduler = UIScheduler(), _ action: @escaping (Base, U) -> Void) -> BindingTarget<U> {
		return BindingTarget(on: scheduler, lifetime: ReactiveCocoa.lifetime(of: base)) { [weak base = self.base] value in
			if let base = base {
				action(base, value)
			}
		}
	}
}

#if swift(>=3.2)
extension Reactive where Base: AnyObject {
	/// Creates a binding target that writes to the object with the given key path  on a
	/// `UIScheduler`.
	///
	/// - parameters:
	///   - keyPath: The key path to be written to.
	///
	/// - returns: A binding target.
	public subscript<Value>(keyPath: ReferenceWritableKeyPath<Base, Value>) -> BindingTarget<Value> {
		return BindingTarget(on: UIScheduler(), lifetime: ReactiveCocoa.lifetime(of: base), object: base, keyPath: keyPath)
	}

	/// Creates a binding target that writes to the object with the given key path.
	///
	/// - parameters:
	///   - keyPath: The key path to be written to.
	///   - scheduler: The scheduler to perform the write on.
	///
	/// - returns: A binding target.
	public subscript<Value>(keyPath: ReferenceWritableKeyPath<Base, Value>, on scheduler: Scheduler) -> BindingTarget<Value> {
		return BindingTarget(on: scheduler, lifetime: ReactiveCocoa.lifetime(of: base), object: base, keyPath: keyPath)
	}
}
#endif
