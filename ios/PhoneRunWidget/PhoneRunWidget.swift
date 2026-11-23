import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PhoneRunWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PhoneRunActivityAttributes.self) { context in
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Label(context.state.phase, systemImage: "figure.run")
            .font(.headline)
          Spacer()
          if !context.isStale {
            Text(context.state.startedAt, style: .timer).monospacedDigit()
          }
        }
        Text(context.isStale ? "Ritmo sin actualizar" : context.state.pace)
          .font(.title2.bold()).monospacedDigit()
        Text([context.state.distance, context.state.progress]
          .filter { !$0.isEmpty }.joined(separator: " · "))
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .padding()
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(context.state.phase, systemImage: "figure.run")
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(context.isStale ? "—" : context.state.pace).monospacedDigit()
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text([context.state.distance, context.state.progress]
            .filter { !$0.isEmpty }.joined(separator: " · "))
        }
      } compactLeading: {
        Image(systemName: "figure.run")
      } compactTrailing: {
        Text(context.isStale ? "—" : context.state.pace.components(separatedBy: " ").first ?? "—")
          .monospacedDigit()
      } minimal: {
        Image(systemName: "figure.run")
      }
    }
  }
}
