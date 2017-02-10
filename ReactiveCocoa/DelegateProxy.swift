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

	func intercept(_ selector: Selector) -> Signal<[Any?], NoError> {
		interceptedSelectors.insert(selector)
		originalSetter(self)
		return self.reactive.signal(for: selector)
	}

	override func responds(to selector: Selector!) -> Bool {
		if interceptedSelectors.contains(selector) {
			return true
		}

		return forwardee?.responds(to: selector) ?? super.responds(to: selector)
	}
}

private let hasSwizzledKey = AssociationKey<Bool>(default: false)

extension DelegateProxy {
	// FIXME: This is a workaround to a compiler issue, where any use of `Self`
	//        through a protocol would result in the following error messages:
	//        1. PHI node operands are not the same type as the result!
	//        2. LLVM ERROR: Broken function found, compilation aborted!
	internal static func proxy<P: DelegateProxy<Delegate>>(
		for instance: NSObject,
		setter: Selector,
		getter: Selector,
		_ key: StaticString = #function
	) -> P {
		return _proxy(for: instance, setter: setter, getter: getter, key) as! P
	}

	private static func _proxy(
		for instance: NSObject,
		setter: Selector,
		getter: Selector,
		_ key: StaticString = #function
	) -> AnyObject {
		let key = AssociationKey<DelegateProxy<Delegate>?>(key)

		return instance.synchronized {
			if let proxy = instance.associations.value(forKey: key) {
				return proxy
			}

			let subclass: AnyClass = swizzleClass(instance)

			// Hide the original setter, and redirect subsequent delegate assignment
			// to the proxy.
			try! ReactiveCocoa.synchronized(subclass) {
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
			let originalSetterImpl: IMP = class_getMethodImplementation(realClass, setter)
			let getterImpl: IMP = class_getMethodImplementation(realClass, getter)

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

			let original = unsafeBitCast(getterImpl, to: Getter.self)(instance, getter) as! Delegate?
			proxy.forwardee = original

			unsafeBitCast(originalSetterImpl, to: Setter.self)(instance, setter, proxy)
			
			return proxy
		}
	}
}
