Pod::Spec.new do |s|
  s.name         = "ReactiveCocoa"
  s.version      = "11.2.2"
  s.summary      = "Streams of values over time"
  s.description  = <<-DESC
                   ReactiveCocoa (RAC) is a Cocoa framework built on top of ReactiveSwift. It provides APIs for using ReactiveSwift with Apple's Cocoa frameworks.
                   DESC
  s.homepage     = "https://github.com/ReactiveCocoa/ReactiveCocoa"
  s.license      = { :type => "MIT", :file => "LICENSE.md" }
  s.author       = "ReactiveCocoa"

  s.osx.deployment_target = "10.9"
  s.ios.deployment_target = "9.0"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = "2.0"

  s.source       = { :git => "https://github.com/ReactiveCocoa/ReactiveCocoa.git", :tag => "#{s.version}" }
  s.source_files = "ReactiveCocoa/*.{swift,h,m}", "ReactiveCocoa/Shared/*.{swift}", "ReactiveCocoaObjC/**/*.{h,m}"
  s.public_header_files = "ReactiveCocoaObjC/include/ObjCRuntimeAliases.h"
  s.osx.source_files = "ReactiveCocoa/AppKit/*.{swift}"
  s.ios.source_files = "ReactiveCocoa/UIKit/*.{swift}", "ReactiveCocoa/UIKit/iOS/*.{swift}"
  s.tvos.source_files = "ReactiveCocoa/UIKit/*.{swift}"
  s.watchos.exclude_files = "ReactiveCocoa/Shared/*.{swift}"
  s.watchos.source_files = "ReactiveCocoa/WatchKit/*.{swift}"
  s.module_name = 'ReactiveCocoa'

  s.dependency 'ReactiveSwift', '~> 6.6'

  s.pod_target_xcconfig = { "OTHER_SWIFT_FLAGS[config=Release]" => "$(inherited) -suppress-warnings" }
  s.swift_versions = ['5.1', '5.2']
end
