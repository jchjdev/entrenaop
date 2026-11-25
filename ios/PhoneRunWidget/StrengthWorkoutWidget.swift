import ActivityKit
import SwiftUI
import WidgetKit

struct StrengthWorkoutWidget: Widget {
  private let orange = Color(red: 1, green: 0.54, blue: 0.31)

  var body: some WidgetConfiguration {
    ActivityConfiguration(for: StrengthWorkoutActivityAttributes.self) { context in
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Label(phase(context), systemImage: "dumbbell.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.8))
          Spacer(minLength: 8)
          if let end = remainingUntil(context) {
            countdown(context, until: end)
              .font(.system(size: 34, weight: .heavy, design: .rounded))
              .foregroundStyle(orange)
              .frame(width: 112, alignment: .trailing)
          }
        }
        exercise(context)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .foregroundStyle(.white)
      .activityBackgroundTint(Color(red: 0.075, green: 0.08, blue: 0.095))
      .activitySystemActionForegroundColor(.white)
      .widgetURL(context.attributes.openURL)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(phase(context), systemImage: "dumbbell.fill")
            .font(.subheadline)
        }
        DynamicIslandExpandedRegion(.trailing) {
          if let end = remainingUntil(context) {
            countdown(context, until: end)
              .font(.headline)
              .foregroundStyle(orange)
              .frame(width: 66, alignment: .trailing)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          exercise(context)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      } compactLeading: {
        Image(systemName: "dumbbell.fill")
      } compactTrailing: {
        if let end = remainingUntil(context) {
          countdown(context, until: end)
            .font(.caption.weight(.semibold))
            .frame(maxWidth: 50)
        } else {
          Text("Fuerza").font(.caption)
        }
      } minimal: {
        Image(systemName: "dumbbell.fill")
      }
      .widgetURL(context.attributes.openURL)
    }
  }

  private func exercise(_ context: ActivityViewContext<StrengthWorkoutActivityAttributes>) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(context.state.exercise)
        .font(.title3.weight(.bold))
        .lineLimit(2)
      Text(context.state.prescription)
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.8))
        .lineLimit(2)
    }
  }

  private func remainingUntil(_ context: ActivityViewContext<StrengthWorkoutActivityAttributes>) -> Date? {
    context.isStale ? nil : context.state.restEndsAt
  }

  private func phase(_ context: ActivityViewContext<StrengthWorkoutActivityAttributes>) -> String {
    if remainingUntil(context) != nil { return "Descanso" }
    return context.state.restEndsAt == nil ? "Entrenamiento en curso" : "Siguiente serie"
  }

  private func countdown(
    _ context: ActivityViewContext<StrengthWorkoutActivityAttributes>, until end: Date
  ) -> some View {
    Text(timerInterval: context.state.publishedAt...end, pauseTime: end, showsHours: false)
      .monospacedDigit()
      .lineLimit(1)
      .minimumScaleFactor(0.65)
      .multilineTextAlignment(.trailing)
  }
}
