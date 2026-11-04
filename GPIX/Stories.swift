import SwiftUI
import AVFoundation
@MainActor
struct StoryViewer:View{
    @EnvironmentObject var store:GpixStore
    @Environment(\.dismiss) var dismiss
    let userID:String
    var postIDs:[String]?=nil
    @State private var index=0
    @State private var progress=0.0
    @State private var text=""
    @State private var viewers=false
    @State private var audio:AVPlayer?
    let timer=Timer.publish(every:0.05,on:.main,in:.common).autoconnect()
    var stories:[Row]{
        postIDs.map{
            $0.map{
                store.post($0)
            }
            .filter{
                !$0.isEmpty
            }
        }
        ?? store.visibleStories(userID)
    }
    var story:Row{
        stories.indices.contains(index) ? stories[index]:[:]
    }
    var body:some View{
        ZStack{
            Color.black.ignoresSafeArea()
            if !story.s("media").isEmpty{
                MediaView(reference:story.s("media"),fill:false)
            }
            else{
                gpixGradient.ignoresSafeArea()
                Text(story.s("text")).font(.largeTitle.bold()).multilineTextAlignment(.center).foregroundStyle(.white).padding(35)
            }
            HStack(spacing:0){
                Color.clear.contentShape(Rectangle()).onTapGesture{
                    previous()
                }
                Color.clear.contentShape(Rectangle()).onTapGesture{
                    next()
                }
            }
            .padding(.vertical,95)
            VStack{
                HStack(spacing:4){
                    ForEach(Array(stories.enumerated()),id:\.offset){
                        i,_ in GeometryReader{
                            g in ZStack(alignment:.leading){
                                Capsule().fill(.white.opacity(0.35))
                                Capsule().fill(.white).frame(width:g.size.width*(i<index ? 1:i==index ? progress:0))
                            }
                        }
                        .frame(height:3)
                    }
                }
                HStack{
                    AvatarView(person:store.person(userID),size:31)
                    Text(store.person(userID).s("username")).bold()
                    Text(ago(story.n("created"))).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Button{
                        dismiss()
                    } label: {
                        Image(systemName:"xmark").font(.title2)
                    }
                }
                .font(.subheadline).foregroundStyle(.white).padding(.top,12)
                Spacer()
                if !story.row("style").row("poll").isEmpty{
                    let poll=story.row("style").row("poll")
                    VStack{
                        Text(poll.s("question")).bold()
                        ForEach(Array(poll.ids("options").enumerated()),id:\.offset){
                            i,title in Button(title){
                                store.perform("pollVote",["id":story.id,"choice":i])
                            }
                            .padding(10).frame(maxWidth:.infinity).background(.white.opacity(0.9),in:Capsule()).foregroundStyle(.black)
                        }
                    }
                    .padding(18).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:20)).padding(.bottom,15)
                }
                if userID==store.myID{
                    Button{
                        viewers=true
                    } label: {
                        Label("\(story.ids("viewers").count) visualizzazioni",systemImage:"eye").foregroundStyle(.white)
                    }
                }
                else{
                    HStack{
                        TextField("Rispondi alla storia…",text:$text).padding(12).background(.ultraThinMaterial,in:Capsule())
                        Button{
                            reply()
                        } label: {
                            Image(systemName:"paperplane")
                        }
                        Button{
                            store.perform("like",["id":story.id,"enabled":!story.ids("likes").contains(store.myID)])
                        } label: {
                            Image(systemName:story.ids("likes").contains(store.myID) ? "heart.fill":"heart").foregroundStyle(story.ids("likes").contains(store.myID) ? .red:.white)
                        }
                    }
                    .foregroundStyle(.white)
                }
            }
            .padding(16)
        }
        .onReceive(timer){
            _ in if !viewers && text.isEmpty{
                progress+=0.05/7
                if progress>=1{
                    next()
                }
            }
        }
        .onChange(of:index){
            _, _ in opened()
        }
        .onAppear{
            opened()
        }
        .onDisappear{
            audio?.pause()
        }
        .sheet(isPresented:$viewers){
            NavigationStack{
                PeopleListView(title:"Visualizzazioni",ids:story.ids("viewers"))
            }
        }
        .gesture(DragGesture().onEnded{
            v in if v.translation.height>80{
                dismiss()
            }
            else if v.translation.width < -45{
                next()
            }
            else if v.translation.width>45{
                previous()
            }
        }
        )
    }
    func next(){
        audio?.pause()
        if index+1<stories.count{
            withAnimation(.easeInOut(duration:0.18)){
                index+=1
                progress=0
            }
        }
        else{
            dismiss()
        }
    }
    func previous(){
        if index>0{
            index-=1
        }
        progress=0
    }
    func opened(){
        guard !story.id.isEmpty else{
            return
        }
        progress=0
        store.perform("see",["id":story.id])
        let ref=story.row("style").s("audio")
        if !ref.isEmpty{
            audio?.pause()
            audio=AVPlayer(url:mediaURL(ref))
            audio?.play()
        }
    }
    func reply(){
        let value=text
        text=""
        Task{
            do{
                let tid=try await store.startThread(userID)
                try await store.act("message",["id":tid,"kind":"story","story":story.id,"text":value])
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
}
@MainActor
struct StoryArchiveView:View{
    @EnvironmentObject var store:GpixStore
    @State private var selected:IdentifiedRow?
    var stories:[Row]{
        store.posts.filter{
            $0.s("author")==store.myID && $0.s("kind")=="story"
        }
    }
    var body:some View{
        ScrollView{
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:3),count:3),spacing:3){
                ForEach(stories,id:\.id){
                    story in Button{
                        selected=IdentifiedRow(row:story)
                    } label: {
                        MediaView(reference:story.s("media"),fill:true).aspectRatio(0.7,contentMode:.fit).overlay(alignment:.bottomLeading){
                            Text(Date(timeIntervalSince1970:story.n("created")).formatted(date:.abbreviated,time:.omitted)).font(.caption2).padding(6).background(.ultraThinMaterial,in:Capsule()).padding(4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Archivio storie").fullScreenCover(item:$selected){
            item in StoryViewer(userID:store.myID,postIDs:[item.id])
        }
    }
}
@MainActor
struct HighlightEditor:View{
    @EnvironmentObject var store:GpixStore
    @Environment(\.dismiss) var dismiss
    @State private var title=""
    @State private var selected:Set<String>=[]
    var body:some View{
        List{
            TextField("Titolo",text:$title)
            ForEach(store.posts.filter{
                $0.s("author")==store.myID && $0.s("kind")=="story"
            }
            ,id:\.id){
                p in Button{
                    if selected.contains(p.id){
                        selected.remove(p.id)
                    }
                    else{
                        selected.insert(p.id)
                    }
                } label: {
                    HStack{
                        MediaView(reference:p.s("media"),fill:true).frame(width:50,height:65)
                        Text(p.s("text")).lineLimit(2)
                        Spacer()
                        Image(systemName:selected.contains(p.id) ? "checkmark.circle.fill":"circle")
                    }
                }
            }
        }
        .navigationTitle("Nuova raccolta").toolbar{
            Button("Crea"){
                Task{
                    do{
                        try await store.act("highlight",["title":title,"posts":Array(selected)])
                        dismiss()
                    }
                    catch{
                        store.error=error.localizedDescription
                    }
                }
            }
            .disabled(title.isEmpty || selected.isEmpty)
        }
    }
}
@MainActor
struct HighlightViewer:View{
    let highlight:Row
    var body:some View{
        StoryViewer(userID:highlight.s("owner"),postIDs:highlight.ids("posts"))
    }
}
@MainActor
struct NoteStrip:View{
    @EnvironmentObject var store:GpixStore
    @State private var selected:IdentifiedRow?
    @State private var composer=false
    var notes:[Row]{
        store.state.rows("notes").filter{
            $0.n("expires")>Date().timeIntervalSince1970
        }
        .map{
            var n=$0
            n["id"]=n.s("owner")
            return n
        }
    }
    var body:some View{
        ScrollView(.horizontal,showsIndicators:false){
            HStack(alignment:.bottom,spacing:18){
                noteCard(store.me,note:notes.first{
                    $0.s("owner")==store.myID
                }
                )
                ForEach(notes.filter{
                    $0.s("owner") != store.myID
                }
                ,id:\.id){
                    n in noteCard(store.person(n.s("owner")),note:n)
                }
            }
            .padding(.top,6).padding(.bottom,8)
        }
        .sheet(isPresented:$composer){
            NoteComposer()
        }
        .sheet(item:$selected){
            item in NoteDetail(note:item.row)
        }
    }
    func noteCard(_ person:Row,note:Row?)->some View {
        VStack(spacing:7){
            ZStack(alignment:.top){
                AvatarView(person:person,size:69).padding(.top,44)
                Text(note?.s("text") ?? "Nuovo giorno,\nnuova nota…").font(.system(size:12)).lineLimit(3).multilineTextAlignment(.center).padding(.horizontal,10).padding(.vertical,10).frame(width:98).background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:22)).overlay(alignment:.bottomLeading) { Circle().fill(Color(uiColor:.secondarySystemGroupedBackground)).frame(width:12,height:12).offset(x:15,y:4) }.shadow(color:.black.opacity(0.07),radius:8,y:3)
            }
            Text(person.id==store.myID ? "La tua nota":person.s("name")).font(.caption).lineLimit(1).frame(width:95)
        }
        .foregroundStyle(.primary).contentShape(Rectangle()).gesture(
        TapGesture(count:2).exclusively(before:TapGesture(count:1)).onEnded {
            result in
            switch result {
                case .first:
                if let note=note,person.id != store.myID {
                    store.perform("noteReact",["user":person.id,"created":note.n("created"),"enabled":!note.b("likedByMe")])
                }
                case .second:
                if person.id==store.myID && note==nil {
                    composer=true
                }
                else if let note=note {
                    selected=IdentifiedRow(row:note.merging(["id":person.id]){
                        _,b in b
                    }
                    )
                }
            }
        }
        )
    }
}
@MainActor
struct NoteComposer:View{
    @EnvironmentObject var store:GpixStore
    @Environment(\.dismiss) var dismiss
    @State private var text=""
    @State private var audience="mutual"
    @State private var busy=false
    var body:some View{
        NavigationStack{
            VStack{
                Spacer()
                TextField("Condividi un pensiero…",text:$text,axis:.vertical).font(.title3).multilineTextAlignment(.center).padding(18).frame(width:230).background(Color(uiColor:.secondarySystemBackground),in:RoundedRectangle(cornerRadius:28)).onChange(of:text){
                    _, value in if value.count>60{
                        text=String(value.prefix(60))
                    }
                }
                Text("\(text.count)/60").font(.caption).foregroundStyle(.secondary)
                AvatarView(person:store.me,size:125)
                Spacer()
                Picker("Condividi con",selection:$audience){
                    Text("Amici").tag("mutual")
                    Text("Amici più stretti").tag("close")
                }
                .pickerStyle(.segmented)
                PrimaryButton(title:busy ? "Condivisione…":"Condividi",disabled:text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || busy){
                    busy=true
                    Task{
                        defer{
                            busy=false
                        }
                        do{
                            try await store.act("note",["text":text,"audience":audience])
                            dismiss()
                        }
                        catch{
                            store.error=error.localizedDescription
                        }
                    }
                }
                Text("La nota scompare dopo 24 ore.").font(.caption).foregroundStyle(.secondary)
            }
            .padding(24).navigationTitle("Nuova nota").navigationBarTitleDisplayMode(.inline).toolbar{
                Button("Annulla"){
                    dismiss()
                }
            }
        }
    }
}
@MainActor
struct NoteDetail:View{
    @EnvironmentObject var store:GpixStore
    @Environment(\.dismiss) var dismiss
    let note:Row
    @State private var reply=""
    @State private var new=false
    var owner:String{
        note.s("owner")
    }
    var body:some View{
        NavigationStack{
            VStack(spacing:23){
                Capsule().fill(.secondary).frame(width:35,height:4)
                AvatarView(person:store.person(owner),size:70)
                Text(note.s("text")).font(.title3).multilineTextAlignment(.center)
                Text("Condivisa con gli amici · "+ago(note.n("created"))).font(.caption).foregroundStyle(.secondary)
                if owner==store.myID{
                    PrimaryButton(title:"Lascia una nuova nota"){
                        new=true
                    }
                    Button("Elimina nota",role:.destructive){
                        store.perform("note",["delete":true])
                        dismiss()
                    }
                }
                else{
                    Button{
                        store.perform("noteReact",["user":owner,"created":note.n("created"),"enabled":!note.b("likedByMe")])
                    } label: {
                        Image(systemName:note.b("likedByMe") ? "heart.fill":"heart").font(.largeTitle).foregroundStyle(.pink)
                    }
                    TextField("Rispondi alla nota…",text:$reply).textFieldStyle(.roundedBorder)
                    PrimaryButton(title:"Invia risposta",disabled:reply.isEmpty){
                        Task{
                            do{
                                let tid=try await store.startThread(owner)
                                try await store.act("message",["id":tid,"text":"Risposta alla tua nota: "+reply])
                                dismiss()
                            }
                            catch{
                                store.error=error.localizedDescription
                            }
                        }
                    }
                }
            }
            .padding(25).presentationDetents([.medium,.large]).sheet(isPresented:$new){
                NoteComposer()
            }
        }
    }
}
