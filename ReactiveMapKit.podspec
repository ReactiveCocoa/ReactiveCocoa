Pod::Spec.new do |s|
  s.name         = "ReactiveMapKit"
  s.version      = "7.2.0"
  s.summary      = "MapKit bindings for ReactiveCocoa."
  s.description  = <<-DESC
                   Provide MapKit bindings for ReactiveCocoa. ReactiveCocoa (RAC) is a Cocoa framework built on top of ReactiveSwift. It provides APIs for using ReactiveSwift with Apple's Cocoa frameworks.
                   DESC
  s.homepage     = "https://github.com/ReactiveCocoa/ReactiveCocoa"
  s.license      = { :type => "MIT", :file => "LICENSE.md" }
  s.author       = "ReactiveCocoa"

  s.osx.deployment_target = "10.9"
  s.ios.deployment_target = "8.0"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = "2.0"

  s.source       = { :git => "https://github.com/ReactiveCocoa/ReactiveCocoa.git", :tag => "#{s.version}" }
  s.source_files = "ReactiveMapKit/*.{swift,h,m}"

  s.dependency 'ReactiveCocoa', "#{s.version}"

  s.pod_target_xcconfig = { "OTHER_SWIFT_FLAGS[config=Release]" => "$(inherited) -suppress-warnings" }
end
