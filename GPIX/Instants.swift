import SwiftUI
import UIKit
@MainActor
struct InstantBubble:View{
    @EnvironmentObject var store:GpixStore
    private var paused:Bool { store.preferences.n("instantsSnoozedUntil")>Date().timeIntervalSince1970 }
    private var pile:[Row] { paused ? [] : store.demo ? store.state.row("demoInstants").rows("received") : store.state.rows("instantPile") }
    var body: some View {
        VStack(spacing:0) {
            ZStack {
                ForEach((0..<3).reversed(),id:\.self) { index in
                    RoundedRectangle(cornerRadius:22)
                        .fill(gpixSoft)
                        .overlay(RoundedRectangle(cornerRadius:22).stroke(Color(uiColor:.systemBackground),lineWidth:3))
                        .overlay {
                            if pile.indices.contains(index) { InstantPilePreview(id:pile[index].id).clipShape(RoundedRectangle(cornerRadius:19)) }
                            if index==0 { GpixIcon(systemName:paused ? "pause" : pile.isEmpty ? "camera" : "photo.on.rectangle",size:25).foregroundStyle(pile.isEmpty ? Color.primary : Color.white) }
                        }
                        .frame(width:82,height:88)
                        .rotationEffect(.radians(Double(index)*0.12-0.07))
                        .offset(x:CGFloat(index)*7,y:CGFloat(index)*(-5))
                        .shadow(color:Color.black.opacity(0.15),radius:12,y:5)
                }
            }
            .frame(width:104,height:98)
            Text(paused ? "In pausa" : "Istantanee").font(.gpix(size:11,weight:.semibold))
                .foregroundStyle(Color.primary).padding(.horizontal,11).padding(.vertical,6)
                .background(Color(uiColor:.systemBackground),in:Capsule())
        }
        .frame(width:104,height:126)
        .contextMenu {
            Button(paused ? "Riprendi istantanee" : "Pausa per 24 ore",systemImage:paused ? "play" : "pause") { snooze() }
            NavigationLink { InstantArchiveView() } label: { Label("Archivio privato",systemImage:"archivebox") }
        }
    }
    private func snooze() {
        Task {
            do {
                if store.demo {
                    var prefs=store.preferences
                    prefs["instantsSnoozedUntil"]=paused ? 0 : Date().timeIntervalSince1970+86400
                    store.state["preferences"]=prefs
                } else {
                    _ = try await store.api("/instants/preferences",["paused":!paused])
                    await store.sync()
                }
            } catch { store.error=error.localizedDescription }
        }
    }

}
@MainActor
struct InstantPilePreview:View {
    @EnvironmentObject var store:GpixStore
    let id:String
    @State private var image:UIImage?
    var body:some View {
        GeometryReader { geometry in
            if let image=image {
                Image(uiImage:image).resizable().scaledToFill().frame(width:geometry.size.width,height:geometry.size.height).clipped()
            }
        }
        .task(id:id) {
            if let data=try? await store.instantPhoto(id,archive:false,preview:true) { image=UIImage(data:data) }
        }
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
    @State private var filter="all"
    @State private var ownSelected:IdentifiedRow?
    private var owners:[String] {
        var result:[String]=[]
        for row in received { let owner=row.s("owner"); if !result.contains(owner) { result.append(owner) } }
        return result
    }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:0) {
                Text("Nuovi momenti").font(.gpix(size:27,weight:.bold)).tracking(-0.6)
                Text("Apri le card degli amici. Scatta e condividi le tue.").foregroundStyle(gpixMuted).padding(.top,8)
                if store.demo { Text("Stai provando la demo").font(.gpix(size:12)).foregroundStyle(gpixMuted).padding(.top,10) }
                createCard.padding(.top,22)
                filters.padding(.top,20)
                if filter != "mine" { friendsSection }
                if filter != "new" { ownSection }
                NavigationLink { InstantArchiveView() } label: {
                    HStack(spacing:16) {
                        Image(systemName:"archivebox").font(.gpix(size:28))
                        VStack(alignment:.leading,spacing:4) {
                            Text("Il tuo archivio").font(.gpix(size:16,weight:.bold))
                            Text("Solo tuo. Rivedi, elimina o crea un riepilogo.").font(.gpix(size:12)).foregroundStyle(gpixMuted)
                        }
                        Spacer(minLength:0)
                        Image(systemName:"chevron.right").font(.gpix(size:18))
                    }.foregroundStyle(gpixInk).padding(.horizontal,18).padding(.vertical,20).background(gpixSoft,in:RoundedRectangle(cornerRadius:23))
                }.padding(.top,28)
            }.padding(.horizontal,18).padding(.top,12).padding(.bottom,40)
        }
        .navigationTitle("Istantanee").navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }.task { await load() }
        .sheet(isPresented:$camera,onDismiss:{ Task { await load() } }) { InstantCamera() }
        .fullScreenCover(item:$selected,onDismiss:{
            Task { await load() }
            if afterViewer { afterViewer=false; Task { @MainActor in try? await Task.sleep(nanoseconds:300_000_000); camera=true } }
        }) { item in InstantDeck(items:received,startID:item.id) { afterViewer=true; selected=nil } }
        .fullScreenCover(item:$ownSelected,onDismiss:{ Task { await load() } }) { item in
            ArchivePhotoView(item:item.row,onDelete:{ Task { try? await store.deleteInstant(item.id); await load() } })
        }
    }
    private var createCard:some View {
        Button { camera=true } label: {
            HStack(spacing:15) {
                GpixIcon(systemName:"camera",size:29).frame(width:54,height:54).background(Color.white.opacity(0.17),in:RoundedRectangle(cornerRadius:18))
                VStack(alignment:.leading,spacing:5) {
                    Text("Crea un’istantanea").font(.gpix(size:19,weight:.bold))
                    Text("Scatta ora. Condividi il tuo momento.").font(.gpix(size:12)).foregroundStyle(Color.white.opacity(0.7))
                }
                Spacer(minLength:6)
                Image(systemName:"plus").font(.gpix(size:25))
            }.foregroundStyle(Color.white).padding(21)
                .background(LinearGradient(colors:[Color(red:103.0/255,green:72.0/255,blue:246.0/255),Color(red:189.0/255,green:72.0/255,blue:199.0/255)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:26))
        }.buttonStyle(GpixPressStyle())
    }
    private var filters:some View {
        HStack(spacing:8) {
            filterChip("all","Tutte")
            filterChip("new","Da aprire")
            filterChip("mine","Le tue")
        }
    }
    private func filterChip(_ id:String,_ title:String)->some View {
        Button { filter=id } label: {
            HStack(spacing:6) { if filter==id { Image(systemName:"checkmark").font(.gpix(size:13,weight:.semibold)) }; Text(title).font(.gpix(size:14,weight:.medium)) }
                .foregroundStyle(gpixInk).padding(.horizontal,14).padding(.vertical,9)
                .background(filter==id ? gpixPurple.opacity(0.13) : Color.clear,in:RoundedRectangle(cornerRadius:9))
                .overlay(RoundedRectangle(cornerRadius:9).stroke(gpixMuted.opacity(filter==id ? 0:0.35)))
        }.buttonStyle(.plain)
    }
    private func sectionHeading(_ title:String,_ detail:String)->some View {
        HStack { Text(title).font(.gpix(size:22,weight:.bold)); Spacer(); Text(detail).font(.gpix(size:12)).foregroundStyle(gpixMuted) }.padding(.top,25).padding(.bottom,14)
    }
    private var friendsSection:some View {
        VStack(alignment:.leading,spacing:0) {
            sectionHeading("Dai tuoi amici","\(received.count) nuove")
            if owners.isEmpty {
                VStack(spacing:12) {
                    Image(systemName:"photo.on.rectangle").font(.gpix(size:35)).foregroundStyle(gpixMuted)
                    Text("Nessuna nuova istantanea").font(.gpix(size:17,weight:.semibold))
                    Text("Quando arrivano nuovi scatti, li trovi qui.\nIntanto puoi creare il tuo.").multilineTextAlignment(.center).foregroundStyle(gpixMuted)
                }.padding(24).frame(maxWidth:.infinity).background(gpixSoft,in:RoundedRectangle(cornerRadius:24))
            } else {
                LazyVGrid(columns:[GridItem(.flexible(),spacing:12),GridItem(.flexible())],spacing:12) {
                    ForEach(owners,id:\.self) { owner in friendCard(owner) }
                }
            }
        }
    }
    private func friendCard(_ owner:String)->some View {
        let rows=received.filter { $0.s("owner")==owner }
        return Button { if let first=rows.first { selected=IdentifiedRow(row:first) } } label: {
            CollectionInstantCard(item:rows.first ?? [:],count:rows.count,own:false)
        }.buttonStyle(GpixPressStyle())
    }
    private var ownSection:some View {
        VStack(alignment:.leading,spacing:0) {
            sectionHeading("Le tue · 24 ore","\(active.count) attive")
            if active.isEmpty {
                HStack(spacing:16) {
                    GpixIcon(systemName:"camera",size:31).foregroundStyle(gpixMuted)
                    Text("Il prossimo istante è tuo.\nPuoi pubblicare anche senza amici.").foregroundStyle(gpixMuted)
                }.padding(20).frame(maxWidth:.infinity,alignment:.leading).overlay(RoundedRectangle(cornerRadius:23).stroke(gpixMuted.opacity(0.25)))
            } else {
                LazyVGrid(columns:[GridItem(.flexible(),spacing:12),GridItem(.flexible())],spacing:12) {
                    ForEach(active,id:\.id) { item in
                        Button { ownSelected=IdentifiedRow(row:item) } label: { CollectionInstantCard(item:item,count:1,own:true) }.buttonStyle(GpixPressStyle())
                    }
                }
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
    private var cardWidth: CGFloat { min(290,max(220,UIScreen.main.bounds.width-86)) }
    var body: some View {
        VStack(alignment:.leading,spacing:0) {
            previewPhoto
            HStack(spacing:10) {
                AvatarView(person:store.person(item.s("owner")),size:34)
                VStack(alignment:.leading,spacing:3) {
                    Text(store.person(item.s("owner")).s("username",item.s("username"))).font(.gpix(size:14,weight:.semibold)).lineLimit(1)
                    Text("Tocca per aprire").font(.gpix(size:11)).foregroundStyle(Color.secondary)
                }
                Spacer(minLength:0)
                GpixIcon(systemName:"arrow.up.right",size:13).foregroundStyle(Color.secondary)
            }
            .padding(13)
        }
        .foregroundStyle(Color.primary).frame(width:cardWidth)
        .background(gpixSoft,in:RoundedRectangle(cornerRadius:25))
        .clipShape(RoundedRectangle(cornerRadius:25))
        .overlay(RoundedRectangle(cornerRadius:25).stroke(Color.primary.opacity(0.07)))
        .shadow(color:Color.black.opacity(0.06),radius:12,y:5)
        .task(id:item.id) { preview=try? await store.instantPhoto(item.id,archive:false,preview:true) }
    }
    private var previewPhoto: some View {
        ZStack(alignment:.bottomLeading) {
            Color.black.opacity(0.92)
            if let data=preview,let image=UIImage(data:data) {
                Image(uiImage:image).resizable().scaledToFill().frame(width:cardWidth,height:290).blur(radius:20).clipped().opacity(0.55)
                Image(uiImage:image).resizable().scaledToFit().frame(width:cardWidth,height:290)
            } else {
                ProgressView().tint(Color.white).frame(width:cardWidth,height:290)
            }
            LinearGradient(colors:[Color.clear,Color.black.opacity(0.55)],startPoint:.center,endPoint:.bottom)
            if !item.s("caption").isEmpty {
                Text(item.s("caption")).font(.gpix(size:14,weight:.medium)).foregroundStyle(Color.white).lineLimit(2).padding(16)
            }
        }
        .frame(width:cardWidth,height:290).clipped()
        .overlay(alignment:.topTrailing) {
            GpixIcon(systemName:"lock.fill",size:11).foregroundStyle(Color.white).padding(9).background(Color.black.opacity(0.3),in:Circle()).padding(12)
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
                Button(emoji) { feedback(emoji, reaction: true) }.font(.gpix(size:22,weight:.regular))
            }
            Spacer()
            Text("\(index + 1)/\(items.count)").font(.gpix(size:12,weight:.regular))
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
                    GpixIcon(systemName:"rectangle.slash",size:60)
                    Text("Contenuto protetto").font(.gpix(size:22,weight:.bold))
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
                            Image(systemName:"xmark").font(.gpix(size:22,weight:.regular)).foregroundStyle(.white).padding()
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
                Text("Puoi crearla anche senza amici. Scade dopo 24 ore e rimane nel tuo archivio privato.").font(.gpix(size:12,weight:.regular)).foregroundStyle(gpixMuted)
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
            Text(key).font(.gpix(size:17,weight:.semibold))
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
                Label("Solo tu puoi vedere le tue istantanee archiviate, conservate fino a un anno.",systemImage:"lock").font(.gpix(size:12,weight:.regular)).foregroundStyle(gpixMuted).padding(13).frame(maxWidth:.infinity,alignment:.leading).background(Color.secondary.opacity(0.07),in:RoundedRectangle(cornerRadius:17))
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
                    .font(.gpix(size:12,weight:.bold))
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
                    Text("Il riepilogo verrà pubblicato come storia.").font(.gpix(size:12,weight:.regular))
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
                        Text(Date(timeIntervalSince1970:item.n("created")).formatted(.dateTime.day())).font(.gpix(size:12,weight:.bold))
                        Spacer()
                        if selected{
                            Image(systemName:"checkmark.circle.fill").foregroundStyle(gpixPurple)
                        }
                    }
                    Spacer()
                    Label("\(Int(item.n("viewsCount")))",systemImage:"eye").font(.gpix(size:10,weight:.semibold)).frame(maxWidth:.infinity,alignment:.leading)
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
                Text("\(total) visualizzazioni").font(.gpix(size:17,weight:.semibold))
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

@MainActor
struct CollectionInstantCard:View {
    @EnvironmentObject var store:GpixStore
    let item:Row
    let count:Int
    let own:Bool
    @State private var image:UIImage?
    private var remaining:String {
        let seconds=max(0,item.n("expires")-Date().timeIntervalSince1970)
        return seconds>=3600 ? "\(Int(ceil(seconds/3600))) h":"\(Int(ceil(seconds/60))) min"
    }
    var body:some View {
        GeometryReader { geometry in
            ZStack(alignment:.bottomLeading) {
                gpixSoft
                if let image=image { Image(uiImage:image).resizable().scaledToFill().frame(width:geometry.size.width,height:geometry.size.height).clipped() }
                LinearGradient(colors:[Color.black.opacity(own ? 0:0.26),Color.clear,Color.black.opacity(0.87)],startPoint:.top,endPoint:.bottom)
                if !own { Image(systemName:"viewfinder").font(.gpix(size:35)).foregroundStyle(Color.white).frame(maxWidth:.infinity,maxHeight:.infinity) }
                VStack(alignment:.leading,spacing:4) {
                    Text(own ? item.s("caption").isEmpty ? "Il tuo istante":item.s("caption") : item.s("username",store.person(item.s("owner")).s("username"))).font(.gpix(size:16,weight:.bold)).lineLimit(own ? 2:1)
                    if !own { Text("Tocca per aprire").font(.gpix(size:11)).foregroundStyle(Color.white.opacity(0.7)) }
                }.foregroundStyle(Color.white).padding(.horizontal,13).padding(.bottom,15)
            }.overlay(alignment:.topLeading) {
                Text(own ? "Scade tra \(remaining)":"\(count) \(count==1 ? "nuova":"nuove")").font(.gpix(size:11,weight:own ? .regular:.bold))
                    .foregroundStyle(own ? Color.white:Color.black).padding(.horizontal,8).padding(.vertical,5).background(own ? Color.black.opacity(0.54):Color.white,in:RoundedRectangle(cornerRadius:12)).padding(12)
            }
            .frame(width:geometry.size.width,height:geometry.size.height).clipped().clipShape(RoundedRectangle(cornerRadius:25))
        }.aspectRatio(1,contentMode:.fit)
        .task(id:item.id) { if let data=try? await store.instantPhoto(item.id,archive:own,preview:!own) { image=UIImage(data:data) } }
    }
}
