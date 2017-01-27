import ReactiveSwift
import enum Result.NoError

internal class DelegateProxy<Delegate: NSObjectProtocol>: NSObject {
	internal weak var forwardee: Delegate? {
		didSet {
			originalSetter(self)
		}
	}

	internal var interceptedSelectors: Set<Selector> = []

	private let originalSetter: (AnyObject) -> Void

	required init(_ originalSetter: @escaping (AnyObject) -> Void) {
		self.originalSetter = originalSetter
	}

	override func forwardingTarget(for selector: Selector!) -> Any? {
		return interceptedSelectors.contains(selector) ? nil : forwardee
	}

	func intercept(_ selector: Selector) -> Signal<(), NoError> {
		interceptedSelectors.insert(selector)
		originalSetter(self)
		return self.reactive.trigger(for: selector)
	}

	override func responds(to selector: Selector!) -> Bool {
		if interceptedSelectors.contains(selector) {
			return true
		}

		return forwardee?.responds(to: selector) ?? super.responds(to: selector)
	}
}

private let hasSwizzledKey = AssociationKey<Bool>(default: false)

internal protocol DelegateProxyProtocol: class {
	associatedtype Delegate: NSObjectProtocol

	weak var forwardee: Delegate? { get set }

	init(_ originalSetter: @escaping (AnyObject) -> Void)
}

extension DelegateProxy: DelegateProxyProtocol {}

extension DelegateProxyProtocol {
	internal static func proxy(for instance: NSObject, setter: Selector, getter: Selector, _ key: AssociationKey<Self?>) -> Self {
		return instance.synchronized {
			if let proxy = instance.associations.value(forKey: key) {
				return proxy
			}

			let subclass: AnyClass = swizzleClass(instance)

			// Hide the original setter, and redirect subsequent delegate assignment
			// to the proxy.
			synchronized(subclass) {
				let subclassAssociations = Associations(subclass as AnyObject)

				if !subclassAssociations.value(forKey: hasSwizzledKey) {
					subclassAssociations.setValue(true, forKey: hasSwizzledKey)

					let method = class_getInstanceMethod(subclass, setter)
					let typeEncoding = method_getTypeEncoding(method)!

					let newSetterImpl: @convention(block) (NSObject, NSObject) -> Void = { object, delegate in
						let proxy = object.associations.value(forKey: key)!
						proxy.forwardee = (delegate as! Delegate)
					}

					class_replaceMethod(subclass,
					                    setter,
					                    imp_implementationWithBlock(newSetterImpl as Any),
					                    typeEncoding)
				}
			}

			// Set the proxy as the delegate.
			let realClass: AnyClass = class_getSuperclass(subclass)
			let originalSetterImpl = class_getMethodImplementation(realClass, setter)
			let getterImpl = class_getMethodImplementation(realClass, getter)

			typealias Setter = @convention(c) (AnyObject, Selector, AnyObject) -> Void
			typealias Getter = @convention(c) (AnyObject, Selector) -> NSObject?

			// As Objective-C classes may cache the information of their delegate at
			// the time the delegates are set, the information has to be "flushed"
			// whenever the proxy forwardee is replaced or a selector is intercepted.
			let proxy = self.init { [weak instance] proxy in
				guard let instance = instance else { return }
				unsafeBitCast(originalSetterImpl, to: Setter.self)(instance, setter, proxy)
			}

			instance.associations.setValue(proxy, forKey: key)

			proxy.forwardee = unsafeBitCast(getterImpl, to: Getter.self)(instance, getter) as! Delegate?
			unsafeBitCast(originalSetterImpl, to: Setter.self)(instance, setter, proxy)
			
			return proxy
		}
	}
}
