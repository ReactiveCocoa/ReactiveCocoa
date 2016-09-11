import Foundation

public func scopedExample(_ exampleDescription: String, _ action: () -> Void) {
	print("\n--- \(exampleDescription) ---\n")
	action()
}

public enum PlaygroundError: Error {
	case example(String)
}
