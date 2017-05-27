import ReactiveSwift
import enum Result.NoError

private let delegateProxySetupKey = AssociationKey<Set<Selector>?>(default: nil)
private let hasSwizzledKey = AssociationKey<Bool>(default: false)

public protocol DelegateProxyProtocol: class {}

// This is supposedly private, and is made `internal` to circumvent a serializer bug.
internal protocol _DelegateProxyProtocol: class {
	func proxyWillIntercept(_ selector: Selector)
	var lifetime: Lifetime { get }
}

public struct DelegateProxyConfiguration {
	fileprivate let objcProtocol: Protocol
	fileprivate let lifetime: Lifetime
	fileprivate let originalSetter: (AnyObject) -> Void
}

open class DelegateProxy<Delegate: NSObjectProtocol>: NSObject, DelegateProxyProtocol, _DelegateProxyProtocol {
	public final var delegateType: Delegate.Type {
		return Delegate.self
	}

	private final weak var _forwardee: AnyObject?

	public weak var forwardee: Delegate? {
		get { return _forwardee as! Delegate? }
		set { replace(newValue) }
	}

	internal final let lifetime: Lifetime

	private final let writeLock = NSLock()
	private final var implementedSelectors: Set<Selector>
	private final let originalSetter: (AnyObject) -> Void
	private final let objcProtocol: Protocol

	public required init(config: DelegateProxyConfiguration) {
		implementedSelectors = type(of: self).implementRequiredMethods(in: config.objcProtocol)

		objcProtocol = config.objcProtocol
		lifetime = config.lifetime
		originalSetter = config.originalSetter

		super.init()
	}

	open override func conforms(to aProtocol: Protocol) -> Bool {
		return aProtocol === objcProtocol || super.conforms(to: aProtocol)
	}

	open override func responds(to selector: Selector!) -> Bool {
		return implementedSelectors.contains(selector) || NSObject.instancesRespond(to: selector) || forwardee?.responds(to: selector) ?? false
	}

	// # Implementation Note
	//
	// Unlike method interception, the specialized `DelegateProxy` itself is swizzled but
	// not the runtime subclass.
	//
	// Implemented selectors are tracked per instance, since the class is shared among
	// multiple instances with varying level of conformances.

	internal final func proxyWillIntercept(_ selector: Selector) {
		writeLock.lock()
		defer { writeLock.unlock() }

		let subclass: AnyClass = swizzleClass(self)
		let perceivedClass: AnyClass = (type(of: self) as AnyObject).objcClass

		try! ReactiveCocoa.synchronized(subclass) {
			if class_getImmediateMethod(perceivedClass, selector) == nil {
				// All required methods should have been implemented. So we only implement
				// optional methods dynamically.
				let description = protocol_getMethodDescription(objcProtocol, selector, false, true)

				guard let typeEncoding = description.types else {
					fatalError("The selector `\(String(describing: selector))` does not exist.")
				}

				precondition(typeEncoding.pointee == Int8(UInt8(ascii: "v")),
							 "DelegateProxy does not support intercepting methods that returns non-void types.")

				let replacedImpl = class_replaceMethod(perceivedClass, selector, _rac_objc_msgForward, typeEncoding)

				precondition(replacedImpl == nil || replacedImpl == _rac_objc_msgForward,
							 "Swizzling DelegateProxy with other libraries is not supported.")
			}
		}

		implementedSelectors.insert(selector)
		originalSetter(self)
	}

	private final func replace(_ forwardee: Delegate?) {
		writeLock.lock()
		defer { writeLock.unlock() }

		// Implement new optional methods that `forwardee` reponds to. While we track what
		// selectors are no longer reachable, we cannot remove them from the class as
		// other proxy instances may rely on it.

		let subclass: AnyClass = swizzleClass(self)
		let perceivedClass: AnyClass = (self as AnyObject).objcClass

		try! ReactiveCocoa.synchronized(subclass) {
			var count: UInt32 = 0

			if let forwardee = forwardee, let list = protocol_copyMethodDescriptionList(objcProtocol, false, true, &count) {
				let buffer = UnsafeBufferPointer(start: list, count: Int(count))
				defer { free(list) }

				for method in buffer where forwardee.responds(to: method.name) && !implementedSelectors.contains(method.name) {
					let previousImpl = class_replaceMethod(perceivedClass, method.name, _rac_objc_msgForward, method.types)
					precondition(previousImpl == nil || previousImpl == _rac_objc_msgForward,
					             "Swizzling DelegateProxy with other libraries is not supported. \(perceivedClass)")
				}
			}
		}

		// The forwardee must be set after implementing methods, but before committing the
		// new set of selectors.
		_forwardee = forwardee

		// Inform the delegator that the conformances have changed.
		originalSetter(self)
	}

	fileprivate static func implementRequiredMethods(in objcProtocol: Protocol) -> Set<Selector> {
		let perceivedClass: AnyClass = (self as AnyObject).objcClass
		let classAssociations = Associations(perceivedClass as AnyObject)

		return try! ReactiveCocoa.synchronized(perceivedClass) {
			if let implementedSelectors = classAssociations.value(forKey: delegateProxySetupKey) {
				return implementedSelectors
			}

			var typeEncodings = [Selector: UnsafePointer<Int8>]()
			var implementedSelectors: Set<Selector> = []

			defer { classAssociations.setValue(implementedSelectors, forKey: delegateProxySetupKey) }

			// Implement `forwardInvocation`.
			let _forwardInvocation: @convention(block) (Unmanaged<AnyObject>, Unmanaged<AnyObject>) -> Void = { object, invocation in
				if let forwardee = (object.takeUnretainedValue() as! DelegateProxy<Delegate>).forwardee {
					let invocation = invocation.takeUnretainedValue()

					if forwardee.responds(to: invocation.selector) {
						invocation.invoke(withTarget: forwardee)
					}
				}
			}

			let previousImpl = class_replaceMethod(perceivedClass,
			                                       ObjCSelector.forwardInvocation,
			                                       imp_implementationWithBlock(_forwardInvocation),
			                                       "v@:@")
			precondition(previousImpl == nil, "Swizzling DelegateProxy with other libraries is not supported. \(perceivedClass)")

			// Implement `methodSignatureForSelector`.
			let _methodSignatureForSelector: @convention(block) (Unmanaged<AnyObject>, Selector) -> AnyObject? = { object, selector in
				let typeEncoding = typeEncodings[selector] ?? method_getTypeEncoding(class_getInstanceMethod(perceivedClass, selector)!)!
				return NSMethodSignature.signature(withObjCTypes: typeEncoding)
			}

			let previousImpl2 = class_replaceMethod(perceivedClass,
			                                       ObjCSelector.methodSignatureForSelector,
			                                       imp_implementationWithBlock(_methodSignatureForSelector),
			                                       "v@::")
			precondition(previousImpl2 == nil, "Swizzling DelegateProxy with other libraries is not supported. \(perceivedClass)")

			// If `self` conforms to `objcProtocol`, all required methods should have been
			// implemented.
			let requiredImplemented = class_conformsToProtocol(perceivedClass, objcProtocol)

			// Implement all required methods of the protocol. Trap if any method has
			// non-void return type, and is not implemented by `self`.

			var count: UInt32 = 0
			if let list = protocol_copyMethodDescriptionList(objcProtocol, true, true, &count) {
				let buffer = UnsafeBufferPointer(start: list, count: Int(count))
				defer { free(list) }

				for method in buffer {
					defer {
						implementedSelectors.insert(method.name)
						typeEncodings[method.name] = UnsafePointer(method.types!)
					}

					guard !requiredImplemented else {
						continue
					}

					// Implemented selectors with matching signatures are picked up by the
					// proxy even if `self` does not conform to the protocol.
					if let implementedMethod = class_getImmediateMethod(perceivedClass, method.name),
					   strcmp(method.types, method_getTypeEncoding(implementedMethod)) == 0 {
						continue
					}

					guard method.types.pointee == Int8(UInt8(ascii: "v")) else {
						fatalError("DelegateProxy does not support protocols with required methods that returns non-void types.")
					}

					_ = class_addMethod(perceivedClass, method.name, _rac_objc_msgForward, method.types)
					implementedSelectors.insert(method.name)
				}
			}

			if let list = protocol_copyMethodDescriptionList(objcProtocol, false, true, &count) {
				let buffer = UnsafeBufferPointer(start: list, count: Int(count))
				defer { free(list) }

				for method in buffer {
					typeEncodings[method.name] = UnsafePointer(method.types!)
				}
			}

			return implementedSelectors
		}
	}
}

extension Reactive where Base: NSObject, Base: DelegateProxyProtocol {
	/// Create a signal which sends a `next` event at the end of every
	/// invocation of `selector` on the object.
	///
	/// It completes when the object deinitializes.
	///
	/// - note: Observers to the resulting signal should not call the method
	///         specified by the selector.
	///
	/// - parameters:
	///   - selector: The selector to observe.
	///
	/// - returns: A trigger signal.
	public func trigger(for selector: Selector) -> Signal<(), NoError> {
		let base = self.base as! _DelegateProxyProtocol
		base.proxyWillIntercept(selector)

		return (self.base as NSObject).reactive.trigger(for: selector)
			.take(during: base.lifetime)
	}

	/// Create a signal which sends a `next` event, containing an array of
	/// bridged arguments, at the end of every invocation of `selector` on the
	/// object.
	///
	/// It completes when the object deinitializes.
	///
	/// - note: Observers to the resulting signal should not call the method
	///         specified by the selector.
	///
	/// - parameters:
	///   - selector: The selector to observe.
	///
	/// - returns: A signal that sends an array of bridged arguments.
	public func signal(for selector: Selector) -> Signal<[Any?], NoError> {
		let base = self.base as! _DelegateProxyProtocol
		base.proxyWillIntercept(selector)

		return (self.base as NSObject).reactive.signal(for: selector)
			.take(during: base.lifetime)
	}
}

extension Reactive where Base: NSObject {
	/// Create a transparent proxy that intercepts calls from `instance` to its delegate
	/// of the given key.
	///
	/// After the proxy is initialized, the delegate setter of `instance` would be
	/// automatically redirected to the proxy.
	///
	/// - important: If you subclass `DelegateProxy`, your implementations are responsible
	///              of forwarding the calls to the forwardee.
	///
	/// - warnings: `DelegateProxy` does not support protocols containing methods that are
	///             non-void returning. It would trap immediately when the proxy
	///             initializes with a protocol containing such a required method, or when
	///             the proxy is asked to intercept such an optional method.
	///
	/// - parameters:
	///   - key: The key of the property that stores the delegate reference.
	///
	/// - returns: The proxy.
	public func proxy<Delegate, Proxy: DelegateProxy<Delegate>>(_: Delegate.Type = Delegate.self, forKey key: String) -> Proxy {
		func remangleIfNeeded(_ name: String) -> String {
			let expression = try! NSRegularExpression(pattern: "^([a-zA-Z0-9\\_\\.]+)\\.\\(([a-zA-Z0-9\\_]+)\\sin\\s([a-zA-Z0-9\\_]+)\\)$")
			if let match = expression.firstMatch(in: name, range: NSMakeRange(0, name.characters.count)) {
				// `name` refers to a private protocol.
				let objcName = name as NSString

				let (moduleNameRange, protocolNameRange, scopeNameRange) = (match.rangeAt(1), match.rangeAt(2), match.rangeAt(3))
				let moduleName = objcName.substring(with: moduleNameRange)
				let protocolName = objcName.substring(with: protocolNameRange)
				let scopeName = objcName.substring(with: scopeNameRange)

				// Example: _TtP18ReactiveCocoaTestsP33_B2B708E0A88135A5DA71A5A2AAFA457014ObjectDelegate_
				return "_TtP\(moduleNameRange.length)\(moduleName)P\(scopeNameRange.length)\(scopeName)\(protocolNameRange.length)\(protocolName)_"
			} else if let range = name.range(of: "__ObjC.") {
				// `name` refers to an Objective-C protocol.
				return name.substring(from: range.upperBound)
			} else {
				// `name` refers to a Swift protocol.
				return name
			}
		}

		let mangledName = remangleIfNeeded(String(reflecting: Delegate.self))
		let objcProtocol = NSProtocolFromString(mangledName)!

		return base.synchronized {
			let getter = Selector(((key)))
			let setter = Selector((("set\(String(key.characters.first!).uppercased())\(String(key.characters.dropFirst())):")))

			let proxyKey = AssociationKey<AnyObject?>(setter.delegateProxyAlias)

			if let proxy = base.associations.value(forKey: proxyKey) {
				return proxy as! Proxy
			}

			let superclass: AnyClass = class_getSuperclass(swizzleClass(base))

			let invokeSuperSetter: @convention(c) (Unmanaged<AnyObject>, AnyClass, Selector, Unmanaged<AnyObject>?) -> Void = { object, superclass, selector, delegate in
				typealias Setter = @convention(c) (Unmanaged<AnyObject>, Selector, Unmanaged<AnyObject>?) -> Void
				let impl = class_getMethodImplementation(superclass, selector)
				unsafeBitCast(impl, to: Setter.self)(object, selector, delegate)
			}

			let newSetterImpl: @convention(block) (Unmanaged<AnyObject>, Unmanaged<AnyObject>?) -> Void = { object, delegate in
				if let proxy = Associations(object.takeUnretainedValue()).value(forKey: proxyKey) as! DelegateProxy<Delegate>? {
					proxy.forwardee = delegate?.takeUnretainedValue() as! Delegate?
				} else {
					invokeSuperSetter(object, superclass, setter, delegate)
				}
			}

			// Hide the original setter, and redirect subsequent delegate assignment
			// to the proxy.
			base.swizzle((setter, newSetterImpl), key: hasSwizzledKey)

			// As Objective-C classes may cache the information of their delegate at
			// the time the delegates are set, the information has to be "flushed"
			// whenever the proxy forwardee is replaced or a selector is intercepted.
			let proxy = Proxy(config: DelegateProxyConfiguration(objcProtocol: objcProtocol, lifetime: base.reactive.lifetime) { [weak base] proxy in
				guard let base = base else { return }
				invokeSuperSetter(.passUnretained(base), superclass, setter, .passUnretained(proxy))
			})

			typealias Getter = @convention(c) (NSObject, Selector) -> AnyObject?
			let getterImpl: IMP = class_getMethodImplementation(object_getClass(base), getter)
			let original = unsafeBitCast(getterImpl, to: Getter.self)(base, getter) as! Delegate?

			// `proxy.forwardee` would invoke the original setter regardless of
			// `original` being `nil` or not.
			proxy.forwardee = original

			// The proxy must be associated after it is set as the target, since
			// `base` may be an isa-swizzled instance that is using the injected
			// setters above.
			base.associations.setValue(proxy, forKey: proxyKey)

			return proxy
		}
	}
}
