require 'xcodeproj'
root=File.expand_path('../..',__dir__)
path=File.join(root,'docs/qa/2026-11-07-bla39/retry18633/PickerUI.xcodeproj')
p=Xcodeproj::Project.new(path)
t=p.new_target(:ui_test_bundle,'PickerUI',:ios,'18.0')
f=p.main_group.new_file(File.join(root,'scripts/qa/Picker18633.swift'))
t.source_build_phase.add_file_reference(f)
t.build_configurations.each do |c|
 c.build_settings['PRODUCT_BUNDLE_IDENTIFIER']='blab.qa18633.PickerUI'
 c.build_settings['GENERATE_INFOPLIST_FILE']='YES'
 c.build_settings['SWIFT_VERSION']='5.0'
 c.build_settings['CODE_SIGNING_ALLOWED']='NO'
 c.build_settings['TEST_TARGET_NAME']=''
 c.build_settings['IPHONEOS_DEPLOYMENT_TARGET']='18.0'
end
p.save
scheme=Xcodeproj::XCScheme.new
scheme.add_build_target(t)
scheme.add_test_target(t)
scheme.save_as(path,'PickerUI',true)
