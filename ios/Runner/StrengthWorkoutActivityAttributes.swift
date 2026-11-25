import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct StrengthWorkoutActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let exercise: String
    let prescription: String
    let restEndsAt: Date?
    let publishedAt: Date
  }

  let executionId: String
  let openURL: URL
}
