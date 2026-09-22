import Flutter
import UIKit
import PDFKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var capsuleChannel: FlutterMethodChannel?
  private let groupID = "group.com.trailcapsule.trailCapsule"
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TravelCapsuleNative")!
    let channel = FlutterMethodChannel(name: "com.trailcapsule.app/native", binaryMessenger: registrar.messenger())
    capsuleChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      let args = call.arguments as? [String: Any] ?? [:]
      do {
        switch call.method {
        case "protectStorage":
          guard let path = args["path"] as? String else { throw CapsuleError.invalidPath }
          var url = URL(fileURLWithPath: path)
          var values = URLResourceValues(); values.isExcludedFromBackup = true
          try url.setResourceValues(values)
          try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: path)
          result(nil)
        case "readInbox":
          guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.groupID) else {
            result(FlutterError(code: "APP_GROUP", message: "分享扩展尚未配置 App Group 签名", details: nil)); return
          }
          let dir = root.appendingPathComponent("inbox", isDirectory: true)
          try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
          let jobs = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }.map { url -> [String: Any] in
            var job = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
            if let file = job["file"] as? String {
              guard file == URL(fileURLWithPath: file).lastPathComponent else { throw CapsuleError.invalidPath }
              job["path"] = dir.appendingPathComponent(file).path
            }
            return job
          }
          result(jobs)
        case "ackInbox":
          guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.groupID) else { throw CapsuleError.invalidPath }
          let dir = root.appendingPathComponent("inbox", isDirectory: true)
          for id in args["ids"] as? [String] ?? [] {
            guard UUID(uuidString: id) != nil else { continue }
            let manifest = dir.appendingPathComponent("\(id).json")
            if let data = try? Data(contentsOf: manifest), let job = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let file = job["file"] as? String, file == URL(fileURLWithPath: file).lastPathComponent {
              try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
            }
            try? FileManager.default.removeItem(at: manifest)
          }
          result(nil)
        case "openPdf":
          guard let path = args["path"] as? String, path.hasPrefix(NSHomeDirectory()+"/"), let doc = PDFDocument(url: URL(fileURLWithPath: path)), !doc.isLocked else {
            result(FlutterError(code: "PDF", message: "无法打开 PDF，文件可能损坏或受密码保护", details: nil)); return
          }
          let page = CapsulePDFController(document: doc, title: args["title"] as? String ?? "PDF")
          guard let root = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).first(where: { $0.isKeyWindow })?.rootViewController else { throw CapsuleError.invalidPath }
          var presenter = root
          while let presented = presenter.presentedViewController { presenter = presented }
          presenter.present(UINavigationController(rootViewController: page), animated: true)
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      } catch { result(FlutterError(code: "STORAGE", message: "本地资料操作失败：\(error.localizedDescription)", details: nil)) }
    }
  }
}
enum CapsuleError: Error { case invalidPath }
final class CapsulePDFController: UIViewController {
  private let document: PDFDocument
  init(document: PDFDocument, title: String) { self.document = document; super.init(nibName: nil, bundle: nil); self.title = title }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override func viewDidLoad() {
    super.viewDidLoad()
    let pdf = PDFView(frame: view.bounds); pdf.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    pdf.document = document; pdf.autoScales = true; pdf.displayMode = .singlePageContinuous
    view.addSubview(pdf)
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
  }
  @objc private func close() { dismiss(animated: true) }
}
