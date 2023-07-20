# User Interface Recipes

### ViewData (aka ViewModel, Presenter) Objects

These objects contain a 1:1 mapping of properties to the controls on your screen. They provide a data-oriented representation of what  the user sees and can interact with. These objects are a good place to encapsulate formatting behavior, input validation, and so on.

For example, consider a UI that displays both a slider and a text field that represent a magnitude. The text field specifies its values in dBFS (decibels, full scale). Commonly, these values appear in the ViewData object with a 1:1 mapping to the model, using only a single `MutableProperty` that represents a value between 0-1:

``` swift
final class VolumeViewData {
	let volume: MutableProperty<Double>
	
	init(initialVolume volume: Double) {
		volume = MutableProperty(volume)
	}
}
```

Now, consider the accompanying view controller:

``` swift
import Foundation
import AppKit
import ReactiveCocoa
import Rex

final class VolumeViewController : NSViewController {
	@IBOutlet var slider: NSSlider!
	@IBOutlet var textField: NSTextField!
	
	let viewData: MutableProperty<VolumeViewData?>(nil)
	
	func viewDidLoad() {
		super.viewDidLoad()
		
		let parseVolume: Double -> String = { /* ... */ }
		let formatVolume: String -> Double = { /* ... */ }
		
		// Create the source signal producers
		let volumeProducer = viewData.flatMap(.Latest) { $0?.volume.producer ?? .empty }
		let decibelStringProducer = volumeProducer.map { 20 * log10( $0 ) }.map(formatVolume)
		
		// Populate the controls
		volumeProducer.observeOn(UIScheduler()).startWithNext { [slider] in slider.value = $0 }
		decibelStringProducer.observeOn(UIScheduler()).startWithNext { [textField] in textField.stringValue = $0 }
		
		// Update the underlying ViewData on UI changes
		textField.rex_stringValues.map(parseVolume).startwithNext { [data] in data?.value.volume.value = $0 }
		slider.rex_doubleValues.startWithNext { [data] in data?.value.volume.value = $0 }
	}
}
```

#### "Too Much Behavior" in the `VolumeViewController`?

The above `ViewController`, while still compact, still carries an awful lot of logic with it. This isn't immediately obvious with a simple model as above, but you'll notice that `parseVolume` and `formatVolume` exist inside the view controller as well. To keep your ViewControllers "as dumb as possible" and achieve a more testable UI, you can push these responsibilities into the view data class and maintain that 1:1 control mapping:

``` swift
final class VolumeViewData {
	// "Outlet" Property / SignalProducer
	let volume: MutableProperty<Double>
	let volumeStringInDecibels: SignalProducer<Double, NoError>
	
	// "Inlet" Signals
	let (volumeInput, volumeInputObserver) = SignalProducer<Double, NoError>.pipe()
	let (volumeInputString, volumeInputStringObserver) = SignalProducer<String, NoError>.pipe()
	
	init(initialVolume volume: Double) {
		volume = MutableProperty(volume)
		
		let parseVolume: Double -> String = { /* ... */ }
		let formatVolume: String -> Double = { /* ... */ }
		
		volumeStringInDecibels = volume.producer.map { 20 * log10( $0 ) }.map(formatVolume)
		
		let parsedVolumeInput = volumeInputString.map(parseVolume)
		volume <~ SignalProducer(values: [volumeInput, parsedVolumeInput]).flatten(.Merge)
	}
}
```

Now the `viewDidLoad` implementation changes to the following:

``` swift
func viewDidLoad() {
	super.viewDidLoad()
	
	// Create the source signal producers
	let volumeProducer = viewData.flatMap(.Latest) { $0?.volume.producer ?? .empty }
	let volumeStringProducer = viewData.flatMap(.Latest) { $0?.volumeStringInDecibels ?? .empty }	
	
	// Update the controls to reflect changes in the ViewData
	volumeProducer.observeOn(UIScheduler()).startWithNext { [slider] in slider.value = $0 }
	decibelStringProducer.observeOn(UIScheduler()).startWithNext { [textField] in textField.stringValue = $0 }
	
	// Send control values to the ViewData
	textField.rex_stringValues.startWithNext { [model] in model.value?.volumeInputStringObserver.sendNext($0) }
	slider.rex_doubleValues.startWithNext { [model] in model.value?.volumeInputObserver.sendNext($0) }
}
```

And you can now test your `VolumeViewData` class to ensure that it behaves appropriately with certain inputs and outputs.

#### `SignalProducer`s of `SignalProducer`s

You'll notice that I declare the `viewData` as a `MutableProperty` rather than just the `VolumeViewData`, and its individual producers must be "unwrapped":

``` swift
let volumeProducer = viewData.flatMap(.Latest) { $0?.volume.producer ?? .empty }
```

This approach has the following benefits:

1. If the UI is long-lived, such as in an inspector, your ViewData object can be changed out while the view is still visible.
2. You don't have to worry about when `viewDidLoad` gets called in relation to setting the value of viewData in the calling code.

#### TODO: Explore `SignalProducer` vs `Signal` vs `Property` etc… in the ViewData class

#### TODO: Notes on lifetimes, avoiding cycles

#### TODO: Static ViewData Objects

These `ViewData` objects serve only to format the model so it is suitably displayed on screen. Some end up as rather simplistic "go-between" objects that offer little to no formatting, so why bother? [No, really. Why?]

#### TODO: Modal ViewData Objects

These are `ViewData` objects that wrap a succinct model object that is "write-only" until the UI disappears and the model object becomes valid / available.

#### TODO: "Façade" ViewData Objects

These are `ViewData` objects that exist as a wrapper or interface for a model that might be changing out from under you. For instance, encompassing an object that is owned by a `NSDocument` subclass that is re-loaded over iCloud, or the user invokes Undo/Redo, etc.

With NSObject subclasses, `DynamicProperty` objects will give you a ton of the functionality you need here.

#### TODO: "Two-way bindings" and why they are not so simple to build

