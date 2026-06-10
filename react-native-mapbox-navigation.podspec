require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))
folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'

# ---------------------------------------------------------------------------
# Mapbox Navigation iOS SDK v3 is distributed ONLY via Swift Package Manager —
# there is NO 3.x CocoaPods pod (the `MapboxNavigation` trunk pod tops out at
# 2.21.0). CocoaPods does not yet support declaring an SPM dependency from a
# podspec (CocoaPods/CocoaPods#11953 is unmerged). So, mirroring how
# @rnmapbox/maps injects MapboxMaps via `$RNMapboxMaps`, this podspec exposes a
# `$RNMapboxNavigation` helper whose pre_install / post_install hooks the host
# app's Podfile must call. post_install adds the mapbox-navigation-ios SPM
# package + its products (MapboxNavigationCore, MapboxNavigationUIKit) to BOTH
# the user app target AND this pod's target, so the pod's Swift can `import` them.
#
# Customization (set in the host Podfile BEFORE `use_native_modules!`):
#   $RNMapboxNavigationVersion = 'exactVersion 3.20.1'   # default below
#   $RNMapboxNavigationSwiftPackageManager = 'manual'    # opt out of SPM injection
#
# Version note: nav 3.20.1 pins MapboxMaps `exact 11.20.2`. Align the host's
# MapboxMaps to the SAME version (e.g. `$RNMapboxMapsVersion = 'exactVersion 11.20.2'`)
# so @rnmapbox/maps (CocoaPods) and the nav SDK (SPM) share one MapboxMaps.
# ---------------------------------------------------------------------------

rnMapboxNavigationDefaultVersion = 'exactVersion 3.20.1'

spm_version = ($RNMapboxNavigationVersion || rnMapboxNavigationDefaultVersion).split
if spm_version.length < 2
  spm_version.prepend('exactVersion')
end

# The pod target name CocoaPods generates for this spec (matches s.name below).
$rnMapboxNavigationPodTargetName = 'react-native-mapbox-navigation'

# Mapbox libs that must be linked as dynamic frameworks so a single copy is
# shared across the app, @rnmapbox/maps and the nav SDK.
$rnMapboxNavTargetsToChangeToDynamic = ['MapboxMobileEvents', 'Turf', 'MapboxMaps', 'MapboxCoreMaps', 'MapboxCommon']

unless $RNMapboxNavigationSwiftPackageManager
  $RNMapboxNavigationSwiftPackageManager = {
    url: "https://github.com/mapbox/mapbox-navigation-ios.git",
    requirement: {
      kind: spm_version.first,
      version: spm_version.last,
    },
    products: ['MapboxNavigationCore', 'MapboxNavigationUIKit']
  }
end

$RNMapboxNavigation = Object.new

def $RNMapboxNavigation.pre_install(installer)
  installer.aggregate_targets.each do |target|
    target.pod_targets.select { |p| $rnMapboxNavTargetsToChangeToDynamic.include?(p.name) }.each do |dynamic_target|
      dynamic_target.instance_variable_set(:@build_type, Pod::BuildType.dynamic_framework)
      puts "* [RNMBNV] Changed #{dynamic_target.name} to #{dynamic_target.send(:build_type)}"
      fail "* [RNMBNV] Unable to change build_type" unless dynamic_target.send(:build_type) == Pod::BuildType.dynamic_framework
    end
  end
end

def $RNMapboxNavigation._check_no_mapbox_spm(project)
  pkg_class = Xcodeproj::Project::Object::XCRemoteSwiftPackageReference
  pkg = project.root_object.package_references.find { |p| p.class == pkg_class && [
    "https://github.com/mapbox/mapbox-navigation-ios.git",
    "https://github.com/mapbox/mapbox-maps-ios.git"
  ].include?(p.repositoryURL) }
  if pkg
    puts "!!! [RNMBNV] Warning: Duplicate Mapbox dependency found, consumed by both SwiftPackageManager and CocoaPods"
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

    # 1. Add the SPM package + products to THIS pod's target inside Pods.xcodeproj,
    #    so the pod's Swift (`import MapboxNavigationCore` / `MapboxNavigationUIKit`) compiles.
    pods_project = installer.pods_project
    pod_target = pods_project.targets.find { |t| t.name == $rnMapboxNavigationPodTargetName }
    if pod_target
      self._add_spm_to_target(
        pods_project,
        pod_target,
        spm_spec[:url],
        spm_spec[:requirement],
        spm_spec[:products]
      )
    else
      puts "!!! [RNMBNV] Could not find pod target '#{$rnMapboxNavigationPodTargetName}' to attach the SPM package"
    end

    # 2. Add the SPM package + products to the user app target(s), so the frameworks
    #    are embedded/linked into the final app.
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
  end
end

Pod::Spec.new do |s|
  s.name         = "react-native-mapbox-navigation"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/stefanpavlovic-tech/react-native-mapbox-navigation.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift}"

  # NOTE: No `s.dependency 'MapboxNavigation'` — the v3 nav SDK is injected via
  # the $RNMapboxNavigation SPM hooks above (called from the host Podfile).

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
