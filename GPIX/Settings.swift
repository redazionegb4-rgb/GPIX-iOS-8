import UIKit

@MainActor final class SettingsController: StackScreen {
    override func viewDidLoad() { super.viewDidLoad();title="Impostazioni e attività";render() }
    override func stateChanged() { render() }
    private func render() {
        let offset=scroll.contentOffset;clear();section("Il tuo account")
        row(session.me.text("name"),subtitle:"@"+session.me.text("username"),accessory:Avatar(session.me,size:44)) { [weak self] in self?.push(EditProfileController()) }
        row("Dispositivi collegati",icon:"laptopcomputer.and.iphone") { [weak self] in self?.push(SessionsController()) }
        row("Modifica profilo",icon:"person.crop.circle") { [weak self] in self?.push(EditProfileController()) }
        row("Password e sicurezza",icon:"lock") { [weak self] in self?.push(SecurityController(mode:"password")) }
        row("Verifica email",icon:"envelope.badge") { [weak self] in self?.push(SecurityController(mode:"verify")) }
        add(Design.divider());section("I tuoi contenuti")
        row("Bozze",icon:"doc.text") { [weak self] in self?.push(LibraryController(mode:"drafts")) }
        row("Elementi salvati",icon:"save") { [weak self] in self?.push(LibraryController(mode:"saved")) }
        row("Archivio",icon:"clock.arrow.circlepath") { [weak self] in self?.push(LibraryController(mode:"archive")) }
        row("Note",icon:"text.bubble") { [weak self] in self?.sheet(NoteController(owner:self?.session.userID ?? "")) }
        add(Design.divider());section("Chi può vedere i tuoi contenuti")
        toggle("Account privato",icon:"lock",value:session.me.flag("private")) { [weak self] in self?.action("profile",["private":$0]) }
        row("Amici più stretti",icon:"star") { [weak self] in self?.push(PeopleController(mode:.close)) }
        row("Account bloccati",icon:"hand.raised") { [weak self] in self?.push(PeopleController(mode:.blocked)) }
        row("Controlli della privacy",icon:"checkmark.shield") { [weak self] in self?.push(PrivacyController(mode:"general")) }
        row("Messaggi e risposte alle storie",icon:"bubble.left.and.bubble.right") { [weak self] in self?.push(PrivacyController(mode:"messages")) }
        row("Richieste di seguirti",icon:"person.badge.plus") { [weak self] in self?.push(FollowRequestsController()) }
        add(Design.divider());section("La tua app")
        toggle("Bolla delle istantanee",icon:"camera",value:!session.preferences.flag("hideInstantBubble")) { [weak self] in self?.action("preferences",["key":"hideInstantBubble","value":!$0]) }
        row("Aspetto",subtitle:UserDefaults.standard.string(forKey:"gpix.appearance") ?? "Sistema",icon:"circle.lefthalf.filled") { [weak self] in self?.menu("Aspetto",items:[("Sistema","system"),("Chiaro","light"),("Scuro","dark")].map { option in (option.0,false,{ UserDefaults.standard.set(option.1,forKey:"gpix.appearance");(UIApplication.shared.delegate as? AppDelegate)?.applyAppearance();self?.render() }) }) }
        row("Notifiche",icon:"bell") { [weak self] in self?.push(PrivacyController(mode:"notifications")) }
        row("La tua attività",icon:"chart.bar") { [weak self] in self?.push(LibraryController(mode:"activity")) }
        add(Design.divider());section("Persone e assistenza")
        row("Cerca persone",icon:"search") { [weak self] in self?.push(PeopleController()) }
        row("Invita amici",icon:"person.2") { [weak self] in guard let self=self else { return };let share=UIActivityViewController(activityItems:["Ti aspetto su GPIX! https://gpix.cc"],applicationActivities:nil);share.popoverPresentationController?.sourceView=self.view;self.present(share,animated:true) }
        row("Assistenza",icon:"questionmark.circle") { [weak self] in self?.push(HelpController()) }
        row("Gestione account",icon:"person.crop.circle.badge.gearshape") { [weak self] in self?.push(SecurityController(mode:"account")) }
        row("Esci",icon:"rectangle.portrait.and.arrow.right") { [weak self] in self?.menu("Uscire da GPIX?",items:[("Esci",true,{ self?.run { await self?.session.logout() } })]) }
        let footer=Design.label("GPIX · 3.0.0 (59)",size:11,color:Design.muted);footer.textAlignment = .center;add(footer,inset:24);scroll.setContentOffset(offset,animated:false)
    }
    private func toggle(_ title:String,icon:String,value:Bool,changed:@escaping(Bool)->Void) { let control=UISwitch();control.onTintColor=Design.violet;control.isOn=value;control.addAction(UIAction { [weak control] _ in changed(control?.isOn ?? false) },for:.valueChanged);row(title,icon:icon,accessory:control) }
}
@MainActor final class PrivacyController: StackScreen {
    let mode:String
    init(mode:String) { self.mode=mode;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad();render() }
    override func stateChanged() { render() }
    private func render() {
        clear()
        switch mode {
        case "messages":
            title="Messaggi e risposte alle storie";section("In che modo le persone possono contattarti")
            choice("Richieste di messaggi",key:"allowMessages");choice("Risposte alle storie",key:"storyReplies");add(Design.divider());section("Chi può vedere che sei online")
            toggle("Mostra stato di attività",key:"activityStatus");let read=UISwitch();read.onTintColor=Design.violet;read.isOn=session.me.enabled("readReceipts");read.addAction(UIAction { [weak self,weak read] _ in self?.action("profile",["readReceipts":read?.isOn ?? true]) },for:.valueChanged);row("Mostra conferme di lettura",accessory:read)
            add(Design.divider());section("Cosa vedi nei messaggi");toggle("Protezione dalle immagini di nudo",key:"imageProtection");toggle("Anteprime",key:"messagePreviews")
        case "notifications":
            title="Notifiche";toggle("Consenti notifiche",key:"pushEnabled")
            section("Le notifiche push richiedono l’autorizzazione di iOS.");row("Impostazioni iPhone",icon:"gear") { if let url=URL(string:UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
        default:
            title="Privacy";choice("Chi può menzionarti",key:"allowMentions");choice("Chi può inviarti messaggi",key:"allowMessages");choice("Risposte alle storie",key:"storyReplies");for pair in [("hiddenStories","Nascondi le storie a"),("muted","Account silenziati"),("restricted","Account con restrizioni")] { row(pair.1,subtitle:"\(session.preferences.strings(pair.0).count) persone",icon:"person.crop.circle") { [weak self] in self?.push(PrivacyPeopleController(key:pair.0,title:pair.1)) } }
        }
    }
    private func toggle(_ text:String,key:String) { let toggle=UISwitch();toggle.onTintColor=Design.violet;toggle.isOn=session.preferences.enabled(key);toggle.addAction(UIAction { [weak self,weak toggle] _ in self?.action("preferences",["key":key,"value":toggle?.isOn ?? true]) },for:.valueChanged);row(text,accessory:toggle) }
    private func choice(_ text:String,key:String) { let value=session.preferences.text(key,"all");row(text,subtitle:["all":"Tutti","following":"Persone che segui","none":"Nessuno"][value] ?? value) { [weak self] in self?.menu(text,items:[("Tutti","all"),("Persone che segui","following"),("Nessuno","none")].map { option in (option.0,false,{ self?.action("preferences",["key":key,"value":option.1]) }) }) } }
}
@MainActor final class EditProfileController: StackScreen {
    private let name=Design.field("Nome"),username=Design.field("Nome utente"),bio=Design.field("Biografia"),pronouns=Design.field("Pronomi")
    private var picker:MediaPicker?,avatarID=""
    override func viewDidLoad() {
        super.viewDidLoad();title="Modifica profilo";navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Salva",style:.done,target:self,action:#selector(save));let me=session.me;name.text=me.text("name");username.text=me.text("username");bio.text=me.text("bio");pronouns.text=me.text("pronouns");username.autocapitalizationType = .none;username.autocorrectionType = .no
        let avatar=Avatar(me,size:90);let center=Design.stack(views:[avatar]);center.alignment = .center;add(center,inset:22)
        add(Design.button("Cambia foto",icon:"camera") { [weak self] in guard let self=self else { return };self.picker=MediaPicker(host:self,video:false,camera:false) { [weak self] data,mime in self?.run { guard let self=self else { return };let media=try await self.session.upload(data,mime:mime);self.avatarID=media.text("id");try await self.session.action("profile",["avatar":self.avatarID]) } };self.picker?.present() },inset:24)
        for pair in [("Nome",name),("Nome utente",username),("Biografia",bio),("Pronomi",pronouns)] { section(pair.0);add(pair.1,inset:20) }
        row("Riordina griglia",icon:"square.grid.3x3") { [weak self] in self?.push(GridOrderController()) }
        row("Collegamenti",icon:"link") { [weak self] in self?.push(LinksController()) }
        row("Genere",subtitle:me.text("gender","Non specificato"),icon:"person") { [weak self] in self?.menu("Genere",items:["Uomo","Donna","Non binario","Preferisco non specificarlo"].map { value in (value,false,{ self?.action("profile",["gender":value]) }) }) }
    }
    @objc private func save() { run { var patch:[String:Any]=["name":self.name.text ?? "","username":self.username.text ?? "","bio":self.bio.text ?? "","pronouns":self.pronouns.text ?? ""];if !self.avatarID.isEmpty { patch["avatar"]=self.avatarID };try await self.session.action("profile",patch);self.navigationController?.popViewController(animated:true) } }
}
@MainActor final class LinksController: StackScreen {
    override func viewDidLoad() { super.viewDidLoad();title="Collegamenti";stateChanged() }
    override func stateChanged() {
        clear();for (i,link) in session.me.list("links").enumerated() { row(link.text("title",link.text("type")),subtitle:link.text("url"),icon:"link") { [weak self] in self?.menu(nil,items:[("Apri profilo",false,{ if let url=URL(string:link.text("url")) { UIApplication.shared.open(url) } }),("Elimina collegamento",true,{ guard let self=self else { return };var links=self.session.me.list("links");links.remove(at:i);self.action("profileLinks",["links":links.map(\.values)]) })]) } }
        row("Aggiungi collegamento",subtitle:"Social, WhatsApp e sito web",icon:"plus.circle") { [weak self] in self?.push(AddLinkController()) }
    }
}
@MainActor final class AddLinkController: StackScreen {
    private var type="instagram"
    private let value=Design.field("Username o ID profilo"),label=Design.field("Nome da mostrare (facoltativo)")
    override func viewDidLoad() { super.viewDidLoad();title="Aggiungi collegamento";navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Aggiungi",style:.done,target:self,action:#selector(save));render() }
    private func render() {
        clear();section("Scegli il social")
        let choices=[("instagram","Instagram"),("facebook","Facebook"),("threads","Threads"),("whatsapp","WhatsApp"),("telegram","Telegram"),("tiktok","TikTok"),("youtube","YouTube"),("x","X"),("website","Sito web")]
        for start in stride(from:0,to:choices.count,by:3) { let row=Design.stack(.horizontal,spacing:7);row.distribution = .fillEqually;for pair in choices[start..<min(start+3,choices.count)] { row.addArrangedSubview(Design.button(pair.1,primary:type==pair.0) { [weak self] in self?.type=pair.0;self?.render() }) };add(row,inset:16) }
        value.placeholder=type=="website" ? "https://esempio.it":type=="whatsapp" ? "+39 333 1234567":"Username o ID profilo";value.keyboardType=type=="whatsapp" ? .phonePad:type=="website" ? .URL:.default;value.autocapitalizationType = .none;value.autocorrectionType = .no
        add(value,inset:20);add(label,inset:20);add(Design.label(type=="website" ? "Il sito si aprirà nel browser.":"Inserisci il profilo o il numero: non serve incollare una pagina web.",size:13,color:Design.muted,lines:0),inset:20)
    }
    @objc private func save() { guard let url=Domain.socialURL(type:type,value:value.text ?? ""),!((value.text ?? "").isEmpty) else { alert("Collegamento non valido","Controlla il profilo o il numero inserito.");return };let item=Entity(["type":type,"value":type=="website" ? url.absoluteString:(value.text ?? ""),"title":(label.text ?? "").isEmpty ? (value.text ?? ""):label.text!,"url":url.absoluteString]);run { try await self.session.action("profileLinks",["links":(self.session.me.list("links")+[item]).map(\.values)]);self.navigationController?.popViewController(animated:true) } }
}
