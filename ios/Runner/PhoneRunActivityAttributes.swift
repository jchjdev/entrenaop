import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct PhoneRunActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let phase: String
    let progress: String
    let pace: String
    let distance: String
    let startedAt: Date
  }

  let session: String
}
