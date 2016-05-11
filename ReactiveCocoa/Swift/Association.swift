import Foundation

/// On first use attaches the object returned from `initial` to the `host` object using
/// `key` via `objc_setAssociatedObject`. On subsequent usage, returns said object via
/// `objc_getAssociatedObject`.
public func associatedObject<Host: AnyObject, T: AnyObject>(host: Host, key: UnsafePointer<()>, @noescape initial: Host -> T) -> T {
	var value = objc_getAssociatedObject(host, key) as? T
	if value == nil {
		value = initial(host)
		objc_setAssociatedObject(host, key, value, .OBJC_ASSOCIATION_RETAIN)
	}
	return value!
}
