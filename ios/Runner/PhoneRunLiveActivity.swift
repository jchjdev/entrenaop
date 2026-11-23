import ActivityKit
import UIKit

@available(iOS 16.2, *)
final class PhoneRunLiveActivity {
  private var activity: Activity<PhoneRunActivityAttributes>?

  init() {
    let stale = Activity<PhoneRunActivityAttributes>.activities
    Task {
      for item in stale { await item.end(nil, dismissalPolicy: .immediate) }
    }
  }

  func publish(_ data: [String: Any], token: String) {
    let now = Date()
    let state = PhoneRunActivityAttributes.ContentState(
      phase: data["phase"] as? String ?? "Carrera",
      progress: data["progress"] as? String ?? "",
      pace: data["pace"] as? String ?? "— min/km",
      distance: data["distance"] as? String ?? "",
      startedAt: now.addingTimeInterval(-Double(data["seconds"] as? Int ?? 0))
    )
    let content = ActivityContent(state: state, staleDate: now.addingTimeInterval(12))
    if let activity, activity.attributes.session == token {
      Task { await activity.update(content) }
      return
    }
    guard UIApplication.shared.applicationState != .background,
      ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    if let old = activity { end(old.attributes.session) }
    activity = try? Activity.request(attributes: PhoneRunActivityAttributes(session: token),
      content: content, pushType: nil)
  }

  func end(_ token: String) {
    guard let current = activity, current.attributes.session == token else { return }
    activity = nil
    Task { await current.end(nil, dismissalPolicy: .immediate) }
  }
}
