import Foundation

public func scopedExample(exampleDescription: String, _ action: () -> Void) {
	print("\n--- \(exampleDescription) ---\n")
	action()
}

public enum Error: ErrorProtocol {
	case Example(String)
}
