import AppKit
import ReactiveSwift
import enum Result.NoError

internal final class ActionProxy<Owner: AnyObject>: NSObject {
	internal weak var target: AnyObject?
	internal var action: Selector?
	internal let invoked: Signal<Owner, NoError>

	private let observer: Signal<Owner, NoError>.Observer
	private unowned let owner: Owner

	internal init(owner: Owner, lifetime: Lifetime) {
		self.owner = owner
		(invoked, observer) = Signal<Owner, NoError>.pipe()
		lifetime.ended.observeCompleted(observer.sendCompleted)
	}

	// In AppKit, action messages always have only one parameter.
	@objc func invoke(_ sender: Any?) {
		if let action = action {
			if let app = NSApp {
				app.sendAction(action, to: target, from: sender)
			} else {
				_ = target?.perform(action, with: sender)
			}
		}

		observer.send(value: owner)
	}
}

private let hasSwizzledKey = AssociationKey<Bool>(default: false)

@objc internal protocol ActionMessageSending: class {
	weak var target: AnyObject? { get set }
	var action: Selector? { get set }
}

extension Reactive where Base: NSObject, Base: ActionMessageSending {
	internal var proxy: ActionProxy<Base> {
		let key = AssociationKey<ActionProxy<Base>?>((#function as StaticString))

		return base.synchronized {
			if let proxy = base.associations.value(forKey: key) {
				return proxy
			}

			let superclass: AnyClass = class_getSuperclass(swizzleClass(base))

			let proxy = ActionProxy<Base>(owner: base, lifetime: lifetime)
			proxy.target = base.target
			proxy.action = base.action

			// The proxy must be associated after it is set as the target, since
			// `base` may be an isa-swizzled instance that is using the injected
			// setters below.
			base.target = proxy
			base.action = #selector(proxy.invoke(_:))
			base.associations.setValue(proxy, forKey: key)

			let newTargetSetterImpl: @convention(block) (NSObject, AnyObject?) -> Void = { object, target in
				if let proxy = object.associations.value(forKey: key) {
					proxy.target = target
				} else {
					typealias Setter = @convention(c) (NSObject, Selector, AnyObject?) -> Void
					let selector = #selector(setter: ActionMessageSending.target)
					let impl = class_getMethodImplementation(superclass, selector)
					unsafeBitCast(impl, to: Setter.self)(object, selector, target)
				}
			}

			let newActionSetterImpl: @convention(block) (NSObject, Selector?) -> Void = { object, action in
				if let proxy = object.associations.value(forKey: key) {
					proxy.action = action
				} else {
					typealias Setter = @convention(c) (NSObject, Selector, Selector?) -> Void
					let selector = #selector(setter: ActionMessageSending.action)
					let impl = class_getMethodImplementation(superclass, selector)
					unsafeBitCast(impl, to: Setter.self)(object, selector, action)
				}
			}

			// Swizzle the instance only after setting up the proxy.
			base.swizzle((#selector(setter: base.target), newTargetSetterImpl),
			             (#selector(setter: base.action), newActionSetterImpl),
			             key: hasSwizzledKey)

			return proxy
		}
	}
}
