import SwiftUI
@MainActor
struct SettingsView:View{
    @EnvironmentObject var store:GpixStore
    @State private var query=""
    func visible(_ name:String)->Bool{
        query.isEmpty || name.localizedCaseInsensitiveContains(query)
    }
    var body:some View{
        List{
            Section("Il tuo account"){
                if visible("Centro gestione account"){
                    NavigationLink{
                        AccountView()
                    } label: {
                        Label("Centro gestione account",systemImage:"person.crop.circle")
                    }
                }
            }
            Section("Come usi GPIX"){
                if visible("Salvati"){
                    NavigationLink{
                        PostCollection(title:"Salvati",mode:"saved")
                    } label: {
                        Label("Salvati",systemImage:"bookmark")
                    }
                }
                if visible("Archivio"){
                    NavigationLink{
                        ArchiveMenu()
                    } label: {
                        Label("Archivio",systemImage:"clock.arrow.circlepath")
                    }
                }
                if visible("La tua attività"){
                    NavigationLink{
                        PostCollection(title:"La tua attività",mode:"own")
                    } label: {
                        Label("La tua attività",systemImage:"waveform.path.ecg")
                    }
                }
                if visible("Notifiche"){
                    Toggle(isOn:pref("pushEnabled",true)){
                        Label("Notifiche",systemImage:"bell")
                    }
                }
                if visible("Bozze"){
                    NavigationLink{
                        DraftsView()
                    } label: {
                        Label("Bozze post e reel",systemImage:"doc.badge.ellipsis")
                    }
                }
            }
            Section("Chi può vedere i tuoi contenuti"){
                Toggle(isOn:Binding(get:{
                    store.me.b("private")
                }
                ,set:{
                    store.perform("profile",["private":$0])
                }
                )){
                    Label("Account privato",systemImage:"lock")
                }
                NavigationLink{
                    ManagePeopleView(title:"Amici più stretti",key:"closeFriends")
                } label: {
                    Label("Amici più stretti",systemImage:"star.circle")
                }
                NavigationLink{
                    ManagePeopleView(title:"Utenti bloccati",key:"blocks")
                } label: {
                    Label("Utenti bloccati",systemImage:"nosign")
                }
                NavigationLink{
                    ManagePeopleView(title:"Nascondi la storia a",key:"hiddenStories")
                } label: {
                    Label("Storia e posizione",systemImage:"eye.slash")
                }
            }
            Section("Come possono interagire gli altri con te"){
                NavigationLink{
                    MessagePrivacyView()
                } label: {
                    Label("Messaggi e risposte alle storie",systemImage:"paperplane")
                }
                NavigationLink{
                    PermissionChoice(title:"Tag e menzioni",key:"allowMentions")
                } label: {
                    Label("Tag e menzioni",systemImage:"at")
                }
                NavigationLink{
                    ManagePeopleView(title:"Con restrizioni",key:"restricted")
                } label: {
                    Label("Con restrizioni",systemImage:"person.crop.circle.badge.exclamationmark")
                }
            }
            Section("Cosa vedi"){
                NavigationLink{
                    ManagePeopleView(title:"Account silenziati",key:"muted")
                } label: {
                    Label("Account silenziati",systemImage:"bell.slash")
                }
                Toggle(isOn:pref("hideInstantBubble",false)){
                    Label("Nascondi bolla istantanee",systemImage:"square.stack.3d.up.slash")
                }
            }
            Section("La tua app"){
                Picker("Aspetto",selection:Binding(get:{
                    store.appearance
                }
                ,set:{
                    store.appearance=$0
                    UserDefaults.standard.set($0,forKey:"gpix.native.appearance")
                }
                )){
                    Text("Sistema").tag("system")
                    Text("Chiaro").tag("light")
                    Text("Scuro").tag("dark")
                }
                Button{
                    if let url=URL(string:UIApplication.openSettingsURLString){
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Autorizzazioni del dispositivo",systemImage:"iphone")
                }
                NavigationLink{
                    SessionView()
                } label: {
                    Label("Dispositivi collegati",systemImage:"laptopcomputer.and.iphone")
                }
            }
            Section("Assistenza"){
                Link(destination:URL(string:"https://gpix.cc/privacy")!){
                    Label("Centro sulla privacy",systemImage:"hand.raised")
                }
                Link(destination:URL(string:"https://gpix.cc/support")!){
                    Label("Aiuto",systemImage:"lifepreserver")
                }
            }
            Section{
                Button("Esci",role:.destructive){
                    Task{
                        await store.logout()
                    }
                }
            }
        }
        .searchable(text:$query,prompt:"Cerca").navigationTitle("Impostazioni e attività").navigationBarTitleDisplayMode(.inline)
    }
    func pref(_ key:String,_ fallback:Bool)->Binding<Bool>{
        Binding(get:{
            store.preferences[key] as? Bool ?? fallback
        }
        ,set:{
            store.preference(key,$0)
        }
        )
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
