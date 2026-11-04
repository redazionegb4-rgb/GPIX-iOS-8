import SwiftUI
import PhotosUI
import AVFoundation
@MainActor
struct InboxView:View{
    @EnvironmentObject var store:GpixStore
    @State private var query=""
    @State private var newChat=false
    var rows:[Row]{
        store.threads.filter{
            !store.request($0) && !store.requestHidden($0) && (query.isEmpty || store.threadTitle($0).localizedCaseInsensitiveContains(query))
        }
    }
    var body:some View{
        ScrollView{
            VStack(alignment:.leading,spacing:20){
                GpixSearchField(text:$query,placeholder:"Cerca una conversazione")
                NoteStrip()
                HStack{
                    Text("Messaggi").font(.headline)
                    Spacer()
                    NavigationLink("Richieste"){
                        MessageRequestsView(hidden:false)
                    }
                    .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(rows,id:\.id){
                    t in NavigationLink{
                        ChatView(threadID:t.id)
                    } label: {
                        HStack(spacing:14){
                            AvatarView(person:store.peer(t),size:62,ring:store.unseenStories(store.peer(t).id),online:store.online(store.peer(t).id))
                            VStack(alignment:.leading,spacing:5){
                                Text(store.threadTitle(t)).font(.system(size:16,weight:store.unread(t)>0 ? .semibold:.regular))
                                Text(preview(t)).font(.system(size:14,weight:store.unread(t)>0 ? .semibold:.regular)).foregroundStyle(store.unread(t)>0 ? .primary:.secondary).lineLimit(1)
                            }
                            Spacer(minLength:4)
                            if store.unread(t)>0{
                                Circle().fill(gpixPurple).frame(width:8,height:8)
                            }
                        }
                        .foregroundStyle(.primary).padding(.vertical,5).contentShape(Rectangle())
                    }
                    .buttonStyle(GpixPressStyle())
                }
                if rows.isEmpty{
                    EmptyViewCard(icon:"paperplane",title:"Le tue conversazioni",subtitle:"Scrivi a una persona per iniziare.")
                }
                if store.preferences["hideInstantBubble"] as? Bool != true{
                    NavigationLink{
                        InstantsView()
                    } label: {
                        InstantBubble()
                    }
                }
            }
            .padding(16)
        }
        .navigationBarTitleDisplayMode(.inline).toolbar{
            ToolbarItem(placement:.principal){
                Text(store.me.s("username")).font(.title3.bold())
            }
            ToolbarItem(placement:.navigationBarTrailing){
                Button{
                    newChat=true
                } label: {
                    Image(systemName:"square.and.pencil").font(.title2)
                }
            }
        }
        .sheet(isPresented:$newChat){
            NavigationStack{
                NewChatView()
            }
        }
        .refreshable{
            await store.sync()
        }
    }
    func preview(_ t:Row)->String{
        let ids=t.rows("messages").map{
            $0.id
        }
        if store.state.rows("notifications").contains(where:{
            $0.s("type")=="messageReaction" && !$0.b("seen") && ids.contains($0.s("ref"))
        }
        ){
            return "Ha reagito a un tuo messaggio"
        }
        guard let m=t.rows("messages").last else{
            return "Inizia una conversazione"
        }
        let text=m.s("text").isEmpty ? ["image":"Foto","audio":"Messaggio vocale","gif":"GIF"][m.s("kind")] ?? "Messaggio":m.s("text")
        return (store.unread(t)>1 ? "\(store.unread(t)) nuovi messaggi":text)+" · "+ago(m.n("created"))
    }
}
@MainActor
struct MessageRequestsView:View{
    @EnvironmentObject var store:GpixStore
    let hidden:Bool
    @State private var all=false
    @State private var manage=false
    var rows:[Row]{
        store.threads.filter{
            hidden ? store.requestHidden($0):store.request($0) && !store.requestHidden($0)
        }
        .filter{
            all || ($0.rows("messages").last?.n("created") ?? 0)>Date().timeIntervalSince1970-30*86400
        }
    }
    var body:some View{
        ScrollView{
            VStack(spacing:24){
                if !hidden{
                    NavigationLink{
                        MessageRequestsView(hidden:true)
                    } label: {
                        HStack{
                            Label("Richieste nascoste",systemImage:"eye.slash")
                            Spacer()
                            Text("\(store.threads.filter{store.requestHidden($0)}.count)").foregroundStyle(.secondary)
                            Image(systemName:"chevron.right")
                        }
                        .foregroundStyle(.primary).padding(.vertical,12)
                    }
                }
                if rows.isEmpty{
                    EmptyViewCard(icon:"paperplane",title:hidden ? "Nessuna richiesta nascosta":"Nessuna richiesta di messaggi recente",subtitle:"Le richieste più vecchie di 30 giorni non sono visibili.").padding(.top,90)
                    Button("Mostra tutto"){
                        all=true
                    }
                    .font(.headline)
                }
                ForEach(rows,id:\.id){
                    t in NavigationLink{
                        ChatView(threadID:t.id)
                    } label: {
                        PersonLine(person:store.peer(t),subtitle:t.rows("messages").last?.s("text") ?? "")
                    }
                }
            }
            .padding(18)
        }
        .navigationTitle(hidden ? "Richieste nascoste":"Richieste di messaggi").navigationBarTitleDisplayMode(.inline).toolbar{
            if !rows.isEmpty{
                Button("Accetta tutte"){
                    Task{
                        for t in rows{
                            try? await store.act("messageRequest",["id":t.id,"decision":"accepted"])
                        }
                    }
                }
            }
        }
    }
}
@MainActor
struct NewChatView:View{
    @EnvironmentObject var store:GpixStore
    @State private var query=""
    @State private var group=false
    @State private var selected:Set<String>=[]
    @State private var title=""
    @State private var threadID=""
    var body:some View{
        List{
            Toggle("Nuovo gruppo",isOn:$group)
            if group{
                TextField("Nome gruppo",text:$title)
            }
            ForEach(store.users.filter{
                $0.id != store.myID && (query.isEmpty || ($0.s("name")+$0.s("username")).localizedCaseInsensitiveContains(query))
            }
            ,id:\.id){
                p in if group{
                    Button{
                        if selected.contains(p.id){
                            selected.remove(p.id)
                        }
                        else{
                            selected.insert(p.id)
                        }
                    } label: {
                        HStack{
                            PersonLine(person:p)
                            Image(systemName:selected.contains(p.id) ? "checkmark.circle.fill":"circle")
                        }
                    }
                }
                else{
                    NavigationLink{
                        ChatStartView(userID:p.id)
                    } label: {
                        PersonLine(person:p)
                    }
                }
            }
        }
        .searchable(text:$query).navigationTitle("Nuovo messaggio").toolbar{
            if group{
                Button("Crea"){
                    Task{
                        do{
                            try await store.act("group",["users":Array(selected),"title":title])
                            if let t=store.threads.first(where:{
                                $0.s("title")==title && $0.s("owner")==store.myID
                            }
                            ){
                                threadID=t.id
                            }
                        }
                        catch{
                            store.error=error.localizedDescription
                        }
                    }
                }
                .disabled(selected.count<2 || title.isEmpty)
            }
        }
        .navigationDestination(isPresented:Binding(get:{
            !threadID.isEmpty
        }
        ,set:{
            if !$0{
                threadID=""
            }
        }
        )){
            ChatView(threadID:threadID)
        }
    }
}
@MainActor
struct ChatStartView:View{
    let userID:String
    @EnvironmentObject var store:GpixStore
    @State private var tid=""
    var body:some View{
        Group{
            if tid.isEmpty{
                ProgressView("Apertura chat…")
            }
            else{
                ChatView(threadID:tid)
            }
        }
        .task{
            do{
                tid=try await store.startThread(userID)
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
}
@MainActor
struct ChatView:View{
    @EnvironmentObject var store:GpixStore
    @Environment(\.scenePhase) private var scene
    let threadID:String
    @State private var text=""
    @State private var reply=""
    @State private var edit=""
    @State private var gif=false
    @State private var camera=false
    @State private var settings=false
    @State private var image:PhotosPickerItem?
    @State private var photo:UIImage?
    @State private var once=false
    @State private var replays=1
    @State private var busy=false
    @State private var typing:[Row]=[]
    @State private var lastTyping=Date.distantPast
    @State private var readIDs:Set<String>=[]
    @State private var call:IdentifiedRow?
    @StateObject private var recorder=VoiceRecorder()
    var thread:Row{
        store.thread(threadID)
    }
    var peer:Row{
        store.peer(thread)
    }
    var body:some View{
        VStack(spacing:0){
            ScrollViewReader{
                proxy in ScrollView{
                    LazyVStack(spacing:13){
                        VStack(spacing:10){
                            AvatarView(person:peer,size:85)
                            Text(store.threadTitle(thread)).font(.title3.bold())
                            Text("@"+peer.s("username")).font(.subheadline).foregroundStyle(.secondary)
                            NavigationLink("Visualizza profilo"){
                                ProfileView(userID:peer.id)
                            }
                            .font(.subheadline.bold()).padding(.horizontal,20).padding(.vertical,10).overlay(Capsule().stroke(.secondary.opacity(0.25)))
                        }
                        .padding(.vertical,28)
                        ForEach(thread.rows("messages").filter{
                            !$0.b("expired") && ($0.n("readExpiresAt")==0 || $0.n("readExpiresAt")>Date().timeIntervalSince1970)
                        }
                        ,id:\.id){
                            m in MessageBubble(message:m,threadID:threadID,onReply:{
                                reply=m.id
                            }
                            ,onEdit:{
                                edit=m.id
                                text=m.s("text")
                            }
                            ).id(m.id)
                        }
                        if !typing.isEmpty{
                            HStack{
                                AvatarView(person:peer,size:24)
                                Text(typing.contains{
                                    $0.s("kind")=="recording"
                                }
                                ? "Sta registrando un vocale…":"Sta scrivendo…").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .padding(14)
                }
                .onChange(of:thread.rows("messages").last?.id){
                    _, id in if let id=id{
                        withAnimation{
                            proxy.scrollTo(id,anchor:.bottom)
                        }
                    }
                }
                .onAppear{
                    if let id=thread.rows("messages").last?.id{
                        proxy.scrollTo(id,anchor:.bottom)
                    }
                }
            }
            if store.request(thread){
                HStack{
                    Button("Accetta"){
                        store.perform("messageRequest",["id":threadID,"decision":"accepted"])
                    }
                    .buttonStyle(RequestButton(primary:true))
                    Button("Nascondi"){
                        store.perform("messageRequest",["id":threadID,"decision":"hidden"])
                    }
                    .buttonStyle(RequestButton(primary:false))
                    Button("Blocca",role:.destructive){
                        store.perform("block",["user":peer.id])
                    }
                }
                .padding(10)
            }
            if !reply.isEmpty || !edit.isEmpty{
                HStack{
                    Text(edit.isEmpty ? "Rispondi: "+(thread.rows("messages").first{
                        $0.id==reply
                    }?.s("text") ?? "Foto") : "Modifica messaggio").font(.caption).lineLimit(1)
                    Spacer()
                    Button{
                        reply=""
                        edit=""
                        text=""
                    } label: {
                        Image(systemName:"xmark")
                    }
                }
                .padding(.horizontal,20).padding(.top,8)
            }
            composer
        }
        .navigationBarTitleDisplayMode(.inline).toolbar{
            ToolbarItem(placement:.principal){
                Button{
                    settings=true
                } label: {
                    HStack(spacing:9){
                        AvatarView(person:peer,size:31,online:store.online(peer.id))
                        VStack(alignment:.leading,spacing:2){
                            Text(store.threadTitle(thread)).font(.subheadline.bold())
                            Text(status).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            ToolbarItem(placement:.navigationBarTrailing){
                HStack(spacing:15){
                    Button{
                        startCall(false)
                    } label: {
                        Image(systemName:"phone")
                    }
                    Button{
                        startCall(true)
                    } label: {
                        Image(systemName:"video")
                    }
                }
            }
        }
        .sheet(isPresented:$gif){
            GiphyPicker{
                url in store.perform("message",["id":threadID,"kind":"gif","media":url,"text":"","reply":reply])
                gif=false
                reply=""
            }
        }
        .sheet(isPresented:$camera){
            CameraPicker(video:false){
                img,url in photo=img
                camera=false
            }
        }
        .sheet(isPresented:Binding(get:{
            photo != nil
        }
        ,set:{
            if !$0{
                photo=nil
            }
        }
        )){
            NavigationStack{
                VStack{
                    if let photo=photo{
                        Image(uiImage:photo).resizable().scaledToFit()
                    }
                    Toggle("Foto temporanea",isOn:$once).padding()
                    if once{
                        Picker("Visualizzazioni",selection:$replays){
                            Text("Una volta").tag(1)
                            Text("Consenti replay").tag(2)
                        }
                        .pickerStyle(.segmented).padding()
                    }
                    PrimaryButton(title:busy ? "Invio…":"Invia foto",disabled:busy){
                        sendPhoto()
                    }
                    .padding()
                }
                .navigationTitle("Invia foto").toolbar{
                    Button("Annulla"){
                        photo=nil
                    }
                }
            }
        }
        .sheet(isPresented:$settings){
            NavigationStack{
                ThreadSettingsView(threadID:threadID)
            }
        }
        .fullScreenCover(item:$call){
            item in CallView(callID:item.id)
        }
        .onChange(of:image){
            _, item in Task{
                if let data=try? await item?.loadTransferable(type:Data.self){
                    photo=UIImage(data:data)
                }
            }
        }
        .onChange(of:text){
            _, _ in signalTyping()
        }
        .task{
            await presenceLoop()
        }
        .onDisappear{
            Task{
                await typingOff()
            }
        }
        .preference(key:HideBottomNavigation.self,value:true)
    }
    var status:String{
        if !typing.isEmpty{
            return "Sta scrivendo…"
        }
        if store.online(peer.id){
            return "Online"
        }
        let last=peer.n("lastActive")
        return last>0 ? "Ultimo accesso "+ago(last)+" fa":""
    }
    var composer:some View{
        HStack(spacing:8){
            Button{
                camera=true
            } label: {
                Image(systemName:"camera.fill").font(.system(size:20,weight:.medium)).foregroundStyle(Color.white).frame(width:40,height:40).background(gpixPurple,in:Circle())
            }
            if recorder.recording{
                Text("Registrazione · \(Int(recorder.seconds)) s").font(.subheadline).foregroundStyle(.red).frame(maxWidth:.infinity,alignment:.leading)
            }
            else{
                TextField(thread.n("messageTTL")==0 ? "Messaggio…":"Messaggio a scadenza…",text:$text,axis:.vertical).textFieldStyle(.plain).lineLimit(1...5).padding(.leading,3)
            }
            if !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty{
                Button("Invia"){
                    sendText()
                }
                .font(.subheadline.bold()).foregroundStyle(.white).padding(.horizontal,14).padding(.vertical,9).background(gpixPurple,in:Capsule())
            }
            else{
                PhotosPicker(selection:$image,matching:.images){
                    Image(systemName:"photo").font(.system(size:21))
                }
                Button{
                    voice()
                } label: {
                    Image(systemName:recorder.recording ? "stop.circle.fill":"mic").font(.system(size:22)).foregroundStyle(recorder.recording ? .red:.primary)
                }
                Menu{
                    Button("GIF e sticker",systemImage:"face.smiling"){
                        gif=true
                    }
                    Button("Fotocamera",systemImage:"camera"){
                        camera=true
                    }
                    Button("Foto temporanea",systemImage:"timer"){
                        once=true
                        camera=true
                    }
                } label: {
                    Image(systemName:"plus.circle").font(.system(size:23))
                }
            }
        }
        .foregroundStyle(Color.primary).padding(.leading,5).padding(.trailing,13).padding(.vertical,5)
        .background(Color(uiColor:.secondarySystemBackground),in:Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.06)))
        .padding(.horizontal,12).padding(.vertical,8)
        .background(Color(uiColor:.systemBackground))
    }
    func sendText(){
        let value=text
        text=""
        let replyID=reply,editID=edit
        reply=""
        edit=""
        Task{
            do{
                try await store.act(editID.isEmpty ? "message":"editMessage",["id":editID.isEmpty ? threadID:editID,"text":value,"reply":replyID])
                await typingOff()
            }
            catch{
                text=value
                store.error=error.localizedDescription
            }
        }
    }
    func sendPhoto(){
        guard let data=photo?.jpegData(compressionQuality:0.9)else{
            return
        }
        busy=true
        Task{
            defer{
                busy=false
            }
            do{
                let m=try await store.upload(data,mime:"image/jpeg")
                try await store.act("message",["id":threadID,"kind":"image","media":m.s("id"),"text":"","viewOnce":once,"maxOpens":replays,"reply":reply])
                photo=nil
                reply=""
                once=false
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
    func voice(){
        Task{
            do{
                if recorder.recording{
                    let data=try recorder.stop()
                    await typingOff()
                    let m=try await store.upload(data,mime:"audio/mp4")
                    try await store.act("message",["id":threadID,"kind":"audio","media":m.s("id"),"text":"","reply":reply])
                    reply=""
                }
                else{
                    try await recorder.start()
                    if !store.demo{
                        _ = try? await store.api("/threads/\(threadID)/typing",["active":true,"kind":"recording"])
                    }
                }
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
    func signalTyping(){
        guard !store.demo,Date().timeIntervalSince(lastTyping)>3 else{
            return
        }
        lastTyping=Date()
        Task{
            _ = try? await store.api("/threads/\(threadID)/typing",["active":!text.isEmpty,"kind":"typing"])
        }
    }
    func typingOff()async{
        if !store.demo{
            _ = try? await store.api("/threads/\(threadID)/typing",["active":false])
        }
    }
    func presenceLoop()async{
        while !Task.isCancelled{
            if scene == .active{
                for m in thread.rows("messages") where m.s("author") != store.myID && !readIDs.contains(m.id) && !m.ids("readBy").contains(store.myID){
                    readIDs.insert(m.id)
                    do{
                        try await store.act("read",["id":m.id])
                    }
                    catch{
                        readIDs.remove(m.id)
                    }
                }
                let ids=thread.rows("messages").map{
                    $0.id
                }
                for n in store.state.rows("notifications") where n.s("type")=="messageReaction" && !n.b("seen") && ids.contains(n.s("ref")){
                    try? await store.act("notificationsRead",["id":n.id])
                }
                if !store.demo,let response=try? await store.api("/threads/\(threadID)/presence"){
                    typing=response.rows("typing").filter{
                        $0.s("user") != store.myID && $0.n("until")>Date().timeIntervalSince1970
                    }
                    var users=store.users
                    for p in response.rows("users"){
                        if let i=users.firstIndex(where:{
                            $0.id==p.id
                        }
                        ){
                            users[i].removeValue(forKey:"online")
                            users[i].removeValue(forKey:"lastActive")
                            users[i].merge(p){
                                _,new in new
                            }
                        }
                    }
                    store.state["users"]=users
                }
            }
            try? await Task.sleep(nanoseconds:2_000_000_000)
        }
    }
    func startCall(_ video:Bool){
        Task{
            do{
                try await store.act("callStart",["id":threadID,"video":video])
                if let row=store.state.rows("calls").first(where:{
                    $0.s("thread")==threadID && $0.s("caller")==store.myID && $0.s("status")=="ringing"
                }
                ){
                    call=IdentifiedRow(row:row)
                }
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
}
@MainActor
struct MessageBubble:View{
    @EnvironmentObject var store:GpixStore
    let message:Row,threadID:String
    let onReply:()->Void,onEdit:()->Void
    @State private var opened:Data?
    @State private var opening=false
    var mine:Bool{
        message.s("author")==store.myID
    }
    var body:some View{
        HStack(alignment:.bottom,spacing:7){
            if mine{
                Spacer(minLength:35)
            }
            else{
                AvatarView(person:store.person(message.s("author")),size:24)
            }
            VStack(alignment:mine ? .trailing:.leading,spacing:4){
                VStack(alignment:.leading,spacing:7){
                    if !message.s("reply").isEmpty{
                        Text("↪ "+(store.thread(threadID).rows("messages").first{
                            $0.id==message.s("reply")
                        }?.s("text") ?? "Foto")).font(.caption).lineLimit(2).padding(7).background(.primary.opacity(0.08),in:RoundedRectangle(cornerRadius:8))
                    }
                    content
                    if message.b("edited"){
                        Text("Modificato").font(.caption2)
                    }
                }
                .padding(message.s("kind")=="image" && !message.b("viewOnce") ? 5:13).background(mine ? gpixPurple:Color.secondary.opacity(0.15),in:RoundedRectangle(cornerRadius:22)).foregroundStyle(mine ? .white:.primary)
                if !message.row("reactions").isEmpty{
                    Text(message.row("reactions").values.compactMap{
                        $0 as? String
                    }
                    .joined()).font(.caption).padding(.horizontal,7).padding(.vertical,3).background(.regularMaterial,in:Capsule()).overlay(Capsule().stroke(.secondary.opacity(0.2)))
                }
                Text(clock(message.n("created"))+(mine ? (message.ids("readBy").contains(where:{
                    $0 != store.myID
                }
                ) ? " · Visto":" · Inviato"):"")).font(.system(size:10)).foregroundStyle(.secondary)
            }
            .frame(maxWidth:290,alignment:mine ? .trailing:.leading).contextMenu{
                Button("Rispondi",systemImage:"arrowshape.turn.up.left",action:onReply)
                ForEach(["❤️","😂","😍","🔥","😢","👏","🌈"],id:\.self){
                    emoji in Button(emoji){
                        store.perform("react",["id":message.id,"emoji":message.row("reactions").s(store.myID)==emoji ? "":emoji])
                    }
                }
                if mine{
                    if message.s("kind")=="text"{
                        Button("Modifica",systemImage:"pencil",action:onEdit)
                    }
                    Button("Elimina per tutti",systemImage:"trash",role:.destructive){
                        store.perform("deleteMessage",["id":message.id])
                    }
                }
            }
            .onTapGesture(count:2){
                store.perform("react",["id":message.id,"emoji":message.row("reactions").s(store.myID)=="❤️" ? "":"❤️"])
            }
            if !mine{
                Spacer(minLength:35)
            }
        }
        .fullScreenCover(isPresented:Binding(get:{
            opened != nil
        }
        ,set:{
            if !$0{
                opened=nil
            }
        }
        )){
            ProtectedPhoto(data:opened,onNext:{
                opened=nil
            }
            )
        }
    }
    @ViewBuilder var content:some View{
        switch message.s("kind"){
            case "image":if message.b("viewOnce"){
                Button{
                    openPhoto()
                } label: {
                    Label(opening ? "Apertura…":message.ids("openedBy").contains(store.myID) ? "Foto aperta":message.n("maxOpens")==2 ? "Foto · consenti replay":"Foto · visualizza una volta",systemImage:"timer")
                }
                .disabled(opening || message.ids("openedBy").contains(store.myID))
            }
            else{
                MediaView(reference:message.s("media"),fill:false).frame(width:220,height:230)
            }
            case "gif":GIFView(reference:message.s("media")).frame(width:210,height:175)
            case "audio":AudioBubble(reference:message.s("media"))
            case "sticker":Text(message.s("text")).font(.system(size:44))
            case "post":NavigationLink{
                PostDetailView(postID:message.row("story").s("postId"))
            } label: {
                VStack{
                    MediaView(reference:store.post(message.row("story").s("postId")).s("media"),fill:true).frame(width:200,height:210)
                    Text("Post condiviso").font(.caption)
                }
            }
            default:if !message.row("story").s("media").isEmpty{
                MediaView(reference:message.row("story").s("media"),fill:true).frame(width:110,height:140)
            }
            Text(message.s("text")).font(.system(size:15))
        }
    }
    func openPhoto(){
        if store.demo{
            if let img=localImage(message.s("media")){
                opened=img.jpegData(compressionQuality:0.9)
            }
            return
        }
        opening=true
        Task{
            defer{
                opening=false
            }
            do{
                opened=try await store.bytes("/messages/\(message.id)/open",payload:[:])
                await store.sync()
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
}
@MainActor
struct AudioBubble:View{
    let reference:String
    @State private var player:AVPlayer?
    @State private var playing=false
    var body:some View{
        HStack(spacing:12){
            Button{
                if player==nil{
                    player=AVPlayer(url:mediaURL(reference))
                }
                if playing{
                    player?.pause()
                }
                else{
                    player?.play()
                }
                playing.toggle()
            } label: {
                Image(systemName:playing ? "pause.fill":"play.fill").font(.title3)
            }
            Image(systemName:"waveform").font(.title2)
            Text("Messaggio vocale").font(.caption)
        }
        .padding(5).onDisappear{
            player?.pause()
        }
        .onReceive(NotificationCenter.default.publisher(for:.AVPlayerItemDidPlayToEndTime)){
            _ in playing=false
            player?.seek(to:.zero)
        }
    }
}
@MainActor
struct ThreadSettingsView:View{
    @EnvironmentObject var store:GpixStore
    let threadID:String
    @State private var title=""
    @State private var selected=""
    var t:Row{
        store.thread(threadID)
    }
    var body:some View{
        Form{
            Section("Messaggi temporanei"){
                Picker("Scompaiono",selection:Binding(get:{
                    Int(t.n("messageTTL"))
                }
                ,set:{
                    store.perform("messageExpiry",["id":threadID,"seconds":$0])
                }
                )){
                    Text("Mai").tag(0)
                    Text("Dopo la lettura").tag(-1)
                    Text("Dopo 1 minuto").tag(60)
                    Text("Dopo 1 ora").tag(3600)
                    Text("Dopo 24 ore").tag(86400)
                }
            }
            Section("Partecipanti"){
                ForEach(t.ids("members"),id:\.self){
                    id in NavigationLink{
                        ProfileView(userID:id)
                    } label: {
                        PersonLine(person:store.person(id))
                    }
                    .swipeActions{
                        if t.s("owner")==store.myID && id != store.myID{
                            Button("Rimuovi",role:.destructive){
                                store.perform("removeMember",["id":threadID,"user":id])
                            }
                        }
                    }
                }
            }
            if !t.s("owner").isEmpty{
                Section("Gruppo"){
                    if t.s("owner")==store.myID{
                        TextField("Nome gruppo",text:$title)
                        Button("Salva nome"){
                            store.perform("renameGroup",["id":threadID,"title":title])
                        }
                        Picker("Aggiungi persona",selection:$selected){
                            Text("Scegli").tag("")
                            ForEach(store.users.filter{
                                !t.ids("members").contains($0.id)
                            }
                            ,id:\.id){
                                p in Text(p.s("name")).tag(p.id)
                            }
                        }
                        Button("Aggiungi"){
                            store.perform("addMember",["id":threadID,"user":selected])
                        }
                        .disabled(selected.isEmpty)
                    }
                    Button("Esci dal gruppo",role:.destructive){
                        store.perform("leaveGroup",["id":threadID])
                    }
                }
            }
        }
        .navigationTitle("Dettagli chat").onAppear{
            title=t.s("title")
        }
    }
}
