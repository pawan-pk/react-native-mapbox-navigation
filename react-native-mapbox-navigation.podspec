require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))
folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'

# ---------------------------------------------------------------------------
# Mapbox Navigation iOS SDK v3 via vendored binary xcframeworks.
#
# Mapbox publishes prebuilt binary .xcframeworks for every nav module at v3.20.1
# via the `mapbox-navigation-ios-build-artifacts` distribution — including the
# three (MapboxNavigationCore / MapboxNavigationUIKit / _MapboxNavigationHelpers)
# that only *appear* source-only in the main mapbox-navigation-ios SPM package
# (its products are empty re-export shims). v3 has no CocoaPods pod, so we vendor
# these binaries directly. They are NOT committed (Mapbox ToS forbids
# redistribution; ~80MB; download-token-gated) — the consuming app fetches them
# into ios/Frameworks/ on demand (see the host app's fetch-mapbox-nav-binaries.sh
# + ~/.netrc Mapbox DOWNLOADS:READ token, the same token @rnmapbox/maps needs).
#
# MapboxMaps (+ transitive MapboxCoreMaps / MapboxCommon / Turf) comes from the
# CocoaPods `MapboxMaps` pod, which @rnmapbox/maps also depends on — CocoaPods
# dedupes pods by name, so there is exactly ONE MapboxMaps copy by construction
# (no SPM, no duplicate-symbol wall, no use_frameworks! requirement).
#
# Versions (interlocked — lift from the matching build-artifacts tag on bump):
# nav 3.20.1 / MapboxNavigationNative 324.20.2 (bucket dash-native) /
# MapboxCommon 24.20.2 / MapboxMaps 11.20.2 (matches @rnmapbox/maps@10.3.1).
# ---------------------------------------------------------------------------

Pod::Spec.new do |s|
  s.name         = "react-native-mapbox-navigation"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/stefanpavlovic-tech/react-native-mapbox-navigation.git", :tag => "#{s.version}" }

  # Non-recursive: the sources are all at ios/ top-level. Avoids descending into
  # ios/Frameworks/ (the vendored xcframeworks) — and avoids an exclude_files
  # pattern, which would ALSO strip the vendored frameworks (CocoaPods applies it
  # broadly), causing "no such module 'MapboxDirections'".
  s.source_files = "ios/*.{h,m,mm,swift}"

  # Placeholder puck (per vehicle type) + donor destination-pin PNGs, bundled as
  # a named resource bundle so the Swift loads them via UIImage(named:in:).
  # Designer-replaceable: same filenames in ios/Assets/ = drop-in swap.
  s.resource_bundles = {
    "MapboxNavigationAssets" => ["ios/Assets/*.png"]
  }

  # Vendor the Mapbox Nav v3 binary xcframeworks (dynamic, library-evolution →
  # link-and-embed once). Fetched on demand into ios/Frameworks/ (see header).
  s.vendored_frameworks = "ios/Frameworks/*.xcframework"
  s.static_framework = true

  # Shared MapboxMaps (CocoaPods) — same pod @rnmapbox/maps consumes, deduped by name.
  s.dependency "MapboxMaps", "11.20.2"

  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES",
    "SWIFT_COMPILATION_MODE" => "wholemodule",
  }

  # Install the React dependencies (New Arch) if RN >= 0.71.0.
  if respond_to?(:install_modules_dependencies, true)
    install_modules_dependencies(s)
  else
    s.dependency "React-Core"

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
