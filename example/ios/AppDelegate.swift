//
//  AppDelegate.swift
//  MapboxNavigationExample
//
//  Created by Pawan Kushwaha on 04/09/2024.
//

import React
import UIKit
import CarPlay
import MapboxNavigation
import MapboxCoreNavigation
import react_native_mapbox_navigation

@main
class AppDelegate: RCTAppDelegate {
  var rootView: UIView?
  
  // MARK: CarPlay
  var _carPlayManager: Any? = nil
  var carPlayManager: CarPlayManager {
      if _carPlayManager == nil {
          _carPlayManager = CarPlayManager(customRoutingProvider: MapboxRoutingProvider(.hybrid))
      }
      
      return _carPlayManager as! CarPlayManager
  }
  weak var currentMapboxNavigationView: MapboxNavigationView?

  // MARK: AppDelegate Functions
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

    moduleName = "MapboxNavigationExample"
    initialProps = [String: Any]()

    let app = super.application(application, didFinishLaunchingWithOptions: launchOptions);

    rootView = self.createRootView(
      with: self.bridge!,
      moduleName: self.moduleName!,
      initProps: self.initialProps!
    )

    return app
  }
  
  override func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    if connectingSceneSession.role == UISceneSession.Role.carTemplateApplication {
      return  UISceneConfiguration(name: "CarPlay", sessionRole: connectingSceneSession.role)
    }
    return UISceneConfiguration(name: "ExampleApp", sessionRole: connectingSceneSession.role)
  }

  override func sourceURL(for bridge: RCTBridge) -> URL? {
    return bundleURL()
  }

  override func bundleURL() -> URL? {
    #if DEBUG
      return RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index");
    #else
      return Bundle.main.url(forResource:"main", withExtension:"jsbundle")
    #endif
  }
}

