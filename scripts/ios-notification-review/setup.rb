require 'xcodeproj'
require 'fileutils'
root = File.expand_path('../..', __dir__)
def extension(project, path, bundle)
 t = project.new_target(:app_extension, 'BlabNotificationContent', :ios, '15.0')
 t.add_system_framework('UserNotificationsUI')
 t.add_system_framework('UserNotifications')
 group = project.main_group.new_group('BlabNotificationContent', path)
 t.source_build_phase.add_file_reference(group.new_file('NotificationViewController.swift'))
 t.source_build_phase.add_file_reference(group.new_file('NotificationDisplay.swift'))
 t.resources_build_phase.add_file_reference(group.new_file('notification_badge_exact.png'))
 t.build_configurations.each { |c| c.build_settings.merge!({'INFOPLIST_FILE'=>"#{path}/Info.plist", 'PRODUCT_BUNDLE_IDENTIFIER'=>bundle, 'SWIFT_VERSION'=>'5.0', 'APPLICATION_EXTENSION_API_ONLY'=>'YES', 'CODE_SIGN_STYLE'=>'Automatic', 'DEVELOPMENT_TEAM'=>'A7QWVJG835', 'SKIP_INSTALL'=>'YES', 'TARGETED_DEVICE_FAMILY'=>'1,2'}) }
 if bundle.start_with?('com.blab.notificationreview')
  t.build_configurations.each { |c| c.build_settings['FLUTTER_BUILD_NAME'] = '1.0'; c.build_settings['FLUTTER_BUILD_NUMBER'] = '1' }
 end
 t
end
# Production app: display-only extension, not activated by any existing payload/category.
p = Xcodeproj::Project.open("#{root}/ios/Runner.xcodeproj")
unless p.targets.any? { |t| t.name == 'BlabNotificationContent' }
 t = extension(p, 'BlabNotificationContent', '$(BLAB_BUNDLE_ID).NotificationContent')
 runner = p.targets.find { |r| r.name == 'Runner' }; runner.add_dependency(t)
 phase = runner.new_copy_files_build_phase('Embed Notification Content'); phase.dst_subfolder_spec = '13'
 phase.add_file_reference(t.product_reference).settings = {'ATTRIBUTES'=>['RemoveHeadersOnCopy']}
 p.save
end
existing = p.targets.find { |t| t.name == 'BlabNotificationContent' }
existing.add_system_framework('UserNotificationsUI'); existing.add_system_framework('UserNotifications'); p.save
unless existing.source_build_phase.files_references.any? { |f| f.path == 'NotificationDisplay.swift' }
 group = p.main_group.groups.find { |g| g.name == 'BlabNotificationContent' }
 existing.source_build_phase.add_file_reference(group.new_file('NotificationDisplay.swift')); p.save
end
config_group = p.main_group.groups.find { |g| g.name == 'BlabNotificationContent' }
config = config_group.files.find { |f| f.path == 'Config.xcconfig' } || config_group.new_file('Config.xcconfig')
existing.build_configurations.each { |c| c.base_configuration_reference = config; c.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)' }
runner = p.targets.find { |t| t.name == 'Runner' }
embed = runner.build_phases.find { |b| b.display_name == 'Embed Notification Content' }
runner.build_phases.delete(embed)
index = runner.build_phases.index { |b| b.display_name == 'Thin Binary' } || runner.build_phases.length
runner.build_phases.insert(index, embed)
p.save
# Small real iOS host to exercise the exact same extension without Flutter/Pods.
path = "#{root}/build/ios-notification-review"; FileUtils.mkdir_p(path)
File.write("#{path}/Communication.entitlements", '<?xml version="1.0"?><plist version="1.0"><dict><key>com.apple.developer.usernotifications.communication</key><true/></dict></plist>')
File.write("#{path}/ReviewInfo.plist", '<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string><key>CFBundleIdentifier</key><string>$(PRODUCT_BUNDLE_IDENTIFIER)</string><key>CFBundleName</key><string>Blab Review</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleVersion</key><string>1</string><key>CFBundleShortVersionString</key><string>1.0</string><key>NSUserActivityTypes</key><array><string>INSendMessageIntent</string></array><key>UILaunchScreen</key><dict/></dict></plist>')

p = Xcodeproj::Project.new("#{path}/Review.xcodeproj")
t = p.new_target(:application, 'BlabNotificationReview', :ios, '15.0')
t.source_build_phase.add_file_reference(p.main_group.new_file("#{root}/scripts/ios-notification-review/App.swift"))
t.resources_build_phase.add_file_reference(p.main_group.new_file("#{root}/ios/BlabNotificationContent/notification_badge_exact.png"))
t.add_system_framework('Intents')
t.build_configurations.each { |c| c.build_settings.merge!({'CODE_SIGN_ENTITLEMENTS'=>"#{path}/Communication.entitlements", 'INFOPLIST_FILE'=>"#{path}/ReviewInfo.plist", 'INFOPLIST_KEY_NSUserActivityTypes'=>['INSendMessageIntent'], 'PRODUCT_BUNDLE_IDENTIFIER'=>'com.blab.notificationreview', 'SWIFT_VERSION'=>'5.0', 'GENERATE_INFOPLIST_FILE'=>'YES', 'INFOPLIST_KEY_CFBundleDisplayName'=>'Blab Review', 'INFOPLIST_KEY_UILaunchScreen_Generation'=>'YES', 'TARGETED_DEVICE_FAMILY'=>'1,2', 'CODE_SIGNING_ALLOWED'=>'NO'}) }
e = extension(p, "#{root}/ios/BlabNotificationContent", 'com.blab.notificationreview.NotificationContent'); t.add_dependency(e)
phase=t.new_copy_files_build_phase('Embed Notification Content'); phase.dst_subfolder_spec='13'; phase.add_file_reference(e.product_reference)
ui=p.new_target(:ui_test_bundle, 'ReviewTests', :ios, '15.0')
ui.source_build_phase.add_file_reference(p.main_group.new_file("#{root}/scripts/ios-notification-review/ReviewTests.swift"))
ui.source_build_phase.add_file_reference(p.main_group.new_file("#{root}/scripts/ios-notification-review/FullAppTests.swift"))
ui.add_dependency(t)
ui.build_configurations.each { |c| c.build_settings.merge!({'PRODUCT_BUNDLE_IDENTIFIER'=>'com.blab.notificationreview.tests', 'SWIFT_VERSION'=>'5.0', 'GENERATE_INFOPLIST_FILE'=>'YES', 'TEST_TARGET_NAME'=>'BlabNotificationReview', 'CODE_SIGNING_ALLOWED'=>'NO'}) }
p.save
scheme=Xcodeproj::XCScheme.new; scheme.add_build_target(t); scheme.add_test_target(ui); scheme.set_launch_target(t); scheme.save_as(p.path, 'BlabNotificationReview', true)
