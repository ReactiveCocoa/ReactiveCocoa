import Foundation

public func scopedExample(exampleDescription: String, _ action: () -> Void) {
	print("\n--- \(exampleDescription) ---\n")
	action()
}

public enum Error: ErrorType {
	case Example(String)
}
