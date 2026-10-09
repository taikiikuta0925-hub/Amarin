import ActivityKit
import Foundation

nonisolated struct ExpiryActivityAttributes: ActivityAttributes {
  nonisolated struct ContentState: Codable, Hashable {
    let name: String
    let category: String
    let expiryDate: Date
    let daysRemaining: Int
    let urgentCount: Int
    let totalActive: Int
    let usesEnglish: Bool

    var countdownEnd: Date {
      let startOfExpiryDay = Calendar.current.startOfDay(for: expiryDate)
      return Calendar.current.date(byAdding: .day, value: 1, to: startOfExpiryDay) ?? expiryDate
    }

    var dayLabel: String {
      if usesEnglish {
        if daysRemaining < 0 { return "Expired" }
        if daysRemaining == 0 { return "Today" }
        if daysRemaining == 1 { return "1 day left" }
        return "\(daysRemaining) days left"
      }
      if daysRemaining < 0 { return "期限切れ" }
      if daysRemaining == 0 { return "今日まで" }
      return "あと\(daysRemaining)日"
    }

    var activityTitle: String {
      usesEnglish ? "Expiry countdown" : "賞味期限までカウントダウン"
    }

    var countLabel: String {
      usesEnglish ? "\(urgentCount) expiring · \(totalActive) tracked" : "期限間近 \(urgentCount)件 · 登録中 \(totalActive)件"
    }
  }

  let itemID: String
}
