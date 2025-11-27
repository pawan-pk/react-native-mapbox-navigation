import Foundation
import React



protocol ParticipantsManagerDelegate: AnyObject {
    func participantsDidUpdate(_ list: [[String: Any]])
}

@objc(ParticipantsManager)
class ParticipantsManager: RCTEventEmitter {
  static var shared: ParticipantsManager?

  private var hasListeners = false
  private var participants: [[String: Any]] = []
  weak var delegate: ParticipantsManagerDelegate?   // 👈 native delegate

  override init() {
    super.init()
    ParticipantsManager.shared = self
    print("✅ ParticipantsManager initialized")
  }

  override static func moduleName() -> String! {
    return "ParticipantsManager"
  }

  override static func requiresMainQueueSetup() -> Bool {
    return true
  }

  override func supportedEvents() -> [String]! {
    return ["onParticipantsUpdate"]
  }

  override func startObserving() {
    hasListeners = true
  }

  override func stopObserving() {
    hasListeners = false
  }

  // Called from JS
  @objc(updateParticipants:)
  func updateParticipants(_ list: [[String: Any]]) {
    participants = list
    // Notify JS listeners
    if hasListeners {
      sendEvent(withName: "onParticipantsUpdate", body: list)
    }
    // Notify native listener
    delegate?.participantsDidUpdate(list)
  }
  // Allow MapboxNavigationView to pull latest list
  func getParticipants() -> [[String: Any]] {
    return participants
  }
}
