import ReactiveSwift
import UIKit

protocol ReactiveUIBarItem {
	var isEnabled: BindingTarget<Bool> { get }
	var image: BindingTarget<UIImage?> { get }
	var title: BindingTarget<String?> { get }
}
