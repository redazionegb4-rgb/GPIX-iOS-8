import SwiftUI
import UIKit
@MainActor
struct InstantBubble:View{
    @EnvironmentObject var store:GpixStore
    var body:some View{
        HStack(spacing:12){
            ZStack{
                RoundedRectangle(cornerRadius:13).fill(gpixGradient).frame(width:52,height:62).rotationEffect(.degrees(-9))
                RoundedRectangle(cornerRadius:13).fill(gpixPurple).frame(width:49,height:59).rotationEffect(.degrees(5))
                Image(systemName:"camera.fill").foregroundStyle(.white).font(.title3)
            }
            VStack(alignment:.leading,spacing:4){
                Text("Istantanee").font(.headline)
                Text("I momenti degli amici, per 24 ore").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName:"chevron.right").foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary).padding(16).background(Color.secondary.opacity(0.07),in:RoundedRectangle(cornerRadius:22))
    }
}
@MainActor
struct InstantsView:View{
    @EnvironmentObject var store:GpixStore
    @State private var received:[Row]=[]
    @State private var active:[Row]=[]
    @State private var selected:IdentifiedRow?
    @State private var camera=false
    @State private var refreshing=false
    @State private var afterViewer=false
    var body:some View{
        ScrollView{
            VStack(alignment:.leading,spacing:25){
                HStack{
                    VStack(alignment:.leading,spacing:6){
                        Text("Un momento. Solo adesso.").font(.title2.bold())
                        Text("Le istantanee restano disponibili per 24 ore.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    NavigationLink{
                        InstantArchiveView()
                    } label: {
                        Image(systemName:"clock.arrow.circlepath").font(.title2)
                    }
                }
                if received.isEmpty{
                    EmptyViewCard(icon:"square.stack.3d.up",title:"Nessuna nuova istantanea",subtitle:"Puoi comunque scattare e condividere la tua.")
                }
                else{
                    ScrollView(.horizontal,showsIndicators:false){
                        HStack(spacing:15){
                            ForEach(received,id:\.id){
                                item in Button{
                                    selected=IdentifiedRow(row:item)
                                } label: {
                                    InstantCard(item:item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(height:340)
                    }
                }
                PrimaryButton(title:"Scatta un’istantanea"){
                    camera=true
                }
                if !active.isEmpty{
                    Text("Le tue istantanee attive").font(.headline)
                    ForEach(active,id:\.id){
                        item in NavigationLink{
                            InstantArchiveView()
                        } label: {
                            HStack{
                                Image(systemName:"camera.on.rectangle")
                                Text(item.s("caption","Istantanea"))
                                Spacer()
                                Label("\(Int(item.n("viewsCount")))",systemImage:"eye")
                            }
                            .font(.subheadline).foregroundStyle(.primary)
                        }
                    }
                }
                NavigationLink{
                    InstantArchiveView()
                } label: {
                    Label("Apri archivio",systemImage:"archivebox")
                }
            }
            .padding(20)
        }
        .navigationTitle("Istantanee").navigationBarTitleDisplayMode(.inline).refreshable{
            await load()
        }
        .task{
            await load()
        }
        .sheet(isPresented:$camera,onDismiss:{
            Task{
                await load()
            }
        }
        ){
            InstantCamera()
        }
        .fullScreenCover(item:$selected,onDismiss:{
            Task{
                await load()
            }
            if afterViewer{
                afterViewer=false
                DispatchQueue.main.asyncAfter(deadline:.now()+0.3){
                    camera=true
                }
            }
        }
        ){
            item in InstantDeck(items:received,startID:item.id){
                afterViewer=true
                selected=nil
            }
        }
    }
    func load()async{
        do{
            let r=try await store.instantList()
            received=r.rows("received")
            active=r.rows("active")
        }
        catch{
            store.error=error.localizedDescription
        }
    }
}
@MainActor
struct InstantCard:View{
    @EnvironmentObject var store:GpixStore
    let item:Row
    @State private var preview:Data?
    var body:some View{
        ZStack(alignment:.bottomLeading){
            RoundedRectangle(cornerRadius:25).fill(gpixGradient)
            if let data=preview,let img=UIImage(data:data){
                Image(uiImage:img).resizable().scaledToFill().frame(width:245,height:325).clipped()
            }
            LinearGradient(colors:[.clear,.black.opacity(0.65)],startPoint:.center,endPoint:.bottom)
            VStack(alignment:.leading,spacing:10){
                HStack{
                    AvatarView(person:store.person(item.s("owner")),size:33)
                    Text(store.person(item.s("owner")).s("username",item.s("username"))).font(.subheadline.bold())
                }
                Text(item.s("caption")).font(.subheadline)
                Label("Tocca per aprire",systemImage:"hand.tap").font(.caption)
            }
            .foregroundStyle(.white).padding(18)
        }
        .frame(width:245,height:325).clipShape(RoundedRectangle(cornerRadius:25)).rotationEffect(.degrees(-2)).task{
            preview=try? await store.instantPhoto(item.id,archive:false,preview:true)
        }
    }
}
@MainActor
struct InstantDeck:View{
    @EnvironmentObject var store:GpixStore
    @Environment(\.dismiss) var dismiss
    let items:[Row],startID:String
    let create: @MainActor () -> Void
    @State private var index=0
    @State private var bytes:Data?
    @State private var opening=false
    @State private var offset=CGSize.zero
    @State private var reply=""
    var current:Row{
        items.indices.contains(index) ? items[index]:[:]
    }
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            nextCard
            VStack {
                deckHeader
                photoContent
                reactionBar
                replyBar
            }
            .foregroundStyle(Color.white)
        }
        .task {
            index = items.firstIndex { $0.id == startID } ?? 0
            await open()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            bytes = nil
            dismiss()
        }
        .onDisappear { bytes = nil }
    }
    @ViewBuilder private var nextCard: some View {
        if index + 1 < items.count {
            InstantCard(item: items[index + 1])
                .scaleEffect(1.1)
                .rotationEffect(.degrees(5))
                .opacity(0.7)
        }
    }
    private var deckHeader: some View {
        HStack {
            Text(store.person(current.s("owner")).s("username", current.s("username"))).bold()
            Spacer()
            Button { dismiss() } label: { Image(systemName: "xmark") }
        }
        .foregroundStyle(Color.white)
        .padding()
    }
    @ViewBuilder private var photoContent: some View {
        if opening {
            ProgressView().tint(Color.white).frame(maxHeight: .infinity)
        } else {
            draggablePhoto
        }
    }
    private var draggablePhoto: some View {
        ProtectedPhoto(data: bytes, onNext: { next() }, showClose: false)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .rotation3DEffect(.degrees(Double(offset.height / 18)), axis: (x: 1, y: 0, z: 0))
            .rotationEffect(.degrees(Double(offset.width / 35)))
            .offset(offset)
            .gesture(cardGesture)
    }
    private var cardGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { offset = $0.translation }
            .onEnded { value in finishDrag(value.translation) }
    }
    private func finishDrag(_ translation: CGSize) {
        if abs(translation.height) > 80 || abs(translation.width) > 70 {
            withAnimation(.easeIn(duration: 0.22)) {
                offset = CGSize(width: translation.width * 3, height: translation.height < 0 ? -900 : 900)
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 230_000_000)
                next()
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { offset = .zero }
        }
    }
    private var reactionBar: some View {
        HStack {
            ForEach(["❤️", "😂", "😍", "🔥"], id: \.self) { emoji in
                Button(emoji) { feedback(emoji, reaction: true) }.font(.title2)
            }
            Spacer()
            Text("\(index + 1)/\(items.count)").font(.caption)
        }
        .padding(.horizontal, 20)
    }
    private var replyBar: some View {
        HStack {
            TextField("Rispondi…", text: $reply).textFieldStyle(.roundedBorder)
            Button("Invia") {
                feedback(reply, reaction: false)
                reply = ""
            }
            .disabled(reply.isEmpty)
        }
        .padding(16)
    }
    func open()async{
        bytes=nil
        opening=true
        defer{
            opening=false
        }
        guard !UIScreen.main.isCaptured,store.foreground else{
            return
        }
        do{
            bytes=try await store.instantPhoto(current.id,archive:false)
        }
        catch{
            store.error=error.localizedDescription
            next()
        }
    }
    func next(){
        bytes=nil
        if index+1<items.count{
            index+=1
            offset = .zero
            Task{
                await open()
            }
        }
        else{
            create()
        }
    }
    func feedback(_ text:String,reaction:Bool){
        Task{
            do{
                _ = try await store.instantFeedback(current.id,text:text,reaction:reaction)
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
}
@MainActor
struct ProtectedPhoto:View{
    let data:Data?
    let onNext: @MainActor () -> Void
    var showClose=true
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) var dismiss
    @State private var captured=UIScreen.main.isCaptured
    @State private var screenshot=false
    var body:some View{
        ZStack{
            Color.black.ignoresSafeArea()
            if phase == .active && !captured && !screenshot,let data=data,let image=UIImage(data:data){
                Image(uiImage:image).resizable().scaledToFit().onTapGesture { onNext() }
            }
            else{
                VStack(spacing:20){
                    Image(systemName:"rectangle.slash").font(.system(size:60))
                    Text("Contenuto protetto").font(.title2.bold())
                    Text("Interrompi la registrazione o duplicazione dello schermo per continuare.").multilineTextAlignment(.center)
                }
                .foregroundStyle(.white).padding(35)
            }
            if showClose{
                VStack{
                    HStack{
                        Button{
                            dismiss()
                        } label: {
                            Image(systemName:"xmark").font(.title2).foregroundStyle(.white).padding()
                        }
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .privacySensitive().onReceive(NotificationCenter.default.publisher(for:UIScreen.capturedDidChangeNotification)){
            _ in captured=UIScreen.main.isCaptured
        }
        .onReceive(NotificationCenter.default.publisher(for:UIApplication.userDidTakeScreenshotNotification)){
            _ in screenshot=true
        }
    }
}
@MainActor
struct InstantCamera:View{
    @EnvironmentObject var store:GpixStore
    @Environment(\.dismiss) var dismiss
    @State private var camera=false
    @State private var image:UIImage?
    @State private var caption=""
    @State private var audience="friends"
    @State private var busy=false
    var body:some View{
        NavigationStack{
            VStack(spacing:20){
                if let image=image{
                    Image(uiImage:image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius:22))
                }
                else{
                    EmptyViewCard(icon:"camera",title:"Scatta il tuo momento",subtitle:"Una foto nuova, disponibile per 24 ore.")
                }
                Button{
                    camera=true
                } label: {
                    Label(image==nil ? "Apri fotocamera":"Scatta di nuovo",systemImage:"camera")
                }
                TextField("Aggiungi un pensiero…",text:$caption).textFieldStyle(.roundedBorder).onChange(of:caption){
                    _, value in caption=String(value.prefix(120))
                }
                Picker("Condividi con",selection:$audience){
                    Text("Amici").tag("friends")
                    Text("Amici più stretti").tag("close")
                }
                .pickerStyle(.segmented)
                PrimaryButton(title:busy ? "Condivisione…":"Condividi istantanea",disabled:image==nil || busy){
                    send()
                }
                Text("Puoi crearla anche senza amici. Scade dopo 24 ore e rimane nel tuo archivio privato.").font(.caption).foregroundStyle(.secondary)
            }
            .padding(22).navigationTitle("Nuova istantanea").toolbar{
                Button("Annulla"){
                    dismiss()
                }
            }
            .sheet(isPresented:$camera){
                CameraPicker(video:false){
                    img,_ in image=img
                    camera=false
                }
            }
        }
    }
    func send(){
        guard let data=image?.jpegData(compressionQuality:0.9)else{
            return
        }
        busy=true
        Task{
            defer{
                busy=false
            }
            do{
                let m=try await store.upload(data,mime:"image/jpeg")
                try await store.sendInstant(media:m.s("id"),caption:caption,audience:audience)
                dismiss()
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
}
@MainActor
struct InstantArchiveView:View{
    @EnvironmentObject var store:GpixStore
    @State private var items:[Row]=[]
    @State private var cursor=""
    @State private var selected:IdentifiedRow?
    @State private var selection:Set<String>=[]
    @State private var selecting=false
    @State private var activeOnly=false
    @State private var create=false
    @State private var recapID=""
    @State private var recapImages:[UIImage]=[]
    @State private var showRecap=false
    var rows:[Row]{
        items.filter{
            !activeOnly || $0.n("expires")>Date().timeIntervalSince1970
        }
    }
    var months:[String]{
        var result:[String]=[]
        for item in rows{
            let key=month(item)
            if !result.contains(key){
                result.append(key)
            }
        }
        return result
    }
    private func archiveMonth(_ key: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(key).font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                ForEach(rows.filter { month($0) == key }, id: \.id) { item in
                    archiveCell(item)
                }
            }
        }
    }
    private func archiveCell(_ item: Row) -> some View {
        Button { selectArchiveItem(item) } label: {
            ArchiveThumb(item: item, selected: selection.contains(item.id))
        }
        .contextMenu { archiveActions(item) }
    }
    @ViewBuilder private func archiveActions(_ item: Row) -> some View {
        Button("Elimina", systemImage: "trash", role: .destructive) { remove(item.id) }
        if item.n("expires") > Date().timeIntervalSince1970 {
            Button("Condividi con gli amici", systemImage: "person.2") { audience(item.id, "friends") }
            Button("Solo amici più stretti", systemImage: "star") { audience(item.id, "close") }
        }
    }
    private func selectArchiveItem(_ item: Row) {
        if !selecting { selected = IdentifiedRow(row: item); return }
        if selection.contains(item.id) { selection.remove(item.id) }
        else if selection.count < 9 { selection.insert(item.id) }
    }
    var body:some View{
        ScrollView{
            VStack(alignment:.leading,spacing:20){
                Label("Solo tu puoi vedere le tue istantanee archiviate, conservate fino a un anno.",systemImage:"lock").font(.caption).foregroundStyle(.secondary).padding(13).frame(maxWidth:.infinity,alignment:.leading).background(Color.secondary.opacity(0.07),in:RoundedRectangle(cornerRadius:17))
                HStack(spacing:10){
                    Button("Tutte"){
                        activeOnly=false
                    }
                    .buttonStyle(RequestButton(primary:!activeOnly))
                    Button("Ultime 24 ore"){
                        activeOnly=true
                    }
                    .buttonStyle(RequestButton(primary:activeOnly))
                    Spacer()
                    Button(selecting ? "Fine":"Seleziona"){
                        selecting.toggle()
                        selection=[]
                    }
                    .font(.caption.bold())
                }
                if rows.isEmpty{
                    EmptyViewCard(icon:"square.grid.2x2",title:"Ancora nessuna istantanea qui",subtitle:"I tuoi momenti saranno raccolti qui, solo per te.")
                }
                ForEach(months, id: \.self) { key in
                    archiveMonth(key)
                }
                if !cursor.isEmpty{
                    Button("Carica precedenti"){
                        Task{
                            await load(more:true)
                        }
                    }
                }
                PrimaryButton(title:selecting ? "Crea riepilogo · \(selection.count)/9":"Crea istantanea",disabled:selecting && selection.isEmpty){
                    if selecting{
                        recap()
                    }
                    else{
                        create=true
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Le tue istantanee").navigationBarTitleDisplayMode(.inline).refreshable{
            await load()
        }
        .task{
            await load()
        }
        .sheet(isPresented:$create,onDismiss:{
            Task{
                await load()
            }
        }
        ){
            InstantCamera()
        }
        .fullScreenCover(item:$selected){
            item in ArchivePhotoView(item:item.row,onDelete:{
                remove(item.id)
            }
            )
        }
        .sheet(isPresented:$showRecap){
            NavigationStack{
                VStack{
                    if let image=recapImages.first{
                        Image(uiImage:image).resizable().scaledToFit()
                    }
                    Text("Il riepilogo verrà pubblicato come storia.").font(.caption)
                    PrimaryButton(title:"Condividi riepilogo"){
                        Task{
                            do{
                                let m=try await store.api("/instants/recap",["ids":Array(selection),"requestKey":recapID])
                                try await store.act("post",["kind":"story","media":m.s("media"),"text":"","idempotencyKey":recapID])
                                showRecap=false
                                selection=[]
                                selecting=false
                            }
                            catch{
                                store.error=error.localizedDescription
                            }
                        }
                    }
                }
                .padding(20).navigationTitle("Riepilogo").toolbar{
                    Button("Annulla"){
                        showRecap=false
                    }
                }
            }
        }
    }
    func month(_ item:Row)->String{
        let f=DateFormatter()
        f.locale=Locale(identifier:"it_IT")
        f.dateFormat="MMMM yyyy"
        return f.string(from:Date(timeIntervalSince1970:item.n("created"))).capitalized
    }
    func load(more:Bool=false)async{
        do{
            let r=try await store.instantArchive(cursor:more ? cursor:"")
            if more{
                items+=r.rows("items")
            }
            else{
                items=r.rows("items")
            }
            cursor=r.s("nextCursor")
        }
        catch{
            store.error=error.localizedDescription
        }
    }
    func remove(_ id:String){
        Task{
            do{
                try await store.deleteInstant(id)
                await load()
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
    func audience(_ id:String,_ audience:String){
        Task{
            do{
                _ = try await store.api("/instants/\(id)/audience",["audience":audience])
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
    func recap(){
        recapID=UUID().uuidString
        Task{
            var images:[UIImage]=[]
            for id in selection{
                if let data=try? await store.instantPhoto(id,archive:true),let image=UIImage(data:data){
                    images.append(image)
                }
            }
            guard !images.isEmpty else{
                return
            }
            let size=CGSize(width:540,height:960)
            let result=UIGraphicsImageRenderer(size:size).image{
                _ in UIColor.black.setFill()
                UIRectFill(CGRect(origin:.zero,size:size))
                let cols=images.count==1 ? 1:images.count<=4 ? 2:3,rows=Int(ceil(Double(images.count)/Double(cols)))
                for (i,image) in images.enumerated(){
                    let rect=CGRect(x:CGFloat(i%cols)*size.width/CGFloat(cols)+3,y:CGFloat(i/cols)*size.height/CGFloat(rows)+3,width:size.width/CGFloat(cols)-6,height:size.height/CGFloat(rows)-6)
                    image.draw(in:rect)
                }
            }
            recapImages=[result]
            showRecap=true
        }
    }
}
@MainActor
struct ArchiveThumb:View{
    @EnvironmentObject var store:GpixStore
    let item:Row
    var selected=false
    @State private var image:UIImage?
    var body:some View{
        GeometryReader{
            g in ZStack(alignment:.bottomLeading){
                Color.secondary.opacity(0.1)
                if let image=image{
                    Image(uiImage:image).resizable().scaledToFill().frame(width:g.size.width,height:g.size.height).clipped()
                }
                LinearGradient(colors:[.clear,.black.opacity(0.5)],startPoint:.center,endPoint:.bottom)
                VStack{
                    HStack{
                        Text(Date(timeIntervalSince1970:item.n("created")).formatted(.dateTime.day())).font(.caption.bold())
                        Spacer()
                        if selected{
                            Image(systemName:"checkmark.circle.fill").foregroundStyle(gpixPurple)
                        }
                    }
                    Spacer()
                    Label("\(Int(item.n("viewsCount")))",systemImage:"eye").font(.system(size:10,weight:.semibold)).frame(maxWidth:.infinity,alignment:.leading)
                }
                .foregroundStyle(.white).padding(8)
            }
        }
        .aspectRatio(1,contentMode:.fit).clipped().task{
            if let data=try? await store.instantPhoto(item.id,archive:true){
                image=UIImage(data:data)
            }
        }
    }
}
@MainActor
struct ArchivePhotoView:View{
    @EnvironmentObject var store:GpixStore
    @Environment(\.dismiss) var dismiss
    let item:Row
    let onDelete: @MainActor () -> Void
    @State private var data:Data?
    @State private var viewers=false
    var body:some View{
        ZStack(alignment:.bottom){
            ProtectedPhoto(data:data,onNext:{
                dismiss()
            }
            )
            HStack{
                Button{
                    viewers=true
                } label: {
                    Label("\(Int(item.n("viewsCount"))) visualizzazioni",systemImage:"eye")
                }
                Spacer()
                Button(role:.destructive){
                    onDelete()
                    dismiss()
                } label: {
                    Image(systemName:"trash")
                }
            }
            .foregroundStyle(.white).padding(25)
        }
        .task{
            do{
                data=try await store.instantPhoto(item.id,archive:true)
            }
            catch{
                store.error=error.localizedDescription
            }
        }
        .sheet(isPresented:$viewers){
            InstantViewers(id:item.id)
        }
    }
}
@MainActor
struct InstantViewers:View{
    @EnvironmentObject var store:GpixStore
    let id:String
    @State private var items:[Row]=[]
    @State private var offset=0
    @State private var total=0
    @State private var more=false
    var body:some View{
        NavigationStack{
            List{
                Text("\(total) visualizzazioni").font(.headline)
                ForEach(Array(items.enumerated()),id:\.offset){
                    _,p in PersonLine(person:["id":p.s("user"),"name":p.s("name"),"username":p.s("username"),"avatar":p.s("avatar")],subtitle:ago(p.n("opened"))+" fa")
                }
                if more{
                    Button("Carica altre"){
                        Task{
                            await load()
                        }
                    }
                }
            }
            .navigationTitle("Visualizzazioni").task{
                await load()
            }
        }
    }
    func load()async{
        do{
            if store.demo{
                items=[]
                return
            }
            let r=try await store.api("/instants/\(id)/viewers?offset=\(offset)")
            items+=r.rows("items")
            total=Int(r.n("total"))
            more=r["nextOffset"] is NSNumber
            offset=Int(r.n("nextOffset"))
        }
        catch{
            store.error=error.localizedDescription
        }
    }
}
extension GpixStore{
    func instantList()async throws->Row{
        if demo{
            return state.row("demoInstants")
        }
        return try await api("/instants")
    }
    func instantArchive(cursor:String)async throws->Row{
        if demo{
            return ["items":state.row("demoInstants").rows("sent"),"nextCursor":""]
        }
        let encoded=cursor.addingPercentEncoding(withAllowedCharacters:.urlQueryAllowed) ?? ""
        return try await api("/instants/archive?cursor="+encoded)
    }
    func instantPhoto(_ id:String,archive:Bool,preview:Bool=false)async throws->Data{
        if demo{
            let r=state.row("demoInstants")
            let item=(r.rows("received")+r.rows("sent")).first{
                $0.id==id
            }
            ?? [:]
            let ref=item.s("media","post1.jpg")
            if let image=localImage(ref),let data=image.jpegData(compressionQuality:0.8){
                if !archive && !preview{
                    var next=r
                    next["received"]=r.rows("received").filter{
                        $0.id != id
                    }
                    state["demoInstants"]=next
                    persistDemo()
                }
                return data
            }
            throw GError(message:"Foto non disponibile")
        }
        return try await bytes("/instants/\(id)/"+(archive ? "archive-photo":preview ? "preview":"open"),payload:archive || preview ? nil:[:])
    }
    func sendInstant(media:String,caption:String,audience:String)async throws{
        if demo{
            var r=state.row("demoInstants"),sent=r.rows("sent")
            let item:Row=["id":UUID().uuidString,"owner":myID,"media":media,"caption":caption,"created":Date().timeIntervalSince1970,"expires":Date().timeIntervalSince1970+86400,"viewsCount":0]
            sent.insert(item,at:0)
            r["sent"]=sent
            r["active"]=sent.filter{
                $0.n("expires")>Date().timeIntervalSince1970
            }
            state["demoInstants"]=r
            return
        }
        _ = try await api("/instants/send",["media":media,"caption":caption,"audience":audience,"requestKey":UUID().uuidString])
    }
    func instantFeedback(_ id:String,text:String,reaction:Bool)async throws->Row{
        if demo{
            return [:]
        }
        return try await api("/instants/\(id)/feedback",["text":text,"kind":reaction ? "reaction":"reply","requestKey":UUID().uuidString])
    }
    func deleteInstant(_ id:String)async throws{
        if demo{
            var r=state.row("demoInstants")
            r["sent"]=r.rows("sent").filter{
                $0.id != id
            }
            state["demoInstants"]=r
            return
        }
        _ = try await api("/instants/\(id)/delete",[:])
    }
}
