import SwiftUI
@MainActor
struct SettingsView: View {
    @EnvironmentObject var store: GpixStore
    @State private var query = ""
    @State private var logout = false
    @State private var note = false
    private func visible(_ title: String) -> Bool {
        query.isEmpty || title.localizedCaseInsensitiveContains(query)
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 11) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.secondary)
                    TextField("Cerca", text: $query).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.secondary) } }
                }
                .padding(15).background(Color(uiColor: .secondarySystemBackground), in: Capsule()).padding(.horizontal,16).padding(.top,12).padding(.bottom,20)
                accountSection
                contentSection
                privacySection
                appSection
                peopleSection
                accessSection
            }
            .padding(.bottom,30)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Impostazioni e attività").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $note) { NoteComposer() }
        .confirmationDialog("Vuoi uscire da GPIX?", isPresented: $logout, titleVisibility: .visible) {
            Button("Esci", role: .destructive) { Task { await store.logout() } }
            Button("Annulla", role: .cancel) {}
        }
    }
    private var accountSection: some View {
        settingSection("Il tuo account", matches: "Dispositivi collegati Modifica profilo Password e sicurezza Verifica email") {
            link("Dispositivi collegati", "laptopcomputer.and.iphone") { SessionView() }
            link("Modifica profilo", "person.crop.circle") { EditProfileView() }
            link("Password e sicurezza", "lock.shield") { SecurityView(mode: "change-password") }
            link("Verifica email", "envelope.badge") { SecurityView(mode: "verify") }
        }
    }
    private var contentSection: some View {
        settingSection("I tuoi contenuti", matches: "Bozze Salvati Archivio Note Riordina griglia") {
            link("Bozze", "doc.text") { DraftsView() }
            link("Salvati", "bookmark") { PostCollection(title: "Salvati", mode: "saved") }
            link("Archivio", "archivebox") { ArchiveMenu() }
            if visible("Note") { Button { note = true } label: { SettingsRow(title: "Note", icon: "text.bubble") } }
            link("Riordina griglia", "square.grid.3x3") { GridOrderView() }
        }
    }
    private var privacySection: some View {
        settingSection("Privacy e interazioni", matches: "Privacy dell’account Amici più stretti Utenti bloccati Gestisci le interazioni Messaggi e risposte alle storie Richieste di seguirti") {
            link("Privacy dell’account", "lock", value: store.me.b("private") ? "Privato" : "Pubblico") { AccountPrivacyView() }
            link("Amici più stretti", "star.circle", value: "\(store.state.ids("closeFriends").count)") { ManagePeopleView(title: "Amici più stretti", key: "closeFriends") }
            link("Utenti bloccati", "nosign", value: "\(store.state.ids("blocks").count)") { ManagePeopleView(title: "Utenti bloccati", key: "blocks") }
            link("Gestisci le interazioni", "shield", subtitle: "Storie, messaggi, menzioni e account silenziati.") { InteractionSettingsView() }
            link("Messaggi e risposte alle storie", "paperplane") { MessagePrivacyView() }
            link("Richieste di seguirti", "person.badge.plus", value: "\(store.state.ids("requests").count)") { RequestsView() }
        }
    }
    private var appSection: some View {
        settingSection("App e notifiche", matches: "Bolla delle istantanee Aspetto Notifiche push Attività ricevuta Autorizzazioni del dispositivo") {
            link("Bolla delle istantanee", "square.stack.3d.up") { InstantBubbleSettingsView() }
            link("Aspetto", "moon", value: store.appearance == "dark" ? "Scuro" : store.appearance == "light" ? "Chiaro" : "Dispositivo") { AppearanceSettingsView() }
            link("Notifiche push", "bell") { NativeNotificationSettingsView() }
            link("Attività ricevuta", "heart") { ActivityView() }
            if visible("Autorizzazioni del dispositivo") {
                Button { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } label: { SettingsRow(title: "Autorizzazioni del dispositivo", icon: "iphone") }
            }
        }
    }
    private var peopleSection: some View {
        settingSection("Persone e assistenza", matches: "Trova persone Invita amici Aiuto Centro sulla privacy") {
            link("Trova persone", "magnifyingglass") { SearchView() }
            if visible("Invita amici") {
                ShareLink(item: URL(string: "https://gpix.cc/?profile=\(store.me.s("username"))")!) { SettingsRow(title: "Invita amici", icon: "square.and.arrow.up") }
            }
            link("Aiuto", "questionmark.circle") { NativeHelpView() }
            if visible("Centro sulla privacy") { Link(destination: URL(string: "https://gpix.cc/privacy")!) { SettingsRow(title: "Centro sulla privacy", icon: "hand.raised") } }
        }
    }
    private var accessSection: some View {
        settingSection("Accesso", matches: "Gestisci accesso e account Esci") {
            link("Gestisci accesso e account", "person.crop.circle.badge.checkmark") { AccountView() }
            if visible("Esci") { Button { logout = true } label: { SettingsRow(title: "Esci", icon: "rectangle.portrait.and.arrow.right", destructive: true) } }
        }
    }
    @ViewBuilder private func link<Destination: View>(_ title: String, _ icon: String, value: String = "", subtitle: String = "", @ViewBuilder destination: () -> Destination) -> some View {
        if visible(title) { NavigationLink(destination: destination) { SettingsRow(title: title, icon: icon, value: value, subtitle: subtitle) } }
    }
    @ViewBuilder private func settingSection<Content: View>(_ title: String, matches: String, @ViewBuilder content: () -> Content) -> some View {
        if query.isEmpty || matches.localizedCaseInsensitiveContains(query) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size:14,weight:.semibold)).foregroundStyle(Color.secondary).padding(.horizontal,18).padding(.top,22).padding(.bottom,8)
                content()
            }
            .padding(.bottom,16)
            Rectangle().fill(Color.primary.opacity(0.045)).frame(height:7)
        }
    }
}
struct SettingsRow: View {
    let title: String
    let icon: String
    var value = ""
    var subtitle = ""
    var destructive = false
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName:icon).font(.system(size:23,weight:.regular)).frame(width:29)
            VStack(alignment:.leading,spacing:4) {
                Text(title).font(.system(size:16))
                if !subtitle.isEmpty { Text(subtitle).font(.system(size:12)).foregroundStyle(Color.secondary) }
            }
            Spacer(minLength:8)
            if !value.isEmpty { Text(value).font(.system(size:14)).foregroundStyle(Color.secondary) }
            Image(systemName:"chevron.right").font(.system(size:14,weight:.medium)).foregroundStyle(Color.secondary)
        }
        .foregroundStyle(destructive ? Color.red : Color.primary)
        .padding(.horizontal,18).padding(.vertical,15).frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())
    }
}
@MainActor struct AccountPrivacyView: View {
    @EnvironmentObject var store:GpixStore
    var body:some View {
        Form {
            Toggle("Account privato",isOn:Binding(get:{ store.me.b("private") },set:{ store.perform("profile",["private":$0]) }))
            Text("Con un account privato approvi tu le richieste di seguirti. Foto del profilo e contatori rimangono visibili.").font(.subheadline).foregroundStyle(Color.secondary)
        }.navigationTitle("Privacy dell’account").navigationBarTitleDisplayMode(.inline)
    }
}
@MainActor struct InteractionSettingsView: View {
    var body:some View {
        List {
            NavigationLink { ManagePeopleView(title:"Nascondi la storia a",key:"hiddenStories") } label: { Label("Storie nascoste",systemImage:"eye.slash") }
            NavigationLink { ManagePeopleView(title:"Account silenziati",key:"muted") } label: { Label("Account silenziati",systemImage:"bell.slash") }
            NavigationLink { ManagePeopleView(title:"Con restrizioni",key:"restricted") } label: { Label("Con restrizioni",systemImage:"person.crop.circle.badge.exclamationmark") }
            NavigationLink { PermissionChoice(title:"Richieste di messaggi",key:"allowMessages") } label: { Label("Richieste di messaggi",systemImage:"paperplane") }
            NavigationLink { PermissionChoice(title:"Tag e menzioni",key:"allowMentions") } label: { Label("Tag e menzioni",systemImage:"at") }
            NavigationLink { PermissionChoice(title:"Risposte alle storie",key:"storyReplies") } label: { Label("Risposte alle storie",systemImage:"bubble.right") }
        }.navigationTitle("Gestisci le interazioni").navigationBarTitleDisplayMode(.inline)
    }
}
@MainActor struct InstantBubbleSettingsView: View {
    @EnvironmentObject var store:GpixStore
    var body:some View {
        Form { Toggle("Mostra bolla delle istantanee",isOn:Binding(get:{ !store.preferences.b("hideInstantBubble") },set:{ store.preference("hideInstantBubble",!$0) })); Text("Puoi aprire e creare istantanee dalla sezione dedicata anche quando la bolla è nascosta.").font(.subheadline).foregroundStyle(Color.secondary) }.navigationTitle("Bolla delle istantanee").navigationBarTitleDisplayMode(.inline)
    }
}
@MainActor struct AppearanceSettingsView: View {
    @EnvironmentObject var store:GpixStore
    var body:some View {
        List {
            ForEach(["system","light","dark"],id:\.self) { mode in
                Button { store.appearance=mode; UserDefaults.standard.set(mode,forKey:"gpix.native.appearance") } label: {
                    HStack { Label(mode == "dark" ? "Scuro" : mode == "light" ? "Chiaro" : "Dispositivo",systemImage:mode == "dark" ? "moon" : mode == "light" ? "sun.max" : "iphone"); Spacer(); if store.appearance == mode { Image(systemName:"checkmark").foregroundStyle(gpixPurple) } }.foregroundStyle(Color.primary)
                }
            }
        }.navigationTitle("Aspetto")
    }
}
@MainActor struct NativeNotificationSettingsView: View {
    @EnvironmentObject var store:GpixStore
    var body:some View {
        Form {
            Section { Toggle("Ricevi notifiche",isOn:Binding(get:{ store.preferences["pushEnabled"] as? Bool ?? true },set:{ store.preference("pushEnabled",$0) })) } footer: { Text("Messaggi, richieste, commenti e chiamate in arrivo.") }
            Section { Text("Le notifiche dentro l’app sono disponibili. Le push a schermo chiuso richiedono la configurazione Firebase ancora da integrare.").font(.subheadline) }
        }.navigationTitle("Notifiche push")
    }
}
struct NativeHelpView: View {
    var body:some View {
        List {
            Section("Profilo") { Label("Apri Profilo → Modifica e premi Fine per salvare.",systemImage:"person.crop.circle") }
            Section("Bozze") { Label("Durante la creazione di un post o reel premi Salva come bozza. Ritrovi i contenuti in Impostazioni → Bozze.",systemImage:"doc.text") }
            Section("Note") { Label("Nei Messaggi tocca La tua nota. Massimo 60 caratteri, durata 24 ore.",systemImage:"text.bubble") }
            Section("Istantanee") { Label("Apri la bolla nei Messaggi per vedere quelle degli amici e crearne una. Le tue sono raccolte nell’Archivio.",systemImage:"square.stack.3d.up") }
            Link("Contatta l’assistenza",destination:URL(string:"https://gpix.cc/support")!)
        }.navigationTitle("Aiuto")
    }
}

@MainActor
struct MessagePrivacyView:View{
    @EnvironmentObject var store:GpixStore
    var body:some View{
        List{
            Section("In che modo le persone possono contattarti"){
                NavigationLink("Richieste di messaggi"){
                    PermissionChoice(title:"Richieste di messaggi",key:"allowMessages")
                }
                NavigationLink("Risposte alle storie"){
                    PermissionChoice(title:"Risposte alle storie",key:"storyReplies")
                }
            }
            Section("Chi può vedere che sei online"){
                Toggle("Mostra stato di attività",isOn:Binding(get:{
                    store.preferences["activityStatus"] as? Bool ?? true
                }
                ,set:{
                    store.preference("activityStatus",$0)
                }
                ))
                Toggle("Mostra conferme di lettura",isOn:Binding(get:{
                    (store.me["readReceipts"] as? Bool) ?? (store.me.n("readReceipts",1)==1)
                }
                ,set:{
                    store.perform("profile",["readReceipts":$0])
                }
                ))
            }
            Section("Cosa vedi nei messaggi"){
                Toggle("Protezione dalle immagini sensibili",isOn:Binding(get:{
                    store.preferences["imageProtection"] as? Bool ?? true
                }
                ,set:{
                    store.preference("imageProtection",$0)
                }
                ))
                Text("Le foto temporanee si aprono su richiesta. Questa preferenza non costituisce un rilevatore automatico di nudità.").font(.caption).foregroundStyle(.secondary)
                Toggle("Anteprime",isOn:Binding(get:{
                    store.preferences["messagePreviews"] as? Bool ?? true
                }
                ,set:{
                    store.preference("messagePreviews",$0)
                }
                ))
            }
        }
        .navigationTitle("Messaggi e risposte alle storie").navigationBarTitleDisplayMode(.inline)
    }
}
@MainActor
struct PermissionChoice:View{
    @EnvironmentObject var store:GpixStore
    let title:String,key:String
    var body:some View{
        List{
            ForEach(["all","following","none"],id:\.self){
                value in Button{
                    store.preference(key,value)
                } label: {
                    HStack{
                        Text(value=="all" ? "Tutti":value=="following" ? "Persone che segui":"Nessuno")
                        Spacer()
                        if store.preferences.s(key,"all")==value{
                            Image(systemName:"checkmark").foregroundStyle(gpixPurple)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle(title)
    }
}
@MainActor
struct ManagePeopleView:View{
    @EnvironmentObject var store:GpixStore
    let title:String,key:String
    @State private var query=""
    var selected:[String]{
        ["blocks","closeFriends"].contains(key) ? store.state.ids(key):store.preferences.ids(key)
    }
    var body:some View{
        List{
            ForEach(store.users.filter{
                $0.id != store.myID && (query.isEmpty || ($0.s("name")+$0.s("username")).localizedCaseInsensitiveContains(query))
            }
            ,id:\.id){
                p in Button{
                    toggle(p.id)
                } label: {
                    HStack{
                        PersonLine(person:p)
                        Image(systemName:selected.contains(p.id) ? "checkmark.circle.fill":"circle").foregroundStyle(selected.contains(p.id) ? gpixPurple:Color.secondary)
                    }
                }
            }
        }
        .searchable(text:$query).navigationTitle(title)
    }
    func toggle(_ id:String){
        let enabled = !selected.contains(id)
        if key=="blocks" || key=="closeFriends"{
            store.perform(key=="blocks" ? "block":"closeFriend",["user":id,"enabled":enabled])
        }
        else{
            store.preference(key,enabled ? selected+[id]:selected.filter{
                $0 != id
            }
            )
        }
    }
}
@MainActor
struct AccountView:View{
    @EnvironmentObject var store:GpixStore
    @State private var deleting=false
    @State private var password=""
    var body:some View{
        Form{
            Section("Profilo"){
                NavigationLink("Modifica informazioni"){
                    EditProfileView()
                }
                Text("@"+store.me.s("username"))
                Text(store.me.s("name"))
            }
            Section("Password e sicurezza"){
                NavigationLink("Modifica password"){
                    SecurityView(mode:"change-password")
                }
                NavigationLink("Verifica email"){
                    SecurityView(mode:"verify")
                }
                NavigationLink("Dispositivi collegati"){
                    SessionView()
                }
            }
            Section{
                Button("Elimina account",role:.destructive){
                    deleting=true
                }
            }
        }
        .navigationTitle("Centro gestione account").alert("Elimina definitivamente l’account",isPresented:$deleting){
            SecureField("Conferma la password",text:$password)
            Button("Elimina",role:.destructive){
                store.perform("deleteAccount",["password":password])
            }
            Button("Annulla",role:.cancel){
            }
        } message: {
            Text("I tuoi post e i tuoi dati verranno eliminati. L’operazione non è reversibile.")
        }
    }
}
@MainActor
struct SecurityView:View{
    @EnvironmentObject var store:GpixStore
    @Environment(\.dismiss) var dismiss
    let mode:String
    @State private var login=""
    @State private var code=""
    @State private var current=""
    @State private var password=""
    @State private var confirm=""
    @State private var sent=false
    @State private var busy=false
    @State private var info=""
    var body:some View{
        Form{
            if !info.isEmpty{
                Text(info).foregroundStyle(gpixPurple)
            }
            if mode=="forgot"{
                TextField("Email o nome utente",text:$login).textInputAutocapitalization(.never)
            }
            if mode=="verify" || mode=="forgot"{
                if sent{
                    TextField("Codice ricevuto",text:$code).keyboardType(.numberPad)
                }
            }
            if mode=="change-password"{
                SecureField("Password attuale",text:$current)
            }
            if mode != "verify" && (mode != "forgot" || sent){
                SecureField("Nuova password (almeno 10 caratteri)",text:$password)
                SecureField("Conferma password",text:$confirm)
            }
            Button(busy ? "Attendi…":sent || mode=="change-password" ? "Conferma":"Invia codice"){
                submit()
            }
            .disabled(busy)
        }
        .navigationTitle(mode=="verify" ? "Verifica email":mode=="forgot" ? "Recupera password":"Modifica password")
    }
    func submit(){
        if store.demo{
            store.error="La demo non usa credenziali reali."
            return
        }
        busy=true
        Task{
            defer{
                busy=false
            }
            do{
                if mode=="verify"{
                    _ = try await store.api("/auth/"+(sent ? "verification-confirm":"verification-send"),["code":code])
                    if sent{
                        await store.sync()
                        dismiss()
                    }
                    else{
                        sent=true
                        info="Controlla la tua email, anche nello spam."
                    }
                }
                else if mode=="forgot" && !sent{
                    let r=try await store.api("/auth/forgot",["login":login])
                    info=r.s("message","Controlla la tua email.")
                    sent=true
                }
                else{
                    guard password.count>=10,password==confirm else{
                        throw GError(message:"Le password devono coincidere e contenere almeno 10 caratteri")
                    }
                    _ = try await store.api("/auth/"+(mode=="forgot" ? "reset":"change-password"),["login":login,"code":code,"current":current,"password":password])
                    dismiss()
                }
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
}
@MainActor
struct SessionView:View{
    @EnvironmentObject var store:GpixStore
    @State private var sessions:[Row]=[]
    var body:some View{
        List{
            ForEach(sessions,id:\.id){
                s in VStack(alignment:.leading,spacing:7){
                    Label(s.s("name",s.s("device","Dispositivo")),systemImage:s.s("platform")=="ios" ? "iphone":"laptopcomputer")
                    Text(s.b("current") ? "Questo dispositivo":"Ultimo accesso "+ago(s.n("lastSeen"))+" fa").font(.caption).foregroundStyle(.secondary)
                    if !s.b("current"){
                        Button("Disconnetti",role:.destructive){
                            revoke(["id":s.id])
                        }
                    }
                }
            }
            Button("Disconnetti gli altri dispositivi",role:.destructive){
                revoke(["others":true])
            }
        }
        .navigationTitle("Dispositivi collegati").task{
            await load()
        }
    }
    func load()async{
        if !store.demo{
            do{
                sessions=try await store.api("/sessions").rows("sessions")
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
    func revoke(_ p:Row){
        Task{
            do{
                _ = try await store.api("/sessions/revoke",p)
                await load()
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
}
@MainActor
struct PostCollection:View{
    let title:String,mode:String
    @EnvironmentObject var store:GpixStore
    var rows:[Row]{
        store.posts.filter{
            mode=="saved" ? $0.b("saved") : $0.s("author")==store.myID && (mode=="archive" ? $0.b("archived") : !$0.b("archived"))
        }
    }
    var body:some View{
        ScrollView{
            LazyVStack{
                ForEach(rows,id:\.id){
                    p in PostCard(post:p)
                }
            }
        }
        .navigationTitle(title)
    }
}
@MainActor
struct ArchiveMenu:View{
    var body:some View{
        List{
            NavigationLink{
                InstantArchiveView()
            } label: {
                Label("Le tue istantanee",systemImage:"square.stack.3d.up")
            }
            NavigationLink{
                PostCollection(title:"Archivio post",mode:"archive")
            } label: {
                Label("Post archiviati",systemImage:"archivebox")
            }
            NavigationLink{
                StoryArchiveView()
            } label: {
                Label("Archivio storie",systemImage:"clock.arrow.circlepath")
            }
        }
        .navigationTitle("Archivio")
    }
}
