import ActivityKit
import SwiftUI
import WidgetKit

@main
struct AmarinLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    ExpiryLiveActivityWidget()
  }
}

struct ExpiryLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: ExpiryActivityAttributes.self) { context in
      lockScreenView(context)
        .activityBackgroundTint(Color(red: 0.10, green: 0.035, blue: 0.025))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          brandMark(size: 36)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(context.state.dayLabel)
            .font(.subheadline.bold())
            .foregroundStyle(statusColor(for: context.state.daysRemaining))
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 2) {
            Text(context.state.name)
              .font(.headline)
              .lineLimit(1)
            Text(context.state.activityTitle)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            Label(context.state.expiryDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
            Spacer()
            Text(context.state.countLabel)
          }
          .font(.caption2.bold())
          .foregroundStyle(.secondary)
        }
      } compactLeading: {
        Image(systemName: "leaf.fill")
          .foregroundStyle(.orange)
      } compactTrailing: {
        Text(shortDayLabel(context.state))
          .font(.caption2.bold())
          .foregroundStyle(statusColor(for: context.state.daysRemaining))
      } minimal: {
        Image(systemName: "clock.badge.exclamationmark.fill")
          .foregroundStyle(.orange)
      }
      .keylineTint(.orange)
    }
  }

  private func lockScreenView(_ context: ActivityViewContext<ExpiryActivityAttributes>) -> some View {
    HStack(spacing: 14) {
      brandMark(size: 48)

      VStack(alignment: .leading, spacing: 3) {
        Text(context.state.activityTitle)
          .font(.caption.bold())
          .foregroundStyle(.white.opacity(0.66))
        Text(context.state.name)
          .font(.headline)
          .foregroundStyle(.white)
          .lineLimit(1)
        Text(context.state.countLabel)
          .font(.caption2)
          .foregroundStyle(.white.opacity(0.58))
          .lineLimit(1)
      }

      Spacer(minLength: 8)

      VStack(alignment: .trailing, spacing: 5) {
        Text(context.state.dayLabel)
          .font(.subheadline.bold())
          .foregroundStyle(statusColor(for: context.state.daysRemaining))
        Label(
          context.state.expiryDate.formatted(date: .numeric, time: .omitted),
          systemImage: "calendar"
        )
        .font(.caption2.bold())
        .foregroundStyle(.white.opacity(0.70))
      }
    }
    .padding(16)
  }

  private func brandMark(size: CGFloat) -> some View {
    Image(systemName: "leaf.fill")
      .font(.system(size: size * 0.38, weight: .bold))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(
        LinearGradient(
          colors: [Color(red: 1, green: 0.27, blue: 0.16), Color(red: 1, green: 0.55, blue: 0.25)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        in: RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
      )
  }

  private func statusColor(for days: Int) -> Color {
    days <= 1 ? .orange : .green
  }

  private func shortDayLabel(_ state: ExpiryActivityAttributes.ContentState) -> String {
    if state.daysRemaining < 0 { return "!" }
    if state.daysRemaining == 0 { return state.usesEnglish ? "TODAY" : "今日" }
    return state.usesEnglish ? "\(state.daysRemaining)d" : "\(state.daysRemaining)日"
  }
}
