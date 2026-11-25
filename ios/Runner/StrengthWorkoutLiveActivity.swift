import ActivityKit
import UIKit

@available(iOS 16.2, *)
@MainActor
final class StrengthWorkoutLiveActivity {
  private var activity: Activity<StrengthWorkoutActivityAttributes>?
  private var pending: Task<Void, Never>?

  init() {
    let previous = Activity<StrengthWorkoutActivityAttributes>.activities
    pending = Task {
      for item in previous { await item.end(nil, dismissalPolicy: .immediate) }
    }
  }

  func show(_ data: [String: Any]) {
    guard let id = data["executionId"] as? String,
      let exercise = data["exercise"] as? String,
      let prescription = data["prescription"] as? String,
      let rawURL = data["openUrl"] as? String,
      let url = URL(string: rawURL) else { return }

    let now = Date()
    let deadline = (data["restEndsAt"] as? NSNumber).flatMap { milliseconds -> Date? in
      let date = Date(timeIntervalSince1970: milliseconds.doubleValue / 1_000)
      return date > now ? date : nil
    }
    let content = ActivityContent(
      state: StrengthWorkoutActivityAttributes.ContentState(
        exercise: exercise, prescription: prescription,
        restEndsAt: deadline, publishedAt: now),
      staleDate: deadline
    )
    enqueue {
      if let current = self.activity, current.attributes.executionId == id,
        current.activityState == .active || current.activityState == .stale {
        await current.update(content)
        return
      }
      guard UIApplication.shared.applicationState != .background,
        ActivityAuthorizationInfo().areActivitiesEnabled else { return }
      if let old = self.activity { await old.end(nil, dismissalPolicy: .immediate) }
      self.activity = try? Activity.request(
        attributes: StrengthWorkoutActivityAttributes(executionId: id, openURL: url),
        content: content, pushType: nil
      )
    }
  }

  func clear(_ executionId: String) {
    enqueue {
      guard let current = self.activity, current.attributes.executionId == executionId else { return }
      self.activity = nil
      await current.end(nil, dismissalPolicy: .immediate)
    }
  }

  private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
    let previous = pending
    // Un salto de descanso puede llegar antes de que ActivityKit marque la tarjeta anterior.
    pending = Task {
      await previous?.value
      await operation()
    }
  }
}
