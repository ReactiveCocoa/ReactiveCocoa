Pod::Spec.new do |s|
  s.name         = 'Rex'
  s.module_name  = 'Rex'
  s.version      = '0.10.0'
  s.summary      = 'ReactiveCocoa Extensions'

  s.description  = <<-DESC
                   Extensions for ReactiveCocoa that may not fit in the core framework.
                   DESC

  s.homepage     = 'https://github.com/neilpa/Rex'
  s.license      = 'MIT'

  s.author             = { 'Neil Pankey' => 'npankey@gmail.com' }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.watchos.deployment_target = '2.0'
  s.tvos.deployment_target = '9.0'

  s.source       = { :git => 'https://github.com/neilpa/Rex.git', :tag => s.version }
  s.dependency 'ReactiveCocoa', '~> 4.1'
  s.ios.framework  = 'UIKit'
  s.tvos.framework = 'UIKit'
  s.osx.framework  = 'AppKit'

  s.source_files  = 'Source/**/*.swift'
  s.ios.exclude_files = 'Source/AppKit/*'
  s.tvos.exclude_files = 'Source/AppKit/*', 'Source/UIKit/UIDatePicker.swift'
  s.watchos.exclude_files = 'Source/AppKit/*', 'Source/UIKit/*'
  s.osx.exclude_files = 'Source/UIKit/*'

end
