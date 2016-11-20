extension Selector {
	/// `self` as a pointer. It is uniqued across instances, similar to
	/// `StaticString`.
	internal var utf8Start: UnsafePointer<Int8> {
		return unsafeBitCast(self, to: UnsafePointer<Int8>.self)
	}

	/// Selector alias cache.
	final class Cache {
		var selectors: [Selector: Selector] = [:]
	}

	/// An alias of `self`, used in method interception.
	internal var alias: Selector {
		enum Static {
			static let cache = ThreadLocal { Cache() }
		}

		let localCache = Static.cache.local

		if let selector = localCache.selectors[self] {
			return selector
		} else {
			let selector = prefixing("rac0_")
			localCache.selectors[self] = selector
			return selector
		}
	}

	/// An alias of `self`, used in method interception specifically for
	/// preserving (if found) an immediate implementation of `self` in the
	/// runtime subclass.
	internal var interopAlias: Selector {
		enum Static {
			static let cache = ThreadLocal { Cache() }
		}

		let localCache = Static.cache.local

		if let selector = localCache.selectors[self] {
			return selector
		} else {
			let selector = prefixing("rac1_")
			localCache.selectors[self] = selector
			return selector
		}
	}

	///
	internal func prefixing(_ prefix: StaticString) -> Selector {
		let length = Int(strlen(utf8Start))
		let prefixedLength = length + prefix.utf8CodeUnitCount

		let asciiPrefix = UnsafeRawPointer(prefix.utf8Start).assumingMemoryBound(to: Int8.self)

		let cString = UnsafeMutablePointer<Int8>.allocate(capacity: prefixedLength + 1)
		defer {
			cString.deinitialize()
			cString.deallocate(capacity: prefixedLength + 1)
		}

		cString.initialize(from: asciiPrefix, count: prefix.utf8CodeUnitCount)
		(cString + prefix.utf8CodeUnitCount).initialize(from: utf8Start, count: length)
		(cString + prefixedLength).initialize(to: Int8(UInt8(ascii: "\0")))

		return sel_registerName(cString)
	}
}
