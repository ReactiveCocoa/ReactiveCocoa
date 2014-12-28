struct SignalTemplateTemplate<T> {
	func lift<U>(f: SignalTemplate<T> -> SignalTemplate<U>) -> SignalTemplateTemplate<U>

	/* Lifted operators */
	func lift<U>(f: Signal<T> -> Signal<U>) -> SignalTemplateTemplate<U> {
		return lift { template in template.lift(f) }
	}

	func map<U>(f: T -> U) -> SignalTemplateTemplate<U> {
		return lift { template in template.map(f) }
	}

	func filter(pred: T -> Bool) -> SignalTemplateTemplate {
		return lift { template in template.filter(pred) }
	}

	func delay(interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> SignalTemplate {
		return lift { template in template.delay(interval, onScheduler: scheduler) }
	}

	func retry(count: Int) -> SignalTemplateTemplate {
		return lift { template in template.retry(count) }
	}

	func repeat(count: Int) -> SignalTemplateTemplate {
		return lift { template in template.repeat(count) }
	}

	func evaluateOn(scheduler: Scheduler) -> SignalTemplateTemplate {
		return lift { template in template.evaluateOn(scheduler) }
	}

	/* Template template operators */
	func merge() -> SignalTemplate
	func concat() -> SignalTemplate
	func switchToLatest() -> SignalTemplate
}
