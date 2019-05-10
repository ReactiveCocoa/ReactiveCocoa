import ReactiveSwift
import WatchKit

extension Reactive where Base: WKInterfaceMovie {
	/// Sets the url of the movie.
	public var movieURL: BindingTarget<URL> {
		return makeBindingTarget { $0.setMovieURL($1) }
	}
	
	/// Sets the video gravity of the movie.
	public var videoGravity: BindingTarget<WKVideoGravity> {
		return makeBindingTarget { $0.setVideoGravity($1) }
	}
	
	/// Sets the poster image of the movie.
	public var posterImage: BindingTarget<WKImage?> {
		return makeBindingTarget { $0.setPosterImage($1) }
	}
	
	/// Whether the movie loops.
	public var loops: BindingTarget<Bool> {
		return makeBindingTarget { $0.setLoops($1) }
	}
}
