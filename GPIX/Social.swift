import SwiftUI
import AVKit
@MainActor
struct FeedView:View {
    @EnvironmentObject var store:GpixStore
    @State private var compose=false
    @State private var activity=false
    @State private var followingOnly=false
    var feed:[Row]{
        store.posts.filter{
            $0.s("kind")=="post" && !$0.b("archived") && (!followingOnly || store.following($0.s("author")))
        }
    }
    var body:some View{
        ScrollViewReader{
            proxy in ScrollView{
                LazyVStack(spacing:0){
                    GeometryReader{
                        g in Color.clear.preference(key:FeedPosition.self,value:g.frame(in:.named("feed")).minY)
                    }
                    .frame(height:0).id("top")
                    StoryStrip().padding(.vertical,12)
                    ForEach(feed,id:\.id){
                        post in PostCard(post:post)
                    }
                    if feed.isEmpty {
                        EmptyViewCard(icon:"photo.on.rectangle",title:"Il tuo feed ti aspetta",subtitle:"Segui nuovi profili o condividi il tuo primo post.")
                    }
                }
            }
            .coordinateSpace(name:"feed").refreshable{
                await store.sync()
            }
            .onReceive(NotificationCenter.default.publisher(for:.gpixHome)){
                _ in withAnimation{
                    proxy.scrollTo("top",anchor:.top)
                }
            }
        }
        .toolbar{
            ToolbarItem(placement:.navigationBarLeading){
                Menu{
                    Button("Nuovo post",systemImage:"photo"){
                        compose=true
                    }
                    NavigationLink{
                        ComposerView(kind:"reel")
                    } label: {
                        Label("Nuovo reel",systemImage:"play.rectangle")
                    }
                    NavigationLink{
                        ComposerView(kind:"story")
                    } label: {
                        Label("Nuova storia",systemImage:"plus.circle")
                    }
                    NavigationLink{
                        LiveListView()
                    } label: {
                        Label("Dirette",systemImage:"video")
                    }
                } label: {
                    Image(systemName:"plus").font(.title2)
                }
            }
            ToolbarItem(placement:.principal){
                Menu{
                    Button("Per te"){
                        followingOnly=false
                    }
                    Button("Seguiti"){
                        followingOnly=true
                    }
                } label: {
                    HStack(spacing:5){
                        Text(followingOnly ? "Seguiti":"Per te").font(.title3.bold())
                        Image(systemName:"chevron.down").font(.caption)
                    }
                }
            }
            ToolbarItem(placement:.navigationBarTrailing){
                Button{
                    activity=true
                } label: {
                    Image(systemName:"heart").font(.title2).overlay(alignment:.topTrailing){
                        if store.state.rows("notifications").contains(where:{
                            !$0.b("seen") && !["messageReaction","message","call","instant"].contains($0.s("type"))
                        }
                        ){
                            Circle().fill(.red).frame(width:7,height:7)
                        }
                    }
                }
            }
        }
        .sheet(isPresented:$compose){
            ComposerView(kind:"post")
        }
        .sheet(isPresented:$activity){
            NavigationStack{
                ActivityView()
            }
        }
    }
}
@MainActor
struct StoryStrip:View {
    @EnvironmentObject var store:GpixStore
    @State private var selected:IdentifiedRow?
    @State private var create=false
    var people:[Row]{
        [store.me]+store.users.filter{
            $0.id != store.myID && !store.visibleStories($0.id).isEmpty
        }
    }
    var body:some View{
        ScrollView(.horizontal,showsIndicators:false){
            HStack(spacing:19){
                ForEach(people,id:\.id){
                    person in Button{
                        if person.id==store.myID && store.visibleStories(person.id).isEmpty{
                            create=true
                        }
                        else{
                            selected=IdentifiedRow(row:person)
                        }
                    } label: {
                        VStack(spacing:7){
                            AvatarView(person:person,size:74,ring:store.unseenStories(person.id)).overlay(alignment:.bottomTrailing){
                                if person.id==store.myID{
                                    Image(systemName:"plus.circle.fill").font(.title3).symbolRenderingMode(.palette).foregroundStyle(.white,.black)
                                }
                            }
                            Text(person.id==store.myID ? "La tua storia":person.s("username")).font(.caption).lineLimit(1).frame(width:85)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal,14)
        }
        .sheet(isPresented:$create){
            ComposerView(kind:"story")
        }
        .fullScreenCover(item:$selected){
            item in StoryViewer(userID:item.id)
        }
    }
}
@MainActor
struct PostCard:View {
    @EnvironmentObject var store:GpixStore
    let post:Row
    @State private var comments=false
    @State private var share=false
    var author:Row{
        store.person(post.s("author"))
    }
    var liked:Bool{
        post.ids("likes").contains(store.myID)
    }
    var media:[String]{
        let rows=post.rows("mediaItems").map{
            $0.s("url")
        }
        return rows.isEmpty ? [post.s("media")]:rows
    }
    var body:some View{
        VStack(alignment:.leading,spacing:0){
            HStack(spacing:10){
                NavigationLink{
                    ProfileView(userID:author.id)
                } label: {
                    AvatarView(person:author,size:34,ring:store.unseenStories(author.id))
                    VStack(alignment:.leading,spacing:2){
                        Text(author.s("username")).font(.system(size:14,weight:.semibold))
                        if !post.s("location").isEmpty{
                            Text(post.s("location")).font(.caption2)
                        }
                    }
                }
                .foregroundStyle(.primary)
                Spacer()
                if author.id != store.myID && !store.following(author.id){
                    Button(store.pending(author.id) ? "Richiesta inviata":"Segui"){
                        store.perform("follow",["user":author.id,"enabled":!store.pending(author.id)])
                    }
                    .font(.caption.bold()).padding(.horizontal,14).padding(.vertical,9).background(Color.secondary.opacity(0.10),in:RoundedRectangle(cornerRadius:10))
                }
                PostOptions(post:post)
            }
            .padding(.horizontal,13).padding(.vertical,12)
            TabView{
                ForEach(Array(media.enumerated()),id:\.offset){
                    _,reference in MediaView(reference:reference,fill:true)
                }
            }
            .tabViewStyle(.page(indexDisplayMode:media.count>1 ? .automatic:.never)).aspectRatio(max(0.55,min(1.91,post.row("style").n("aspect",1))),contentMode:.fit).onTapGesture(count:2){
                store.perform("like",["id":post.id,"enabled":true])
            }
            HStack(spacing:18){
                Button{
                    store.perform("like",["id":post.id,"enabled":!liked])
                } label: {
                    Image(systemName:liked ? "heart.fill":"heart").foregroundStyle(liked ? .red:.primary)
                }
                Button{
                    comments=true
                } label: {
                    Image(systemName:"bubble.right")
                }
                Button{
                    share=true
                } label: {
                    Image(systemName:"paperplane")
                }
                Button{
                    store.perform("repost",["id":post.id,"enabled":!post.ids("reposts").contains(store.myID)])
                } label: {
                    Image(systemName:"arrow.2.squarepath").font(.system(size:20))
                }
                Spacer()
                Button{
                    store.perform("save",["id":post.id,"enabled":!post.b("saved")])
                } label: {
                    Image(systemName:post.b("saved") ? "bookmark.fill":"bookmark")
                }
            }
            .font(.system(size:24)).foregroundStyle(.primary).padding(.horizontal,14).padding(.top,12)
            VStack(alignment:.leading,spacing:6){
                if !post.b("hideLikes"){
                    Text("\(post.ids("likes").count) Mi piace").font(.system(size:13,weight:.semibold))
                }
                if !post.s("text").isEmpty{
                    (Text(author.s("username")+" ").bold()+Text(post.s("text"))).font(.system(size:14))
                }
                if !post.rows("comments").isEmpty{
                    Button("Visualizza tutti i \(post.rows("comments").count) commenti"){
                        comments=true
                    }
                    .font(.system(size:13)).foregroundStyle(.secondary)
                }
                Text(ago(post.n("created"))).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .sheet(isPresented:$comments){
            CommentsView(postID:post.id)
        }
        .sheet(isPresented:$share){
            SharePostView(postID:post.id)
        }
    }
}
@MainActor
struct PostOptions:View {
    @EnvironmentObject var store:GpixStore
    let post:Row
    @State private var editing=false
    @State private var text=""
    @State private var location=""
    @State private var report=false
    @State private var reason=""
    var mine:Bool{
        post.s("author")==store.myID
    }
    var body:some View{
        Menu{
            if mine{
                Button("Modifica",systemImage:"pencil"){
                    text=post.s("text")
                    location=post.s("location")
                    editing=true
                }
                Button(store.me.ids("pinnedPosts").contains(post.id) ? "Rimuovi dai fissati":"Fissa sul profilo",systemImage:"pin"){
                    store.perform("pinPost",["id":post.id,"enabled":!store.me.ids("pinnedPosts").contains(post.id)])
                }
                Button(post.b("archived") ? "Mostra sul profilo":"Archivia",systemImage:"archivebox"){
                    store.perform("archivePost",["id":post.id,"enabled":!post.b("archived")])
                }
                Button(post.b("commentsOff") ? "Attiva commenti":"Disattiva commenti",systemImage:"bubble.right"){
                    store.perform("postOptions",["id":post.id,"commentsOff":!post.b("commentsOff"),"hideLikes":post.b("hideLikes")])
                }
                Button(post.b("hideLikes") ? "Mostra Mi piace":"Nascondi Mi piace",systemImage:"heart.slash"){
                    store.perform("postOptions",["id":post.id,"commentsOff":post.b("commentsOff"),"hideLikes":!post.b("hideLikes")])
                }
                Button("Elimina",systemImage:"trash",role:.destructive){
                    store.perform("deletePost",["id":post.id])
                }
            }
            else{
                Button("Segnala",systemImage:"flag"){
                    report=true
                }
            }
        } label: {
            Image(systemName:"ellipsis").font(.title3).padding(5)
        }
        .foregroundStyle(.primary)
        .sheet(isPresented:$editing){
            NavigationStack{
                Form{
                    TextField("Didascalia",text:$text,axis:.vertical)
                    TextField("Luogo",text:$location)
                }
                .navigationTitle("Modifica post").toolbar{
                    ToolbarItem(placement:.confirmationAction){
                        Button("Salva"){
                            Task{
                                do{
                                    try await store.act("editPost",["id":post.id,"text":text,"location":location])
                                    editing=false
                                }
                                catch{
                                    store.error=error.localizedDescription
                                }
                            }
                        }
                    }
                }
            }
        }
        .alert("Segnala contenuto",isPresented:$report){
            TextField("Motivo",text:$reason)
            Button("Invia"){
                store.perform("report",["id":post.id,"reason":reason])
            }
            Button("Annulla",role:.cancel){
            }
        }
    }
}
@MainActor
struct CommentsView:View {
    @EnvironmentObject var store:GpixStore
    @Environment(\.dismiss) var dismiss
    let postID:String
    @State private var text=""
    @State private var reply=""
    @State private var remove:IdentifiedRow?
    @State private var gif=false
    var post:Row{
        store.post(postID)
    }
    var body:some View{
        NavigationStack{
            VStack(spacing:0){
                ScrollView{
                    LazyVStack(alignment:.leading,spacing:22){
                        ForEach(post.rows("comments"),id:\.id){
                            comment in commentRow(comment)
                        }
                    }
                    .padding(18)
                }
                Divider()
                if !reply.isEmpty{
                    HStack{
                        Text("Risposta al commento").font(.caption)
                        Spacer()
                        Button{
                            reply=""
                        } label: {
                            Image(systemName:"xmark")
                        }
                    }
                    .padding(.horizontal)
                }
                HStack(spacing:12){
                    AvatarView(person:store.me,size:31)
                    TextField("Aggiungi un commento…",text:$text,axis:.vertical).lineLimit(1...4)
                    Button{
                        gif=true
                    } label: {
                        Image(systemName:"face.smiling")
                    }
                    Button("Invia"){
                        send()
                    }
                    .disabled(text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                }
                .padding(14)
            }
            .navigationTitle("Commenti").navigationBarTitleDisplayMode(.inline).toolbar{
                ToolbarItem(placement:.confirmationAction){
                    Button("Fine"){
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog("Eliminare il commento e le risposte?",isPresented:Binding(get:{
            remove != nil
        }
        ,set:{
            if !$0 {
                remove=nil
            }
        }
        )){
            Button("Elimina",role:.destructive){
                if let c=remove {
                    store.perform("deleteComment",["id":c.id])
                }
                remove=nil
            }
        }
        .sheet(isPresented:$gif){
            GiphyPicker{
                url in store.perform("comment",["id":postID,"text":"","media":url,"parent":reply])
                gif=false
                reply=""
            }
        }
    }
    func commentRow(_ c:Row)->some View{
        HStack(alignment:.top,spacing:11){
            AvatarView(person:store.person(c.s("author")),size:33)
            VStack(alignment:.leading,spacing:6){
                Text(store.person(c.s("author")).s("username")).font(.caption.bold())
                Text(c.s("text")).font(.subheadline)
                if !c.s("media").isEmpty{
                    GIFView(reference:c.s("media")).frame(height:120)
                }
                HStack(spacing:14){
                    Text(ago(c.n("created")))
                    Button("Rispondi"){
                        reply=c.id
                    }
                    if c.b("hidden"){
                        Text("Nascosto agli altri").foregroundStyle(.orange)
                    }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength:0)
            VStack{
                Button{
                    store.perform("likeComment",["id":c.id,"enabled":!c.ids("likes").contains(store.myID)])
                } label: {
                    Image(systemName:c.ids("likes").contains(store.myID) ? "heart.fill":"heart").font(.caption).foregroundStyle(c.ids("likes").contains(store.myID) ? .red:.secondary)
                }
                if c.s("author")==store.myID || post.s("author")==store.myID{
                    Menu{
                        if post.s("author")==store.myID{
                            Button(c.b("hidden") ? "Mostra commento":"Nascondi agli altri",systemImage:"eye.slash"){
                                store.perform("hideComment",["id":c.id,"enabled":!c.b("hidden")])
                            }
                        }
                        Button("Elimina",systemImage:"trash",role:.destructive){
                            remove=IdentifiedRow(row:c)
                        }
                    } label: {
                        Image(systemName:"ellipsis").padding(.top,8)
                    }
                }
            }
        }
        .padding(.leading,c.s("parent").isEmpty ? 0:38)
    }
    func send(){
        let value=text
        text=""
        let parent=reply
        reply=""
        Task{
            do{
                try await store.act("comment",["id":postID,"text":value,"parent":parent])
            }
            catch{
                text=value
                store.error=error.localizedDescription
            }
        }
    }
}
@MainActor
struct SharePostView:View{
    @EnvironmentObject var store:GpixStore
    @Environment(\.dismiss) var dismiss
    let postID:String
    var body:some View{
        NavigationStack{
            List{
                ForEach(store.threads,id:\.id){
                    t in Button{
                        Task{
                            do{
                                try await store.act("sharePost",["id":t.id,"post":postID])
                                dismiss()
                            }
                            catch{
                                store.error=error.localizedDescription
                            }
                        }
                    } label: {
                        PersonLine(person:store.peer(t),subtitle:store.threadTitle(t))
                    }
                }
                ShareLink(item:URL(string:"https://gpix.cc/?post=\(postID)")!){
                    Label("Condividi link",systemImage:"square.and.arrow.up")
                }
            }
            .navigationTitle("Invia a").toolbar{
                Button("Fine"){
                    dismiss()
                }
            }
        }
    }
}
@MainActor
struct RequestsView:View{
    @EnvironmentObject var store:GpixStore
    @State private var accepted:Set<String>=[]
    @State private var order:[String]=[]
    @State private var query=""
    @State private var manage=false
    @State private var selection:Set<String>=[]
    var ids:[String]{
        order.filter{
            (store.state.ids("requests").contains($0)||accepted.contains($0)) && (query.isEmpty || (store.person($0).s("username")+store.person($0).s("name")).localizedCaseInsensitiveContains(query))
        }
    }
    var body:some View{
        ScrollView{
            VStack(spacing:22){
                HStack{
                    Image(systemName:"magnifyingglass")
                    TextField("Cerca nome utente o nome visualizzato",text:$query)
                }
                .padding(14).background(Color.secondary.opacity(0.08),in:Capsule()).padding(.top,8)
                NavigationLink{
                    SearchView()
                } label: {
                    HStack(spacing:15){
                        Image(systemName:"sparkle.magnifyingglass").font(.title).padding(14).overlay(Circle().stroke(.primary))
                        VStack(alignment:.leading){
                            Text("Scopri altri profili").font(.subheadline.bold())
                            Text("Vedi suggerimenti non personalizzati").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName:"chevron.right").foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
                ForEach(ids,id:\.self){
                    id in HStack(spacing:10){
                        if manage && !accepted.contains(id){
                            Button{
                                if selection.contains(id){
                                    selection.remove(id)
                                }
                                else{
                                    selection.insert(id)
                                }
                            } label: {
                                Image(systemName:selection.contains(id) ? "checkmark.circle.fill":"circle")
                            }
                        }
                        NavigationLink{
                            ProfileView(userID:id)
                        } label: {
                            PersonLine(person:store.person(id),subtitle:accepted.contains(id) ? "Richiesta accettata":mutual(id))
                        }
                        if accepted.contains(id){
                            Button(store.following(id) ? "Segui già":store.pending(id) ? "Richiesta inviata":"Segui anche tu"){
                                store.perform("follow",["user":id,"enabled":!store.pending(id)])
                            }
                            .buttonStyle(RequestButton(primary:true)).disabled(store.following(id))
                        }
                        else{
                            Button("Conferma"){
                                accept(id)
                            }
                            .buttonStyle(RequestButton(primary:true))
                            Button("Elimina"){
                                store.perform("accept",["user":id,"enabled":false])
                            }
                            .buttonStyle(RequestButton(primary:false))
                        }
                    }
                }
                if ids.isEmpty{
                    EmptyViewCard(icon:"person.badge.plus",title:"Nessuna richiesta",subtitle:"Le nuove richieste appariranno qui.").padding(.top,50)
                }
                if manage && !selection.isEmpty{
                    PrimaryButton(title:"Conferma \(selection.count) richieste"){
                        Task{
                            for id in selection {
                                do{
                                    try await store.act("accept",["user":id])
                                    accepted.insert(id)
                                }
                                catch{
                                    store.error=error.localizedDescription
                                }
                            }
                            selection=[]
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Richieste di seguirti").navigationBarTitleDisplayMode(.inline).toolbar{
            Button(manage ? "Fine":"Gestisci"){
                manage.toggle()
            }
        }
        .onAppear{
            appendOrder()
        }
        .onReceive(store.$state){
            _ in appendOrder()
        }
    }
    func appendOrder(){
        for id in store.state.ids("requests") where !order.contains(id){
            order.append(id)
        }
    }
    func mutual(_ id:String)->String{
        let count=Int(store.state.row("requestDetails").row(id).n("mutualCount"))
        return count>0 ? "\(count) in comune":store.person(id).s("username")
    }
    func accept(_ id:String){
        Task{
            do{
                try await store.act("accept",["user":id])
                accepted.insert(id)
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
}
struct RequestButton:ButtonStyle{
    let primary:Bool
    func makeBody(configuration:Configuration)->some View{
        configuration.label.font(.system(size:12,weight:.semibold)).lineLimit(1).minimumScaleFactor(0.8).padding(.horizontal,11).padding(.vertical,12).background(primary ? gpixPurple:Color.secondary.opacity(0.10),in:RoundedRectangle(cornerRadius:11)).foregroundStyle(primary ? .white:.primary).opacity(configuration.isPressed ? 0.65:1)
    }
}
@MainActor
struct SearchView:View{
    @EnvironmentObject var store:GpixStore
    @State private var query=""
    var people:[Row]{
        store.users.filter{
            $0.id != store.myID && (query.isEmpty || ($0.s("name")+$0.s("username")).localizedCaseInsensitiveContains(query))
        }
    }
    var body:some View{
        ScrollView{
            VStack(alignment:.leading,spacing:18){
                HStack{
                    Image(systemName:"magnifyingglass")
                    TextField("Cerca",text:$query).onSubmit{
                        store.remember(query)
                    }
                    if !query.isEmpty{
                        Button{
                            query=""
                        } label: {
                            Image(systemName:"xmark.circle.fill")
                        }
                    }
                }
                .padding(14).background(Color.secondary.opacity(0.08),in:Capsule())
                if query.isEmpty && !store.history().isEmpty{
                    HStack{
                        Text("Ricerche recenti").bold()
                        Spacer()
                        Button("Cancella cronologia"){
                            store.clearHistory()
                        }
                        .font(.caption)
                    }
                    ForEach(store.history(),id:\.self){
                        value in Button{
                            query=value
                            store.remember(value)
                        } label: {
                            Label(value,systemImage:"clock.arrow.circlepath").foregroundStyle(.primary)
                        }
                    }
                    Divider()
                }
                ForEach(people,id:\.id){
                    p in NavigationLink{
                        ProfileView(userID:p.id).onAppear{
                            store.remember(query.isEmpty ? p.s("username"):query)
                        }
                    } label: {
                        PersonLine(person:p)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Cerca").navigationBarTitleDisplayMode(.inline)
    }
}
@MainActor
struct ActivityView:View{
    @EnvironmentObject var store:GpixStore
    var body:some View{
        List{
            NavigationLink{
                RequestsView()
            } label: {
                Label("Richieste di seguirti · \(store.state.ids("requests").count)",systemImage:"person.badge.plus")
            }
            ForEach(store.state.rows("notifications").filter{
                !["messageReaction","message","instant","call"].contains($0.s("type"))
            }
            ,id:\.id){
                n in NavigationLink{
                    ProfileView(userID:n.s("actor")).onAppear{
                        store.perform("notificationsRead",["id":n.id])
                    }
                } label: {
                    PersonLine(person:store.person(n.s("actor")),subtitle:label(n)+" · "+ago(n.n("created")))
                }
            }
        }
        .navigationTitle("Notifiche").toolbar{
            Button("Segna lette"){
                store.perform("notificationsRead")
            }
        }
    }
    func label(_ n:Row)->String{
        switch n.s("type"){
            case "storyLike":return "Ha messo Mi piace alla tua storia"
            case "like":return "Ha messo Mi piace al tuo post"
            case "comment":return "Ha commentato il tuo post"
            case "followRequest":return "Vuole seguirti"
            case "followAccepted":return "Ha accettato la tua richiesta"
            case "follow":return "Ha iniziato a seguirti"
            case "noteLike":return "Ha messo Mi piace alla tua nota"
            case "repost":return "Ha ripubblicato il tuo post"
            default:return "Nuova attività"
        }
    }
}
