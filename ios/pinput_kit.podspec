Pod::Spec.new do |s|
  s.name             = 'pinput_kit'
  s.version          = '0.1.0'
  s.summary          = 'Pin code / OTP fields for DartNative: native one-time-code hint.'
  s.description      = <<-DESC
Native side of pinput_kit for iOS: marks the hidden native text field as a
one-time-code field so the keyboard suggests an incoming SMS code.
                       DESC
  s.homepage         = 'https://github.com/edkluivert/pinput_kit'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Kluivert' => 'team@funkash.com' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*.swift'
  s.swift_version    = '5.9'
  s.platform         = :ios, '14.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
