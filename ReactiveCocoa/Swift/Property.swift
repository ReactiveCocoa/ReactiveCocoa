final class Property<T> {
	var value: T { get set }
	let changes: SignalTemplate<T>

	init(initialValue: T)
}

func <~ <T>(property: Property<T>, signal: Signal<T>)
func <~ <T>(property: Property<T>, template: SignalTemplate<T>)
