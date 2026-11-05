import UIKit

@MainActor final class SecurityController: StackScreen {
    let mode:String
    private var sent=false
    private let login=Design.field("Email o nome utente"),code=Design.field("Codice ricevuto"),current=Design.field("Password attuale",secure:true),password=Design.field("Nuova password",secure:true),confirm=Design.field("Conferma password",secure:true)
    init(mode:String) { self.mode=mode;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad();render() }
    private func render() {
        clear();title=mode=="verify" ? "Verifica email":mode=="forgot" ? "Recupera password":mode=="account" ? "Gestione account":"Password e sicurezza";add(Design.spacer(20))
        if mode=="account" {
            row("Dispositivi collegati",icon:"iphone") { [weak self] in self?.push(SessionsController()) }
            row("Cambia password",icon:"lock") { [weak self] in self?.push(SecurityController(mode:"password")) }
            row("Elimina account",subtitle:"Questa operazione è definitiva",icon:"trash") { [weak self] in self?.menu("Eliminare definitivamente l’account?",items:[("Continua",true,{ self?.prompt("Conferma con la tua password",secure:true) { self?.action("deleteAccount",["password":$0]) } })]) };return
        }
        if mode=="verify" { add(Design.label(session.me.flag("emailVerified") ? "La tua email è verificata.":"Conferma il tuo indirizzo email per proteggere l’account.",size:17,weight:.semibold,lines:0),inset:24);if session.me.flag("emailVerified") { return } }
        if mode=="forgot" { add(login,inset:24) }
        if sent && ["verify","forgot"].contains(mode) { code.keyboardType = .numberPad;add(code,inset:24) }
        if mode=="password" { add(current,inset:24) }
        if mode=="password" || (mode=="forgot" && sent) { add(password,inset:24);add(confirm,inset:24);section("Usa almeno 10 caratteri.") }
        add(Design.button(mode=="password" || sent ? "Conferma":"Invia codice",primary:true) { [weak self] in self?.submit() },inset:24)
    }
    private func submit() {
        guard !session.isDemo else { alert("Modalità demo","Le credenziali non sono modificate nella demo.");return }
        run {
            if self.mode=="verify" { _ = try await self.session.api("/auth/"+(self.sent ? "verification-confirm":"verification-send"),["code":self.code.text ?? ""]);if self.sent { try await self.session.sync();if self.presentingViewController != nil { self.dismiss(animated:true) } else { self.navigationController?.popViewController(animated:true) } } else { self.sent=true;self.render();self.alert("Codice inviato","Controlla la tua email, anche nello spam.") } }
            else if self.mode=="forgot" && !self.sent { _ = try await self.session.api("/auth/forgot",["login":self.login.text ?? ""]);self.sent=true;self.render();self.alert("Controlla la tua email","Se l’account esiste, riceverai un codice.") }
            else { guard let password=self.password.text,password.count>=10,password==self.confirm.text else { throw GPIXFailure.message("Le password devono coincidere e contenere almeno 10 caratteri.") };_ = try await self.session.api("/auth/"+(self.mode=="forgot" ? "reset":"change-password"),["login":self.login.text ?? "","code":self.code.text ?? "","current":self.current.text ?? "","password":password]);self.navigationController?.popViewController(animated:true) }
        }
    }
}
@MainActor final class SessionsController: StackScreen {
    override func viewDidLoad() { super.viewDidLoad();title="Dispositivi collegati";run { try await self.load() } }
    private func load() async throws {
        clear();let items=session.isDemo ? [Entity(["device":"Questo iPhone","current":true])]:try await session.api("/sessions").list("sessions")
        for item in items { row(item.text("device","Dispositivo"),subtitle:item.flag("current") ? "Questo dispositivo":"Ultimo accesso "+Domain.ago(item.number("lastSeen")),icon:"iphone") { [weak self] in guard !item.flag("current") else { return };self?.menu("Disconnettere questo dispositivo?",items:[("Disconnetti",true,{ self?.run { _ = try await self?.session.api("/sessions/revoke",["id":item.id]);try await self?.load() } })]) } }
        row("Disconnetti gli altri dispositivi",icon:"rectangle.portrait.and.arrow.right") { [weak self] in self?.run { _ = try await self?.session.api("/sessions/revoke",["others":true]);try await self?.load() } }
    }
}
@MainActor final class LibraryController: StackScreen {
    let mode:String
    init(mode:String) { self.mode=mode;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad();stateChanged() }
    override func stateChanged() {
        clear()
        if mode=="drafts" {
            title="Bozze";let drafts=(UserDefaults.standard.array(forKey:"gpix.drafts.\(session.userID)") as? [[String:Any]] ?? []).map(Entity.init)
            for draft in drafts { row(draft.text("text").isEmpty ? "Bozza":draft.text("text"),subtitle:draft.text("kind").capitalized,icon:"doc.text") { [weak self] in self?.menu("Bozza",items:[("Riprendi",false,{ let editor=PublishController(kind:draft.text("kind"));editor.restore(draft);self?.sheet(editor,full:true) }),("Elimina",true,{ var stored=UserDefaults.standard.array(forKey:"gpix.drafts.\(Session.shared.userID)") as? [[String:Any]] ?? [];stored.removeAll { $0["id"] as? String == draft.id };UserDefaults.standard.set(stored,forKey:"gpix.drafts.\(Session.shared.userID)");self?.stateChanged() })]) } }
            if drafts.isEmpty { empty("Nessuna bozza",detail:"Salva un contenuto mentre lo crei per riprenderlo più tardi.",symbol:"doc.text") };return
        }
        if mode=="archive" {
            title="Archivio";row("Istantanee",subtitle:"Scatti e visualizzazioni",icon:"camera") { [weak self] in self?.push(InstantArchiveController()) }
            section("Storie archiviate");let stories=session.posts.filter { $0.text("author")==session.userID && $0.text("kind")=="story" };for story in stories { row(story.text("text").isEmpty ? "Storia":story.text("text"),subtitle:Date(timeIntervalSince1970:story.number("created")).formatted(date:.abbreviated,time:.omitted),icon:"photo") { [weak self] in self?.present(StoryViewer(stories:[story]),animated:true) } }
            section("Post archiviati");for p in session.posts.filter({$0.text("author")==session.userID && $0.flag("archived")}) { row(p.text("text","Post"),icon:"photo") { [weak self] in self?.menu(nil,items:[("Mostra sul profilo",false,{ self?.action("archivePost",["id":p.id,"enabled":false]) }),("Apri",false,{ self?.push(PostDetailController(id:p.id)) })]) } };return
        }
        title=mode=="saved" ? "Elementi salvati":"La tua attività"
        let posts=session.posts.filter { mode=="saved" ? $0.flag("saved"):$0.strings("likes").contains(session.userID) }
        if mode=="activity" { row("Cronologia ricerche",subtitle:"\(session.history.count) ricerche",icon:"clock") { [weak self] in self?.push(SearchController()) };row("Cancella cronologia ricerche",icon:"trash") { [weak self] in self?.session.clearHistory() } }
        if posts.isEmpty { empty("Nessun contenuto",detail:mode=="saved" ? "Salva i post che vuoi ritrovare qui.":"I contenuti a cui hai messo Mi piace appariranno qui.",symbol:"bookmark") }
        add(PhotoGrid(posts:posts,parent:self))
    }
}
@MainActor final class HelpController: StackScreen {
    override func viewDidLoad() {
        super.viewDidLoad();title="Assistenza";row("Segnala un problema",icon:"exclamationmark.bubble") { [weak self] in self?.prompt("Descrivi il problema") { self?.action("report",["type":"app","reason":$0]) } }
        row("Informativa sulla privacy",icon:"hand.raised") { self.open("https://gpix.cc/privacy") };row("Termini di servizio",icon:"doc.text") { self.open("https://gpix.cc/terms") };row("Visita GPIX",icon:"globe") { self.open("https://gpix.cc") }
    }
    private func open(_ value:String) { if let url=URL(string:value) { UIApplication.shared.open(url) } }
}
