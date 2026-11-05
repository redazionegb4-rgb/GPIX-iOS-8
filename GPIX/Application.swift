import UIKit

@main @MainActor final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var observer: NSObjectProtocol?
    private var showingHome: Bool?
    func application(_ application:UIApplication,didFinishLaunchingWithOptions launchOptions:[UIApplication.LaunchOptionsKey:Any]? = nil) -> Bool {
        let nav=UINavigationBarAppearance();nav.configureWithOpaqueBackground();nav.backgroundColor=Design.background;nav.shadowColor = .clear;nav.titleTextAttributes=[.font:Design.font(18,.bold),.foregroundColor:Design.ink]
        UINavigationBar.appearance().standardAppearance=nav;UINavigationBar.appearance().scrollEdgeAppearance=nav;UINavigationBar.appearance().tintColor=Design.ink
        let w=UIWindow(frame:UIScreen.main.bounds);window=w;let launch=UIViewController();launch.view.backgroundColor=Design.background
        let logo=UIImageView(image:UIImage(named:"GpixLogo"));logo.contentMode = .scaleAspectFit;launch.view.addSubview(logo);logo.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([logo.centerXAnchor.constraint(equalTo:launch.view.centerXAnchor),logo.centerYAnchor.constraint(equalTo:launch.view.centerYAnchor),logo.widthAnchor.constraint(equalToConstant:150),logo.heightAnchor.constraint(equalToConstant:100)])
        w.rootViewController=launch;w.makeKeyAndVisible();applyAppearance()
        routeIfNeeded()
        observer=NotificationCenter.default.addObserver(forName:Session.changed,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.routeIfNeeded() } }
        Task { do { try await Session.shared.sync() } catch { }; self.routeIfNeeded();Session.shared.startPolling() }
        return true
    }
    func applicationDidBecomeActive(_ application:UIApplication) { Task { await Session.shared.presence(true) } }
    func applicationWillResignActive(_ application:UIApplication) { Task { await Session.shared.presence(false) } }
    func applyAppearance() { let mode=UserDefaults.standard.string(forKey:"gpix.appearance") ?? "system";window?.overrideUserInterfaceStyle=mode == "dark" ? .dark:mode == "light" ? .light:.unspecified }
    private func routeIfNeeded() {
        let home = Session.shared.signedIn
        guard let window = window, showingHome != home else { return }
        showingHome = home
        window.rootViewController = home
            ? HomeController()
            : UINavigationController(rootViewController: WelcomeController())
    }
}
@MainActor final class WelcomeController: StackScreen {
    override func viewDidLoad() {
        super.viewDidLoad();navigationController?.setNavigationBarHidden(true,animated:false)
        let logo=UIImageView(image:UIImage(named:"GpixLogo"));logo.contentMode = .scaleAspectFit;logo.heightAnchor.constraint(equalToConstant:110).isActive=true
        let heading=Design.label("Il tuo mondo,\nconnesso.",size:37,weight:.bold,lines:2);heading.textAlignment = .center
        let sub=Design.label("Condividi i tuoi momenti.\nRitrova le persone che contano.",size:16,color:Design.muted,lines:2);sub.textAlignment = .center
        add(Design.spacer(85));add(logo,inset:65);add(Design.spacer(30));add(heading,inset:24);add(Design.spacer(18));add(sub,inset:24);add(Design.spacer(55))
        add(Design.button("Accedi",primary:true) { [weak self] in self?.push(AuthController(register:false)) },inset:26)
        add(Design.button("Crea un nuovo account") { [weak self] in self?.push(AuthController(register:true)) },inset:26)
        add(Design.button("Esplora la demo",icon:"sparkles") { [weak self] in self?.session.loadDemo() },inset:26)
        let footer=Design.label("Connettiti. Condividi. Sii te stesso.",size:12,color:Design.muted);footer.textAlignment = .center;add(footer,inset:25)
    }
    override func viewWillAppear(_ animated:Bool) { super.viewWillAppear(animated);navigationController?.setNavigationBarHidden(true,animated:animated) }
}
@MainActor final class AuthController: StackScreen {
    let register:Bool
    let server=Design.field("Indirizzo HTTPS del server")
    let name=Design.field("Nome completo"),username=Design.field("Nome utente"),email=Design.field("Email"),password=Design.field("Password",secure:true),confirm=Design.field("Conferma password",secure:true)
    var submit:UIButton!
    init(register:Bool) { self.register=register;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad();navigationController?.setNavigationBarHidden(false,animated:true);title=register ? "Crea account":"Accedi";add(Design.spacer(25))
        add(Design.label(register ? "Entra nel tuo mondo." : "Bentornato su GPIX.",size:28,weight:.bold,lines:2),inset:24)
        add(Design.label(register ? "Inizia a condividere i tuoi momenti." : "Accedi per ritrovare amici e conversazioni.",size:14,color:Design.muted,lines:2),inset:24);add(Design.spacer(22))
        if register { add(name,inset:24);add(username,inset:24);email.keyboardType = .emailAddress;add(email,inset:24) } else { email.placeholder="Email o nome utente";add(email,inset:24) }
        for f in [username,email] { f.autocapitalizationType = .none;f.autocorrectionType = .no }
        server.text=Domain.server.absoluteString;server.keyboardType = .URL;server.autocapitalizationType = .none;add(server,inset:24)
        password.textContentType=register ? .newPassword:.password;email.textContentType=register ? .emailAddress:.username;add(password,inset:24);if register { add(confirm,inset:24) }
        submit=Design.button(register ? "Crea account":"Accedi",primary:true) { [weak self] in self?.authenticate() };add(submit,inset:24)
        if !register { add(Design.button("Password dimenticata?") { [weak self] in self?.push(SecurityController(mode:"forgot")) },inset:24) }
        scroll.keyboardDismissMode = .interactive
    }
    private func authenticate() {
        guard let login=email.text,!login.isEmpty,let pass=password.text,!pass.isEmpty else { alert("Completa i campi","Inserisci le tue credenziali.");return }
        if register && (pass != confirm.text || (username.text ?? "").isEmpty || (name.text ?? "").isEmpty) { alert("Controlla i dati","Inserisci nome e username e conferma la password.");return }
        guard let address=server.text,let url=URL(string:address),url.scheme=="https",url.host != nil else { alert("Server non valido","Inserisci un indirizzo HTTPS.");return };UserDefaults.standard.set(address.trimmingCharacters(in:CharacterSet(charactersIn:"/")),forKey:"gpix.server")
        submit.isEnabled=false
        run { defer { self.submit.isEnabled=true };try await self.session.signIn(mode:self.register ? "register":"login",values:self.register ? ["name":self.name.text ?? "","username":self.username.text ?? "","email":login,"password":pass]:["login":login,"password":pass]) }
    }
}

@MainActor final class HomeController: UIViewController, UINavigationControllerDelegate {
    private let bar=UIView(),buttons=Design.stack(.horizontal)
    private var width:NSLayoutConstraint!,height:NSLayoutConstraint!
    private var controllers:[UINavigationController]=[]
    private var selected = 0
    private var isCompact = false
    private var previousScroll: CGFloat?
    private var scrollTravel: CGFloat = 0
    private var incomingObservation:NSObjectProtocol?
    private var incomingID=""
    override func viewDidLoad() {
        super.viewDidLoad();view.backgroundColor=Design.background
        let roots:[UIViewController]=[FeedController(),ReelsController(),InboxController(),SearchController(),ProfileController(id:Session.shared.userID)]
        controllers=roots.map { let nav=UINavigationController(rootViewController:$0);nav.delegate=self;return nav }
        bar.backgroundColor=Design.background.withAlphaComponent(0.97);bar.layer.cornerRadius=40;bar.layer.borderWidth=0.6;bar.layer.borderColor=Design.line.cgColor;bar.layer.shadowColor=UIColor.black.cgColor;bar.layer.shadowOpacity=0.08;bar.layer.shadowRadius=28;bar.layer.shadowOffset=CGSize(width:0,height:5)
        view.addSubview(bar);bar.translatesAutoresizingMaskIntoConstraints=false;width=bar.widthAnchor.constraint(equalTo:view.widthAnchor,constant:-40);height=bar.heightAnchor.constraint(equalToConstant:64)
        NSLayoutConstraint.activate([width,height,bar.centerXAnchor.constraint(equalTo:view.centerXAnchor),bar.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-10)])
        bar.addSubview(buttons);buttons.pin(to:bar,insets:UIEdgeInsets(top:5,left:6,bottom:5,right:6));buttons.distribution = .fillEqually;buttons.alignment = .center
        for i in 0..<5 { let b=Design.icon(["home","reel","send","search","person.crop.circle"][i]) { [weak self] in self?.select(i) };b.accessibilityLabel=["Home","Reel","Messaggi","Cerca","Profilo"][i];buttons.addArrangedSubview(b) }
        if let button=buttons.arrangedSubviews.last as? UIButton { button.setImage(nil,for:.normal);let avatar=Avatar(Session.shared.me,size:28);avatar.isUserInteractionEnabled=false;button.addSubview(avatar);avatar.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([avatar.centerXAnchor.constraint(equalTo:button.centerXAnchor),avatar.centerYAnchor.constraint(equalTo:button.centerYAnchor)]) }
        incomingObservation=NotificationCenter.default.addObserver(forName:Session.changed,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.checkIncoming() } }
        select(0)
        if Session.shared.me.values["emailVerified"] != nil && !Session.shared.me.flag("emailVerified") && !Session.shared.isDemo { DispatchQueue.main.async { self.present(UINavigationController(rootViewController:SecurityController(mode:"verify")),animated:true) } }
    }
    private func select(_ index:Int) {
        guard controllers.indices.contains(index) else { return }
        let nav = controllers[index]
        if selected == index && nav.parent === self {
            nav.popToRootViewController(animated: true)
        }
        selected = index
        if nav.parent == nil {
            addChild(nav)
            view.insertSubview(nav.view, belowSubview: bar)
            nav.view.pin(to: view)
            nav.didMove(toParent: self)
        }
        previousScroll = nil
        scrollTravel = 0
        if index == 0 { (controllers[0].viewControllers.first as? FeedController)?.scrollToTop() }
        for (i,nav) in controllers.enumerated() { nav.viewIfLoaded?.isHidden = i != index }
        for (i,button) in buttons.arrangedSubviews.enumerated() { button.backgroundColor=i == index ? Design.soft:.clear;button.layer.cornerRadius=25;if i<4,let b=button as? UIButton { let normal=["home","reel","send","search"][i];b.setImage(Glyph.image(normal+(i==index && i<3 ? ".fill":""),size:25),for:.normal) } }
        bar.isHidden=controllers[index].viewControllers.count>1;compact(false)
    }
    private func checkIncoming() {
        guard presentedViewController==nil,let call=Session.shared.state.list("calls").first(where:{$0.text("callee")==Session.shared.userID && $0.text("status")=="ringing"}),incomingID != call.id else { return }
        incomingID=call.id
        let alert=UIAlertController(title:Session.shared.person(call.text("caller")).text("name"),message:call.flag("video") ? "Videochiamata in arrivo":"Chiamata in arrivo",preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"Rifiuta",style:.destructive) { _ in Task { try? await Session.shared.action("callEnd",["id":call.id]) } })
        alert.addAction(UIAlertAction(title:"Rispondi",style:.default) { [weak self] _ in let nav=UINavigationController(rootViewController:CallController(callID:call.id));nav.modalPresentationStyle = .fullScreen;self?.present(nav,animated:true) })
        present(alert,animated:true)
    }
    deinit { if let observation=incomingObservation { NotificationCenter.default.removeObserver(observation) } }
    func trackScroll(_ scroll: UIScrollView, from screen: UIViewController) {
        guard selected != 1, controllers.indices.contains(selected), controllers[selected].topViewController === screen,
              scroll.isDragging || scroll.isDecelerating else { return }
        let offset = scroll.contentOffset.y + scroll.adjustedContentInset.top
        let delta = offset - (previousScroll ?? offset)
        previousScroll = offset
        if offset <= 8 { compact(false); scrollTravel = 0; return }
        guard abs(delta) >= 0.1 else { return }
        if scrollTravel.sign != delta.sign { scrollTravel = 0 }
        scrollTravel += delta
        if scrollTravel > 20 { compact(true) }
        if scrollTravel < -12 { compact(false) }
    }

    func compact(_ compact: Bool) {
        guard compact != isCompact else { return }
        isCompact = compact
        width.constant = compact ? max(260, min(600, view.bounds.width - 96)) - view.bounds.width : -40
        height.constant = compact ? 54 : 64
        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.24,
                       delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            self.view.layoutIfNeeded()
        }
    }
    func navigationController(_ navigationController:UINavigationController,willShow viewController:UIViewController,animated:Bool) { if controllers.indices.contains(selected),navigationController === controllers[selected] { bar.isHidden=navigationController.viewControllers.count>1 } }
}
@MainActor extension UIViewController {
    var home:HomeController? { var p: UIViewController?=self;while let c=p { if let h=c as? HomeController { return h };p=c.parent };return nil }
}
