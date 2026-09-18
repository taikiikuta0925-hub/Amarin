import Flutter
import SwiftUI
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var notificationChannel: FlutterMethodChannel?
  private var liquidGlassFactory: AmarinLiquidGlassBarFactory?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let glassFactory = AmarinLiquidGlassBarFactory(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
    engineBridge.applicationRegistrar.register(
      glassFactory,
      withId: "amarin/liquid-glass-bar"
    )
    liquidGlassFactory = glassFactory

    let channel = FlutterMethodChannel(
      name: "tabekiri/notifications",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "initialize":
        result(true)
      case "requestPermission":
        ExpiryNotificationScheduler.requestPermission(result: result)
      case "syncReminders":
        guard let arguments = call.arguments as? [String: Any] else {
          result(
            FlutterError(
              code: "invalid_arguments",
              message: "通知設定を読み取れませんでした。",
              details: nil
            )
          )
          return
        }
        let enabled = arguments["enabled"] as? Bool ?? false
        let reminders = arguments["reminders"] as? [[String: Any]] ?? []
        ExpiryNotificationScheduler.sync(
          enabled: enabled,
          reminders: reminders,
          result: result
        )
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    notificationChannel = channel
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }
}

private final class AmarinLiquidGlassBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    AmarinLiquidGlassPlatformView(
      frame: frame,
      viewId: viewId,
      arguments: args,
      messenger: messenger
    )
  }
}

private final class AmarinLiquidGlassPlatformView: NSObject, FlutterPlatformView {
  private let containerView: UIView
  private let model: AmarinLiquidGlassBarModel
  private let channel: FlutterMethodChannel
  private var hostingController: UIHostingController<AnyView>?

  init(
    frame: CGRect,
    viewId: Int64,
    arguments: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    let selectedIndex =
      (arguments as? [String: Any])?["selectedIndex"] as? Int ?? 0
    containerView = UIView(frame: frame)
    channel = FlutterMethodChannel(
      name: "amarin/liquid_glass_bar_\(viewId)",
      binaryMessenger: messenger
    )
    model = AmarinLiquidGlassBarModel(selectedIndex: selectedIndex)
    super.init()

    containerView.backgroundColor = .clear
    containerView.isOpaque = false

    model.onTabSelected = { [weak channel] index in
      channel?.invokeMethod("tabSelected", arguments: index)
    }
    model.onAddFood = { [weak channel] in
      channel?.invokeMethod("addFood", arguments: nil)
    }

    let rootView: AnyView
    if #available(iOS 26.0, *) {
      rootView = AnyView(AmarinNativeLiquidGlassBar(model: model))
    } else {
      rootView = AnyView(AmarinCompatibleGlassBar(model: model))
    }

    let hostingController = UIHostingController(rootView: rootView)
    hostingController.view.frame = containerView.bounds
    hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    hostingController.view.backgroundColor = .clear
    hostingController.view.isOpaque = false
    containerView.addSubview(hostingController.view)
    self.hostingController = hostingController

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "setSelectedIndex":
        if let index = call.arguments as? Int {
          self.model.selectedIndex = index
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView {
    containerView
  }
}

private final class AmarinLiquidGlassBarModel: ObservableObject {
  @Published var selectedIndex: Int
  var onTabSelected: ((Int) -> Void)?
  var onAddFood: (() -> Void)?

  init(selectedIndex: Int) {
    self.selectedIndex = selectedIndex
  }

  func select(_ index: Int) {
    guard selectedIndex != index else { return }
    selectedIndex = index
    onTabSelected?(index)
  }
}

@available(iOS 26.0, *)
private struct AmarinNativeLiquidGlassBar: View {
  @ObservedObject var model: AmarinLiquidGlassBarModel

  private let accent = Color(red: 1.0, green: 0.37, blue: 0.20)
  private let tabs = [
    ("house.fill", "ホーム"),
    ("refrigerator.fill", "食品"),
    ("book.closed.fill", "レシピ"),
    ("star.circle.fill", "ポイント"),
  ]

  var body: some View {
    GlassEffectContainer(spacing: 10) {
      HStack(spacing: 10) {
        HStack(spacing: 2) {
          ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
            tabButton(index: index, systemImage: tab.0, title: tab.1)
          }
        }
        .padding(6)
        .glassEffect(
          .regular.tint(Color.white.opacity(0.04)),
          in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )

        Button(action: { model.onAddFood?() }) {
          Image(systemName: "plus")
            .font(.system(size: 22, weight: .bold))
            .frame(width: 58, height: 58)
        }
        .buttonStyle(.glassProminent)
        .tint(accent)
        .accessibilityLabel("食品を登録")
      }
    }
    .padding(.horizontal, 12)
    .padding(.top, 8)
    .padding(.bottom, 12)
  }

  private func tabButton(
    index: Int,
    systemImage: String,
    title: String
  ) -> some View {
    let selected = model.selectedIndex == index
    return Button(action: { model.select(index) }) {
      VStack(spacing: 3) {
        Image(systemName: systemImage)
          .font(.system(size: 19, weight: selected ? .bold : .semibold))
        Text(title)
          .font(.system(size: 9.5, weight: selected ? .bold : .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .foregroundStyle(selected ? accent : Color.primary.opacity(0.62))
      .frame(maxWidth: .infinity, minHeight: 54)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .glassEffect(
      selected ? .regular.tint(accent.opacity(0.18)).interactive() : .identity,
      in: RoundedRectangle(cornerRadius: 23, style: .continuous)
    )
    .accessibilityLabel(title)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

private struct AmarinCompatibleGlassBar: View {
  @ObservedObject var model: AmarinLiquidGlassBarModel

  private let accent = Color(red: 1.0, green: 0.37, blue: 0.20)
  private let tabs = [
    ("house.fill", "ホーム"),
    ("refrigerator.fill", "食品"),
    ("book.closed.fill", "レシピ"),
    ("star.circle.fill", "ポイント"),
  ]

  var body: some View {
    HStack(spacing: 10) {
      HStack(spacing: 2) {
        ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
          Button(action: { model.select(index) }) {
            VStack(spacing: 3) {
              Image(systemName: tab.0).font(.system(size: 19, weight: .semibold))
              Text(tab.1).font(.system(size: 9.5, weight: .semibold))
            }
            .foregroundStyle(model.selectedIndex == index ? accent : .secondary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
              model.selectedIndex == index
                ? accent.opacity(0.13)
                : Color.clear,
              in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
          }
          .buttonStyle(.plain)
        }
      }
      .padding(6)
      .background(
        .ultraThinMaterial,
        in: RoundedRectangle(cornerRadius: 32, style: .continuous)
      )

      Button(action: { model.onAddFood?() }) {
        Image(systemName: "plus")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 58, height: 58)
          .background(accent, in: Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("食品を登録")
    }
    .padding(.horizontal, 12)
    .padding(.top, 8)
    .padding(.bottom, 12)
  }
}

private enum ExpiryNotificationScheduler {
  private static let identifierPrefix = "tabekiri.expiry."
  private static let storedIdentifiersKey = "tabekiri_expiry_notification_ids"
  private static let maximumPendingReminders = 64

  static func requestPermission(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge]
    ) { granted, error in
      DispatchQueue.main.async {
        if let error {
          result(
            FlutterError(
              code: "permission_error",
              message: error.localizedDescription,
              details: nil
            )
          )
        } else {
          result(granted)
        }
      }
    }
  }

  static func sync(
    enabled: Bool,
    reminders: [[String: Any]],
    result: @escaping FlutterResult
  ) {
    let center = UNUserNotificationCenter.current()
    let defaults = UserDefaults.standard
    let oldIdentifiers = defaults.stringArray(forKey: storedIdentifiersKey) ?? []
    center.removePendingNotificationRequests(withIdentifiers: oldIdentifiers)

    guard enabled else {
      defaults.removeObject(forKey: storedIdentifiersKey)
      result(nil)
      return
    }

    let now = Date()
    let requests = reminders.prefix(maximumPendingReminders).compactMap { reminder in
      makeRequest(from: reminder, now: now)
    }
    let identifiers = requests.map(\.identifier)
    defaults.set(identifiers, forKey: storedIdentifiersKey)

    guard !requests.isEmpty else {
      result(nil)
      return
    }

    let group = DispatchGroup()
    let lock = NSLock()
    var firstError: Error?

    for request in requests {
      group.enter()
      center.add(request) { error in
        if let error {
          lock.lock()
          if firstError == nil {
            firstError = error
          }
          lock.unlock()
        }
        group.leave()
      }
    }

    group.notify(queue: .main) {
      if let firstError {
        result(
          FlutterError(
            code: "schedule_error",
            message: firstError.localizedDescription,
            details: nil
          )
        )
      } else {
        result(nil)
      }
    }
  }

  private static func makeRequest(
    from reminder: [String: Any],
    now: Date
  ) -> UNNotificationRequest? {
    guard
      let id = reminder["id"] as? String,
      let title = reminder["title"] as? String,
      let body = reminder["body"] as? String,
      let scheduledAt = reminder["scheduledAt"] as? NSNumber
    else {
      return nil
    }

    let scheduledDate = Date(
      timeIntervalSince1970: scheduledAt.doubleValue / 1_000
    )
    guard scheduledDate > now else { return nil }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.categoryIdentifier = "EXPIRY_REMINDER"
    if let itemId = reminder["itemId"] as? String {
      content.userInfo = ["itemId": itemId]
    }

    let dateComponents = Calendar.autoupdatingCurrent.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: scheduledDate
    )
    let trigger = UNCalendarNotificationTrigger(
      dateMatching: dateComponents,
      repeats: false
    )
    return UNNotificationRequest(
      identifier: identifierPrefix + id,
      content: content,
      trigger: trigger
    )
  }
}
