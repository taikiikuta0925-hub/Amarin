import PhotosUI
import SwiftUI
import UIKit
import UserNotifications

private func uiText(_ english: Bool, _ japanese: String, _ englishText: String) -> String {
  english ? englishText : japanese
}

@main
struct AmarinApp: App {
  @StateObject private var store = FoodStore()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(store)
        .environment(\.locale, store.appLanguage.locale)
        .preferredColorScheme(nil)
        .tint(store.activeTint)
    }
  }
}

enum AppLanguage: String, CaseIterable, Identifiable {
  case system
  case japanese = "ja"
  case english = "en"

  var id: String { rawValue }

  var locale: Locale {
    switch self {
    case .system: .current
    case .japanese: Locale(identifier: "ja")
    case .english: Locale(identifier: "en")
    }
  }

  func title(english: Bool) -> String {
    switch self {
    case .system: uiText(english, "システム設定に合わせる", "Follow System Language")
    case .japanese: uiText(english, "日本語", "Japanese")
    case .english: "English"
    }
  }

  var usesEnglish: Bool {
    self == .english || (self == .system && Locale.current.language.languageCode?.identifier == "en")
  }

  var apiLocale: String { usesEnglish ? "en-US" : "ja-JP" }
}

// MARK: - Models

struct FoodItem: Codable, Identifiable, Hashable {
  var id: String
  var name: String
  var category: String
  var expiryDate: Date
  var registeredAt: Date
  var registeredWithAi: Bool
  var consumedAt: Date?
  var earnedPoints: Int
  var outcome: String? = nil

  var isConsumed: Bool { consumedAt != nil }
  var isLost: Bool { outcome == "lost" }

  var daysRemaining: Int {
    Calendar.current.dateComponents(
      [.day],
      from: Calendar.current.startOfDay(for: Date()),
      to: Calendar.current.startOfDay(for: expiryDate)
    ).day ?? 0
  }
}

struct RecipeSuggestion: Codable, Identifiable, Hashable {
  struct Ingredient: Codable, Hashable {
    let name: String
    let amount: String
    let available: Bool
  }

  var id: String { title }
  let title: String
  let description: String
  let cookTimeMinutes: Int
  let servings: String
  let ingredients: [Ingredient]
  let steps: [String]
  let usesRegisteredItems: [String]
  let tip: String
}

struct ChatMessage: Identifiable, Codable, Hashable {
  let id: UUID
  let role: String
  let text: String

  init(id: UUID = UUID(), role: String, text: String) {
    self.id = id
    self.role = role
    self.text = text
  }
}

enum RewardCategory: String {
  case theme = "テーマ"
  case badge = "バッジ"
  case effect = "演出"
  case coupon = "クーポン"

  func title(english: Bool) -> String {
    guard english else { return rawValue }
    switch self {
    case .theme: return "Theme"
    case .badge: return "Badge"
    case .effect: return "Effect"
    case .coupon: return "Coupon"
    }
  }
}

struct RewardItem: Identifiable {
  let id: String
  let category: RewardCategory
  let icon: String
  let title: String
  let subtitle: String
  let detail: String
  let cost: Int
  let rarity: String
  let primary: Color
  let secondary: Color
  var exchangeable = true

  static let catalog: [RewardItem] = [
    RewardItem(id: "theme_classic", category: .theme, icon: "sun.max.fill", title: "Amarin Classic", subtitle: "あたたかいオレンジ", detail: "あまりん標準のテーマ。食卓のあたたかさをイメージした、明るく親しみやすいカラーです。", cost: 0, rarity: "STANDARD", primary: .amarinOrange, secondary: .pink),
    RewardItem(id: "theme_aurora", category: .theme, icon: "aqi.medium", title: "Aurora Mint", subtitle: "透明感のあるミント", detail: "オーロラの光をイメージした限定テーマ。ボタンや選択表示がミントカラーに変化します。", cost: 100, rarity: "RARE", primary: .mint, secondary: .cyan),
    RewardItem(id: "theme_midnight", category: .theme, icon: "moon.stars.fill", title: "Midnight AI", subtitle: "深い紫とネオンブルー", detail: "AI KITCHENから生まれた近未来テーマ。アプリのアクセントが紫色に変化します。", cost: 300, rarity: "EPIC", primary: .purple, secondary: .blue),
    RewardItem(id: "theme_sakura", category: .theme, icon: "camera.macro", title: "Sakura Bloom", subtitle: "やわらかな桜色", detail: "春の食材と満開の桜をイメージしたシーズンテーマです。", cost: 500, rarity: "LEGEND", primary: .pink, secondary: .orange),
    RewardItem(id: "theme_forest", category: .theme, icon: "tree.fill", title: "Forest Pulse", subtitle: "森を感じる深緑", detail: "深い森と新鮮な野菜をイメージした自然派テーマ。アクセントが落ち着いたグリーンに変化します。", cost: 180, rarity: "RARE", primary: .green, secondary: .teal),
    RewardItem(id: "theme_ocean", category: .theme, icon: "water.waves", title: "Ocean Glass", subtitle: "透き通るオーシャンブルー", detail: "水面を通る光を表現したLiquid Glass向けテーマ。爽やかなブルーを楽しめます。", cost: 250, rarity: "EPIC", primary: .blue, secondary: .cyan),
    RewardItem(id: "theme_mono", category: .theme, icon: "circle.lefthalf.filled", title: "Mono Future", subtitle: "研ぎ澄まされたモノクロ", detail: "余計な色を抑えたミニマルテーマ。アクセントをクールなグレーへ切り替えます。", cost: 420, rarity: "EPIC", primary: .gray, secondary: .black),
    RewardItem(id: "theme_harvest", category: .theme, icon: "crown.fill", title: "Golden Harvest", subtitle: "実りを祝うゴールド", detail: "たくさんの食品を救ったプレイヤーのための最高ランクテーマです。", cost: 800, rarity: "MYTHIC", primary: .yellow, secondary: .orange),
    RewardItem(id: "badge_seed", category: .badge, icon: "leaf.fill", title: "はじめの一歩", subtitle: "フードレスキュー初心者", detail: "食品ロス削減を始めた証。コレクションに保存される最初のバッジです。", cost: 60, rarity: "COMMON", primary: .green, secondary: .mint),
    RewardItem(id: "badge_streak", category: .badge, icon: "flame.fill", title: "7 Days Streak", subtitle: "一週間の継続バッジ", detail: "食品管理を続けるプレイヤーへ贈る、燃えるストリークバッジです。", cost: 120, rarity: "RARE", primary: .orange, secondary: .red),
    RewardItem(id: "effect_spark", category: .effect, icon: "sparkles", title: "Spark Finish", subtitle: "食べきり時の光エフェクト", detail: "食品を食べきった瞬間を、きらめく演出でお祝いするコレクション報酬です。", cost: 150, rarity: "RARE", primary: .yellow, secondary: .orange),
    RewardItem(id: "effect_chime", category: .effect, icon: "waveform", title: "Future Chime", subtitle: "達成時の限定サウンド", detail: "ミッション達成を近未来的なチャイムで知らせるサウンドコレクションです。", cost: 180, rarity: "RARE", primary: .cyan, secondary: .blue),
    RewardItem(id: "badge_rescue", category: .badge, icon: "shield.lefthalf.filled", title: "Rescue Hero", subtitle: "冷蔵庫を守るヒーロー", detail: "食材を大切に使い切るプレイヤーのための特別バッジです。", cost: 220, rarity: "EPIC", primary: .blue, secondary: .cyan),
    RewardItem(id: "badge_amarin", category: .badge, icon: "hare.fill", title: "Amarin Buddy", subtitle: "あまりん限定バッジ", detail: "あまりんと一緒に食品ロスを減らした証になる限定キャラクターバッジです。", cost: 280, rarity: "EPIC", primary: .pink, secondary: .purple),
    RewardItem(id: "effect_confetti", category: .effect, icon: "party.popper.fill", title: "Celebration MAX", subtitle: "豪華な達成エフェクト", detail: "レベルアップや食べきり達成をカラフルな紙吹雪で祝います。", cost: 350, rarity: "EPIC", primary: .pink, secondary: .yellow),
    RewardItem(id: "effect_cosmos", category: .effect, icon: "circle.hexagongrid.fill", title: "Cosmos Frame", subtitle: "プロフィール用の星空フレーム", detail: "プロフィールアイコンの周りを星空が巡る、最高レアリティのコレクションです。", cost: 400, rarity: "LEGEND", primary: .indigo, secondary: .purple),
    RewardItem(id: "badge_zero", category: .badge, icon: "medal.star.fill", title: "Zero Waste Master", subtitle: "最高位の称号バッジ", detail: "食品を無駄なく使い切り続けたマスターだけが持てる特別な称号です。", cost: 520, rarity: "LEGEND", primary: .yellow, secondary: .purple),
    RewardItem(id: "effect_recipe", category: .effect, icon: "book.pages.fill", title: "Secret Recipe Skin", subtitle: "AIレシピ限定スキン", detail: "AI KITCHENのレシピカードに特別なホログラム演出を追加するコレクションです。", cost: 700, rarity: "MYTHIC", primary: .purple, secondary: .cyan),
    RewardItem(id: "coupon_rescue", category: .coupon, icon: "ticket.fill", title: "レスキュークーポン", subtitle: "協力店で使える予定", detail: "将来、協力店との連携後に提供予定の仮報酬です。現在は交換できません。", cost: 600, rarity: "COMING SOON", primary: .orange, secondary: .red, exchangeable: false),
  ]

  func localizedCopy(english: Bool) -> (title: String, subtitle: String, detail: String) {
    guard english else { return (title, subtitle, detail) }
    switch id {
    case "theme_classic": return (title, "Warm orange", "Amarin's signature theme, inspired by the warmth and friendliness of the family table.")
    case "theme_aurora": return (title, "Crystal-clear mint", "A limited theme inspired by aurora light. Buttons and selections glow in mint.")
    case "theme_midnight": return (title, "Deep purple and neon blue", "A futuristic theme born in AI Kitchen that transforms the app accents to purple.")
    case "theme_sakura": return (title, "Soft cherry-blossom pink", "A seasonal theme inspired by spring ingredients and cherry blossoms in full bloom.")
    case "theme_forest": return (title, "Deep forest green", "A nature-inspired theme based on deep forests and fresh vegetables, with calm green accents.")
    case "theme_ocean": return (title, "Clear ocean blue", "A Liquid Glass theme inspired by light passing through water, finished in refreshing blue.")
    case "theme_mono": return (title, "Refined monochrome", "A minimal theme with restrained color and cool gray accents.")
    case "theme_harvest": return (title, "Celebratory gold", "A top-tier theme for players who have rescued many food items.")
    case "badge_seed": return ("First Step", "Food-rescue beginner", "Your first badge, awarded for starting your journey to reduce food waste.")
    case "badge_streak": return (title, "One-week streak badge", "A fiery streak badge for players who keep managing their food for seven days.")
    case "effect_spark": return (title, "Rescue sparkle effect", "Celebrate the moment you finish an item with a sparkling collection effect.")
    case "effect_chime": return (title, "Exclusive achievement sound", "A futuristic chime that plays when you complete a mission.")
    case "badge_rescue": return (title, "Fridge-protecting hero", "A special badge for players who carefully use every ingredient.")
    case "badge_amarin": return (title, "Amarin limited badge", "A limited character badge proving that you reduced food waste together with Amarin.")
    case "effect_confetti": return (title, "Premium celebration effect", "Colorful confetti celebrates level-ups and successful food rescues.")
    case "effect_cosmos": return (title, "Starry profile frame", "A highest-rarity collection frame with a star field orbiting your profile icon.")
    case "badge_zero": return (title, "Highest-rank title badge", "A special title reserved for masters who consistently use food without waste.")
    case "effect_recipe": return (title, "Exclusive AI recipe skin", "Adds a special holographic effect to recipe cards in AI Kitchen.")
    case "coupon_rescue": return ("Rescue Coupon", "Planned for partner stores", "A preview reward planned for future partner-store integrations. It cannot be redeemed yet.")
    default: return (title, subtitle, detail)
    }
  }
}

struct PlayerLevel {
  static let thresholds = [0, 100, 300, 600, 1000, 1500, 2200, 3000]
  static let names = ["たね", "めばえ", "若葉", "花", "実り", "豊作", "大地", "レジェンド"]

  let level: Int
  let name: String
  let progress: Double
  let pointsToNext: Int
  let isMax: Bool

  init(points: Int) {
    let value = max(0, points)
    var index = 0
    for next in 1..<Self.thresholds.count where value >= Self.thresholds[next] { index = next }
    level = index + 1
    name = Self.names[index]
    isMax = index == Self.thresholds.count - 1
    if isMax {
      progress = 1
      pointsToNext = 0
    } else {
      let start = Self.thresholds[index]
      let end = Self.thresholds[index + 1]
      progress = Double(value - start) / Double(end - start)
      pointsToNext = end - value
    }
  }

  func localizedName(english: Bool) -> String {
    guard english else { return name }
    let englishNames = ["Seed", "Sprout", "Leaf", "Bloom", "Harvest", "Bounty", "Earth", "Legend"]
    return englishNames[max(0, min(level - 1, englishNames.count - 1))]
  }
}

// MARK: - Store

@MainActor
final class FoodStore: ObservableObject {
  @Published private(set) var items: [FoodItem] = []
  @Published private(set) var points = 0
  @Published private(set) var lifetimePoints = 0
  @Published private(set) var redeemedRewardIDs: Set<String> = []
  @Published private(set) var activeThemeID = "theme_classic"
  @Published var appLanguage = AppLanguage.system {
    didSet { defaults.set(appLanguage.rawValue, forKey: languageKey) }
  }
  @Published var notificationsEnabled = false {
    didSet { persist() }
  }
  @Published var reminderHour = 9 {
    didSet { persist() }
  }

  private let defaults = UserDefaults.standard
  private let itemsKey = "tabekiri_food_items_v1"
  private let pointsKey = "tabekiri_points_v1"
  private let lifetimePointsKey = "tabekiri_lifetime_points_v1"
  private let notificationsKey = "tabekiri_notifications_v1"
  private let reminderHourKey = "tabekiri_reminder_hour_v1"
  private let rewardsKey = "tabekiri_rewards_v1"
  private let activeThemeKey = "tabekiri_active_theme_v1"
  private let languageKey = "amarin_language_v1"

  init() {
    load()
  }

  var activeItems: [FoodItem] {
    items.filter { !$0.isConsumed }.sorted { $0.expiryDate < $1.expiryDate }
  }

  var consumedItems: [FoodItem] {
    items.filter(\.isConsumed).sorted { ($0.consumedAt ?? .distantPast) > ($1.consumedAt ?? .distantPast) }
  }

  var activeTint: Color {
    switch activeThemeID {
    case "theme_aurora": .mint
    case "theme_midnight": .purple
    case "theme_sakura": .pink
    case "theme_forest": .green
    case "theme_ocean": .blue
    case "theme_mono": .gray
    case "theme_harvest": .yellow
    default: .amarinOrange
    }
  }

  var activeSecondaryTint: Color {
    switch activeThemeID {
    case "theme_aurora": .cyan
    case "theme_midnight": .blue
    case "theme_sakura": .orange
    case "theme_forest": .teal
    case "theme_ocean": .cyan
    case "theme_mono": .black
    case "theme_harvest": .orange
    default: .pink
    }
  }

  var activeThemeGradient: [Color] {
    switch activeThemeID {
    case "theme_aurora": [.mint, Color(red: 0.08, green: 0.66, blue: 0.76)]
    case "theme_midnight": [Color(red: 0.36, green: 0.15, blue: 0.78), .blue]
    case "theme_sakura": [Color(red: 0.95, green: 0.28, blue: 0.58), .orange]
    case "theme_forest": [Color(red: 0.05, green: 0.48, blue: 0.30), .teal]
    case "theme_ocean": [Color(red: 0.03, green: 0.40, blue: 0.87), .cyan]
    case "theme_mono": [Color(red: 0.13, green: 0.15, blue: 0.19), .gray]
    case "theme_harvest": [Color(red: 0.78, green: 0.43, blue: 0.02), .orange]
    default: [Color(red: 1, green: 0.29, blue: 0.18), Color(red: 1, green: 0.52, blue: 0.32)]
    }
  }

  func owns(_ reward: RewardItem) -> Bool {
    reward.id == "theme_classic" || redeemedRewardIDs.contains(reward.id)
  }

  @discardableResult
  func redeem(_ reward: RewardItem) -> Bool {
    guard reward.exchangeable, !owns(reward), points >= reward.cost else { return false }
    points -= reward.cost
    redeemedRewardIDs.insert(reward.id)
    if reward.category == .theme { activeThemeID = reward.id }
    persist()
    return true
  }

  func activateTheme(_ reward: RewardItem) {
    guard reward.category == .theme, owns(reward) else { return }
    activeThemeID = reward.id
    persist()
  }

  func add(name: String, category: String, expiryDate: Date, registeredWithAi: Bool) {
    items.append(
      FoodItem(
        id: UUID().uuidString,
        name: name,
        category: category,
        expiryDate: expiryDate,
        registeredAt: Date(),
        registeredWithAi: registeredWithAi,
        consumedAt: nil,
        earnedPoints: 0
      )
    )
    persistAndSync()
  }

  func pointsForConsuming(_ item: FoodItem) -> Int {
    if item.daysRemaining < 0 { return 0 }
    if item.daysRemaining <= 1 { return 20 }
    if item.daysRemaining <= 3 { return 15 }
    return 10
  }

  func pointsForWasting(_ item: FoodItem) -> Int {
    item.daysRemaining < 0 ? 20 : 10
  }

  @discardableResult
  func consume(_ item: FoodItem) -> Int {
    guard let index = items.firstIndex(where: { $0.id == item.id }), !items[index].isConsumed else {
      return 0
    }
    let earned = pointsForConsuming(item)
    items[index].consumedAt = Date()
    items[index].earnedPoints = earned
    items[index].outcome = "consumed"
    points += earned
    lifetimePoints += earned
    persistAndSync()
    return earned
  }

  @discardableResult
  func markAsWaste(_ item: FoodItem) -> Int {
    guard let index = items.firstIndex(where: { $0.id == item.id }), !items[index].isConsumed else {
      return 0
    }
    let penalty = pointsForWasting(item)
    items[index].consumedAt = Date()
    items[index].earnedPoints = -penalty
    items[index].outcome = "lost"
    points = max(0, points - penalty)
    persistAndSync()
    return -penalty
  }

  func delete(_ item: FoodItem) {
    items.removeAll { $0.id == item.id }
    persistAndSync()
  }

  func delete(at offsets: IndexSet, from source: [FoodItem]) {
    let ids = Set(offsets.compactMap { source.indices.contains($0) ? source[$0].id : nil })
    items.removeAll { ids.contains($0.id) }
    persistAndSync()
  }

  @discardableResult
  func requestNotifications() async -> Bool {
    let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge]
    )) ?? false
    notificationsEnabled = granted
    await syncNotifications()
    return granted
  }

  func syncNotifications() async {
    let center = UNUserNotificationCenter.current()
    let identifiers = await center.pendingNotificationRequests().map(\.identifier).filter {
      $0.hasPrefix("amarin.expiry.")
    }
    center.removePendingNotificationRequests(withIdentifiers: identifiers)
    guard notificationsEnabled else { return }

    for item in activeItems.prefix(30) {
      for offset in [-3, 0] {
        guard let targetDay = Calendar.current.date(byAdding: .day, value: offset, to: item.expiryDate),
          let scheduled = Calendar.current.date(bySettingHour: reminderHour, minute: 0, second: 0, of: targetDay),
          scheduled > Date() else { continue }
        let content = UNMutableNotificationContent()
        if appLanguage.usesEnglish {
          content.title = offset == 0 ? "Expires Today" : "Expiry Date Approaching"
          content.body = offset == 0
            ? "\(item.name) expires today. Enjoy it while it is fresh."
            : "\(item.name) expires in three days."
        } else {
          content.title = offset == 0 ? "今日が賞味期限です" : "賞味期限が近づいています"
          content.body = offset == 0
            ? "\(item.name)は今日までです。おいしいうちに食べきりましょう。"
            : "\(item.name)の期限まであと3日です。"
        }
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: scheduled)
        try? await center.add(UNNotificationRequest(
          identifier: "amarin.expiry.\(item.id).\(offset)",
          content: content,
          trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        ))
      }
    }
  }

  private func storedObject(for key: String) -> Any? {
    defaults.object(forKey: key) ?? defaults.object(forKey: "flutter.\(key)")
  }

  private func load() {
    points = storedObject(for: pointsKey) as? Int ?? 0
    lifetimePoints = storedObject(for: lifetimePointsKey) as? Int ?? points
    redeemedRewardIDs = Set(storedObject(for: rewardsKey) as? [String] ?? [])
    activeThemeID = storedObject(for: activeThemeKey) as? String ?? "theme_classic"
    appLanguage = AppLanguage(rawValue: defaults.string(forKey: languageKey) ?? "system") ?? .system
    notificationsEnabled = storedObject(for: notificationsKey) as? Bool ?? false
    reminderHour = storedObject(for: reminderHourKey) as? Int ?? 9

    let raw = storedObject(for: itemsKey) as? String
    if let raw, let data = raw.data(using: .utf8),
      let decoded = try? JSONDecoder.amarin.decode([FoodItem].self, from: data)
    {
      items = decoded
    } else { items = [] }
  }

  private func persist() {
    if let data = try? JSONEncoder.amarin.encode(items), let raw = String(data: data, encoding: .utf8) {
      defaults.set(raw, forKey: itemsKey)
      defaults.set(raw, forKey: "flutter.\(itemsKey)")
    }
    defaults.set(points, forKey: pointsKey)
    defaults.set(points, forKey: "flutter.\(pointsKey)")
    defaults.set(lifetimePoints, forKey: lifetimePointsKey)
    defaults.set(Array(redeemedRewardIDs), forKey: rewardsKey)
    defaults.set(activeThemeID, forKey: activeThemeKey)
    defaults.set(notificationsEnabled, forKey: notificationsKey)
    defaults.set(notificationsEnabled, forKey: "flutter.\(notificationsKey)")
    defaults.set(reminderHour, forKey: reminderHourKey)
    defaults.set(reminderHour, forKey: "flutter.\(reminderHourKey)")
  }

  private func persistAndSync() {
    persist()
    Task { await syncNotifications() }
  }
}

// MARK: - AI

enum AIError: LocalizedError {
  case invalidResponse
  case server(String)

  var errorDescription: String? {
    switch self {
    case .invalidResponse: "AIから正しい回答を受け取れませんでした"
    case .server(let message): message
    }
  }
}

struct AIService {
  static let shared = AIService()
  private let baseURL = URL(string: "https://tabekiri-ai.tx-appe-chi.workers.dev")!

  func analyze(imageData: Data, mimeType: String = "image/jpeg", locale: String = "ja-JP") async throws
    -> (name: String, category: String, expiryDate: Date)
  {
    let json = try await post(
      path: "analyze-expiry",
      body: [
        "imageBase64": imageData.base64EncodedString(),
        "mimeType": mimeType,
        "today": DateFormatter.apiDate.string(from: Date()),
        "locale": locale,
      ]
    )
    let payload = json["data"] as? [String: Any] ?? json
    guard let name = payload["name"] as? String,
      let expiry = payload["expiryDate"] as? String,
      let expiryDate = DateFormatter.apiDate.date(from: expiry)
    else { throw AIError.invalidResponse }
    return (name, payload["category"] as? String ?? "その他", expiryDate)
  }

  func recipes(items: [FoodItem], preference: String, locale: String = "ja-JP") async throws -> [RecipeSuggestion] {
    let json = try await post(
      path: "suggest-recipes",
      body: [
        "items": items.map {
          [
            "name": $0.name,
            "category": $0.category,
            "expiryDate": DateFormatter.apiDate.string(from: $0.expiryDate),
            "daysRemaining": $0.daysRemaining,
          ] as [String: Any]
        },
        "preference": preference,
        "today": DateFormatter.apiDate.string(from: Date()),
        "locale": locale,
      ]
    )
    guard let raw = json["recipes"], JSONSerialization.isValidJSONObject(raw) else {
      throw AIError.invalidResponse
    }
    let data = try JSONSerialization.data(withJSONObject: raw)
    return try JSONDecoder().decode([RecipeSuggestion].self, from: data)
  }

  func chat(items: [FoodItem], messages: [ChatMessage], locale: String = "ja-JP") async throws -> String {
    let json = try await post(
      path: "recipe-chat",
      body: [
        "items": items.map {
          [
            "name": $0.name,
            "category": $0.category,
            "expiryDate": DateFormatter.apiDate.string(from: $0.expiryDate),
            "daysRemaining": $0.daysRemaining,
          ] as [String: Any]
        },
        "messages": messages.map { ["role": $0.role, "text": $0.text] },
        "today": DateFormatter.apiDate.string(from: Date()),
        "locale": locale,
      ]
    )
    guard let reply = json["reply"] as? String, !reply.isEmpty else {
      throw AIError.invalidResponse
    }
    return reply
  }

  struct ProductResult {
    let reply: String
    let ready: Bool
    let name: String
    let category: String
    let expiryDate: Date?
  }

  struct DailyQuote {
    let quote: String
    let note: String
  }

  func dailyQuote(activeCount: Int, rescuedCount: Int, locale: String = "ja-JP") async throws -> DailyQuote {
    let json = try await post(
      path: "daily-quote",
      body: [
        "today": DateFormatter.apiDate.string(from: Date()),
        "activeCount": activeCount,
        "rescuedCount": rescuedCount,
        "locale": locale,
      ]
    )
    guard let quote = json["quote"] as? String,
      let note = json["note"] as? String,
      !quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { throw AIError.invalidResponse }
    return DailyQuote(quote: quote, note: note)
  }

  func identify(messages: [ChatMessage], locale: String = "ja-JP") async throws -> ProductResult {
    let json = try await post(
      path: "identify-product",
      body: [
        "messages": messages.map { ["role": $0.role, "text": $0.text] },
        "today": DateFormatter.apiDate.string(from: Date()),
        "locale": locale,
      ]
    )
    guard let reply = json["reply"] as? String, !reply.isEmpty else { throw AIError.invalidResponse }
    let name = json["name"] as? String ?? ""
    let expiry = (json["expiryDate"] as? String).flatMap(DateFormatter.apiDate.date)
    return ProductResult(
      reply: reply,
      ready: json["ready"] as? Bool == true && !name.isEmpty && expiry != nil,
      name: name,
      category: json["category"] as? String ?? "その他",
      expiryDate: expiry
    )
  }

  private func post(path: String, body: [String: Any]) async throws -> [String: Any] {
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 30
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
    guard 200..<300 ~= http.statusCode else {
      let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
      throw AIError.server(json?["error"] as? String ?? "AIサーバーでエラーが発生しました")
    }
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw AIError.invalidResponse
    }
    return json
  }
}

// MARK: - Root

enum AppTab: Int, CaseIterable {
  case home, foods, recipes, points, add

  func title(english: Bool) -> String {
    switch self {
    case .home: uiText(english, "ホーム", "Home")
    case .foods: uiText(english, "食品", "Food")
    case .recipes: uiText(english, "レシピ", "Recipes")
    case .points: uiText(english, "ポイント", "Rewards")
    case .add: uiText(english, "追加", "Add")
    }
  }

  var symbol: String {
    switch self {
    case .home: "house.fill"
    case .foods: "refrigerator.fill"
    case .recipes: "book.closed.fill"
    case .points: "star.circle.fill"
    case .add: "plus"
    }
  }
}

struct RootView: View {
  @EnvironmentObject private var store: FoodStore
  @State private var tab: AppTab = .home
  @State private var showingAdd = false

  var body: some View {
    Group {
      if #available(iOS 27.0, *) {
        SystemLiquidGlassTabs(selection: $tab, showingAdd: $showingAdd)
      } else {
        ZStack(alignment: .bottom) {
          tabContent.safeAreaPadding(.bottom, 94)
          NativeTabBar(selection: $tab) { showingAdd = true }
        }
      }
    }
    .background(Color.amarinBackground.ignoresSafeArea())
    .sheet(isPresented: $showingAdd) {
      AddFlowView { showingAdd = false; tab = .foods }
        .environmentObject(store)
    }
    .onAppear {
#if DEBUG
      if ProcessInfo.processInfo.arguments.contains("--show-rewards") { tab = .points }
      if ProcessInfo.processInfo.arguments.contains("--show-recipes") { tab = .recipes }
#endif
    }
  }

  @ViewBuilder
  private var tabContent: some View {
    switch tab {
    case .home, .add:
      HomeView(onAdd: { showingAdd = true }, onLevelTap: { withAnimation(.snappy) { tab = .points } })
    case .foods: FoodsView()
    case .recipes: RecipesView()
    case .points: PointsView()
    }
  }
}

@available(iOS 27.0, *)
private struct SystemLiquidGlassTabs: View {
  @EnvironmentObject private var store: FoodStore
  @Binding var selection: AppTab
  @Binding var showingAdd: Bool
  @State private var previousTab: AppTab = .home

  var body: some View {
    TabView(selection: $selection) {
      Tab(AppTab.home.title(english: store.appLanguage.usesEnglish), systemImage: "house.fill", value: AppTab.home) {
        HomeView(onAdd: { showingAdd = true }, onLevelTap: { withAnimation(.snappy) { selection = .points } })
      }
      Tab(AppTab.foods.title(english: store.appLanguage.usesEnglish), systemImage: "refrigerator.fill", value: AppTab.foods) {
        FoodsView()
      }
      Tab(AppTab.recipes.title(english: store.appLanguage.usesEnglish), systemImage: "book.closed.fill", value: AppTab.recipes) {
        RecipesView()
      }
      Tab(AppTab.points.title(english: store.appLanguage.usesEnglish), systemImage: "star.circle.fill", value: AppTab.points) {
        PointsView()
      }
      Tab(AppTab.add.title(english: store.appLanguage.usesEnglish), systemImage: "plus", value: AppTab.add, role: .prominent) {
        Color.amarinBackground.ignoresSafeArea()
      }
    }
    .tabBarMinimizeBehavior(.never)
    .onChange(of: selection) { oldValue, newValue in
      if newValue == .add {
        showingAdd = true
        selection = oldValue == .add ? previousTab : oldValue
      } else {
        previousTab = newValue
      }
    }
  }
}

struct NativeTabBar: View {
  @EnvironmentObject private var store: FoodStore
  @Binding var selection: AppTab
  let onAdd: () -> Void

  var body: some View {
    if #available(iOS 26.0, *) {
      GlassEffectContainer(spacing: 10) {
        HStack(spacing: 10) {
          tabButtons
            .padding(6)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32, style: .continuous))

          Button(action: onAdd) {
            Image(systemName: "plus")
              .font(.system(size: 22, weight: .bold))
              .frame(width: 58, height: 58)
          }
          .buttonStyle(.glassProminent)
          .tint(.amarinOrange)
          .accessibilityLabel(uiText(store.appLanguage.usesEnglish, "食品を登録", "Add food"))
        }
      }
      .padding(.horizontal, 12)
      .padding(.bottom, 8)
    } else {
      HStack(spacing: 10) {
        tabButtons.padding(6).background(.ultraThinMaterial, in: Capsule())
        Button(action: onAdd) {
          Image(systemName: "plus")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 58, height: 58)
            .background(Color.amarinOrange, in: Circle())
        }
      }
      .padding(.horizontal, 12)
      .padding(.bottom, 8)
    }
  }

  private var tabButtons: some View {
    HStack(spacing: 2) {
      ForEach(AppTab.allCases.filter { $0 != .add }, id: \.rawValue) { tab in
        Button {
          withAnimation(.snappy) { selection = tab }
        } label: {
          VStack(spacing: 3) {
            Image(systemName: tab.symbol)
              .font(.system(size: 19, weight: selection == tab ? .bold : .semibold))
            Text(tab.title(english: store.appLanguage.usesEnglish))
              .font(.system(size: 9.5, weight: selection == tab ? .bold : .semibold))
              .lineLimit(1)
          }
          .foregroundStyle(selection == tab ? Color.amarinOrange : Color.secondary)
          .frame(maxWidth: .infinity, minHeight: 54)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
  }
}

// MARK: - Home

struct HomeView: View {
  @EnvironmentObject private var store: FoodStore
  @State private var showingNotifications = false
  @State private var showingLanguage = false
  @State private var dailyQuote = "おいしい今日を選ぶことが、やさしい明日につながる。"
  @State private var dailyQuoteNote = "期限の近い食品を一つ、今日の献立へ。"
  @State private var quoteIsLoading = false
  let onAdd: () -> Void
  let onLevelTap: () -> Void

  var body: some View {
    ZStack(alignment: .top) {
      LinearGradient(
        colors: [store.activeTint.opacity(0.13), store.activeSecondaryTint.opacity(0.055), .clear],
        startPoint: .topLeading,
        endPoint: .center
      )
      .frame(height: 440)
      .ignoresSafeArea()

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 22) {
          modernHeader
          statusCard
          quickActions

          HStack(alignment: .firstTextBaseline) {
            Text(uiText(store.appLanguage.usesEnglish, "期限が近い食品", "Expiring soon"))
              .font(.system(size: 20, weight: .bold, design: .rounded))
            Spacer()
            if !store.activeItems.isEmpty {
              Text(uiText(store.appLanguage.usesEnglish, "期限順", "By expiry")).font(.caption.bold()).foregroundStyle(.secondary)
            }
          }

          if store.activeItems.isEmpty { modernEmptyState } else {
            VStack(spacing: 10) {
              ForEach(store.activeItems.prefix(3)) { FoodRow(item: $0) }
            }
          }

        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 30)
      }
    }
    .sheet(isPresented: $showingNotifications) { NotificationSettingsView() }
    .sheet(isPresented: $showingLanguage) { LanguageSettingsView() }
    .task(id: store.appLanguage) { await loadDailyQuote() }
  }

  private var modernHeader: some View {
    HStack(spacing: 11) {
      Image(systemName: "leaf.fill")
        .font(.system(size: 19, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 42, height: 42)
        .background(LinearGradient(colors: store.activeThemeGradient, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: store.activeTint.opacity(0.28), radius: 12, y: 5)
      VStack(alignment: .leading, spacing: 0) {
        Text(store.appLanguage.usesEnglish ? "Amarin" : "あまりん").font(.system(size: 21, weight: .bold, design: .rounded))
        Text(uiText(store.appLanguage.usesEnglish, "おいしく、むだなく。", "Enjoy food. Waste less.")).font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      Button { showingLanguage = true } label: {
        Image(systemName: "globe")
          .font(.system(size: 16, weight: .bold))
          .frame(width: 38, height: 38)
      }
      .buttonStyle(.plain)
      .amarinGlass(in: Circle())
      .accessibilityLabel(uiText(store.appLanguage.usesEnglish, "言語", "Language"))
      let player = PlayerLevel(points: store.lifetimePoints)
      Button(action: onLevelTap) {
        ZStack {
          Circle().stroke(store.activeTint.opacity(0.14), lineWidth: 4)
          Circle()
            .trim(from: 0, to: max(0.025, player.progress))
            .stroke(
              AngularGradient(colors: [store.activeTint, .yellow, store.activeTint], center: .center),
              style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
          VStack(spacing: -2) {
            Text("LV").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
            Text("\(player.level)").font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(.primary)
          }
        }
        .frame(width: 48, height: 48)
        .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .amarinGlass(in: Circle())
      .accessibilityLabel(store.appLanguage.usesEnglish ? "Level \(player.level), \(store.points) points. Open level page" : "レベル\(player.level)、\(store.points)ポイント。レベルページを開く")
    }
  }

  private var statusCard: some View {
    let urgent = store.activeItems.filter { $0.daysRemaining <= 3 }.count
    return VStack(alignment: .leading, spacing: 18) {
      HStack {
        HStack(spacing: 7) {
          Circle().fill(.white).frame(width: 7, height: 7)
          Text("TODAY").font(.caption2.bold()).tracking(1.2)
        }
        .padding(.horizontal, 11).padding(.vertical, 7)
        .background(.white.opacity(0.16), in: Capsule())
        Spacer()
        Button { showingNotifications = true } label: {
          Image(systemName: store.notificationsEnabled ? "bell.badge.fill" : "bell")
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 38, height: 38)
            .background(.white.opacity(0.16), in: Circle())
        }.buttonStyle(.plain)
      }

      VStack(alignment: .leading, spacing: 7) {
        HStack(spacing: 7) {
          Image(systemName: "sparkles")
          Text("GEMINI DAILY").tracking(1.1)
          if quoteIsLoading { ProgressView().controlSize(.small).tint(.white) }
        }
        .font(.system(size: 10, weight: .heavy, design: .rounded))
        .foregroundStyle(.white.opacity(0.72))

        Text("“\(dailyQuote)”")
          .font(.system(size: 25, weight: .bold, design: .rounded))
          .lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
        Text(dailyQuoteNote)
          .font(.subheadline).foregroundStyle(.white.opacity(0.80))
          .fixedSize(horizontal: false, vertical: true)
      }

      HStack(spacing: 10) {
        Label(store.appLanguage.usesEnglish ? "\(store.activeItems.count) tracked" : "\(store.activeItems.count) 登録中", systemImage: "refrigerator.fill")
        Label(store.appLanguage.usesEnglish ? "\(urgent) expiring" : "\(urgent) もうすぐ", systemImage: "clock.fill")
      }
      .font(.caption.bold()).foregroundStyle(.white.opacity(0.86))
    }
    .foregroundStyle(.white)
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      ZStack {
        LinearGradient(colors: store.activeThemeGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        Circle().fill(.white.opacity(0.12)).frame(width: 190).offset(x: 145, y: -95)
        Circle().fill(store.activeSecondaryTint.opacity(0.25)).frame(width: 150).offset(x: -145, y: 115)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    .shadow(color: store.activeTint.opacity(0.22), radius: 24, y: 12)
  }

  private var quickActions: some View {
    HStack(spacing: 10) {
      ModernActionButton(icon: "camera.viewfinder", title: uiText(store.appLanguage.usesEnglish, "AIスキャン", "AI Scan"), subtitle: uiText(store.appLanguage.usesEnglish, "写真から登録", "Add from photo"), tint: store.activeTint, action: onAdd)
      ModernActionButton(icon: "sparkles", title: uiText(store.appLanguage.usesEnglish, "AIに相談", "Ask AI"), subtitle: uiText(store.appLanguage.usesEnglish, "会話で特定", "Identify by chat"), tint: store.activeSecondaryTint, action: onAdd)
    }
  }

  @MainActor
  private func loadDailyQuote() async {
    let defaults = UserDefaults.standard
    let today = DateFormatter.apiDate.string(from: Date())
    let languageSuffix = store.appLanguage.usesEnglish ? "en" : "ja"
    let dateKey = "amarin_daily_quote_date_v3_\(languageSuffix)"
    let quoteKey = "amarin_daily_quote_text_v3_\(languageSuffix)"
    let noteKey = "amarin_daily_quote_note_v3_\(languageSuffix)"

    if store.appLanguage.usesEnglish {
      dailyQuote = "A small choice today can make tomorrow's table kinder."
      dailyQuoteNote = "Bring one item nearing expiry into today's meal."
    } else {
      dailyQuote = "おいしい今日を選ぶことが、やさしい明日につながる。"
      dailyQuoteNote = "期限の近い食品を一つ、今日の献立へ。"
    }

    if defaults.string(forKey: dateKey) == today,
      let cachedQuote = defaults.string(forKey: quoteKey),
      let cachedNote = defaults.string(forKey: noteKey),
      !cachedQuote.isEmpty, !cachedNote.isEmpty
    {
      dailyQuote = cachedQuote
      dailyQuoteNote = cachedNote
      return
    }

    quoteIsLoading = true
    defer { quoteIsLoading = false }
    do {
      let result = try await AIService.shared.dailyQuote(
        activeCount: store.activeItems.count,
        rescuedCount: store.consumedItems.filter { !$0.isLost }.count,
        locale: store.appLanguage.apiLocale
      )
      dailyQuote = result.quote
      dailyQuoteNote = result.note
      defaults.set(today, forKey: dateKey)
      defaults.set(result.quote, forKey: quoteKey)
      defaults.set(result.note, forKey: noteKey)
    } catch {}
  }

  private var modernEmptyState: some View {
    HStack(spacing: 16) {
      Image(systemName: "refrigerator")
        .font(.system(size: 25, weight: .medium))
        .foregroundStyle(store.activeTint)
        .frame(width: 56, height: 56)
        .background(store.activeTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
      VStack(alignment: .leading, spacing: 4) {
        Text(uiText(store.appLanguage.usesEnglish, "まだ空っぽです", "Your fridge is empty")).font(.headline)
        Text(uiText(store.appLanguage.usesEnglish, "写真・AI・手入力ですぐ追加できます", "Add an item with a photo, AI, or manual entry.")).font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      Button(action: onAdd) { Image(systemName: "plus").font(.headline).frame(width: 38, height: 38) }
        .buttonStyle(.borderedProminent).buttonBorderShape(.circle)
    }
    .padding(16)
    .amarinGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}

private struct ModernActionButton: View {
  let icon: String
  let title: String
  let subtitle: String
  let tint: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 11) {
        Image(systemName: icon)
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(tint)
          .frame(width: 38, height: 38)
          .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        VStack(alignment: .leading, spacing: 2) {
          Text(LocalizedStringKey(title)).font(.subheadline.bold()).foregroundStyle(.primary)
          Text(LocalizedStringKey(subtitle)).font(.caption2).foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .amarinGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}

struct FoodRow: View {
  @EnvironmentObject private var store: FoodStore
  let item: FoodItem
  @State private var confirmingConsume = false
  @State private var earnedPoints: Int?
  @State private var recordedLoss = false

  var body: some View {
    HStack(spacing: 13) {
      Text(categoryEmoji(item.category)).font(.title2)
        .frame(width: 54, height: 54)
        .background(Color.amarinOrange.opacity(0.12), in: RoundedRectangle(cornerRadius: 17))
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 4) {
          Text(item.name).font(.headline).lineLimit(1)
          if item.registeredWithAi {
            Image(systemName: "sparkles").foregroundStyle(Color.amarinOrange).font(.caption)
          }
        }
        Text("\(item.expiryDate.formatted(date: .abbreviated, time: .omitted)) · \(localizedCategory(item.category, english: store.appLanguage.usesEnglish))")
          .font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 5) {
        Text(dayLabel(item.daysRemaining, english: store.appLanguage.usesEnglish)).font(.subheadline.bold())
          .foregroundStyle(item.daysRemaining <= 3 ? Color.amarinOrange : Color.green)
        Button(uiText(store.appLanguage.usesEnglish, "結果を記録", "Record result")) { confirmingConsume = true }
          .font(.caption.bold()).foregroundStyle(item.daysRemaining < 0 ? .red : .green)
      }
    }
    .padding(15)
    .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 22).stroke(.primary.opacity(0.08)))
    .confirmationDialog(uiText(store.appLanguage.usesEnglish, "食品の結果を記録", "Record food result"), isPresented: $confirmingConsume, titleVisibility: .visible) {
      Button(uiText(store.appLanguage.usesEnglish, "食べきった！", "Finished it!")) {
        recordedLoss = false
        earnedPoints = store.consume(item)
      }
      Button(uiText(store.appLanguage.usesEnglish, "ロスしてしまった", "Food was wasted"), role: .destructive) {
        recordedLoss = true
        earnedPoints = store.markAsWaste(item)
      }
      Button(uiText(store.appLanguage.usesEnglish, "キャンセル", "Cancel"), role: .cancel) {}
    } message: {
      let points = store.pointsForConsuming(item)
      let penalty = store.pointsForWasting(item)
      Text(store.appLanguage.usesEnglish
        ? "Finished: +\(points) P\nWasted: −\(penalty) P (balance never drops below zero)"
        : "食べきり：+\(points) P\nロス：−\(penalty) P（残高は0未満になりません）")
    }
    .alert(recordedLoss
      ? uiText(store.appLanguage.usesEnglish, "ロスを記録しました", "Waste recorded")
      : uiText(store.appLanguage.usesEnglish, "食べきり達成！", "Food rescued!"), isPresented: Binding(
      get: { earnedPoints != nil },
      set: { if !$0 { earnedPoints = nil } }
    )) {
      Button("OK") { earnedPoints = nil }
    } message: {
      let change = earnedPoints ?? 0
      Text(store.appLanguage.usesEnglish
        ? "\(change >= 0 ? "+" : "")\(change) points\nBalance: \(store.points) P"
        : "\(change >= 0 ? "+" : "")\(change) ポイント\n残高 \(store.points) P")
    }
  }
}

// MARK: - Foods

struct FoodsView: View {
  @EnvironmentObject private var store: FoodStore
  @State private var filter = 0
  @State private var deleteCandidate: FoodItem?
  private var shown: [FoodItem] {
    switch filter { case 1: store.consumedItems; case 2: store.items.sorted { $0.expiryDate < $1.expiryDate }; default: store.activeItems }
  }

  var body: some View {
    NavigationStack {
      List {
        Picker(uiText(store.appLanguage.usesEnglish, "表示", "Display"), selection: $filter) {
          Text(uiText(store.appLanguage.usesEnglish, "期限内", "Active")).tag(0)
          Text(uiText(store.appLanguage.usesEnglish, "記録済み", "History")).tag(1)
          Text(uiText(store.appLanguage.usesEnglish, "すべて", "All")).tag(2)
        }
        .pickerStyle(.segmented).listRowBackground(Color.clear).listRowSeparator(.hidden)
        ForEach(shown) { item in
          if item.isConsumed {
            HStack {
              Text(categoryEmoji(item.category))
              VStack(alignment: .leading) {
                Text(item.name).bold()
                Text(item.isLost
                  ? uiText(store.appLanguage.usesEnglish, "ロスを記録 · \(item.earnedPoints) P", "Waste recorded · \(item.earnedPoints) P")
                  : uiText(store.appLanguage.usesEnglish, "食べきり済み · +\(item.earnedPoints) P", "Finished · +\(item.earnedPoints) P"))
                  .font(.caption).foregroundStyle(item.isLost ? .red : .secondary)
              }
              Spacer()
              Image(systemName: item.isLost ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(item.isLost ? .red : .green)
            }
              .swipeActions { Button(uiText(store.appLanguage.usesEnglish, "削除", "Delete"), role: .destructive) { deleteCandidate = item } }
          } else {
            FoodRow(item: item).swipeActions { Button(uiText(store.appLanguage.usesEnglish, "削除", "Delete"), role: .destructive) { deleteCandidate = item } }
          }
        }.listRowBackground(Color.clear).listRowSeparator(.hidden)
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .navigationTitle(uiText(store.appLanguage.usesEnglish, "食品リスト", "Food List"))
      .confirmationDialog(uiText(store.appLanguage.usesEnglish, "食品を削除しますか？", "Delete this item?"), isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } }), titleVisibility: .visible) {
        Button(uiText(store.appLanguage.usesEnglish, "削除", "Delete"), role: .destructive) { if let item = deleteCandidate { store.delete(item) }; deleteCandidate = nil }
        Button(uiText(store.appLanguage.usesEnglish, "キャンセル", "Cancel"), role: .cancel) { deleteCandidate = nil }
      } message: {
        Text(deleteCandidate.map {
          uiText(store.appLanguage.usesEnglish, "\($0.name)を一覧から削除します。", "Remove \($0.name) from the list.")
        } ?? "")
      }
    }
  }
}

// MARK: - Recipes

struct RecipesView: View {
  @EnvironmentObject private var store: FoodStore
  @State private var preference = ""
  @State private var recipes: [RecipeSuggestion] = []
  @State private var messages: [ChatMessage] = []
  @State private var chatText = ""
  @State private var loading = false
  @State private var chatting = false
  @State private var glow = false
  @State private var error: String?
  private var usableItems: [FoodItem] { store.activeItems.filter { $0.daysRemaining >= 0 } }

  var body: some View {
    NavigationStack {
      ZStack(alignment: .top) {
        recipeBackground

        ScrollView {
          LazyVStack(alignment: .leading, spacing: 20) {
            recipeHero
            requestConsole

            if let error {
              Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote).foregroundStyle(.red)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            }

            if !recipes.isEmpty {
              HStack {
                VStack(alignment: .leading, spacing: 2) {
                  Text("AI PROPOSALS").font(.caption2.bold()).tracking(1.6).foregroundStyle(.cyan)
                  Text(uiText(store.appLanguage.usesEnglish, "今日の提案", "Today's ideas")).font(.system(size: 22, weight: .bold, design: .rounded))
                }
                Spacer()
                Text("\(recipes.count) RECIPES")
                  .font(.caption2.bold()).tracking(0.8).foregroundStyle(.secondary)
              }
            }

            ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
              RecipeCard(recipe: recipe, index: index)
            }

            chefConsole
          }
          .padding(.horizontal, 18)
          .padding(.top, 12)
          .padding(.bottom, 34)
        }
      }
      .toolbar(.hidden, for: .navigationBar)
      .onAppear {
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { glow = true }
      }
    }
  }

  private var recipeBackground: some View {
    ZStack(alignment: .top) {
      Color(uiColor: .systemBackground).ignoresSafeArea()
      RadialGradient(
        colors: [Color.purple.opacity(glow ? 0.20 : 0.10), .clear],
        center: UnitPoint(x: 0.84, y: 0.02), startRadius: 10, endRadius: 300
      )
      .frame(height: 560).ignoresSafeArea()
      RadialGradient(
        colors: [Color.cyan.opacity(glow ? 0.13 : 0.06), .clear],
        center: UnitPoint(x: 0.05, y: 0.38), startRadius: 5, endRadius: 260
      )
      .frame(height: 620).ignoresSafeArea()
    }
  }

  private var recipeHero: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        HStack(spacing: 8) {
          Circle().fill(.mint).frame(width: 7, height: 7)
            .shadow(color: .mint, radius: glow ? 8 : 3)
          Text("AMARIN AI · ONLINE")
            .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.3)
        }
        .padding(.horizontal, 11).padding(.vertical, 7)
        .background(.white.opacity(0.10), in: Capsule())
        Spacer()
        Image(systemName: "wand.and.stars.inverse")
          .font(.system(size: 20, weight: .semibold))
          .frame(width: 42, height: 42)
          .background(.white.opacity(0.10), in: Circle())
      }

      VStack(alignment: .leading, spacing: 7) {
        Text("AI KITCHEN")
          .font(.system(size: 36, weight: .black, design: .rounded))
          .tracking(-1.2)
        Text(usableItems.isEmpty
          ? uiText(store.appLanguage.usesEnglish, "食材を登録すると、AIが献立を設計します。", "Add ingredients and AI will design your next meal.")
          : uiText(store.appLanguage.usesEnglish, "冷蔵庫の\(usableItems.count)品から、次の一皿を設計します。", "Designing your next dish from \(usableItems.count) fridge items."))
          .font(.subheadline).foregroundStyle(.white.opacity(0.72))
      }

      if usableItems.isEmpty {
        Label(uiText(store.appLanguage.usesEnglish, "利用できる食材がありません", "No usable ingredients"), systemImage: "refrigerator")
          .font(.caption.bold()).foregroundStyle(.white.opacity(0.75))
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(usableItems.prefix(8)) { item in
              HStack(spacing: 6) {
                Text(categoryEmoji(item.category))
                Text(item.name).lineLimit(1)
              }
              .font(.caption.bold())
              .padding(.horizontal, 11).padding(.vertical, 8)
              .background(.white.opacity(0.10), in: Capsule())
              .overlay(Capsule().stroke(.white.opacity(0.14)))
            }
          }
        }
      }

      HStack(spacing: 0) {
        heroMetric(value: "\(usableItems.count)", label: "INGREDIENTS")
        Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 30)
        heroMetric(value: "3", label: "IDEAS")
        Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 30)
        heroMetric(value: "AI", label: "OPTIMIZED")
      }
    }
    .foregroundStyle(.white)
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      ZStack {
        LinearGradient(
          colors: [Color(red: 0.15, green: 0.08, blue: 0.34), Color(red: 0.12, green: 0.34, blue: 0.48)],
          startPoint: .topLeading, endPoint: .bottomTrailing
        )
        Circle().fill(.purple.opacity(0.38)).frame(width: 210).blur(radius: 8).offset(x: 150, y: -100)
        Circle().fill(.cyan.opacity(0.20)).frame(width: 180).blur(radius: 12).offset(x: -150, y: 125)
        RecipeGridPattern().opacity(0.14)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(LinearGradient(colors: [.white.opacity(0.30), .cyan.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)))
    .shadow(color: .purple.opacity(0.20), radius: 26, y: 13)
  }

  private func heroMetric(value: String, label: String) -> some View {
    VStack(spacing: 3) {
      Text(value).font(.system(size: 17, weight: .bold, design: .rounded))
      Text(label).font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.8).foregroundStyle(.white.opacity(0.55))
    }
    .frame(maxWidth: .infinity)
  }

  private var requestConsole: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 10) {
        Image(systemName: "slider.horizontal.3")
          .foregroundStyle(.cyan)
          .frame(width: 34, height: 34)
          .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
        VStack(alignment: .leading, spacing: 1) {
          Text(uiText(store.appLanguage.usesEnglish, "リクエスト", "Request")).font(.headline)
          Text(uiText(store.appLanguage.usesEnglish, "時間・味・気分をAIへ伝える", "Tell AI your time, taste, and mood.")).font(.caption).foregroundStyle(.secondary)
        }
      }

      HStack(spacing: 10) {
        TextField(uiText(store.appLanguage.usesEnglish, "例：15分以内、さっぱり", "e.g. Light and ready in 15 minutes"), text: $preference)
          .font(.subheadline)
          .padding(.horizontal, 14).padding(.vertical, 13)
          .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 15))
        if !preference.isEmpty {
          Button { preference = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
            .buttonStyle(.plain)
        }
      }

      Button { Task { await generate() } } label: {
        HStack(spacing: 10) {
          if loading { ProgressView().tint(.white) } else { Image(systemName: "sparkles") }
          Text(loading ? "GENERATING..." : uiText(store.appLanguage.usesEnglish, "レシピを生成", "Generate recipes"))
            .font(.system(size: 15, weight: .bold, design: .rounded))
          Spacer()
          if !loading { Image(systemName: "arrow.right").font(.subheadline.bold()) }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 17).frame(height: 52)
        .background(LinearGradient(colors: [.purple, .blue, .cyan], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .shadow(color: .purple.opacity(loading ? 0.12 : 0.28), radius: 16, y: 7)
      }
      .buttonStyle(.plain)
      .disabled(loading || usableItems.isEmpty)
      .opacity(usableItems.isEmpty ? 0.42 : 1)
    }
    .padding(17)
    .amarinGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  private var chefConsole: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 11) {
        ZStack {
          Circle().fill(LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
          Image(systemName: "waveform").foregroundStyle(.white).font(.subheadline.bold())
        }.frame(width: 42, height: 42).shadow(color: .purple.opacity(0.25), radius: 9)
        VStack(alignment: .leading, spacing: 2) {
          Text("AI CHEF CONSOLE").font(.caption2.bold()).tracking(1.2).foregroundStyle(.purple)
          Text(uiText(store.appLanguage.usesEnglish, "代用品や作り方を相談", "Ask about substitutes or steps")).font(.headline)
        }
        Spacer()
        HStack(spacing: 5) {
          Circle().fill(.green).frame(width: 6, height: 6)
          Text("LIVE").font(.caption2.bold()).foregroundStyle(.secondary)
        }
      }

      ForEach(messages) { message in
        HStack(alignment: .bottom, spacing: 8) {
          if message.role == "user" { Spacer(minLength: 42) }
          if message.role != "user" {
            Image(systemName: "sparkles").font(.caption).foregroundStyle(.cyan)
          }
          Text(message.text)
            .font(.subheadline)
            .padding(.horizontal, 13).padding(.vertical, 11)
            .background(message.role == "user" ? Color.purple.opacity(0.16) : Color.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          if message.role != "user" { Spacer(minLength: 42) }
        }
      }

      if chatting {
        HStack(spacing: 8) {
          ProgressView().controlSize(.small).tint(.cyan)
          Text(uiText(store.appLanguage.usesEnglish, "AIシェフが考えています", "AI Chef is thinking")).font(.caption).foregroundStyle(.secondary)
        }
      }

      HStack(spacing: 10) {
        TextField(uiText(store.appLanguage.usesEnglish, "AIシェフに質問する", "Ask AI Chef"), text: $chatText)
          .font(.subheadline)
          .padding(.horizontal, 14).frame(height: 46)
          .background(.primary.opacity(0.055), in: Capsule())
        Button { Task { await sendChat() } } label: {
          Image(systemName: "arrow.up")
            .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(chatting || chatText.trimmingCharacters(in: .whitespaces).isEmpty || usableItems.isEmpty)
      }
      Text(uiText(store.appLanguage.usesEnglish, "アレルギーや加熱状態など、安全性は必ずご自身で確認してください。", "Always verify allergies, cooking temperatures, and food safety yourself."))
        .font(.caption2).foregroundStyle(.secondary)
    }
    .padding(17)
    .amarinGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  private func generate() async {
    loading = true
    error = nil
    defer { loading = false }
    do {
      recipes = try await AIService.shared.recipes(items: usableItems, preference: preference, locale: store.appLanguage.apiLocale)
    } catch {
      self.error = store.appLanguage.usesEnglish ? "AI could not generate recipes. Please try again." : error.localizedDescription
    }
  }

  private func sendChat() async {
    let text = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    chatText = ""
    messages.append(ChatMessage(role: "user", text: text))
    chatting = true
    defer { chatting = false }
    do {
      let reply = try await AIService.shared.chat(items: usableItems, messages: messages, locale: store.appLanguage.apiLocale)
      withAnimation(.snappy) { messages.append(ChatMessage(role: "assistant", text: reply)) }
    } catch {
      self.error = store.appLanguage.usesEnglish ? "AI Chef could not reply. Please try again." : error.localizedDescription
    }
  }
}

private struct RecipeCard: View {
  let recipe: RecipeSuggestion
  let index: Int
  @State private var expanded = true
  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      Button { withAnimation(.snappy) { expanded.toggle() } } label: {
        HStack(alignment: .top, spacing: 13) {
          Text(String(format: "%02d", index + 1))
            .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(.cyan)
            .frame(width: 38, height: 38)
            .background(.cyan.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
          VStack(alignment: .leading, spacing: 5) {
            Text(recipe.title).font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(.primary)
            Text(recipe.description).font(.caption).foregroundStyle(.secondary).lineLimit(expanded ? 3 : 1)
            HStack(spacing: 8) {
              Label("\(recipe.cookTimeMinutes) MIN", systemImage: "clock")
              Label(recipe.servings, systemImage: "person.2")
            }.font(.caption2.bold()).foregroundStyle(.purple)
          }
          Spacer(minLength: 4)
          Image(systemName: expanded ? "minus" : "plus")
            .font(.caption.bold()).foregroundStyle(.secondary)
            .frame(width: 30, height: 30).background(.primary.opacity(0.055), in: Circle())
        }
      }.buttonStyle(.plain)
      if expanded {
        Rectangle().fill(LinearGradient(colors: [.clear, .cyan.opacity(0.55), .purple.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 1)
        Label("INGREDIENTS", systemImage: "basket.fill").font(.caption.bold()).tracking(1).foregroundStyle(.cyan)
        ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, ingredient in
          HStack(spacing: 9) {
            Image(systemName: ingredient.available ? "checkmark.circle.fill" : "plus.circle")
              .foregroundStyle(ingredient.available ? .mint : .secondary)
            Text(ingredient.name).font(.subheadline)
            Spacer()
            Text(ingredient.amount).font(.caption).foregroundStyle(.secondary)
          }
        }
        Label("SEQUENCE", systemImage: "list.number").font(.caption.bold()).tracking(1).foregroundStyle(.purple)
        ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
          HStack(alignment: .top, spacing: 11) {
            Text("\(index + 1)")
              .font(.caption2.bold()).foregroundStyle(.white)
              .frame(width: 24, height: 24)
              .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            Text(step).font(.subheadline).fixedSize(horizontal: false, vertical: true)
          }
        }
        if !recipe.tip.isEmpty {
          HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lightbulb.max.fill").foregroundStyle(.yellow)
            Text(recipe.tip).font(.caption).foregroundStyle(.secondary)
          }
          .padding(12).frame(maxWidth: .infinity, alignment: .leading)
          .background(LinearGradient(colors: [.yellow.opacity(0.10), .purple.opacity(0.06)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 14))
        }
      }
    }
    .padding(17)
    .amarinGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay(alignment: .leading) {
      Capsule().fill(LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom)).frame(width: 3).padding(.vertical, 24)
    }
  }
}

private struct RecipeGridPattern: View {
  var body: some View {
    Canvas { context, size in
      var path = Path()
      let step: CGFloat = 28
      stride(from: CGFloat.zero, through: size.width, by: step).forEach { x in
        path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
      }
      stride(from: CGFloat.zero, through: size.height, by: step).forEach { y in
        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
      }
      context.stroke(path, with: .color(.white), lineWidth: 0.5)
    }
  }
}

// MARK: - Points

struct PointsView: View {
  @EnvironmentObject private var store: FoodStore
  @State private var selectedReward: RewardItem?
  @State private var showingLevelDetails = false
  @State private var themePage = "theme_classic"
  @State private var pulse = false

  private var player: PlayerLevel { PlayerLevel(points: store.lifetimePoints) }
  private var themes: [RewardItem] { RewardItem.catalog.filter { $0.category == .theme } }

  var body: some View {
    NavigationStack {
      ZStack(alignment: .top) {
        LinearGradient(
          colors: [store.activeTint.opacity(0.15), Color.purple.opacity(0.07), .clear],
          startPoint: .topLeading, endPoint: .center
        )
        .frame(height: 560).ignoresSafeArea()

        ScrollView {
          LazyVStack(alignment: .leading, spacing: 24) {
            Button { showingLevelDetails = true } label: { playerHero }
              .buttonStyle(.plain)
              .accessibilityLabel(uiText(store.appLanguage.usesEnglish, "レベルと昇格条件を見る", "View level and promotion requirements"))

            sectionHeader(eyebrow: "THEME DECK", title: uiText(store.appLanguage.usesEnglish, "テーマを選ぶ", "Choose a theme"), detail: uiText(store.appLanguage.usesEnglish, "横にスワイプ", "Swipe sideways"))
            TabView(selection: $themePage) {
              ForEach(themes) { reward in
                ThemeRewardCard(reward: reward) { selectedReward = reward }
                  .padding(.horizontal, 2)
                  .tag(reward.id)
              }
            }
            .frame(height: 246)
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 6) {
              ForEach(themes) { reward in
                Capsule()
                  .fill(themePage == reward.id ? store.activeTint : Color.secondary.opacity(0.20))
                  .frame(width: themePage == reward.id ? 22 : 6, height: 6)
                  .animation(.snappy, value: themePage)
              }
            }
            .frame(maxWidth: .infinity)

            sectionHeader(eyebrow: "REWARD MAP", title: uiText(store.appLanguage.usesEnglish, "報酬コレクション", "Reward collection"), detail: uiText(store.appLanguage.usesEnglish, "丸をタップで詳細", "Tap a circle"))
            rewardMap

            earnGuide
            historyCard
          }
          .padding(.horizontal, 18)
          .padding(.top, 12)
          .padding(.bottom, 36)
        }
      }
      .toolbar(.hidden, for: .navigationBar)
      .sheet(item: $selectedReward) { reward in
        RewardDetailView(reward: reward)
          .environmentObject(store)
          .presentationDetents([.medium, .large])
          .presentationDragIndicator(.visible)
      }
      .sheet(isPresented: $showingLevelDetails) {
        LevelDetailView()
          .environmentObject(store)
          .presentationDetents([.large])
          .presentationDragIndicator(.visible)
      }
      .onAppear {
        themePage = store.activeThemeID
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { pulse = true }
      }
    }
  }

  private var playerHero: some View {
    HStack(spacing: 18) {
      ZStack {
        Circle().stroke(.white.opacity(0.16), lineWidth: 7)
        Circle()
          .trim(from: 0, to: max(0.02, player.progress))
          .stroke(AngularGradient(colors: [.white, .yellow, .white], center: .center), style: StrokeStyle(lineWidth: 7, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Circle().fill(.white.opacity(0.11)).padding(10)
        VStack(spacing: 0) {
          Text("LV").font(.system(size: 9, weight: .bold, design: .monospaced)).opacity(0.65)
          Text("\(player.level)").font(.system(size: 31, weight: .black, design: .rounded))
        }
      }
      .frame(width: 102, height: 102)
      .scaleEffect(pulse ? 1.02 : 0.98)

      VStack(alignment: .leading, spacing: 5) {
        Text("AMARIN REWARDS").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.4).opacity(0.65)
        HStack(alignment: .firstTextBaseline, spacing: 5) {
          Text("\(store.points)").font(.system(size: 40, weight: .black, design: .rounded))
          Text("P").font(.title3.bold()).opacity(0.7)
        }
        Text("LEVEL \(player.level) · \(player.localizedName(english: store.appLanguage.usesEnglish))").font(.caption.bold()).opacity(0.75)
        Text(player.isMax
          ? uiText(store.appLanguage.usesEnglish, "最高レベルに到達", "Maximum level reached")
          : uiText(store.appLanguage.usesEnglish, "昇格まで \(player.pointsToNext) XP", "\(player.pointsToNext) XP to next rank"))
          .font(.caption2).opacity(0.65)
      }
      Spacer(minLength: 0)
      VStack(spacing: 4) {
        Image(systemName: "chevron.right").font(.caption.bold())
        Text(uiText(store.appLanguage.usesEnglish, "詳細", "DETAILS")).font(.system(size: 8, weight: .bold))
      }.opacity(0.70)
    }
    .foregroundStyle(.white)
    .padding(20)
    .frame(maxWidth: .infinity)
    .background {
      ZStack {
        LinearGradient(colors: [store.activeTint, store.activeTint.opacity(0.62), .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        Circle().fill(.white.opacity(0.13)).frame(width: 170).offset(x: 165, y: -75)
        Circle().fill(.yellow.opacity(0.12)).frame(width: 130).offset(x: -165, y: 85)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    .shadow(color: store.activeTint.opacity(0.24), radius: 25, y: 12)
  }

  private func sectionHeader(eyebrow: String, title: String, detail: String) -> some View {
    HStack(alignment: .bottom) {
      VStack(alignment: .leading, spacing: 3) {
        Text(LocalizedStringKey(eyebrow)).font(.caption2.bold()).tracking(1.4).foregroundStyle(store.activeTint)
        Text(LocalizedStringKey(title)).font(.system(size: 22, weight: .bold, design: .rounded))
      }
      Spacer()
      Text(LocalizedStringKey(detail)).font(.caption).foregroundStyle(.secondary)
    }
  }

  private var rewardMap: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(alignment: .top, spacing: 16) {
        ForEach(Array(RewardItem.catalog.filter { $0.category != .theme }.enumerated()), id: \.element.id) { index, reward in
          RewardNode(reward: reward, index: index) { selectedReward = reward }
        }
      }
      .padding(.horizontal, 3).padding(.vertical, 8)
    }
    .scrollTargetBehavior(.viewAligned)
  }

  private var earnGuide: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label(uiText(store.appLanguage.usesEnglish, "ポイントの集め方", "How to earn points"), systemImage: "bolt.fill").font(.headline)
        Spacer()
        Text("EARN").font(.caption2.bold()).tracking(1).foregroundStyle(store.activeTint)
      }
      HStack(spacing: 8) {
        earnChip(icon: "clock.fill", points: "+20", label: uiText(store.appLanguage.usesEnglish, "期限直前", "Due soon"))
        earnChip(icon: "fork.knife", points: "+15", label: uiText(store.appLanguage.usesEnglish, "3日前", "3 days"))
        earnChip(icon: "leaf.fill", points: "+10", label: uiText(store.appLanguage.usesEnglish, "早め", "Early"))
      }
      HStack(spacing: 9) {
        Image(systemName: "arrow.down.circle.fill").foregroundStyle(.red)
        Text(uiText(store.appLanguage.usesEnglish, "ロスを記録すると −10 P、期限切れは −20 P", "Waste: −10 P · Expired: −20 P")).font(.caption.bold())
        Spacer()
        Text(uiText(store.appLanguage.usesEnglish, "XPは維持", "XP stays")).font(.caption2.bold()).foregroundStyle(.secondary)
      }
      .padding(11).background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
    .padding(17)
    .amarinGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  private func earnChip(icon: String, points: String, label: String) -> some View {
    VStack(spacing: 5) {
      Image(systemName: icon).foregroundStyle(store.activeTint)
      Text(points).font(.headline)
      Text(label).font(.caption2).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity).padding(.vertical, 11)
    .background(store.activeTint.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
  }

  private var historyCard: some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack {
        Text(uiText(store.appLanguage.usesEnglish, "最近のポイント", "Recent points")).font(.headline)
        Spacer()
        Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
      }
      let history = store.consumedItems.filter { $0.earnedPoints != 0 || $0.isLost }
      if history.isEmpty {
        Text(uiText(store.appLanguage.usesEnglish, "食品を食べきると、ここにポイント履歴が表示されます。", "Your point history will appear here after you finish food."))
          .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 6)
      } else {
        ForEach(history.prefix(5)) { item in
          HStack(spacing: 11) {
            Text(categoryEmoji(item.category)).frame(width: 36, height: 36).background(.primary.opacity(0.05), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
              Text(item.name).font(.subheadline.bold())
              Text(item.isLost
                ? uiText(store.appLanguage.usesEnglish, "ロスを記録", "Waste recorded")
                : uiText(store.appLanguage.usesEnglish, "食べきり達成", "Food rescued")).font(.caption2).foregroundStyle(item.isLost ? .red : .secondary)
            }
            Spacer()
            Text("\(item.earnedPoints > 0 ? "+" : "")\(item.earnedPoints) P")
              .font(.subheadline.bold()).foregroundStyle(item.isLost ? .red : .green)
          }
        }
      }
    }
    .padding(17)
    .amarinGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}

private struct LevelDetailView: View {
  @EnvironmentObject private var store: FoodStore
  @Environment(\.dismiss) private var dismiss

  private var player: PlayerLevel { PlayerLevel(points: store.lifetimePoints) }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          VStack(alignment: .leading, spacing: 10) {
            Text("RANK ROAD").font(.caption2.bold()).tracking(1.7).foregroundStyle(store.activeTint)
            Text(uiText(store.appLanguage.usesEnglish, "レベル \(player.level)", "Level \(player.level)") + " · \(player.localizedName(english: store.appLanguage.usesEnglish))")
              .font(.system(size: 30, weight: .black, design: .rounded))
            Text(uiText(store.appLanguage.usesEnglish, "交換してもレベルは下がりません。累計XPは、これまで救った食品の記録です。", "Redeeming rewards never lowers your level. Lifetime XP records all the food you have rescued."))
              .font(.subheadline).foregroundStyle(.secondary)
          }

          HStack(spacing: 10) {
            rankMetric(icon: "sparkles", value: "\(store.lifetimePoints)", label: uiText(store.appLanguage.usesEnglish, "累計XP", "Lifetime XP"))
            rankMetric(icon: "star.fill", value: "\(store.points)", label: uiText(store.appLanguage.usesEnglish, "交換ポイント", "Points"))
            rankMetric(icon: "trophy.fill", value: "\(player.level)/\(PlayerLevel.thresholds.count)", label: uiText(store.appLanguage.usesEnglish, "現在ランク", "Current rank"))
          }

          if !player.isMax {
            VStack(alignment: .leading, spacing: 9) {
              HStack {
                Text(uiText(store.appLanguage.usesEnglish, "次の昇格まで", "Next promotion")).font(.subheadline.bold())
                Spacer()
                Text(uiText(store.appLanguage.usesEnglish, "あと \(player.pointsToNext) XP", "\(player.pointsToNext) XP to go")).font(.subheadline.bold()).foregroundStyle(store.activeTint)
              }
              ProgressView(value: player.progress).tint(store.activeTint)
            }
            .padding(16)
            .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.primary.opacity(0.08)))
          }

          Text(uiText(store.appLanguage.usesEnglish, "昇格ロード", "Rank Road")).font(.title2.bold())

          VStack(spacing: 0) {
            ForEach(PlayerLevel.thresholds.indices, id: \.self) { index in
              let reached = store.lifetimePoints >= PlayerLevel.thresholds[index]
              let current = player.level == index + 1
              HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                  ZStack {
                    Circle().fill(reached ? store.activeTint : Color.secondary.opacity(0.16))
                    if reached {
                      Image(systemName: current ? "location.fill" : "checkmark")
                        .font(.caption.bold()).foregroundStyle(.white)
                    } else {
                      Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                    }
                  }
                  .frame(width: 42, height: 42)
                  if index < PlayerLevel.thresholds.count - 1 {
                    Rectangle().fill(reached ? store.activeTint.opacity(0.45) : Color.secondary.opacity(0.14)).frame(width: 3, height: 54)
                  }
                }

                VStack(alignment: .leading, spacing: 4) {
                  HStack {
                    Text("LEVEL \(index + 1) · \(levelName(index + 1, english: store.appLanguage.usesEnglish))").font(.headline)
                    if current {
                      Text("CURRENT").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(store.activeTint)
                        .padding(.horizontal, 7).padding(.vertical, 4).background(store.activeTint.opacity(0.11), in: Capsule())
                    }
                    Spacer()
                    Text("\(PlayerLevel.thresholds[index]) XP").font(.caption.bold()).foregroundStyle(.secondary)
                  }
                  Text(rankUnlock(index)).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.top, 2)
              }
            }
          }
        }
        .padding(20)
      }
      .background(RadialGradient(colors: [store.activeTint.opacity(0.13), .clear], center: .topLeading, startRadius: 10, endRadius: 430).ignoresSafeArea())
      .navigationTitle(uiText(store.appLanguage.usesEnglish, "ランク詳細", "Rank Details"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button(uiText(store.appLanguage.usesEnglish, "閉じる", "Close")) { dismiss() } } }
    }
  }

  private func rankMetric(icon: String, value: String, label: String) -> some View {
    VStack(spacing: 5) {
      Image(systemName: icon).foregroundStyle(store.activeTint)
      Text(value).font(.headline)
      Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).lineLimit(1)
    }
    .frame(maxWidth: .infinity).padding(.vertical, 13)
    .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
  }

  private func rankUnlock(_ index: Int) -> String {
    if store.appLanguage.usesEnglish {
      switch index {
      case 0: return "Unlock point exchange and the Classic theme"
      case 1: return "Unlock RARE themes and badge exchange"
      case 2: return "Unlock AI KITCHEN rank effects"
      case 3: return "Gain access to EPIC collections"
      case 4: return "Unlock LEGEND rewards and an exclusive profile title"
      case 5: return "Unlock the Golden Harvest challenge"
      case 6: return "Gain access to MYTHIC collections"
      default: return "Highest rank · Certified Amarin Legend"
      }
    }
    switch index {
    case 0: return "ポイント交換とClassicテーマが解放"
    case 1: return "RAREテーマ・バッジ交換が解放"
    case 2: return "AI KITCHENランク演出が解放"
    case 3: return "EPICコレクションへの挑戦権"
    case 4: return "LEGEND報酬と限定プロフィール称号"
    case 5: return "Golden Harvestチャレンジが解放"
    case 6: return "MYTHICコレクションへの挑戦権"
    default: return "最高ランク・あまりんレジェンド認定"
    }
  }
}

private struct ThemeRewardCard: View {
  @EnvironmentObject private var store: FoodStore
  let reward: RewardItem
  let action: () -> Void

  var body: some View {
    let copy = reward.localizedCopy(english: store.appLanguage.usesEnglish)
    Button(action: action) {
      ZStack(alignment: .bottomLeading) {
        LinearGradient(colors: [reward.primary, reward.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
        Circle().fill(.white.opacity(0.15)).frame(width: 180).offset(x: 150, y: -65)
        Circle().stroke(.white.opacity(0.12), lineWidth: 28).frame(width: 150).offset(x: -105, y: 90)
        VStack(alignment: .leading, spacing: 14) {
          HStack {
            Text(reward.rarity).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.2)
              .padding(.horizontal, 10).padding(.vertical, 6).background(.white.opacity(0.15), in: Capsule())
            Spacer()
            if store.activeThemeID == reward.id {
              Label(uiText(store.appLanguage.usesEnglish, "使用中", "ACTIVE"), systemImage: "checkmark.circle.fill").font(.caption.bold())
            } else if store.owns(reward) {
              Label(uiText(store.appLanguage.usesEnglish, "所持", "OWNED"), systemImage: "checkmark").font(.caption.bold())
            }
          }
          Spacer()
          Image(systemName: reward.icon).font(.system(size: 38, weight: .medium))
          VStack(alignment: .leading, spacing: 3) {
            Text(copy.title).font(.system(size: 25, weight: .bold, design: .rounded))
            Text(copy.subtitle).font(.subheadline).opacity(0.76)
          }
          HStack {
            Label(reward.cost == 0 ? "FREE" : "\(reward.cost) P", systemImage: "star.fill").font(.caption.bold())
            Spacer()
            Label(uiText(store.appLanguage.usesEnglish, "詳細", "Details"), systemImage: "arrow.up.right").font(.caption.bold())
          }
        }
        .padding(19)
      }
      .foregroundStyle(.white)
      .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 27, style: .continuous).stroke(.white.opacity(0.24)))
      .shadow(color: reward.primary.opacity(0.24), radius: 18, y: 9)
    }
    .buttonStyle(.plain)
    .padding(.vertical, 4)
  }
}

private struct RewardNode: View {
  @EnvironmentObject private var store: FoodStore
  let reward: RewardItem
  let index: Int
  let action: () -> Void

  var body: some View {
    let copy = reward.localizedCopy(english: store.appLanguage.usesEnglish)
    Button(action: action) {
      VStack(spacing: 9) {
        ZStack {
          Circle().fill(LinearGradient(colors: [reward.primary.opacity(0.95), reward.secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
          Circle().stroke(.white.opacity(0.35), lineWidth: 2).padding(5)
          Image(systemName: store.owns(reward) ? reward.icon : (store.points >= reward.cost ? reward.icon : "lock.fill"))
            .font(.system(size: 23, weight: .bold)).foregroundStyle(.white)
        }
        .frame(width: 76, height: 76)
        .shadow(color: reward.primary.opacity(0.28), radius: 12, y: 6)
        Text(copy.title).font(.caption.bold()).lineLimit(1).frame(width: 96)
        Text(store.owns(reward)
          ? uiText(store.appLanguage.usesEnglish, "獲得済み", "OWNED")
          : reward.exchangeable ? "\(reward.cost) P" : uiText(store.appLanguage.usesEnglish, "準備中", "SOON"))
          .font(.caption2.bold()).foregroundStyle(store.owns(reward) ? .green : .secondary)
      }
      .padding(.vertical, index.isMultiple(of: 2) ? 0 : 20)
      .scrollTargetLayout()
    }
    .buttonStyle(.plain)
  }
}

private struct RewardDetailView: View {
  @EnvironmentObject private var store: FoodStore
  @Environment(\.dismiss) private var dismiss
  let reward: RewardItem
  @State private var justUnlocked = false

  private var owned: Bool { store.owns(reward) }

  var body: some View {
    let copy = reward.localizedCopy(english: store.appLanguage.usesEnglish)
    ScrollView {
      VStack(spacing: 22) {
        ZStack {
          Circle().fill(LinearGradient(colors: [reward.primary, reward.secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
            .shadow(color: reward.primary.opacity(0.38), radius: 25, y: 12)
          Circle().stroke(.white.opacity(0.32), lineWidth: 2).padding(9)
          Image(systemName: reward.icon).font(.system(size: 43, weight: .bold)).foregroundStyle(.white)
        }
        .frame(width: 126, height: 126)

        VStack(spacing: 7) {
          Text(reward.rarity).font(.caption2.bold()).tracking(1.5).foregroundStyle(reward.primary)
          Text(copy.title).font(.system(size: 28, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
          Text(copy.subtitle).font(.subheadline).foregroundStyle(.secondary)
        }

        Text(copy.detail)
          .font(.body).multilineTextAlignment(.center).foregroundStyle(.secondary)
          .padding(.horizontal, 8)

        HStack(spacing: 12) {
          detailMetric(title: "TYPE", value: reward.category.title(english: store.appLanguage.usesEnglish))
          detailMetric(title: "COST", value: reward.cost == 0 ? "FREE" : "\(reward.cost) P")
          detailMetric(title: "BALANCE", value: "\(store.points) P")
        }

        if justUnlocked {
          Label(uiText(store.appLanguage.usesEnglish, "アンロックしました！", "Unlocked!"), systemImage: "party.popper.fill")
            .font(.headline).foregroundStyle(.green)
            .transition(.scale.combined(with: .opacity))
        }

        actionButton
      }
      .padding(24)
    }
    .background(RadialGradient(colors: [reward.primary.opacity(0.13), .clear], center: .top, startRadius: 20, endRadius: 380).ignoresSafeArea())
  }

  private func detailMetric(title: String, value: String) -> some View {
    VStack(spacing: 4) {
      Text(title).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
      Text(value).font(.caption.bold())
    }
    .frame(maxWidth: .infinity).padding(.vertical, 12)
    .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
  }

  @ViewBuilder
  private var actionButton: some View {
    if reward.category == .theme && owned {
      Button {
        store.activateTheme(reward)
        dismiss()
      } label: {
        Label(store.activeThemeID == reward.id
          ? uiText(store.appLanguage.usesEnglish, "このテーマを使用中", "Theme active")
          : uiText(store.appLanguage.usesEnglish, "このテーマを使う", "Use this theme"), systemImage: store.activeThemeID == reward.id ? "checkmark.circle.fill" : "paintpalette.fill")
          .frame(maxWidth: .infinity).frame(height: 50)
      }
      .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 16))
      .disabled(store.activeThemeID == reward.id)
    } else if owned {
      Label(uiText(store.appLanguage.usesEnglish, "コレクション獲得済み", "Collection owned"), systemImage: "checkmark.seal.fill")
        .font(.headline).foregroundStyle(.green).frame(maxWidth: .infinity).frame(height: 50)
        .background(.green.opacity(0.11), in: RoundedRectangle(cornerRadius: 16))
    } else if !reward.exchangeable {
      Label("COMING SOON", systemImage: "clock.fill")
        .font(.headline).foregroundStyle(.secondary).frame(maxWidth: .infinity).frame(height: 50)
        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
    } else {
      Button {
        if store.redeem(reward) {
          withAnimation(.spring) { justUnlocked = true }
        }
      } label: {
        Label(store.points >= reward.cost
          ? uiText(store.appLanguage.usesEnglish, "\(reward.cost) Pで交換", "Redeem for \(reward.cost) P")
          : uiText(store.appLanguage.usesEnglish, "あと \(reward.cost - store.points) P", "Need \(reward.cost - store.points) P"), systemImage: store.points >= reward.cost ? "lock.open.fill" : "lock.fill")
          .frame(maxWidth: .infinity).frame(height: 50)
      }
      .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 16))
      .tint(reward.primary)
      .disabled(store.points < reward.cost)
    }
  }
}

// MARK: - Add food

struct NotificationSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: FoodStore
  @State private var enabled = false
  @State private var hour = 9
  private let hours = [8, 9, 12, 18, 20]
  var body: some View {
    NavigationStack { Form {
      Section { Toggle(uiText(store.appLanguage.usesEnglish, "通知を受け取る", "Receive notifications"), isOn: $enabled) } footer: { Text(uiText(store.appLanguage.usesEnglish, "賞味期限の3日前と当日にお知らせします", "Get notified three days before expiry and on the expiry date.")) }
      Section(uiText(store.appLanguage.usesEnglish, "通知する時間", "Notification time")) { Picker(uiText(store.appLanguage.usesEnglish, "時刻", "Time"), selection: $hour) { ForEach(hours, id: \.self) { Text("\($0):00").tag($0) } }.pickerStyle(.segmented).disabled(!enabled) }
    }.navigationTitle(uiText(store.appLanguage.usesEnglish, "期限のお知らせ", "Expiry Alerts")).toolbar {
      ToolbarItem(placement: .cancellationAction) { Button(uiText(store.appLanguage.usesEnglish, "閉じる", "Close")) { dismiss() } }
      ToolbarItem(placement: .confirmationAction) { Button(uiText(store.appLanguage.usesEnglish, "設定を保存", "Save")) { Task { let granted = enabled ? await store.requestNotifications() : false; store.notificationsEnabled = enabled && granted; store.reminderHour = hour; await store.syncNotifications(); dismiss() } } }
    }.onAppear { enabled = store.notificationsEnabled; hour = store.reminderHour } }
  }
}

struct LanguageSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject private var store: FoodStore

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(AppLanguage.allCases) { language in
            Button {
              withAnimation(.snappy) { store.appLanguage = language }
            } label: {
              HStack(spacing: 14) {
                Image(systemName: language == .system ? "iphone" : "globe")
                  .foregroundStyle(store.activeTint)
                  .frame(width: 38, height: 38)
                  .background(store.activeTint.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
                Text(language.title(english: store.appLanguage.usesEnglish))
                  .font(.headline)
                  .foregroundStyle(.primary)
                Spacer()
                if store.appLanguage == language {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(store.activeTint)
                }
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
        } footer: {
          Text(uiText(store.appLanguage.usesEnglish, "システム設定を選ぶと、iPhoneの言語に自動で合わせます。", "Follow System Language automatically matches your iPhone language."))
        }

        Section(uiText(store.appLanguage.usesEnglish, "表示モード", "Appearance")) {
          HStack(spacing: 14) {
            Image(systemName: colorScheme == .dark ? "moon.stars.fill" : "sun.max.fill")
              .foregroundStyle(colorScheme == .dark ? .purple : .orange)
              .frame(width: 38, height: 38)
              .background((colorScheme == .dark ? Color.purple : Color.orange).opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
              Text(colorScheme == .dark
                ? uiText(store.appLanguage.usesEnglish, "ダークモード", "Dark Mode")
                : uiText(store.appLanguage.usesEnglish, "ライトモード", "Light Mode")).font(.headline)
              Text(uiText(store.appLanguage.usesEnglish, "iPhoneのシステム設定に自動で合わせます", "Automatically follows your iPhone settings.")).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("AUTO").font(.system(size: 9, weight: .bold, design: .monospaced))
              .foregroundStyle(store.activeTint)
              .padding(.horizontal, 8).padding(.vertical, 5)
              .background(store.activeTint.opacity(0.10), in: Capsule())
          }
        }
      }
      .navigationTitle(uiText(store.appLanguage.usesEnglish, "言語", "Language"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(uiText(store.appLanguage.usesEnglish, "完了", "Done")) { dismiss() }
        }
      }
    }
  }
}

struct AddFlowView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: FoodStore
  @State private var route = 0
  let onComplete: () -> Void
  var body: some View {
    NavigationStack {
      List {
        Section { Text(uiText(store.appLanguage.usesEnglish, "登録方法を選んでください", "Choose how to add your item.")).foregroundStyle(.secondary) }
        Button { route = 4 } label: { AddChoice(icon: "camera.fill", color: .orange, title: uiText(store.appLanguage.usesEnglish, "写真を撮ってAI登録", "Scan with Camera"), subtitle: uiText(store.appLanguage.usesEnglish, "商品名と賞味期限をAIが読み取ります", "AI reads the product and expiry date."), badge: uiText(store.appLanguage.usesEnglish, "おすすめ", "RECOMMENDED")) }
        Button { route = 1 } label: { AddChoice(icon: "photo.on.rectangle", color: .green, title: uiText(store.appLanguage.usesEnglish, "アルバムから選ぶ", "Choose from Photos"), subtitle: uiText(store.appLanguage.usesEnglish, "保存済みの写真をAIで読み取ります", "Analyze a saved photo with AI.")) }
        Button { route = 2 } label: { AddChoice(icon: "bubble.left.and.bubble.right.fill", color: .purple, title: uiText(store.appLanguage.usesEnglish, "AIと会話して登録", "Identify with AI Chat"), subtitle: uiText(store.appLanguage.usesEnglish, "質問に答えて商品と期限を特定します", "Chat to identify the item and expiry date."), badge: "NEW") }
        Button { route = 3 } label: { AddChoice(icon: "calendar.badge.plus", color: .blue, title: uiText(store.appLanguage.usesEnglish, "手入力で登録", "Enter Manually"), subtitle: uiText(store.appLanguage.usesEnglish, "商品名と日付を自分で入力します", "Enter the item name and date yourself.")) }
      }.buttonStyle(.plain).navigationTitle(uiText(store.appLanguage.usesEnglish, "食品を登録", "Add Food")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(uiText(store.appLanguage.usesEnglish, "閉じる", "Close")) { dismiss() } } }
        .navigationDestination(isPresented: Binding(get: { route != 0 }, set: { if !$0 { route = 0 } })) {
          if route == 2 { ProductAgentView(onComplete: onComplete) } else { AddFoodView(startWithPhotoPicker: route == 1, startWithCamera: route == 4, onComplete: onComplete) }
        }
    }
  }
}

private struct AddChoice: View {
  let icon: String; let color: Color; let title: String; let subtitle: String; var badge: String? = nil
  var body: some View { HStack(spacing: 14) { Image(systemName: icon).foregroundStyle(color).frame(width: 48, height: 48).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 15)); VStack(alignment: .leading, spacing: 4) { HStack { Text(LocalizedStringKey(title)).bold(); if let badge { Text(LocalizedStringKey(badge)).font(.caption2.bold()).foregroundStyle(.orange) } }; Text(LocalizedStringKey(subtitle)).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary) }.padding(.vertical, 5) }
}

struct ProductAgentView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: FoodStore
  @State private var messages: [ChatMessage] = []
  @State private var input = ""
  @State private var sending = false
  @State private var candidate: AIService.ProductResult?
  @State private var error: String?
  @FocusState private var inputFocused: Bool
  let onComplete: () -> Void

  private var suggestions: [String] {
    store.appLanguage.usesEnglish
      ? ["It's milk", "The date is September 20, 2026", "It's a vegetable"]
      : ["牛乳です", "期限は2026年9月20日", "野菜です"]
  }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color.purple.opacity(0.12), store.activeTint.opacity(0.07), .clear],
        startPoint: .topLeading,
        endPoint: .center
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        agentHeader

        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(spacing: 13) {
              ForEach(messages) { message in
                ProductChatBubble(message: message, tint: store.activeTint)
                  .id(message.id)
              }

              if messages.count == 1 && !sending {
                suggestionChips
              }

              if sending {
                HStack(spacing: 10) {
                  ProgressView().tint(.purple)
                  Text(uiText(store.appLanguage.usesEnglish, "Geminiが商品を特定しています…", "Gemini is identifying your item…"))
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                  Spacer()
                }
                .padding(14)
                .amarinGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
              }

              if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                  .font(.caption).foregroundStyle(.red)
                  .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                  .background(.red.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
              }

              if let candidate, candidate.ready, let date = candidate.expiryDate {
                identifiedCard(candidate: candidate, date: date)
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
          }
          .onChange(of: messages.count) {
            if let last = messages.last {
              withAnimation(.snappy) { proxy.scrollTo(last.id, anchor: .bottom) }
            }
          }
        }

        composer
      }
    }
    .navigationTitle("AI Product Finder")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      guard messages.isEmpty else { return }
      messages = [ChatMessage(
        role: "assistant",
        text: store.appLanguage.usesEnglish
          ? "Let's identify your item together. Tell me its name, type, package details, and the printed expiry date."
          : "一緒に商品を特定しましょう。商品名、種類、パッケージの特徴など、分かることを教えてください。"
      )]
    }
  }

  private var agentHeader: some View {
    HStack(spacing: 13) {
      ZStack {
        Circle().fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
        Image(systemName: "sparkles").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
      }
      .frame(width: 48, height: 48)
      .shadow(color: .purple.opacity(0.28), radius: 12, y: 5)

      VStack(alignment: .leading, spacing: 3) {
        Text("GEMINI PRODUCT AGENT").font(.system(size: 11, weight: .heavy, design: .monospaced)).tracking(1)
        HStack(spacing: 5) {
          Circle().fill(.green).frame(width: 7, height: 7)
          Text(uiText(store.appLanguage.usesEnglish, "LIVE · 自然な言葉で話しかけてください", "LIVE · Speak naturally")).font(.caption).foregroundStyle(.secondary)
        }
      }
      Spacer()
      Image(systemName: "shield.checkered").foregroundStyle(.green)
    }
    .padding(.horizontal, 17).padding(.vertical, 12)
    .background(.ultraThinMaterial)
  }

  private var suggestionChips: some View {
    VStack(alignment: .leading, spacing: 9) {
      Text("QUICK REPLIES").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.1).foregroundStyle(.secondary)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(suggestions, id: \.self) { suggestion in
            Button {
              input = suggestion
              Task { await send() }
            } label: {
              Text(LocalizedStringKey(suggestion)).font(.caption.bold())
                .padding(.horizontal, 12).padding(.vertical, 9)
            }
            .buttonStyle(.plain)
            .amarinGlass(in: Capsule())
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func identifiedCard(candidate: AIService.ProductResult, date: Date) -> some View {
    VStack(alignment: .leading, spacing: 15) {
      HStack {
        Label("ITEM IDENTIFIED", systemImage: "checkmark.seal.fill")
          .font(.system(size: 10, weight: .heavy, design: .monospaced)).tracking(1)
        Spacer()
        Text("READY").font(.system(size: 9, weight: .bold, design: .monospaced))
          .padding(.horizontal, 8).padding(.vertical, 5).background(.white.opacity(0.17), in: Capsule())
      }
      VStack(alignment: .leading, spacing: 4) {
        Text(candidate.name).font(.system(size: 25, weight: .bold, design: .rounded))
        Label("\(localizedCategory(candidate.category, english: store.appLanguage.usesEnglish)) · \(date.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar.badge.checkmark")
          .font(.subheadline).opacity(0.84)
      }
      Button {
        store.add(name: candidate.name, category: candidate.category, expiryDate: date, registeredWithAi: true)
        onComplete()
      } label: {
        Label(uiText(store.appLanguage.usesEnglish, "この内容で登録", "Add this item"), systemImage: "plus.circle.fill")
          .font(.headline).frame(maxWidth: .infinity).frame(height: 48)
          .foregroundStyle(.green)
          .background(.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .foregroundStyle(.white)
    .padding(18)
    .background(LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .shadow(color: .green.opacity(0.22), radius: 18, y: 9)
  }

  private var composer: some View {
    HStack(spacing: 10) {
      TextField(uiText(store.appLanguage.usesEnglish, "例：青いパックの牛乳です", "e.g. It's milk in a blue carton"), text: $input, axis: .vertical)
        .lineLimit(1...3)
        .focused($inputFocused)
        .padding(.horizontal, 15).padding(.vertical, 12)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

      Button { Task { await send() } } label: {
        Image(systemName: "arrow.up")
          .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
          .frame(width: 44, height: 44)
          .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
      }
      .buttonStyle(.plain)
      .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
      .opacity(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending ? 0.45 : 1)
    }
    .padding(.horizontal, 14).padding(.vertical, 10)
    .background(.ultraThinMaterial)
  }

  private func send() async {
    let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    input = ""
    error = nil
    candidate = nil
    messages.append(ChatMessage(role: "user", text: text))
    sending = true
    defer { sending = false }
    do {
      let result = try await AIService.shared.identify(messages: messages, locale: store.appLanguage.apiLocale)
      messages.append(ChatMessage(role: "assistant", text: result.reply))
      candidate = result.ready ? result : nil
    } catch {
      self.error = store.appLanguage.usesEnglish ? "Gemini could not identify the item. Please try again." : error.localizedDescription
    }
  }
}

private struct ProductChatBubble: View {
  let message: ChatMessage
  let tint: Color

  var body: some View {
    HStack(alignment: .bottom, spacing: 8) {
      if message.role == "user" { Spacer(minLength: 42) }
      if message.role != "user" {
        Image(systemName: "sparkles")
          .font(.caption.bold()).foregroundStyle(.white)
          .frame(width: 28, height: 28)
          .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
      }
      Text(message.text)
        .font(.subheadline)
        .padding(.horizontal, 14).padding(.vertical, 11)
        .foregroundStyle(message.role == "user" ? .white : .primary)
        .background {
          if message.role == "user" {
            LinearGradient(colors: [tint, tint.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
          } else {
            LinearGradient(colors: [Color.primary.opacity(0.07), Color.primary.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
      if message.role != "user" { Spacer(minLength: 42) }
    }
    .frame(maxWidth: .infinity)
  }
}

struct AddFoodView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: FoodStore
  @State private var name = ""
  @State private var category = "その他"
  @State private var expiryDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
  @State private var photoItem: PhotosPickerItem?
  @State private var showLibrary = false
  @State private var showCamera = false
  @State private var imageData: Data?
  @State private var analyzing = false
  @State private var registeredWithAi = false
  @State private var error: String?
  let startWithPhotoPicker: Bool
  let startWithCamera: Bool
  let onComplete: (() -> Void)?

  init(startWithPhotoPicker: Bool = false, startWithCamera: Bool = false, onComplete: (() -> Void)? = nil) {
    self.startWithPhotoPicker = startWithPhotoPicker
    self.startWithCamera = startWithCamera
    self.onComplete = onComplete
  }

  private var categories: [String] {
    store.appLanguage.usesEnglish
      ? ["Dairy", "Drinks", "Refrigerated", "Meat & Fish", "Fruit & Vegetables", "Prepared Food", "Condiments", "Other"]
      : ["乳製品", "飲み物", "冷蔵品", "肉・魚", "野菜・果物", "お惣菜", "調味料", "その他"]
  }

  var body: some View {
    Form {
        if let imageData, let image = UIImage(data: imageData) {
          Section { Image(uiImage: image).resizable().scaledToFill().frame(height: 180).clipped().clipShape(RoundedRectangle(cornerRadius: 18)) }
        }
        if startWithPhotoPicker || startWithCamera || imageData != nil {
          Section(uiText(store.appLanguage.usesEnglish, "AIで読み取る", "Analyze with AI")) {
            Button { showCamera = true } label: { Label(uiText(store.appLanguage.usesEnglish, "写真を撮る", "Take Photo"), systemImage: "camera.fill") }
            Button { showLibrary = true } label: { Label(analyzing ? uiText(store.appLanguage.usesEnglish, "解析しています…", "Analyzing…") : uiText(store.appLanguage.usesEnglish, "アルバムから選ぶ", "Choose from Photos"), systemImage: "photo.on.rectangle") }
              .disabled(analyzing)
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
          }
        }

        Section(uiText(store.appLanguage.usesEnglish, "食品", "Food")) {
          TextField(uiText(store.appLanguage.usesEnglish, "食品名", "Food name"), text: $name)
          Picker(uiText(store.appLanguage.usesEnglish, "カテゴリー", "Category"), selection: $category) {
            ForEach(categories, id: \.self) { Text($0) }
          }
          DatePicker(uiText(store.appLanguage.usesEnglish, "賞味期限", "Expiry date"), selection: $expiryDate, displayedComponents: .date)
        }
      }
      .navigationTitle(uiText(store.appLanguage.usesEnglish, "食品を登録", "Add Food"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(uiText(store.appLanguage.usesEnglish, "キャンセル", "Cancel")) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(uiText(store.appLanguage.usesEnglish, "保存", "Save")) {
            store.add(
              name: name.trimmingCharacters(in: .whitespacesAndNewlines),
              category: category,
              expiryDate: expiryDate,
              registeredWithAi: registeredWithAi
            )
            if let onComplete { onComplete() } else { dismiss() }
          }
          .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .photosPicker(isPresented: $showLibrary, selection: $photoItem, matching: .images)
      .onChange(of: photoItem) { _, item in guard let item else { return }; Task { await analyze(item) } }
      .fullScreenCover(isPresented: $showCamera) {
        CameraPicker { data in imageData = data; Task { await analyze(data) } }
          .ignoresSafeArea()
      }
      .onAppear {
        if store.appLanguage.usesEnglish && category == "その他" { category = "Other" }
        if startWithPhotoPicker { showLibrary = true }
        if startWithCamera { showCamera = true }
      }
  }

  private func analyze(_ item: PhotosPickerItem) async {
    analyzing = true
    error = nil
    defer { analyzing = false }
    do {
      guard let data = try await item.loadTransferable(type: Data.self) else {
        throw AIError.invalidResponse
      }
      imageData = data
      let result = try await AIService.shared.analyze(imageData: data, locale: store.appLanguage.apiLocale)
      name = result.name
      category = result.category
      expiryDate = result.expiryDate
      registeredWithAi = true
    } catch {
      self.error = store.appLanguage.usesEnglish ? "AI could not analyze this image. Please try again." : error.localizedDescription
    }
  }

  private func analyze(_ data: Data) async {
    analyzing = true; error = nil; defer { analyzing = false }
    do { let result = try await AIService.shared.analyze(imageData: data, locale: store.appLanguage.apiLocale); name = result.name; category = result.category; expiryDate = result.expiryDate; registeredWithAi = true }
    catch { self.error = store.appLanguage.usesEnglish ? "AI could not analyze this image. Please try again." : error.localizedDescription }
  }
}

private struct CameraPicker: UIViewControllerRepresentable {
  @Environment(\.dismiss) private var dismiss
  let onImage: (Data) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
    picker.cameraCaptureMode = .photo
    picker.delegate = context.coordinator
    return picker
  }
  func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
  final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    let parent: CameraPicker
    init(parent: CameraPicker) { self.parent = parent }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
      if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.82) { parent.onImage(data) }
      parent.dismiss()
    }
  }
}

// MARK: - Helpers

extension View {
  @ViewBuilder
  func amarinGlass<S: Shape>(in shape: S) -> some View {
    if #available(iOS 26.0, *) {
      self.glassEffect(.regular, in: shape)
    } else {
      self
        .background(.ultraThinMaterial, in: shape)
        .overlay(shape.stroke(.primary.opacity(0.08)))
    }
  }
}

extension Color {
  static let amarinOrange = Color(red: 1.0, green: 0.37, blue: 0.20)
  static let amarinBackground = Color(uiColor: .systemGroupedBackground)
}

extension JSONDecoder {
  static var amarin: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let value = try decoder.singleValueContainer().decode(String.self)
      let withFraction = ISO8601DateFormatter()
      withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      if let date = withFraction.date(from: value) { return date }
      let plain = ISO8601DateFormatter()
      if let date = plain.date(from: value) { return date }
      for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = format
        if let date = formatter.date(from: value) { return date }
      }
      throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Unsupported date: \(value)")
    }
    return decoder
  }
}

extension JSONEncoder {
  static var amarin: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }
}

extension DateFormatter {
  static let apiDate: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()
}

private func categoryEmoji(_ category: String) -> String {
  switch category {
  case "乳製品", "Dairy": "🥛"
  case "飲み物", "Drinks", "Beverages": "🧃"
  case "冷蔵品", "Refrigerated": "🧊"
  case "野菜", "野菜・果物", "Vegetables", "Fruit & Vegetables": "🥕"
  case "お惣菜", "Prepared Food": "🍱"
  case "肉・魚", "Meat & Fish": "🐟"
  case "調味料", "Condiments", "Seasonings": "🧂"
  default: "🍽️"
  }
}

private func localizedCategory(_ category: String, english: Bool) -> String {
  if english {
    switch category {
    case "乳製品": return "Dairy"
    case "飲み物": return "Drinks"
    case "冷蔵品": return "Refrigerated"
    case "肉・魚": return "Meat & Fish"
    case "野菜", "野菜・果物": return "Fruit & Vegetables"
    case "お惣菜": return "Prepared Food"
    case "調味料": return "Condiments"
    case "その他": return "Other"
    default: return category
    }
  }
  switch category {
  case "Dairy": return "乳製品"
  case "Drinks", "Beverages": return "飲み物"
  case "Refrigerated": return "冷蔵品"
  case "Meat & Fish": return "肉・魚"
  case "Vegetables", "Fruit & Vegetables": return "野菜・果物"
  case "Prepared Food": return "お惣菜"
  case "Condiments", "Seasonings": return "調味料"
  case "Other": return "その他"
  default: return category
  }
}

private func dayLabel(_ days: Int, english: Bool) -> String {
  if days < 0 { return uiText(english, "期限切れ", "Expired") }
  if days == 0 { return uiText(english, "今日まで", "Due today") }
  return uiText(english, "あと\(days)日", "\(days)d left")
}

private func levelName(_ level: Int, english: Bool) -> String {
  let japanese = ["たね", "めばえ", "若葉", "花", "実り", "豊作", "大地", "レジェンド"]
  let englishNames = ["Seed", "Sprout", "Leaf", "Bloom", "Harvest", "Bounty", "Earth", "Legend"]
  let index = max(0, min(level - 1, japanese.count - 1))
  return english ? englishNames[index] : japanese[index]
}
