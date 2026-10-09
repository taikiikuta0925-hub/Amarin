import ActivityKit
import Foundation

@MainActor
enum ExpiryLiveActivityManager {
  static var isAuthorized: Bool {
    ActivityAuthorizationInfo().areActivitiesEnabled
  }

  static func synchronize(
    item: FoodItem?,
    urgentCount: Int,
    totalActive: Int,
    usesEnglish: Bool,
    enabled: Bool
  ) async {
    let activities = Activity<ExpiryActivityAttributes>.activities

    guard enabled, isAuthorized, let item else {
      for activity in activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
      return
    }

    let state = ExpiryActivityAttributes.ContentState(
      name: item.name,
      category: item.category,
      expiryDate: item.expiryDate,
      daysRemaining: item.daysRemaining,
      urgentCount: urgentCount,
      totalActive: totalActive,
      usesEnglish: usesEnglish
    )
    let content = ActivityContent(state: state, staleDate: state.countdownEnd)

    if let matching = activities.first(where: { $0.attributes.itemID == item.id }) {
      await matching.update(content)
      for activity in activities where activity.id != matching.id {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
      return
    }

    for activity in activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }

    do {
      _ = try Activity.request(
        attributes: ExpiryActivityAttributes(itemID: item.id),
        content: content,
        pushType: nil
      )
    } catch {
      // ActivityKit can reject a request when Live Activities are disabled
      // globally or the system has reached its active-session limit.
    }
  }
}
