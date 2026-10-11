import Flutter
import UIKit
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let notificationChannel = FlutterMethodChannel(
      name: "com.tradepulse.stocksimulator/notifications",
      binaryMessenger: controller.binaryMessenger
    )

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    notificationChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "areNotificationsEnabled":
        if #available(iOS 10.0, *) {
          UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
              let enabled = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
              result(enabled)
            }
          }
        } else {
          let enabled = UIApplication.shared.currentUserNotificationSettings?.types.isEmpty == false
          result(enabled)
        }

      case "requestNotificationPermission":
        if #available(iOS 10.0, *) {
          UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
              result(granted)
            }
          }
        } else {
          let settings = UIUserNotificationSettings(types: [.alert, .sound, .badge], categories: nil)
          UIApplication.shared.registerUserNotificationSettings(settings)
          result(true)
        }

      case "showNotification":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments must be a map", details: nil))
          return
        }
        let title = args["title"] as? String ?? "Trade X"
        let body = args["body"] as? String ?? ""
        let details = args["details"] as? String
        let id = args["id"] as? Int ?? 1001

        if #available(iOS 10.0, *) {
          let content = UNMutableNotificationContent()
          content.title = title
          if let details = details, !details.isEmpty {
            content.body = "\(body)\n\n\(details)"
          } else {
            content.body = body
          }
          content.sound = .default

          let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
          let request = UNNotificationRequest(identifier: "tradex_\(id)", content: content, trigger: trigger)

          UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
              if let error = error {
                result(FlutterError(code: "NOTIFICATION_ERROR", message: error.localizedDescription, details: nil))
              } else {
                result(true)
              }
            }
          }
        } else {
          let notification = UILocalNotification()
          notification.alertTitle = title
          notification.alertBody = details != nil ? "\(body)\n\n\(details!)" : body
          notification.fireDate = Date().addingTimeInterval(1)
          notification.soundName = UILocalNotificationDefaultSoundName
          UIApplication.shared.scheduleLocalNotification(notification)
          result(true)
        }

      case "scheduleHourlyNotification":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments must be a map", details: nil))
          return
        }
        let title = args["title"] as? String ?? "Trade X — Hourly Update"
        let body = args["body"] as? String ?? ""
        let details = args["details"] as? String
        let intervalMinutes = args["intervalMinutes"] as? Int ?? 60

        let timeInterval = max(60.0, Double(intervalMinutes * 60))

        if #available(iOS 10.0, *) {
          let content = UNMutableNotificationContent()
          content.title = title
          if let details = details, !details.isEmpty {
            content.body = "\(body)\n\n\(details)"
          } else {
            content.body = body
          }
          content.sound = .default

          let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: true)
          let request = UNNotificationRequest(identifier: "tradex_hourly_notification", content: content, trigger: trigger)

          UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
              if let error = error {
                result(FlutterError(code: "NOTIFICATION_ERROR", message: error.localizedDescription, details: nil))
              } else {
                result(true)
              }
            }
          }
        } else {
          let notification = UILocalNotification()
          notification.alertTitle = title
          notification.alertBody = details != nil ? "\(body)\n\n\(details!)" : body
          notification.repeatInterval = .hour
          notification.fireDate = Date().addingTimeInterval(timeInterval)
          notification.soundName = UILocalNotificationDefaultSoundName
          UIApplication.shared.scheduleLocalNotification(notification)
          result(true)
        }

      case "cancelNotifications":
        if #available(iOS 10.0, *) {
          UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
          UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        } else {
          UIApplication.shared.cancelAllLocalNotifications()
        }
        result(true)

      case "openUrl":
        guard let args = call.arguments as? [String: Any],
              let urlString = args["url"] as? String,
              let url = URL(string: urlString) else {
          result(FlutterError(code: "INVALID_URL", message: "Invalid or missing URL", details: nil))
          return
        }
        if UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url, options: [:]) { success in
            result(success)
          }
        } else {
          result(FlutterError(code: "CANNOT_OPEN_URL", message: "Cannot open URL", details: nil))
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    })

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle foreground notification presentation
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
}
