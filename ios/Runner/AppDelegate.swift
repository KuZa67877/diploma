import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let exportChannel = "medi_ai/export_share"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: exportChannel,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterError(code: "unavailable", message: "App delegate missing", details: nil))
          return
        }

        switch call.method {
        case "shareText":
          guard
            let args = call.arguments as? [String: Any],
            let text = args["text"] as? String,
            !text.isEmpty
          else {
            result(FlutterError(code: "invalid_args", message: "Text is required", details: nil))
            return
          }
          let subject = args["subject"] as? String
          self.presentShareSheet(items: [text], subject: subject, result: result)

        case "shareFile":
          guard
            let args = call.arguments as? [String: Any],
            let path = args["path"] as? String,
            !path.isEmpty
          else {
            result(FlutterError(code: "invalid_args", message: "Path is required", details: nil))
            return
          }
          var items: [Any] = []
          if let text = (args["text"] as? String), !text.isEmpty {
            items.append(text)
          }
          items.append(URL(fileURLWithPath: path))
          let subject = args["subject"] as? String
          self.presentShareSheet(items: items, subject: subject, result: result)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func presentShareSheet(
    items: [Any],
    subject: String?,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.main.async {
      guard let root = self.topViewController() else {
        result(
          FlutterError(code: "unavailable", message: "No view controller available", details: nil)
        )
        return
      }

      let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
      if let subject, !subject.isEmpty {
        activity.setValue(subject, forKey: "subject")
      }

      if let popover = activity.popoverPresentationController {
        popover.sourceView = root.view
        popover.sourceRect = CGRect(
          x: root.view.bounds.midX,
          y: root.view.bounds.midY,
          width: 0,
          height: 0
        )
        popover.permittedArrowDirections = []
      }

      root.present(activity, animated: true) {
        result(nil)
      }
    }
  }

  private func topViewController(
    from controller: UIViewController? = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.windows.first(where: \.isKeyWindow) }
      .first?
      .rootViewController
  ) -> UIViewController? {
    if let navigation = controller as? UINavigationController {
      return topViewController(from: navigation.visibleViewController)
    }
    if let tab = controller as? UITabBarController {
      return topViewController(from: tab.selectedViewController)
    }
    if let presented = controller?.presentedViewController {
      return topViewController(from: presented)
    }
    return controller
  }
}
