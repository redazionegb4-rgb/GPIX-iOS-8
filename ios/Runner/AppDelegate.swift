import Flutter
import UIKit
import Photos
import Speech

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var transcription: VoiceTranscription?
  private var gallery: PhotoGalleryBridge?
  private var instantPrivacy: InstantPrivacyBridge?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let registry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: registry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    gallery = PhotoGalleryBridge(messenger: messenger)
    transcription = VoiceTranscription(messenger: messenger)
    instantPrivacy = InstantPrivacyBridge(messenger: messenger)
    if let registrar = registry.registrar(forPlugin: "GPIXSecurePhoto") {
      registrar.register(SecurePhotoFactory(), withId: "GPIX/secure-photo")
    }
  }
}

private final class VoiceTranscription {
  private let channel: FlutterMethodChannel
  private var recognizer: SFSpeechRecognizer?
  private var task: SFSpeechRecognitionTask?
  private var timeout: DispatchWorkItem?
  private var pending: FlutterResult?
  private var session: UUID?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "GPIX/transcription", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "transcribe" else { result(FlutterMethodNotImplemented); return }
      guard let self = self, let arguments = call.arguments as? [String: String],
            let path = arguments["path"], let language = arguments["language"] else {
        result(FlutterError(code: "AUDIO", message: "Vocale non disponibile.", details: nil))
        return
      }
      self.transcribe(path: path, language: language, result: result)
    }
  }

  private func transcribe(path: String, language: String, result: @escaping FlutterResult) {
    guard pending == nil else {
      result(FlutterError(code: "BUSY", message: "È già in corso una trascrizione.", details: nil))
      return
    }
    guard #available(iOS 13.0, *),
          let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)),
          recognizer.supportsOnDeviceRecognition else {
      result(FlutterError(code: "UNAVAILABLE",
        message: "Riconoscimento vocale italiano sul dispositivo non disponibile.", details: nil))
      return
    }
    pending = result
    let identifier = UUID()
    session = identifier
    SFSpeechRecognizer.requestAuthorization { [weak self] status in
      DispatchQueue.main.async {
        guard let self = self, self.session == identifier else { return }
        guard status == .authorized else {
          self.finish(error: "Consenti il riconoscimento vocale nelle impostazioni di GPIX.")
          return
        }
        guard recognizer.isAvailable else {
          self.finish(error: "Riconoscimento vocale temporaneamente non disponibile.")
          return
        }
        self.recognizer = recognizer
        let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: path))
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        let deadline = DispatchWorkItem { [weak self] in
          self?.finish(error: "Tempo scaduto durante la trascrizione.")
        }
        self.timeout = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + 90, execute: deadline)
        self.task = recognizer.recognitionTask(with: request) { [weak self] recognition, error in
          DispatchQueue.main.async {
            guard let self = self, self.session == identifier else { return }
            if let recognition = recognition, recognition.isFinal {
              self.finish(text: recognition.bestTranscription.formattedString)
            } else if error != nil {
              self.finish(error: "Impossibile riconoscere il parlato di questo vocale.")
            }
          }
        }
      }
    }
  }

  private func finish(text: String? = nil, error: String? = nil) {
    let result = pending
    pending = nil
    session = nil
    timeout?.cancel()
    timeout = nil
    task?.cancel()
    task = nil
    recognizer = nil
    if let error = error {
      result?(FlutterError(code: "TRANSCRIPTION", message: error, details: nil))
    } else {
      result?(text)
    }
  }
}

private final class PhotoGalleryBridge {
  private let channel: FlutterMethodChannel
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "GPIX/gallery", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      if call.method == "recent" {
        let completion: (PHAuthorizationStatus) -> Void = { status in
          var allowed = status == .authorized
          if #available(iOS 14, *) { allowed = allowed || status == .limited }
          guard allowed else {
            DispatchQueue.main.async { result(FlutterError(code: "PERMISSION", message: "Consenti l’accesso alle foto oppure usa la galleria di sistema.", details: nil)) }; return
          }
          DispatchQueue.global(qos: .userInitiated).async { self.recent(result) }
        }
        if #available(iOS 14, *) {
          PHPhotoLibrary.requestAuthorization(for: .readWrite, handler: completion)
        } else {
          PHPhotoLibrary.requestAuthorization(completion)
        }
      } else if call.method == "copy", let args = call.arguments as? [String: Any], let id = args["id"] as? String {
        self.copy(id, result)
      } else { result(FlutterMethodNotImplemented) }
    }
  }
  private func recent(_ result: @escaping FlutterResult) {
    let options = PHFetchOptions(); options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]; options.fetchLimit = 100
    let assets = PHAsset.fetchAssets(with: .image, options: options)
    let imageOptions = PHImageRequestOptions(); imageOptions.isSynchronous = true; imageOptions.deliveryMode = .fastFormat; imageOptions.resizeMode = .fast; imageOptions.isNetworkAccessAllowed = false
    var photos = [[String: Any]]()
    assets.enumerateObjects { asset, _, _ in
      PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 180, height: 180), contentMode: .aspectFill, options: imageOptions) { image, _ in
        if let data = image?.jpegData(compressionQuality: 0.75) { photos.append(["id": asset.localIdentifier, "thumbnail": FlutterStandardTypedData(bytes: data)]) }
      }
    }
    DispatchQueue.main.async { result(photos) }
  }
  private func copy(_ id: String, _ result: @escaping FlutterResult) {
    guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
      result(FlutterError(code: "GALLERY", message: "Foto non disponibile", details: nil)); return
    }
    let options = PHImageRequestOptions(); options.isNetworkAccessAllowed = true; options.deliveryMode = .highQualityFormat
    PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
      guard let data = data, let image = UIImage(data: data) else { DispatchQueue.main.async {result(FlutterError(code: "GALLERY", message: "Impossibile leggere la foto", details: nil))}; return }
      DispatchQueue.global(qos: .userInitiated).async {
        let factor = min(1, 3000 / max(image.size.width, image.size.height)); let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("gpix-photo-\(UUID().uuidString).jpg")
        do { guard let encoded = normalized.jpegData(compressionQuality: 0.95) else { throw NSError(domain: "GPIX", code: 1) }; try encoded.write(to: path, options: .atomic); DispatchQueue.main.async { result(path.path) } }
        catch { DispatchQueue.main.async { result(FlutterError(code: "GALLERY", message: "Impossibile preparare la foto", details: nil)) } }
      }
    }
  }
}

// Recording/background cover complements the isolated native photo surface below.
// Secure text rendering is not a documented UIKit contract for arbitrary photos:
// validate on each supported iOS release; fail closed if its canvas is unavailable.
private final class InstantPrivacyBridge: NSObject {
  private let channel: FlutterMethodChannel
  private var sceneWindow: UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first(where: { $0.isKeyWindow })
  }
  private var secure = false
  private var cover: UIView?
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "GPIX/privacy", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      guard call.method == "secure" else { result(FlutterMethodNotImplemented); return }
      self.secure = (call.arguments as? Bool) == true
      self.updateCover()
      let screen = self.sceneWindow?.windowScene?.screen
      result(!self.secure || (screen?.isCaptured == false && SecurePhotoSurface.available()))
    }
    NotificationCenter.default.addObserver(self, selector: #selector(captureChanged), name: UIScreen.capturedDidChangeNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(sceneWillDeactivate), name: UIScene.willDeactivateNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(updateCover), name: UIScene.didActivateNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(screenshot), name: UIApplication.userDidTakeScreenshotNotification, object: nil)
  }
  @objc private func captureChanged() {
    updateCover()
    if secure && sceneWindow?.windowScene?.screen.isCaptured == true {
      channel.invokeMethod("captured", arguments: nil)
    }
  }
  @objc private func screenshot() {
    if secure { channel.invokeMethod("captured", arguments: nil) }
  }
  @objc private func sceneWillDeactivate() {
    applyCover(inactive: true)
  }
  @objc private func updateCover() {
    applyCover(inactive: sceneWindow?.windowScene?.activationState != .foregroundActive)
  }
  private func applyCover(inactive: Bool) {
    let window = sceneWindow
    let hide = secure && (inactive || window?.windowScene?.screen.isCaptured != false)
    if hide, cover == nil, let view = window?.rootViewController?.view {
      let overlay = UIView(frame: view.bounds); overlay.backgroundColor = .black
      overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      view.addSubview(overlay); cover = overlay
    } else if !hide { cover?.removeFromSuperview(); cover = nil }
  }
  deinit { NotificationCenter.default.removeObserver(self) }
}

// Keep photo bytes outside Flutter's image compositor on iOS. No private selectors,
// private class names, layer reparenting, or KVC are used. The UIKit hierarchy is
// nevertheless implementation-dependent, so absence of a secure canvas is a hard failure.
private final class SecurePhotoFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    let data = ((args as? [String: Any])?["bytes"] as? FlutterStandardTypedData)?.data
    return SecurePhotoSurface(frame: frame, data: data)
  }
}
private final class SecurePhotoSurface: NSObject, FlutterPlatformView {
  private let container: UIView
  private let field: UITextField
  private let photo = UIImageView()
  static func available() -> Bool {
    let field = UITextField(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
    field.isSecureTextEntry = true; field.text = " "; field.layoutIfNeeded()
    return field.subviews.first != nil
  }
  init(frame: CGRect, data: Data?) {
    container = UIView(frame: frame); container.backgroundColor = .black
    field = UITextField(frame: container.bounds)
    super.init()
    field.isSecureTextEntry = true; field.text = " "; field.textColor = .clear
    field.backgroundColor = .black; field.isUserInteractionEnabled = false
    field.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    container.addSubview(field); field.layoutIfNeeded()
    guard let canvas = field.subviews.first else { return }
    canvas.frame = container.bounds; canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    photo.frame = canvas.bounds; photo.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    photo.contentMode = .scaleAspectFill; photo.clipsToBounds = true; photo.backgroundColor = .black
    canvas.addSubview(photo)
    if !UIScreen.main.isCaptured, UIApplication.shared.applicationState == .active, let data = data { photo.image = UIImage(data: data) }
    NotificationCenter.default.addObserver(self, selector: #selector(hide), name: UIScreen.capturedDidChangeNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(hide), name: UIScene.willDeactivateNotification, object: nil)
  }
  @objc private func hide() { photo.image = nil }
  func view() -> UIView { container }
  deinit { photo.image = nil; NotificationCenter.default.removeObserver(self) }
}
