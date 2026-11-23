import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PhoneRunWidget: Widget {
  private let orange = Color(red: 1, green: 0.54, blue: 0.31)

  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PhoneRunActivityAttributes.self) { context in
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Label(context.state.phase, systemImage: "figure.run")
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
          Spacer()
          if !context.state.progress.isEmpty {
            Text(context.state.progress)
              .lineLimit(1)
              .minimumScaleFactor(0.8)
              .foregroundStyle(.white.opacity(0.8))
          }
        }
        .font(.subheadline)
        HStack(alignment: .bottom, spacing: 12) {
          VStack(alignment: .leading, spacing: 0) {
            Text(context.isStale ? "Ritmo sin actualizar" : "Ritmo reciente")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.white.opacity(0.8))
            HStack(alignment: .firstTextBaseline, spacing: 5) {
              Text(paceValue(context))
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(paceValue(context) == "—" ? .white.opacity(0.8) : orange)
              Text("min/km")
                .font(.caption.weight(.semibold))
                .fixedSize()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(paceValue(context) == "—" ? "Ritmo pendiente" : context.state.pace)
          }
          .layoutPriority(1)
          Spacer(minLength: 0)
          VStack(alignment: .trailing, spacing: 4) {
            if !context.state.distance.isEmpty {
              Text(context.state.distance).accessibilityLabel("Distancia \(context.state.distance)")
            }
            if !context.isStale {
              Text(context.state.startedAt, style: .timer)
                .multilineTextAlignment(.trailing)
            }
          }
          .font(.subheadline.weight(.semibold).monospacedDigit())
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .foregroundStyle(.white.opacity(0.8))
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .foregroundStyle(.white)
      .activityBackgroundTint(Color(red: 0.075, green: 0.08, blue: 0.095))
      .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(context.state.phase, systemImage: "figure.run")
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(context.isStale ? "—" : context.state.pace)
            .font(.headline.monospacedDigit())
            .foregroundStyle(orange)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text([context.state.distance, context.state.progress]
            .filter { !$0.isEmpty }.joined(separator: " · "))
        }
      } compactLeading: {
        Image(systemName: "figure.run")
      } compactTrailing: {
        Text(paceValue(context)).fontWeight(.semibold).monospacedDigit()
      } minimal: {
        Image(systemName: "figure.run")
      }
    }
  }

  private func paceValue(_ context: ActivityViewContext<PhoneRunActivityAttributes>) -> String {
    context.isStale ? "—" : String(context.state.pace.split(separator: " ").first ?? "—")
  }
}
