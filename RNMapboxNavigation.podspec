# Customization:
#  $RNMapboxNavigationVersion - version specification ("~> 3.6.0", "~> 3.1.0" or "exactVersion 3.6.0" mapbox-navigation/SPM)
#  $RNMapboxMapsSwiftPackageManager can be either
#     "manual" - you're responsible for the Mapbox lib dependency either using cocoapods or SPM
#     Hash - ```
#         {
#           url: "https://github.com/mapbox/mapbox-navigation-ios.git",
#           requirement: {
#             kind: 'exactVersion',
#             version: 3.6.0,
#           },
#           product_name: ['MapboxNavigationCore','MapboxNavigationUIKit']
#         }
#         ```

require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))
folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'


# MARK: - For now before [PR Release](https://github.com/CocoaPods/CocoaPods/pull/11953)
rnMapboxNavigationDefaultVersion = 'exactVersion 3.6.0'

spm_version = ($RNMapboxNavigationVersion || rnMapboxNavigationDefaultVersion).split
  if spm_version.length < 2
    spm_version.prepend('exactVersion')
  end

$rnMapboxNavTargetsToChangeToDynamic = ['MapboxNavigation', 'MapboxNavigationNative', 'Turf', 'MapboxMaps', 'MapboxCoreMaps', 'MapboxCommon']

unless $RNMapboxNavigationSwiftPackageManager
  $RNMapboxNavigationSwiftPackageManager = {
    url: "https://github.com/mapbox/mapbox-navigation-ios.git",
    requirement: {
      kind: spm_version.first,
      version: spm_version.last,
    },
    products: ['MapboxNavigationCore','MapboxNavigationUIKit']
  }
end

$RNMapboxNavigation = Object.new

def $RNMapboxNavigation.pre_install(installer)
  installer.aggregate_targets.each do |target|
    target.pod_targets.select { |p| $rnMapboxNavTargetsToChangeToDynamic.include?(p.name) }.each do |mobile_events_target|
      mobile_events_target.instance_variable_set(:@build_type,Pod::BuildType.dynamic_framework)
      puts "* [RNMBNV] Changed #{mobile_events_target.name} to #{mobile_events_target.send(:build_type)}"
      fail "* [RNMBNV] Unable to change build_type" unless mobile_events_target.send(:build_type) == Pod::BuildType.dynamic_framework
    end
  end
end

def $RNMapboxNavigation._check_no_mapbox_spm(project)
  pkg_class = Xcodeproj::Project::Object::XCRemoteSwiftPackageReference
  ref_class = Xcodeproj::Project::Object::XCSwiftPackageProductDependency
  pkg = project.root_object.package_references.find { |p| p.class == pkg_class && [
    "https://github.com/mapbox/mapbox-navigation-ios.git",
    "https://github.com/mapbox/mapbox-maps-ios.git"
  ].include?(p.repositoryURL) }
  if pkg
    puts "!!! Warning: Duplicate Mapbox dependency found, it's consumed by both SwiftPackageManager and CocoaPods"
  end
end

def $RNMapboxNavigation._add_spm_to_target(project, target, url, requirement, products)
  pkg_class = Xcodeproj::Project::Object::XCRemoteSwiftPackageReference
  ref_class = Xcodeproj::Project::Object::XCSwiftPackageProductDependency
  pkg = project.root_object.package_references.find { |p| p.class == pkg_class && p.repositoryURL == url }
  if !pkg
    pkg = project.new(pkg_class)
    pkg.repositoryURL = url
    pkg.requirement = requirement
    project.root_object.package_references << pkg
  end
  products.each do |product_name|
    ref = target.package_product_dependencies.find do |r| 
      r.class == ref_class && r.package == pkg && r.product_name == product_name 
    end
    next if ref
    ref = project.new(ref_class)
    ref.package = pkg
    ref.product_name = product_name
    target.package_product_dependencies << ref
  end
end

def $RNMapboxNavigation.post_install(installer)
  if $RNMapboxNavigationSwiftPackageManager
    return if $RNMapboxNavigationSwiftPackageManager == "manual"

    spm_spec = $RNMapboxNavigationSwiftPackageManager
    project = installer.pods_project
    self._add_spm_to_target(
      project,
      project.targets.find { |t| t.name == "RNMapboxNavigation"},
      spm_spec[:url],
      spm_spec[:requirement],
      spm_spec[:products]
    )

    installer.aggregate_targets.group_by(&:user_project).each do |project, targets|
      targets.each do |target|
        target.user_targets.each do |user_target|
          self._add_spm_to_target(
            project,
            user_target,
            spm_spec[:url],
            spm_spec[:requirement],
            spm_spec[:products]
          )
        end
      end
    end
  else
    self._check_no_mapbox_spm(installer.pods_project)
    installer.aggregate_targets.group_by(&:user_project).each do |project, targets|
      targets.each do |target|
        target.user_targets.each do |user_target|
          self._check_no_mapbox_spm(project)
        end
      end
    end
  end
end

Pod::Spec.new do |s|
  s.name         = "RNMapboxNavigation"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/pawan-pk/react-native-mapbox-navigation.git", :tag => "#{s.version}" }

  s.source_files = [
    "ios/**/*.swift",
    "ios/**/*.{h,m,mm,cpp}"
  ]

  s.public_header_files = [
    "ios/MapboxBridge.h"
  ]

  # s.dependency 'MapboxDirections', '~> 2.14'

  # SPM in Cocoapods not supported yet [PR Request](https://github.com/CocoaPods/CocoaPods/pull/11953)
  # s.spm_dependency(
  #   url: 'https://github.com/mapbox/mapbox-navigation-ios.git',
  #   requirement: {kind: 'upToNextMajorVersion', minimumVersion: '3.6.0'},
  #   products: ['MapboxNavigationCore','MapboxNavigationUIKit']
  # )

  # Use install_modules_dependencies helper to install the dependencies if React Native version >=0.71.0.
  # See https://github.com/facebook/react-native/blob/febf6b7f33fdb4904669f99d795eba4c0f95d7bf/scripts/cocoapods/new_architecture.rb#L79.
  if respond_to?(:install_modules_dependencies, true)
    install_modules_dependencies(s)
  else
    s.dependency "React-Core"

    # Don't install the dependencies when we run `pod install` in the old architecture.
    if ENV['RCT_NEW_ARCH_ENABLED'] == '1' then
      s.compiler_flags = folly_compiler_flags + " -DRCT_NEW_ARCH_ENABLED=1"
      s.pod_target_xcconfig    = {
          "HEADER_SEARCH_PATHS" => "\"$(PODS_ROOT)/boost\"",
          "OTHER_CPLUSPLUSFLAGS" => "-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1",
          "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
      }
      s.dependency "React-RCTFabric"
      s.dependency "React-Codegen"
      s.dependency "RCT-Folly"
      s.dependency "RCTRequired"
      s.dependency "RCTTypeSafety"
      s.dependency "ReactCommon/turbomodule/core"
    end
  end
end
