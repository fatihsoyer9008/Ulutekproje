import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var documentsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    documentsChannel = FlutterMethodChannel(
      name: "com.example.fis_uygulamasi/documents",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    documentsChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "shareFile" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self = self else {
        result(FlutterError(code: "share_unavailable", message: "Paylaşım ekranı açılamadı.", details: nil))
        return
      }
      self.shareFile(call, result: result)
    }
  }

  private func shareFile(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let sourcePath = arguments["sourcePath"] as? String,
      let fileName = arguments["fileName"] as? String
    else {
      result(FlutterError(code: "invalid_arguments", message: "Paylaşım bilgileri eksik.", details: nil))
      return
    }

    let fileURL = URL(fileURLWithPath: sourcePath)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      result(FlutterError(code: "file_not_found", message: "Paylaşılacak dosya bulunamadı.", details: nil))
      return
    }
    guard let presenter = topViewController() else {
      result(FlutterError(code: "share_unavailable", message: "Paylaşım ekranı açılamadı.", details: nil))
      return
    }

    let controller = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
    controller.popoverPresentationController?.sourceView = presenter.view
    controller.popoverPresentationController?.sourceRect = CGRect(
      x: presenter.view.bounds.midX,
      y: presenter.view.bounds.midY,
      width: 0,
      height: 0
    )
    controller.completionWithItemsHandler = { _, completed, _, error in
      if let error {
        result(FlutterError(code: "share_failed", message: error.localizedDescription, details: nil))
      } else if completed {
        result(fileName)
      } else {
        result(FlutterError(code: "share_cancelled", message: "Paylaşım iptal edildi.", details: nil))
      }
    }
    presenter.present(controller, animated: true)
  }

  private func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    var controller = scene?.windows.first { $0.isKeyWindow }?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}
