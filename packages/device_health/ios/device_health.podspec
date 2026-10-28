Pod::Spec.new do |s|
  s.name = 'device_health'
  s.version = '0.1.0'
  s.summary = 'Lectura local explícita de carreras de Salud.'
  s.description = s.summary
  s.homepage = 'https://github.com/jchjdev/entrenaop'
  s.license = { :type => 'Proprietary' }
  s.author = { 'EntrenaOP' => 'EntrenaOP' }
  s.source = { :path => '.' }
  s.source_files = 'device_health/Sources/device_health/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.swift_version = '5.0'
  s.frameworks = 'HealthKit'
  s.weak_frameworks = 'WorkoutKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
