import ReactiveSwift
import Result
import Nimble
import Quick
@testable import ReactiveCocoa

class AssociationSpec: QuickSpec {
	override func spec() {
		it("should create and retrieve the same object") {
			let object = NSObject()
			let token = NSObject()

			var counter = 0

			func retrieve() -> NSObject {
				return object.reactive.associatedValue { _ in
					counter += 1
					return token
				}
			}

			expect(counter) == 0

			let firstResult = retrieve()
			expect(counter) == 1

			let secondResult = retrieve()
			expect(counter) == 1

			expect(firstResult).to(beIdenticalTo(secondResult))
			expect(firstResult).to(beIdenticalTo(token))
		}

		it("should support multiple keys per object") {
			let object = NSObject()
			let token = NSObject()
			let token2 = NSObject()

			var counter = 0
			var counter2 = 0


			func retrieve() -> NSObject {
				return object.reactive.associatedValue { _ in
					counter += 1
					return token
				}
			}

			func retrieve2() -> NSObject {
				return object.reactive.associatedValue(forKey: "customKey") { _ in
					counter2 += 1
					return token2
				}
			}

			expect(counter) == 0

			let firstResult = retrieve()
			expect(counter) == 1

			let secondResult = retrieve()
			expect(counter) == 1

			expect(firstResult).to(beIdenticalTo(secondResult))
			expect(firstResult).to(beIdenticalTo(token))

			expect(counter2) == 0

			let thirdResult = retrieve2()
			expect(counter2) == 1

			let forthResult = retrieve2()
			expect(counter2) == 1

			expect(thirdResult).to(beIdenticalTo(forthResult))
			expect(thirdResult).to(beIdenticalTo(token2))
		}
	}
}
