import Foundation
import ReactiveSwift
import enum Result.NoError

extension Reactive where Base: NSObject {
	/// Create a signal which sends a `next` event at the end of every invocation
	/// of `selector` on the object.
	///
	/// `trigger(for:from:)` can be used to intercept optional protocol
	/// requirements by supplying the protocol as `protocol`. The instance need
	/// not have a concrete implementation of the requirement.
	///
	/// However, as Cocoa classes usually cache information about delegate
	/// conformances, trigger signals for optional, unbacked protocol requirements
	/// should be set up before the instance is assigned as the corresponding
	/// delegate.
	///
	/// - parameters:
	///   - selector: The selector to observe.
	///   - protocol: The protocol of the selector, or `nil` if the selector does
	///               not belong to any protocol.
	///
	/// - returns:
	///   A trigger signal.
	public func trigger(for selector: Selector, from protocol: Protocol? = nil) -> Signal<(), NoError> {
		return base.synchronized {
			let map = associatedValue { _ in NSMutableDictionary() }

			let selectorName = String(describing: selector) as NSString
			if let signal = map.object(forKey: selectorName) as! Signal<(), NoError>? {
				return signal
			}

			let (signal, observer) = Signal<(), NoError>.pipe()
			let isSuccessful = base._rac_setupInvocationObservation(for: selector,
			                                                        protocol: `protocol`,
			                                                        receiver: observer.send(value:))
			precondition(isSuccessful)

			lifetime.ended.observeCompleted(observer.sendCompleted)
			map.setObject(signal, forKey: selectorName)

			return signal
		}
	}

	/// Create a signal which sends a `next` event, containing an array of bridged
	/// arguments, at the end of every invocation of `selector` on the object.
	///
	/// `trigger(for:from:)` can be used to intercept optional protocol
	/// requirements by supplying the protocol as `protocol`. The instance need
	/// not have a concrete implementation of the requirement.
	///
	/// However, as Cocoa classes usually cache information about delegate
	/// conformances, trigger signals for optional, unbacked protocol requirements
	/// should be set up before the instance is assigned as the corresponding
	/// delegate.
	///
	/// - parameters:
	///   - selector: The selector to observe.
	///   - protocol: The protocol of the selector, or `nil` if the selector does
	///               not belong to any protocol.
	///
	/// - returns:
	///   A signal that sends an array of bridged arguments.
	public func signal(for selector: Selector, from protocol: Protocol? = nil) -> Signal<[Any?], NoError> {
		return base.synchronized {
			let map = associatedValue { _ in NSMutableDictionary() }

			let selectorName = String(describing: selector) as NSString
			if let signal = map.object(forKey: selectorName) as! Signal<[Any?], NoError>? {
				return signal
			}

			let (signal, observer) = Signal<[Any?], NoError>.pipe()
			let isSuccessful = base._rac_setupInvocationObservation(for: selector,
			                                                        protocol: `protocol`,
			                                                        argsReceiver: bridge(observer))
			precondition(isSuccessful)

			lifetime.ended.observeCompleted(observer.sendCompleted)
			map.setObject(signal, forKey: selectorName)

			return signal
		}
	}
}

private func bridge(_ observer: Observer<[Any?], NoError>) -> (RACSwiftInvocationArguments) -> Void {
	return { arguments in
		let count = arguments.count

		var bridged = [Any?]()
		bridged.reserveCapacity(count - 2)

		// Ignore `self` and `_cmd`.
		for position in 2 ..< count {
			let rawEncoding = arguments.argumentType(at: position)
			let encoding = TypeEncoding(rawValue: rawEncoding.pointee) ?? .undefined

			func extract<U>(_ type: U.Type) -> U {
				let pointer = UnsafeMutableRawPointer.allocate(bytes: MemoryLayout<U>.size,
				                                               alignedTo: MemoryLayout<U>.alignment)
				defer {
					pointer.deallocate(bytes: MemoryLayout<U>.size,
					                   alignedTo: MemoryLayout<U>.alignment)
				}

				arguments.copyArgument(at: position, to: pointer)
				return pointer.assumingMemoryBound(to: type).pointee
			}

			switch encoding {
			case .char:
				bridged.append(NSNumber(value: extract(CChar.self)))
			case .int:
				bridged.append(NSNumber(value: extract(CInt.self)))
			case .short:
				bridged.append(NSNumber(value: extract(CShort.self)))
			case .long:
				bridged.append(NSNumber(value: extract(CLong.self)))
			case .longLong:
				bridged.append(NSNumber(value: extract(CLongLong.self)))
			case .unsignedChar:
				bridged.append(NSNumber(value: extract(CUnsignedChar.self)))
			case .unsignedInt:
				bridged.append(NSNumber(value: extract(CUnsignedInt.self)))
			case .unsignedShort:
				bridged.append(NSNumber(value: extract(CUnsignedShort.self)))
			case .unsignedLong:
				bridged.append(NSNumber(value: extract(CUnsignedLong.self)))
			case .unsignedLongLong:
				bridged.append(NSNumber(value: extract(CUnsignedLongLong.self)))
			case .float:
				bridged.append(NSNumber(value: extract(CFloat.self)))
			case .double:
				bridged.append(NSNumber(value: extract(CDouble.self)))
			case .bool:
				bridged.append(NSNumber(value: extract(CBool.self)))
			case .object:
				bridged.append(extract((AnyObject?).self))
			case .type:
				bridged.append(extract((AnyClass?).self))
			case .selector:
				bridged.append(arguments.selectorString(at: position))
			case .undefined:
				var size = 0, alignment = 0
				NSGetSizeAndAlignment(rawEncoding, &size, &alignment)
				let buffer = UnsafeMutableRawPointer.allocate(bytes: size, alignedTo: alignment)
				defer { buffer.deallocate(bytes: size, alignedTo: alignment) }

				arguments.copyArgument(at: position, to: buffer)
				bridged.append(NSValue(bytes: buffer, objCType: rawEncoding))
			}
		}

		observer.send(value: bridged)
	}
}


private enum TypeEncoding: Int8 {
	case char = 99
	case int = 105
	case short = 115
	case long = 108
	case longLong = 113

	case unsignedChar = 67
	case unsignedInt = 73
	case unsignedShort = 83
	case unsignedLong = 76
	case unsignedLongLong = 81

	case float = 102
	case double = 100

	case bool = 66

	case object = 64
	case type = 35
	case selector = 58

	case undefined = -1
}
