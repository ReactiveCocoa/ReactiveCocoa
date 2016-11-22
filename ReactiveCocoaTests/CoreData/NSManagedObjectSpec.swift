import Quick
import Nimble
import CoreData
import ReactiveSwift
import ReactiveCocoa
import enum Result.NoError

private class TestManagedObject: NSManagedObject {
	@NSManaged var integer: Int
}

class NSManagedObjectSpec: QuickSpec {
	override func spec() {
		describe("values(forKeyPath:)") {
			let integerProperty = NSAttributeDescription()
			integerProperty.name = "integer"
			integerProperty.attributeType = .integer64AttributeType
			integerProperty.isOptional = false
			integerProperty.defaultValue = 0

			let testEntity = NSEntityDescription()
			testEntity.managedObjectClassName = NSStringFromClass(TestManagedObject.self)
			testEntity.name = "TestManagedObject"
			testEntity.properties = [integerProperty]

			let objectModel = NSManagedObjectModel()
			objectModel.entities = [testEntity]

			var coordinator: NSPersistentStoreCoordinator!
			var context: NSManagedObjectContext!
			var object: NSManagedObject!

			beforeSuite {
				coordinator = NSPersistentStoreCoordinator(managedObjectModel: objectModel)
				expect {
					try coordinator.addPersistentStore(ofType: NSInMemoryStoreType,
					                                   configurationName: nil,
					                                   at: nil,
					                                   options: nil)
					}.toNot(throwError())

				context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
				context.persistentStoreCoordinator = coordinator
			}

			beforeEach {
				object = TestManagedObject(entity: testEntity, insertInto: context)
				expect { try context.save() }.toNot(throwError())
			}

			it("should not emit `nil` when the managed object is turned into a fault, and should emit the current value when the managed object is faulted in.") {
				var values = [Any?]()

				object.reactive
					.values(forKeyPath: #keyPath(TestManagedObject.integer))
					.startWithValues { values.append($0) }

				expect(object.isFault) == false
				expect(object.faultingState) == 0
				expect(values as NSArray) == [0] as NSArray

				context.refresh(object, mergeChanges: false)
				expect(object.isFault) == true
				expect(object.faultingState) != 0
				expect(values as NSArray) == [0] as NSArray

				object.willAccessValue(forKey: nil)
				expect(object.isFault) == false
				expect(object.faultingState) == 0
				expect(values as NSArray) == [0, 0] as NSArray
			}

			it("should not emit `nil` when the managed object marked as deleted is saved.") {
				var values = [Any?]()

				object.reactive
					.values(forKeyPath: #keyPath(TestManagedObject.integer))
					.startWithValues { values.append($0) }

				expect(object.isFault) == false
				expect(object.faultingState) == 0
				expect(object.isDeleted) == false
				expect(values as NSArray) == [0] as NSArray

				context.delete(object)
				expect(object.isDeleted) == true
				expect(values as NSArray) == [0] as NSArray

				expect { try context.save() }.toNot(throwError())
				expect(object.isDeleted) == false
				expect(values as NSArray) == [0] as NSArray
			}
		}
	}
}
