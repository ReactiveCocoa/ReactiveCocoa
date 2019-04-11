import Foundation
import ReactiveCocoa
import ReactiveSwift
import Quick
import Nimble

class DeprecationsSpec: QuickSpec {
    override func spec() {
        describe("NSObject.reactive.values(forKeyPath:)") {
            class TestKVOObject: NSObject {
                @objc dynamic var value: Int = 0
            }

            it("should observe the initial value and changes for the key path") {
                let object = TestKVOObject()
                var values: [Int] = []

                object.reactive.producer(forKeyPath: #keyPath(TestKVOObject.value)).startWithValues { value in
                    values.append(value as! Int)
                }

                expect(values) == [0]

                object.value = 1
                expect(values) == [0, 1]
            }
        }
    }
}
