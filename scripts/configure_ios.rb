require 'xcodeproj'
project = Xcodeproj::Project.open(File.expand_path('../ios/Runner.xcodeproj', __dir__))
runner = project.targets.find { |t| t.name == 'Runner' }
runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
end
unless project.targets.any? { |t| t.name == 'ShareExtension' }
  target = project.new_target(:app_extension, 'ShareExtension', :ios, '15.0')
  group = project.main_group.new_group('ShareExtension', 'ShareExtension')
  target.source_build_phase.add_file_reference(group.new_file('ShareViewController.swift'))
  group.new_file('Info.plist'); group.new_file('ShareExtension.entitlements')
  target.build_configurations.each do |config|
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.trailcapsule.trailCapsule.ShareExtension'
    config.build_settings['INFOPLIST_FILE'] = 'ShareExtension/Info.plist'
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'ShareExtension/ShareExtension.entitlements'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
    config.build_settings['SKIP_INSTALL'] = 'YES'
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  end
  runner.add_dependency(target)
  phase = runner.new_copy_files_build_phase('Embed App Extensions')
  phase.dst_subfolder_spec = '13'
  phase.add_file_reference(target.product_reference).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  # Embed before Flutter's thinning phase to avoid an Xcode dependency cycle.
  runner.build_phases.delete(phase)
  runner.build_phases.insert(0, phase)
end
extension = project.targets.find { |t| t.name == 'ShareExtension' }
extension.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['MARKETING_VERSION'] = '1.0.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
end
project.save
