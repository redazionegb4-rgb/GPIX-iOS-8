import UIKit

@MainActor enum Design {
    static let violet = UIColor(red: 113/255, green: 69/255, blue: 232/255, alpha: 1)
    static let danger = UIColor(red: 237/255, green: 73/255, blue: 86/255, alpha: 1)
    static let muted = UIColor(red: 133/255, green: 133/255, blue: 143/255, alpha: 1)
    static let ink = UIColor { $0.userInterfaceStyle == .dark ? .white : UIColor(red: 21/255, green: 21/255, blue: 27/255, alpha: 1) }
    static let background = UIColor { $0.userInterfaceStyle == .dark ? .black : .white }
    static let soft = UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 37/255, green: 37/255, blue: 45/255, alpha: 1) : UIColor(red: 244/255, green: 244/255, blue: 247/255, alpha: 1) }
    static let line = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.18, alpha: 1) : UIColor(red: 235/255, green: 235/255, blue: 239/255, alpha: 1) }
    static func font(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        guard UITraitCollection.current.userInterfaceStyle != .dark,
              let base = UIFont(name: "Roboto-Regular", size: size) else {
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
        let descriptor = base.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: size)
    }
    static func label(_ text: String, size: CGFloat = 14, weight: UIFont.Weight = .regular, color: UIColor? = nil, lines: Int = 1) -> UILabel {
        let label = UILabel(); label.text = text; label.font = font(size, weight); label.textColor = color ?? ink; label.numberOfLines = lines; return label
    }
    static func button(_ text: String, primary: Bool = false, icon: String? = nil, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled(); config.title = text; config.baseBackgroundColor = primary ? violet : soft; config.baseForegroundColor = primary ? .white : ink
        config.background.cornerRadius = 13; config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { input in var a = input; a.font = font(14, .semibold); return a }
        if let icon = icon { config.image = UIImage(systemName: icon); config.imagePadding = 8 }
        let button = UIButton(configuration: config, primaryAction: UIAction { _ in action() }); button.accessibilityLabel = text; return button
    }
    static func icon(_ name: String, size: CGFloat = 25, color: UIColor? = nil, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system); button.setImage(Glyph.image(name, size: size) ?? UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .regular)), for: .normal)
        button.tintColor = color ?? ink; button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true; button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside); return button
    }
    static func stack(_ axis: NSLayoutConstraint.Axis = .vertical, spacing: CGFloat = 0, views: [UIView] = []) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views); stack.axis = axis; stack.spacing = spacing; return stack
    }
    static func field(_ placeholder: String, secure: Bool = false) -> UITextField {
        let field = UITextField(); field.placeholder = placeholder; field.font = font(15); field.textColor = ink; field.backgroundColor = soft; field.layer.cornerRadius = 14
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1)); field.leftViewMode = .always; field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1)); field.rightViewMode = .always
        field.isSecureTextEntry = secure; field.heightAnchor.constraint(equalToConstant: 54).isActive = true; return field
    }
    static func divider() -> UIView { let view = UIView(); view.backgroundColor = line; view.heightAnchor.constraint(equalToConstant: 0.5).isActive = true; return view }
    static func inset(_ child: UIView, _ insets: UIEdgeInsets = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)) -> UIView {
        let view = UIView(); view.addSubview(child); child.pin(to: view, insets: insets); return view
    }
    static func spacer(_ height: CGFloat) -> UIView { let v = UIView(); v.heightAnchor.constraint(equalToConstant: height).isActive = true; return v }
}

@MainActor extension UIView {
    func pin(to parent: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: insets.left), trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -insets.right), topAnchor.constraint(equalTo: parent.topAnchor, constant: insets.top), bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -insets.bottom)])
    }
    func onTap(_ work: @escaping () -> Void) { isUserInteractionEnabled = true; let recognizer = ClosureTap(work); addGestureRecognizer(recognizer) }
}
@MainActor final class ClosureTap: UITapGestureRecognizer, UIGestureRecognizerDelegate {
    private let work: () -> Void
    init(_ work: @escaping () -> Void) { self.work = work; super.init(target: nil, action: nil); delegate=self;cancelsTouchesInView=false;addTarget(self, action: #selector(run)) }
    @objc private func run() { work() }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool { var current=touch.view;while let v=current { if v is UIControl { return false };if v === view { break };current=v.superview };return true }
}

/// The navigation glyphs use the same 24-point paths as the Android design.
@MainActor enum Glyph {
    static func image(_ name: String, size: CGFloat) -> UIImage? {
        let known = ["home", "home.fill", "heart", "heart.fill", "send", "send.fill", "camera", "save", "save.fill", "search", "reel", "reel.fill", "more"]
        guard known.contains(name) else { return nil }
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { context in
            context.cgContext.scaleBy(x: size/24, y: size/24)
            let p = UIBezierPath(); p.lineWidth = 1.85; p.lineCapStyle = .round; p.lineJoinStyle = .round
            switch name.replacingOccurrences(of: ".fill", with: "") {
            case "home":
                p.move(to: CGPoint(x:3,y:10)); for v in [(12.0,2.8),(21,10),(21,21),(15.4,21),(15.4,14),(8.6,14),(8.6,21),(3,21)] { p.addLine(to:CGPoint(x:v.0,y:v.1)) }; p.close()
            case "heart":
                p.move(to:CGPoint(x:12,y:21)); p.addCurve(to:CGPoint(x:2.3,y:8), controlPoint1:CGPoint(x:8,y:18),controlPoint2:CGPoint(x:2.3,y:13.5)); p.addCurve(to:CGPoint(x:12,y:6),controlPoint1:CGPoint(x:2.3,y:2.5),controlPoint2:CGPoint(x:9,y:1.8)); p.addCurve(to:CGPoint(x:21.7,y:8),controlPoint1:CGPoint(x:15,y:1.8),controlPoint2:CGPoint(x:21.7,y:2.5)); p.addCurve(to:CGPoint(x:12,y:21),controlPoint1:CGPoint(x:21.7,y:13.5),controlPoint2:CGPoint(x:16,y:18)); p.close()
            case "send":
                p.move(to:CGPoint(x:3,y:9.2)); for v in [(10.2,13.5),(14.4,21),(21.5,2.5),(3,9.2)] { p.addLine(to:CGPoint(x:v.0,y:v.1)) }; p.move(to:CGPoint(x:10.2,y:13.5));p.addLine(to:CGPoint(x:20.9,y:3.2))
            case "camera":
                p.append(UIBezierPath(roundedRect:CGRect(x:2,y:6,width:20,height:15),cornerRadius:3));p.move(to:CGPoint(x:7,y:6));p.addLine(to:CGPoint(x:9,y:3));p.addLine(to:CGPoint(x:15,y:3));p.addLine(to:CGPoint(x:17,y:6));p.append(UIBezierPath(ovalIn:CGRect(x:7.5,y:9,width:9,height:9)))
            case "save": p.move(to:CGPoint(x:5,y:3)); for v in [(19.0,3.0),(19,22),(12,16),(5,22)] { p.addLine(to:CGPoint(x:v.0,y:v.1)) };p.close()
            case "search": p.append(UIBezierPath(ovalIn:CGRect(x:3,y:3,width:14,height:14)));p.move(to:CGPoint(x:15.2,y:15.2));p.addLine(to:CGPoint(x:22,y:22))
            case "reel": p.append(UIBezierPath(roundedRect:CGRect(x:3,y:3,width:18,height:18),cornerRadius:4));p.move(to:CGPoint(x:10,y:8));p.addLine(to:CGPoint(x:16,y:12));p.addLine(to:CGPoint(x:10,y:16));p.close()
            default: for x in [5.0,12,19] { p.append(UIBezierPath(ovalIn:CGRect(x:x-1,y:11,width:2,height:2))) }
            }
            UIColor.black.setStroke(); UIColor.black.setFill()
            if name.hasSuffix(".fill") { p.usesEvenOddFillRule=true;p.fill() } else { p.stroke() }
        }.withRenderingMode(.alwaysTemplate)
    }
}

@MainActor class Screen: UIViewController {
    let session = Session.shared
    var observation: NSObjectProtocol?
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = Design.background; navigationItem.backButtonTitle = ""
        observation = NotificationCenter.default.addObserver(forName: Session.changed, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.stateChanged() } }
    }
    deinit { if let observation = observation { NotificationCenter.default.removeObserver(observation) } }
    func stateChanged() { }
    func run(_ operation: @escaping @MainActor () async throws -> Void) {
        Task { @MainActor [weak self] in do { try await operation() } catch is CancellationError { } catch { self?.showError(error) } }
    }
    func showError(_ error: Error) { alert("Operazione non riuscita", error.localizedDescription) }
    func alert(_ title: String, _ message: String) { present(MessageDialog(title:title,message:message),animated:true) }
    func action(_ name: String, _ payload: [String:Any] = [:]) { run { try await self.session.action(name,payload) } }
    func push(_ controller: UIViewController) { navigationController?.pushViewController(controller, animated: true) }
    func sheet(_ controller: UIViewController, full: Bool = false) {
        let nav = UINavigationController(rootViewController:controller); nav.modalPresentationStyle = full ? .fullScreen : .pageSheet
        if !full { nav.sheetPresentationController?.detents = [.large()]; nav.sheetPresentationController?.prefersGrabberVisible = true }
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem:.close,primaryAction:UIAction { [weak nav] _ in nav?.dismiss(animated:true) }); present(nav,animated:true)
    }
    func menu(_ title: String? = nil, items: [(String, Bool, () -> Void)], source: UIView? = nil) {
        let controller=ActionMenu(title:title,items:items)
        if let sheet=controller.sheetPresentationController { sheet.detents=[.custom(identifier:.init("gpixMenu")) { context in min(context.maximumDetentValue,CGFloat(items.count)*56+110+(title == nil ? 0:35)) }];sheet.prefersGrabberVisible=true;sheet.preferredCornerRadius=26 }
        present(controller,animated:true)
    }
    func prompt(_ title: String, value: String = "", secure: Bool = false, completion: @escaping (String) -> Void) {
        let a=UIAlertController(title:title,message:nil,preferredStyle:.alert);a.addTextField { $0.text=value;$0.isSecureTextEntry=secure };a.addAction(UIAlertAction(title:"Annulla",style:.cancel));a.addAction(UIAlertAction(title:"Salva",style:.default) { _ in completion(a.textFields?.first?.text ?? "") });present(a,animated:true)
    }
}
@MainActor class StackScreen: Screen, UIScrollViewDelegate {
    let scroll = UIScrollView()
    let content = Design.stack(spacing:0)
    private var topConstraint:NSLayoutConstraint!
    private var bottomConstraint:NSLayoutConstraint!
    override func viewDidLoad() {
        super.viewDidLoad(); scroll.alwaysBounceVertical = true;scroll.delegate=self;view.addSubview(scroll);scroll.translatesAutoresizingMaskIntoConstraints=false
        topConstraint=scroll.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor);bottomConstraint=scroll.bottomAnchor.constraint(equalTo:view.bottomAnchor)
        NSLayoutConstraint.activate([topConstraint,scroll.leadingAnchor.constraint(equalTo:view.leadingAnchor),scroll.trailingAnchor.constraint(equalTo:view.trailingAnchor),bottomConstraint])
        scroll.addSubview(content);content.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([content.leadingAnchor.constraint(equalTo:scroll.contentLayoutGuide.leadingAnchor),content.trailingAnchor.constraint(equalTo:scroll.contentLayoutGuide.trailingAnchor),content.topAnchor.constraint(equalTo:scroll.contentLayoutGuide.topAnchor),content.bottomAnchor.constraint(equalTo:scroll.contentLayoutGuide.bottomAnchor),content.widthAnchor.constraint(equalTo:scroll.frameLayoutGuide.widthAnchor)])
        scroll.contentInset.bottom = 100
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === scroll else { return }
        home?.trackScroll(scrollView, from: self)
    }
    func attachHeader(_ header:UIView) {
        view.addSubview(header);header.translatesAutoresizingMaskIntoConstraints=false;topConstraint.isActive=false
        NSLayoutConstraint.activate([header.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),header.leadingAnchor.constraint(equalTo:view.leadingAnchor),header.trailingAnchor.constraint(equalTo:view.trailingAnchor),scroll.topAnchor.constraint(equalTo:header.bottomAnchor)])
    }
    func attachFooter(_ footer:UIView) {
        view.addSubview(footer);footer.translatesAutoresizingMaskIntoConstraints=false;bottomConstraint.isActive=false
        NSLayoutConstraint.activate([footer.bottomAnchor.constraint(equalTo:view.keyboardLayoutGuide.topAnchor),footer.leadingAnchor.constraint(equalTo:view.leadingAnchor),footer.trailingAnchor.constraint(equalTo:view.trailingAnchor),scroll.bottomAnchor.constraint(equalTo:footer.topAnchor)])
    }
    func clear() { for child in content.arrangedSubviews { content.removeArrangedSubview(child);child.removeFromSuperview() } }
    func add(_ view: UIView, inset: CGFloat = 0) { content.addArrangedSubview(inset == 0 ? view : Design.inset(view,UIEdgeInsets(top:8,left:inset,bottom:8,right:inset))) }
    func empty(_ title: String, detail: String = "", symbol: String = "sparkles") {
        let image=UIImageView(image:UIImage(systemName:symbol));image.tintColor=Design.muted;image.contentMode = .scaleAspectFit;image.heightAnchor.constraint(equalToConstant:64).isActive=true
        let label=Design.label(title,size:22,weight:.bold,lines:0);label.textAlignment = .center
        let description=Design.label(detail,size:14,color:Design.muted,lines:0);description.textAlignment = .center
        add(Design.stack(spacing:18,views:[Design.spacer(70),image,label,description]),inset:28)
    }
    func section(_ text: String) { add(Design.label(text,size:13,weight:.semibold,color:Design.muted),inset:20) }
    func row(_ title: String, subtitle: String = "", icon: String? = nil, accessory: UIView? = nil, action: (() -> Void)? = nil) {
        let labels=Design.stack(spacing:5,views:[Design.label(title,size:16),Design.label(subtitle,size:12,color:Design.muted,lines:0)]);if subtitle.isEmpty { labels.arrangedSubviews.last?.isHidden=true }
        let h=Design.stack(.horizontal,spacing:14);h.alignment = .center
        if let icon=icon { let image=UIImageView(image:Glyph.image(icon,size:23) ?? UIImage(systemName:icon));image.tintColor=Design.ink;image.contentMode = .scaleAspectFit;image.widthAnchor.constraint(equalToConstant:25).isActive=true;h.addArrangedSubview(image) }
        h.addArrangedSubview(labels)
        if let accessory=accessory { h.addArrangedSubview(accessory) } else if action != nil { let i=UIImageView(image:UIImage(systemName:"chevron.right"));i.tintColor=Design.muted;i.setContentHuggingPriority(.required,for:.horizontal);h.addArrangedSubview(i) }
        let wrap=Design.inset(h,UIEdgeInsets(top:17,left:20,bottom:17,right:20));if let action=action { wrap.onTap(action) };add(wrap)
    }
}
