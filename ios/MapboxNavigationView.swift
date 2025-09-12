
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import MapboxMaps

extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder!.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}

public protocol MapboxCarPlayDelegate {
    func connect(with navigationView: MapboxNavigationView)
    func disconnect()
}

public protocol MapboxCarPlayNavigationDelegate {
    func startNavigation(with navigationView: MapboxNavigationView)
    func endNavigation()
}

public class MapboxNavigationView: UIView, NavigationViewControllerDelegate, ParticipantsManagerDelegate {
  public weak var navViewController: NavigationViewController?
  public var indexedRouteResponse: IndexedRouteResponse?

  var embedded: Bool
  var embedding: Bool

  @objc public var startOrigin: NSArray = [] {
    didSet { setNeedsLayout() }
  }

  var waypoints: [Waypoint] = [] {
    didSet { setNeedsLayout() }
  }

  func setWaypoints(waypoints: [MapboxWaypoint]) {
    self.waypoints = waypoints.enumerated().map { (index, waypointData) in
      let name = waypointData.name as? String ?? "\(index)"
      let waypoint = Waypoint(coordinate: waypointData.coordinate, name: name)
      waypoint.separatesLegs = waypointData.separatesLegs
      return waypoint
    }
  }

  @objc var destination: NSArray = [] {
    didSet { setNeedsLayout() }
  }

  @objc var shouldSimulateRoute: Bool = false
  @objc var showsEndOfRouteFeedback: Bool = false
  @objc var showCancelButton: Bool = false
  @objc var hideStatusView: Bool = false
  @objc var mute: Bool = false
  @objc var distanceUnit: NSString = "imperial"
  @objc var language: NSString = "us"
  @objc var destinationTitle: NSString = "Destination"
  @objc var travelMode: NSString = "driving-traffic"

  @objc var onLocationChange: RCTDirectEventBlock?
  @objc var onRouteProgressChange: RCTDirectEventBlock?
  @objc var onError: RCTDirectEventBlock?
  @objc var onCancelNavigation: RCTDirectEventBlock?
  @objc var onArrive: RCTDirectEventBlock?
  @objc var vehicleMaxHeight: NSNumber?
  @objc var vehicleMaxWidth: NSNumber?
  var pointAnnotationManager: PointAnnotationManager?
  var cacheManager: LRUCache<String,URL> = LRUCache<String,URL>(capacity: 10000)

  override init(frame: CGRect) {
    self.embedded = false
    self.embedding = false
    super.init(frame: frame)
    ParticipantsManager.shared?.delegate = self
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func layoutSubviews() {
    super.layoutSubviews()

    if (navViewController == nil && !embedding && !embedded) {
      embed()
    } else {
      navViewController?.view.frame = bounds
    }
  }

  func participantsDidUpdate(_ list: [[String: Any]]) {
    updateParticipantsOnMap(list)
  }

  public override func removeFromSuperview() {
    super.removeFromSuperview()
    // cleanup and teardown any existing resources
    self.navViewController?.removeFromParent()

    // MARK: End CarPlay Navigation
    if let carPlayNavigation = UIApplication.shared.delegate as? MapboxCarPlayNavigationDelegate {
      carPlayNavigation.endNavigation()
    }
    NotificationCenter.default.removeObserver(self, name: .navigationSettingsDidChange, object: nil)
  }

  private func embed() {
    guard startOrigin.count == 2 && destination.count == 2 else { return }

    embedding = true

    let originWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: startOrigin[1] as! CLLocationDegrees, longitude: startOrigin[0] as! CLLocationDegrees))
    var waypointsArray = [originWaypoint]

    // Add Waypoints
    waypointsArray.append(contentsOf: waypoints)

    let destinationWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: destination[1] as! CLLocationDegrees, longitude: destination[0] as! CLLocationDegrees), name: destinationTitle as String)
    waypointsArray.append(destinationWaypoint)

    let profile: MBDirectionsProfileIdentifier

    switch travelMode {
      case "cycling":
        profile = .cycling
      case "walking":
        profile = .walking
      case "driving-traffic":
        profile = .automobileAvoidingTraffic
      default:
        profile = .automobile
    }

    let options = NavigationRouteOptions(waypoints: waypointsArray, profileIdentifier: profile)

    let locale = self.language.replacingOccurrences(of: "-", with: "_")
    options.locale = Locale(identifier: locale)
    options.distanceMeasurementSystem =  distanceUnit == "imperial" ? .imperial : .metric

    Directions.shared.calculateRoutes(options: options) { [weak self] result in
      guard let strongSelf = self, let parentVC = strongSelf.parentViewController else {
        return
      }

      switch result {
        case .failure(let error):
          strongSelf.onError!(["message": error.localizedDescription])
        case .success(let response):
          strongSelf.indexedRouteResponse = response
          let navigationOptions = NavigationOptions(simulationMode: strongSelf.shouldSimulateRoute ? .always : .never)
          let vc = NavigationViewController(for: response, navigationOptions: navigationOptions)

          vc.showsEndOfRouteFeedback = strongSelf.showsEndOfRouteFeedback
          StatusView.appearance().isHidden = strongSelf.hideStatusView

          NavigationSettings.shared.voiceMuted = strongSelf.mute
          NavigationSettings.shared.distanceUnit = strongSelf.distanceUnit == "imperial" ? .mile : .kilometer

          vc.delegate = strongSelf

          parentVC.addChild(vc)
          strongSelf.addSubview(vc.view)
          vc.view.frame = strongSelf.bounds
          vc.didMove(toParent: parentVC)
          strongSelf.navViewController = vc
      }

      strongSelf.embedding = false
      strongSelf.embedded = true

      // MARK: Start CarPlay Navigation
      if let carPlayNavigation = UIApplication.shared.delegate as? MapboxCarPlayNavigationDelegate {
        carPlayNavigation.startNavigation(with: strongSelf)
      }
    }
  }

  public func navigationViewController(_ navigationViewController: NavigationViewController, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
    onLocationChange?([
      "longitude": location.coordinate.longitude,
      "latitude": location.coordinate.latitude,
      "heading": 0,
      "accuracy": location.horizontalAccuracy.magnitude
    ])
    onRouteProgressChange?([
      "distanceTraveled": progress.distanceTraveled,
      "durationRemaining": progress.durationRemaining,
      "fractionTraveled": progress.fractionTraveled,
      "distanceRemaining": progress.distanceRemaining
    ])
  }

  public func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
    if (!canceled) {
      return;
    }
    onCancelNavigation?(["message": "Navigation Cancel"]);
  }

  public func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) -> Bool {
    onArrive?([
      "name": waypoint.name ?? waypoint.description,
      "longitude": waypoint.coordinate.latitude,
      "latitude": waypoint.coordinate.longitude,
    ])
    return true;
  }

  private func updateParticipantsOnMap(_ list: [[String: Any]]) {
    guard let mapView = navViewController?.navigationMapView else { return }
    if pointAnnotationManager == nil {
      pointAnnotationManager = mapView.mapView.annotations.makePointAnnotationManager()
    }
    var uannotations: [PointAnnotation] = []
    for user in list {
      guard
        let id = user["id"] as? String,
        let lat = user["lat"] as? Double,
        let lng = user["lng"] as? Double
      else { continue }
      let imageUrl = user["imageUrl"] as? String ?? ""
      let newCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
      var annotation = PointAnnotation(id: id, coordinate: newCoordinate)
      if let imageUrl = cacheManager.get(id), let userImge = UIImage(contentsOfFile: imageUrl.path)  {
        annotation.image = .init(image: userImge, name: id)
      } else if let image = imageFromURI(imageUrl,userId: id) {
        annotation.image = .init(image: image.withRounded(radius: 10, borderWidth: 1, borderColor: UIColor.white), name: id)
      }
      annotation.userInfo = user
      uannotations.append(annotation)
    }
    self.pointAnnotationManager?.annotations = uannotations
  }
  
  func imageFromURI(_ uri: String, userId: String) -> UIImage? {
    if uri.hasPrefix("asset:/") {
      let name = uri.replacingOccurrences(of: "asset:/", with: "")
      return UIImage(named: name)
    } else if uri.hasPrefix("file://") {
      let path = uri.replacingOccurrences(of: "file://", with: "")
      return UIImage(contentsOfFile: path)
    } else {
      downloadImageToTemp(urlString: uri, userId: userId, completion: { [weak self,userId] result in
        guard let self = self else { return }
        switch result {
          case .success(let success):
            self.cacheManager.put(userId, value: success.1)
          case .failure(let failure):
            print(failure.localizedDescription)
        }
      })
    }
    return nil
  }

  func downloadImageToTemp(urlString: String, userId: String , completion: @escaping (Result<(UIImage,URL), Error>) -> Void) {
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent("\(userId).jpg")
    if FileManager.default.fileExists(atPath: fileURL.path) {
      completion(.success((UIImage(contentsOfFile: fileURL.path)!, fileURL)))
      return
    }

    guard let url = URL(string: urlString) else {
      completion(.failure(NSError(domain: "InvalidURL", code: -1)))
      return
    }

    let task = URLSession.shared.dataTask(with: url) {[userId] data, response, error in
      if let error = error {
        completion(.failure(error))
        return
      }

      guard let data = data,
              let image = UIImage(data: data)?.withRounded(radius: 10, borderWidth: 1, borderColor: UIColor.white),
              let newImageData = image.pngData()
      else {
        completion(.failure(NSError(domain: "InvalidImageData", code: -2)))
        return
      }

      // Create a temp file URL
      let tempDir = FileManager.default.temporaryDirectory
      let fileURL = tempDir.appendingPathComponent("\(userId).jpg")

      do {
        try newImageData.write(to: fileURL)
        completion(.success((image,fileURL)))
      } catch {
        completion(.failure(error))
      }
    }
    task.resume()
  }
}
