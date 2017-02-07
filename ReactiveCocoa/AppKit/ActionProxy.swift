import AppKit
import ReactiveSwift
import enum Result.NoError

internal final class ActionProxy<Owner: AnyObject> {
	internal weak var target: AnyObject?
	internal var action: Selector?
	internal let signal: Signal<Owner, NoError>

	private let observer: Signal<Owner, NoError>.Observer
	private unowned let owner: Owner

	internal init(owner: Owner, lifetime: Lifetime) {
		self.owner = owner
		(signal, observer) = Signal<Owner, NoError>.pipe()
		lifetime.ended.observeCompleted(observer.sendCompleted)
	}

	// In AppKit, action messages always have only one parameter.
	@objc func consume(_ sender: Any?) {
		if let action = action {
			if let target = target {
				_ = target.perform(action, with: sender)
			} else {
				NSApp.sendAction(action, to: nil, from: sender)
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

			let proxy = ActionProxy<Base>(owner: base, lifetime: lifetime)
			base.associations.setValue(proxy, forKey: key)

			proxy.target = base.target
			proxy.action = base.action

			base.target = proxy
			base.action = #selector(proxy.consume(_:))

			// Swizzle the instance only after setting up the proxy.
			let subclass: AnyClass = swizzleClass(base)

			let targetSetter = #selector(setter: base.target)
			let actionSetter = #selector(setter: base.action)

			// Swizzle the original setters, and redirect subsequent target and action
			// assignments to the proxy.
			try! ReactiveCocoa.synchronized(subclass) {
				print(subclass)
				let subclassAssociations = Associations(subclass as AnyObject)

				if !subclassAssociations.value(forKey: hasSwizzledKey) {
					subclassAssociations.setValue(true, forKey: hasSwizzledKey)

					let targetSetterMethod = class_getInstanceMethod(subclass, targetSetter)
					let targetSetterTypeEncoding = method_getTypeEncoding(targetSetterMethod)!

					let newTargetSetterImpl: @convention(block) (NSObject, AnyObject?) -> Void = { object, target in
						let proxy = object.associations.value(forKey: key)!
						proxy.target = target
					}

					class_replaceMethod(subclass,
					                    targetSetter,
					                    imp_implementationWithBlock(newTargetSetterImpl as Any),
					                    targetSetterTypeEncoding)

					let actionSetterMethod = class_getInstanceMethod(subclass, actionSetter)
					let actionSetterTypeEncoding = method_getTypeEncoding(actionSetterMethod)!

					let newActionSetterImpl: @convention(block) (NSObject, Selector?) -> Void = { object, selector in
						let proxy = object.associations.value(forKey: key)!
						proxy.action = selector
					}

					class_replaceMethod(subclass,
					                    actionSetter,
					                    imp_implementationWithBlock(newActionSetterImpl as Any),
					                    actionSetterTypeEncoding)
				}
			}
			
			return proxy
		}
	}
}
