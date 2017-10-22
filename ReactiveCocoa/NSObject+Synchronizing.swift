extension NSObjectProtocol {
	internal func synchronized<Result>(execute: () throws -> Result) rethrows -> Result {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }
		return try execute()
	}
}

internal func synchronized<Result>(_ token: AnyObject, execute: () throws -> Result) rethrows -> Result {
	objc_sync_enter(token)
	defer { objc_sync_exit(token) }
	return try execute()
}
