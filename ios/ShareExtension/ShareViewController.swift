import UIKit
import UniformTypeIdentifiers

/// The extension saves independently. It never tries to launch the containing app.
final class ShareViewController: UIViewController {
  private let groupID = "group.com.trailcapsule.trailCapsule"
  private let status = UILabel()
  private let save = UIButton(type: .system)
  private var started = false
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor(red: 0.97, green: 0.965, blue: 0.94, alpha: 1)
    let title = UILabel(); title.text = "收进旅途胶囊"; title.font = .boldSystemFont(ofSize: 25)
    status.text = "保存到本地收件箱，稍后在应用内归档。"; status.numberOfLines = 0
    save.setTitle("保存到收件箱", for: .normal); save.titleLabel?.font = .boldSystemFont(ofSize: 18)
    save.addTarget(self, action: #selector(begin), for: .touchUpInside)
    let cancel = UIButton(type: .system); cancel.setTitle("关闭", for: .normal); cancel.addTarget(self, action: #selector(close), for: .touchUpInside)
    let stack = UIStackView(arrangedSubviews: [title, status, save, cancel]); stack.axis = .vertical; stack.spacing = 24; stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28), stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
  }
  @objc private func close() { extensionContext?.completeRequest(returningItems: nil) }
  @objc private func begin() {
    guard !started else { return }; started = true; save.isEnabled = false; status.text = "正在保存，请稍候…"
    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
    guard providers.count <= 10, !providers.isEmpty else { finish("请选择 1–10 份图片、PDF、链接或文字。"); return }
    guard var root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else { finish("无法访问收件箱，请检查 App Group 签名配置。"); return }
    do {
      var values = URLResourceValues(); values.isExcludedFromBackup = true; try root.setResourceValues(values)
      let dir = root.appendingPathComponent("inbox", isDirectory: true)
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: dir.path)
      process(providers, index: 0, directory: dir, saved: 0)
    } catch { finish("保存失败：\(error.localizedDescription)") }
  }
  private func process(_ providers: [NSItemProvider], index: Int, directory: URL, saved: Int) {
    if index == providers.count { finish("已保存 \(saved) 份资料。打开旅途胶囊即可整理，离线也能查看。"); return }
    let provider = providers[index]
    if let type = provider.registeredTypeIdentifiers.first(where: { identifier in guard let t = UTType(identifier) else { return false }; return t.conforms(to: .pdf) || t.conforms(to: .image) }) {
      provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, error in
        guard let self = self else { return }
        do {
          guard let url = url, error == nil else { throw ShareError.invalidFile }
          let ext = UTType(type)?.preferredFilenameExtension ?? url.pathExtension.lowercased()
          guard ["pdf","jpg","jpeg","png","webp","heic","heif"].contains(ext) else { throw ShareError.invalidFile }
          let id = UUID().uuidString; let file = "\(id).\(ext)"; let target = directory.appendingPathComponent(file)
          let temporary = directory.appendingPathComponent("\(id).part")
          do {
            guard let input = InputStream(url: url), let output = OutputStream(url: temporary, append: false) else { throw ShareError.invalidFile }
            input.open(); output.open(); defer { input.close(); output.close() }
            var buffer = [UInt8](repeating: 0, count: 65536); var total = 0
            while true {
              let n = input.read(&buffer, maxLength: buffer.count)
              if n < 0 { throw ShareError.invalidFile }; if n == 0 { break }
              total += n; if total > 50*1024*1024 { throw ShareError.tooLarge }
              try buffer.withUnsafeBufferPointer { ptr in
                var written = 0
                while written < n { let count = output.write(ptr.baseAddress!.advanced(by: written), maxLength: n-written); if count <= 0 { throw ShareError.invalidFile }; written += count }
              }
            }
            guard total > 0 else { throw ShareError.invalidFile }
            output.close()
            try FileManager.default.moveItem(at: temporary, to: target)
            var name = provider.suggestedName ?? url.lastPathComponent
            if URL(fileURLWithPath: name).pathExtension.isEmpty { name += ".\(ext)" }
            try self.write(["id":id,"file":file,"name":name], id: id, directory: directory)
          } catch { try? FileManager.default.removeItem(at: temporary); try? FileManager.default.removeItem(at: target); throw error }
          self.process(providers, index:index+1,directory:directory,saved:saved+1)
        } catch { self.finish("已保存 \(saved) 份；此附件无法保存（格式、空间或 50 MB 限制）。请关闭后重试未保存的内容。") }
      }
    } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) || provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
      let type = provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) ? UTType.url.identifier : UTType.plainText.identifier
      provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] value, error in
        guard let self = self else { return }
        do {
          let text = (value as? URL)?.absoluteString ?? (value as? String) ?? ""
          guard error == nil, !text.isEmpty, text.count <= 100000 else { throw ShareError.invalidFile }
          let id = UUID().uuidString
          try self.write(["id":id,"text":text,"name":provider.suggestedName ?? "分享的文字"],id:id,directory:directory)
          self.process(providers,index:index+1,directory:directory,saved:saved+1)
        } catch { self.finish("已保存 \(saved) 份；文字无法保存，请重试。") }
      }
    } else { finish("已保存 \(saved) 份；不支持该类型，请选择图片、PDF、链接或文字。") }
  }
  private func write(_ job:[String:Any],id:String,directory:URL) throws {
    let data = try JSONSerialization.data(withJSONObject:job)
    try data.write(to:directory.appendingPathComponent("\(id).json"),options:.atomic)
  }
  private func finish(_ message:String) { DispatchQueue.main.async { self.status.text=message;self.save.isHidden=true } }
}
private enum ShareError:Error { case invalidFile,tooLarge }
