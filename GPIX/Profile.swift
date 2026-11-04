import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
@MainActor
struct ProfileView:View{
    @EnvironmentObject var store:GpixStore
    let userID:String
    @State private var section=0
    @State private var edit=false
    @State private var create=false
    @State private var links=false
    @State private var people=false
    @State private var story=false
    var person:Row{
        store.person(userID)
    }
    var mine:Bool{
        userID==store.myID
    }
    var grid:[Row] {
        let pins=person.ids("pinnedPosts")
        let order=person.ids("gridOrder")
        let all=store.posts.filter{
            !$0.b("archived") && $0.s("kind") != "story"
        }
        let rows:[Row]
        if section==3 {
            rows=all.filter{
                $0.row("style").ids("taggedUsers").contains(userID)
            }
        }
        else if section==2 {
            rows=all.filter{
                $0.ids("reposts").contains(userID)
            }
        }
        else {
            rows=all.filter{
                $0.s("author")==userID && (section != 1 || $0.s("kind")=="reel")
            }
        }
        return rows.sorted {
            a,b in
            let ai=pins.firstIndex(of:a.id) ?? 999
            let bi=pins.firstIndex(of:b.id) ?? 999
            if ai != bi {
                return ai<bi
            }
            return (order.firstIndex(of:a.id) ?? 999) < (order.firstIndex(of:b.id) ?? 999)
        }
    }
    var body:some View{
        ScrollView{
            VStack(alignment:.leading,spacing:16){
                HStack(spacing:20){
                    Button{
                        if !store.visibleStories(userID).isEmpty{
                            story=true
                        }
                        else if mine{
                            create=true
                        }
                    } label: {
                        AvatarView(person:person,size:86,ring:store.unseenStories(userID)).overlay(alignment:.bottomTrailing){
                            if mine{
                                Image(systemName:"plus.circle.fill").font(.title3).symbolRenderingMode(.palette).foregroundStyle(.white,.primary)
                            }
                        }
                    }
                    VStack(alignment:.leading,spacing:13){
                        Text(person.s("name")).font(.system(size:16,weight:.semibold))
                        HStack(spacing:22){
                            stat(Int(person.n("postCount",Double(grid.count))),title:"post")
                            stat(Int(person.n("followers")),title:"follower")
                            stat(Int(person.n("following")),title:"seguiti")
                        }
                    }
                    Spacer(minLength:0)
                }
                VStack(alignment:.leading,spacing:4){
                    if !person.s("pronouns").isEmpty{
                        Text(person.s("pronouns")).foregroundStyle(.secondary)
                    }
                    Text(person.s("bio")).font(.subheadline)
                }
                ScrollView(.horizontal,showsIndicators:false){
                    HStack(spacing:8){
                        ForEach(Array(person.rows("links").enumerated()),id:\.offset){
                            _,link in if let url=URL(string:link.s("url")){
                                Link(destination:ProfileLinks.deepLink(link) ?? url){
                                    Label(link.s("title"),systemImage:ProfileLinks.icon(link.s("type"))).font(.system(size:13,weight:.semibold)).padding(.horizontal,12).padding(.vertical,9).overlay(Capsule().stroke(.secondary.opacity(0.25)))
                                }
                            }
                        }
                        if mine{
                            Button{
                                links=true
                            } label: {
                                Label("Aggiungi",systemImage:"plus").font(.system(size:13,weight:.semibold)).fixedSize().padding(.horizontal,13).padding(.vertical,9).background(Color(uiColor:.systemBackground),in:Capsule()).overlay(Capsule().stroke(Color.primary.opacity(0.14)))
                            }
                        }
                    }
                }
                .foregroundStyle(.primary)
                HStack(spacing:8){
                    if mine{
                        Button("Modifica"){
                            edit=true
                        }
                        .buttonStyle(ProfileButton())
                        ShareLink(item:URL(string:"https://gpix.cc/?profile=\(person.s("username"))")!){
                            Text("Condividi profilo")
                        }
                        .buttonStyle(ProfileButton())
                        Button{
                            people.toggle()
                        } label: {
                            Image(systemName:"person.badge.plus")
                        }
                        .buttonStyle(ProfileButton())
                    }
                    else{
                        Button(store.following(userID) ? "Segui già":store.pending(userID) ? "Richiesta inviata":"Segui"){
                            store.perform("follow",["user":userID,"enabled":!(store.following(userID)||store.pending(userID))])
                        }
                        .buttonStyle(ProfileButton())
                        NavigationLink{
                            ChatStartView(userID:userID)
                        } label: {
                            Text("Messaggio")
                        }
                        .buttonStyle(ProfileButton())
                    }
                }
                if people{
                    Text("Persone suggerite").font(.headline)
                    ScrollView(.horizontal,showsIndicators:false){
                        HStack(spacing:12){
                            ForEach(store.users.filter{
                                $0.id != userID && $0.id != store.myID
                            }
                            ,id:\.id){
                                p in VStack(spacing:12){
                                    AvatarView(person:p,size:72)
                                    Text(p.s("name")).font(.subheadline.bold())
                                    Button(store.following(p.id) ? "Segui già":"Segui"){
                                        store.perform("follow",["user":p.id,"enabled":!store.following(p.id)])
                                    }
                                    .buttonStyle(RequestButton(primary:true))
                                }
                                .frame(width:145).padding(16).overlay(RoundedRectangle(cornerRadius:18).stroke(.secondary.opacity(0.2)))
                            }
                        }
                    }
                }
                highlights
                HStack{
                    ForEach(Array(["square.grid.3x3","play.rectangle","arrow.2.squarepath","person.crop.square"].enumerated()),id:\.offset){
                        index,icon in Button{
                            section=index
                        } label: {
                            Image(systemName:icon).font(.system(size:24,weight:.medium)).frame(maxWidth:.infinity).padding(.vertical,10).foregroundStyle(section==index ? Color.primary:Color.secondary).overlay(alignment:.bottom){
                                if section==index{
                                    Rectangle().frame(height:2)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal,-16)
                if person.b("private") && !mine && !store.following(userID){
                    EmptyViewCard(icon:"lock",title:"Questo account è privato",subtitle:"Segui questo account per vedere foto e video.")
                }
                else if grid.isEmpty{
                    EmptyViewCard(icon:section==3 ? "person.crop.square":"photo",title:section==3 ? "Foto con te":"Ancora nessun contenuto",subtitle:section==3 ? "Le foto in cui vieni menzionato compariranno qui.":"I contenuti di questo profilo compariranno qui.")
                }
                else{
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:2),count:3),spacing:2){
                        ForEach(grid,id:\.id){
                            p in NavigationLink{
                                PostDetailView(postID:p.id)
                            } label: {
                                ProfilePostMedia(post:p).aspectRatio(0.8,contentMode:.fit).overlay(alignment:.topTrailing){
                                    if person.ids("pinnedPosts").contains(p.id){
                                        Image(systemName:"pin.fill").foregroundStyle(.white).padding(8).shadow(radius:3)
                                    }
                                    else if p.s("kind")=="reel"{
                                        Image(systemName:"play.fill").foregroundStyle(.white).padding(8)
                                    }
                                }
                            }
                            .contextMenu{
                                if mine{
                                    Button("Fissa / rimuovi",systemImage:"pin"){
                                        store.perform("pinPost",["id":p.id,"enabled":!person.ids("pinnedPosts").contains(p.id)])
                                    }
                                    Button("Archivia",systemImage:"archivebox"){
                                        store.perform("archivePost",["id":p.id])
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal,-16)
                }
            }
            .padding(16)
        }
        .navigationBarTitleDisplayMode(.inline).toolbar{
            ToolbarItem(placement:.principal){
                HStack(spacing:6){
                    if person.b("private"){
                        Image(systemName:"lock").font(.caption)
                    }
                    Text(person.s("username")).font(.title3.bold())
                }
            }
            ToolbarItem(placement:.navigationBarLeading){
                if mine{
                    Button{
                        create=true
                    } label: {
                        Image(systemName:"plus").font(.title2)
                    }
                }
            }
            ToolbarItem(placement:.navigationBarTrailing){
                if mine{
                    NavigationLink{
                        SettingsView()
                    } label: {
                        Image(systemName:"line.3.horizontal").font(.title2)
                    }
                }
                else{
                    Menu{
                        Button("Blocca",systemImage:"hand.raised",role:.destructive){
                            store.perform("block",["user":userID])
                        }
                        Button("Aggiungi agli amici più stretti",systemImage:"star"){
                            store.perform("closeFriend",["user":userID,"enabled":!store.state.ids("closeFriends").contains(userID)])
                        }
                    } label: {
                        Image(systemName:"ellipsis")
                    }
                }
            }
        }
        .sheet(isPresented:$edit){
            EditProfileView()
        }
        .sheet(isPresented:$links){
            ProfileLinks()
        }
        .sheet(isPresented:$create){
            ComposerView(kind:"post")
        }
        .fullScreenCover(isPresented:$story){
            StoryViewer(userID:userID)
        }
    }
    func stat(_ count:Int,title:String)->some View{
        NavigationLink{
            PeopleListView(title:title,ids:person.ids(title=="follower" ? "followersList":"followingList"))
        } label: {
            VStack(alignment:.leading,spacing:2){
                Text("\(count)").font(.system(size:18,weight:.semibold))
                Text(title).font(.system(size:13))
            }
            .foregroundStyle(.primary)
        }
    }
    var highlights:some View{
        ScrollView(.horizontal,showsIndicators:false){
            HStack(spacing:19){
                if mine{
                    NavigationLink{
                        HighlightEditor()
                    } label: {
                        VStack{
                            Image(systemName:"plus").font(.title).frame(width:66,height:66).overlay(Circle().stroke(.secondary.opacity(0.2),lineWidth:2))
                            Text("Nuova").font(.caption)
                        }
                    }
                }
                ForEach(store.state.rows("highlights").filter{
                    $0.s("owner")==userID
                }
                ,id:\.id){
                    h in NavigationLink{
                        HighlightViewer(highlight:h)
                    } label: {
                        VStack{
                            MediaView(reference:store.post(h.ids("posts").first ?? "").s("media"),fill:true).frame(width:66,height:66).clipShape(Circle())
                            Text(h.s("title")).font(.caption)
                        }
                    }
                    .contextMenu{
                        if mine{
                            Button("Elimina",role:.destructive){
                                store.perform("deleteHighlight",["id":h.id])
                            }
                        }
                    }
                }
            }
            .foregroundStyle(.primary)
        }
    }
}
struct ProfileButton:ButtonStyle{
    func makeBody(configuration:Configuration)->some View{
        configuration.label.font(.system(size:13,weight:.semibold)).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth:.infinity,minHeight:38).padding(.horizontal,8).background(Color(uiColor:.secondarySystemBackground),in:RoundedRectangle(cornerRadius:11)).foregroundStyle(Color.primary).scaleEffect(configuration.isPressed ? 0.98:1).opacity(configuration.isPressed ? 0.7:1)
    }
}
@MainActor
struct PeopleListView:View{
    let title:String
    let ids:[String]
    @EnvironmentObject var store:GpixStore
    var body:some View{
        List(ids,id:\.self){
            id in NavigationLink{
                ProfileView(userID:id)
            } label: {
                PersonLine(person:store.person(id))
            }
        }
        .navigationTitle(title.capitalized)
    }
}
@MainActor
struct PostDetailView:View{
    let postID:String
    @EnvironmentObject var store:GpixStore
    var body:some View{
        ScrollView{
            if store.post(postID).s("kind")=="reel"{
                NativeVideo(reference:store.post(postID).s("media")).frame(height:500)
            }
            else{
                PostCard(post:store.post(postID))
            }
        }
        .navigationTitle("Post").navigationBarTitleDisplayMode(.inline)
    }
}
@MainActor
struct EditProfileView:View{
    @EnvironmentObject var store:GpixStore
    @Environment(\.dismiss) var dismiss
    @State private var name=""
    @State private var username=""
    @State private var bio=""
    @State private var pronouns=""
    @State private var gender=""
    @State private var image:PhotosPickerItem?
    @State private var avatar=""
    @State private var busy=false
    var body:some View{
        NavigationStack{
            Form{
                Section{
                    VStack(spacing:15){
                        AvatarView(person:avatar.isEmpty ? store.me:["avatar":avatar],size:100)
                        PhotosPicker(selection:$image,matching:.images){
                            Text("Modifica immagine del profilo").font(.headline)
                        }
                    }
                    .frame(maxWidth:.infinity).padding(.vertical,18)
                }
                Section{
                    TextField("Nome",text:$name)
                    TextField("Nome utente",text:$username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Pronomi",text:$pronouns)
                    TextField("Biografia",text:$bio,axis:.vertical).lineLimit(3...6)
                    NavigationLink("Link"){
                        ProfileLinks(embedded:true)
                    }
                    Picker("Genere",selection:$gender){
                        ForEach(["","Uomo","Donna","Non binario","Preferisco non specificarlo"],id:\.self){
                            Text($0.isEmpty ? "Non specificato":$0)
                        }
                    }
                }
                Section{
                    NavigationLink("Riordina griglia"){
                        GridOrderView()
                    }
                    NavigationLink("Informazioni personali"){
                        AccountView()
                    }
                }
            }
            .navigationTitle("Modifica profilo").navigationBarTitleDisplayMode(.inline).toolbar{
                ToolbarItem(placement:.cancellationAction){
                    Button("Annulla"){
                        dismiss()
                    }
                }
                ToolbarItem(placement:.confirmationAction){
                    Button(busy ? "Attendi…":"Fine"){
                        save()
                    }
                    .disabled(busy)
                }
            }
            .onAppear{
                name=store.me.s("name")
                username=store.me.s("username")
                bio=store.me.s("bio")
                pronouns=store.me.s("pronouns")
                gender=store.me.s("gender")
            }
            .onChange(of:image){
                _, item in Task{
                    if let data=try? await item?.loadTransferable(type:Data.self),let img=UIImage(data:data),let jpeg=img.jpegData(compressionQuality:0.9){
                        busy=true
                        defer{
                            busy=false
                        }
                        do{
                            let m=try await store.upload(jpeg,mime:"image/jpeg")
                            avatar=m.s("id")
                        }
                        catch{
                            store.error=error.localizedDescription
                        }
                    }
                }
            }
        }
    }
    func save(){
        busy=true
        Task{
            defer{
                busy=false
            }
            do{
                var payload:Row=["name":name,"username":username,"bio":bio,"pronouns":pronouns,"gender":gender]
                if !avatar.isEmpty{
                    payload["avatar"]=avatar
                }
                try await store.act("profile",payload)
                dismiss()
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
}
@MainActor
struct ProfileLinks:View{
    @EnvironmentObject var store:GpixStore
    @Environment(\.dismiss) var dismiss
    var embedded=false
    @State private var links:[Row]=[]
    @State private var type="website"
    @State private var value=""
    @State private var title=""
    @State private var adding=false
    static let kinds=["website","instagram","facebook","threads","whatsapp","telegram","tiktok","youtube","x"]
    static func icon(_ type:String)->String{
        ["website":"globe","instagram":"camera","facebook":"f.circle","threads":"at","whatsapp":"phone.bubble","telegram":"paperplane","tiktok":"music.note","youtube":"play.rectangle","x":"x.circle"][type] ?? "link"
    }
    static func deepLink(_ row:Row)->URL?{
        let type=row.s("type"),value=row.s("value")
        let strings=["instagram":"instagram://user?username=\(value)","facebook":"fb://profile/\(value)","whatsapp":"whatsapp://send?phone=\(value)","telegram":"tg://resolve?domain=\(value)"]
        guard let text=strings[type],let url=URL(string:text),UIApplication.shared.canOpenURL(url)else{
            return nil
        }
        return url
    }
    var content:some View{
        List{
            Section("I tuoi collegamenti"){
                ForEach(Array(links.enumerated()),id:\.offset){
                    index,row in HStack{
                        Image(systemName:Self.icon(row.s("type")))
                        VStack(alignment:.leading){
                            Text(row.s("title"))
                            Text(row.s("value",row.s("url"))).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete{
                    links.remove(atOffsets:$0)
                    save()
                }
                Button{
                    adding=true
                } label: {
                    Label("Aggiungi collegamento",systemImage:"plus")
                }
                .disabled(links.count>=5)
            }
            Section{
                Text("Per i social inserisci il nome utente; per WhatsApp il numero completo di prefisso. Per un sito inserisci l’indirizzo HTTPS.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Link").onAppear{
            links=store.me.rows("links")
        }
        .sheet(isPresented:$adding){
            NavigationStack{
                Form{
                    Picker("Tipo",selection:$type){
                        ForEach(Self.kinds,id:\.self){
                            Label($0.capitalized,systemImage:Self.icon($0))
                        }
                    }
                    TextField(type=="website" ? "https://…":type=="whatsapp" ? "Numero con prefisso":"Nome utente",text:$value).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Titolo (facoltativo)",text:$title)
                }
                .navigationTitle("Aggiungi link").toolbar{
                    ToolbarItem(placement:.cancellationAction){
                        Button("Annulla"){
                            adding=false
                        }
                    }
                    ToolbarItem(placement:.confirmationAction){
                        Button("Aggiungi"){
                            links.append(["type":type,"value":value,"title":title])
                            save()
                            value=""
                            title=""
                            adding=false
                        }
                        .disabled(value.isEmpty)
                    }
                }
            }
        }
    }
    var body:some View{
        Group{
            if embedded{
                content
            }
            else{
                NavigationStack{
                    content.toolbar{
                        Button("Fine"){
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    func save(){
        Task{
            do{
                try await store.act("profileLinks",["links":links])
                links=store.me.rows("links")
            }
            catch{
                store.error=error.localizedDescription
                links=store.me.rows("links")
            }
        }
    }
}
@MainActor
struct GridOrderView:View{
    @EnvironmentObject var store:GpixStore
    @State private var ids:[String]=[]
    var body:some View{
        List{
            ForEach(ids,id:\.self){
                id in HStack{
                    MediaView(reference:store.post(id).s("media"),fill:true).frame(width:50,height:60).clipped()
                    Text(store.post(id).s("text")).lineLimit(2)
                }
            }
            .onMove{
                from,to in ids.move(fromOffsets:from,toOffset:to)
            }
        }
        .environment(\.editMode,.constant(.active)).navigationTitle("Riordina griglia").toolbar{
            Button("Salva"){
                store.perform("gridOrder",["ids":ids])
            }
        }
        .onAppear{
            let all=store.posts.filter{
                $0.s("author")==store.myID && $0.s("kind") != "story" && !$0.b("archived")
            }
            .map{
                $0.id
            }
            let savedOrder = store.me.ids("gridOrder")
            let savedIDs = savedOrder.filter { all.contains($0) }
            let remainingIDs = all.filter { !savedOrder.contains($0) }
            ids = savedIDs + remainingIDs
        }
    }
}
