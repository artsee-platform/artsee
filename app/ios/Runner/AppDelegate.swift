import Flutter
import TIMPush
import UIKit
import tencent_cloud_chat_push

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, TIMPushDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  @objc func businessID() -> Int32 {
    TencentCloudChatPushFlutterModal.shared.businessID()
  }

  // Kept for compatibility with the TIMPush 8.7 delegate spelling.
  @objc func offlinePushCertificateID() -> Int32 {
    TencentCloudChatPushFlutterModal.shared.offlinePushCertificateID()
  }

  @objc func applicationGroupID() -> String {
    TencentCloudChatPushFlutterModal.shared.applicationGroupID()
  }

  @objc func onRemoteNotificationReceived(_ notice: String?) -> Bool {
    TencentCloudChatPushPlugin.shared.tryNotifyDartOnNotificationClickEvent(notice)
    return true
  }
}
