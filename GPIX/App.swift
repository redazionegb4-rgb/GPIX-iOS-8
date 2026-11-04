import SwiftUI
@main @MainActor struct GpixNativeApp: App {
    @StateObject private var store = GpixStore()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).tint(gpixPurple).preferredColorScheme(store.colorScheme)
            .task {
                await store.boot()
            }
            .onChange(of:phase){
                _, value in Task{
                    await store.activity(value == .active)
                }
            }
            .alert("GPIX",isPresented:Binding(get:{
                !store.error.isEmpty
            }
            ,set:{
                if !$0 {
                    store.error=""
                }
            }
            )){
                Button("OK"){
                    store.error=""
                }
            } message: {
                Text(store.error)
            }
        }
    }
}
struct RootView: View {
    @EnvironmentObject var store:GpixStore
    @State private var create=false
    @State private var compact=false
    @State private var navigationReset=0
    @State private var incoming: IdentifiedRow?
    var body: some View {
        Group {
            if !store.ready {
                VStack(spacing:24){
                    Image("GpixLogo").resizable().scaledToFit().frame(width:220)
                    ProgressView()
                }
                .frame(maxWidth:.infinity,maxHeight:.infinity)
            }
            else if !store.signedIn {
                AuthView().transition(.opacity.combined(with:.move(edge:.bottom)))
            }
            else {
                ZStack(alignment:.bottom){
                    NavigationStack {
                        Group {
                            switch store.tab {
                                case 0:FeedView()
                                case 1:ReelsView()
                                case 2:InboxView()
                                case 3:SearchView()
                                default:ProfileView(userID:store.myID)
                            }
                        }
                        .padding(.bottom,78)
                    }
                    .id("\(store.tab)-\(navigationReset)")
                    HStack(spacing:0){
                        nav(0,"house","house.fill")
                        nav(1,"play.rectangle","play.rectangle.fill")
                        nav(2,"paperplane","paperplane.fill")
                        nav(3,"magnifyingglass","magnifyingglass")
                        Button{
                            store.tab=4
                        } label: {
                            AvatarView(person:store.me,size:compact ? 25:31).padding(12).frame(maxWidth:.infinity).background(store.tab==4 ? Color.primary.opacity(0.06):.clear,in:Capsule())
                        }
                    }
                    .padding(6).background(.ultraThinMaterial,in:Capsule()).overlay(Capsule().stroke(.primary.opacity(0.08))).padding(.horizontal,compact ? 48:22).padding(.bottom,8).shadow(color:.black.opacity(0.07),radius:18,y:4)
                }
                .onPreferenceChange(FeedPosition.self){
                    offset in withAnimation(.easeInOut(duration:0.25)){
                        compact=offset < -90
                    }
                }
                .onReceive(store.$state){
                    state in if incoming==nil,let call=state.rows("calls").first(where:{
                        $0.s("callee")==store.myID && $0.s("status")=="ringing"
                    }
                    ) {
                        incoming=IdentifiedRow(row:call)
                    }
                }
            }
        }
        .animation(.easeInOut(duration:0.3),value:store.signedIn)
        .sheet(item:$incoming){
            item in CallView(callID:item.id)
        }
    }
    func nav(_ number:Int,_ icon:String,_ selected:String)->some View{
        Button{
            if number==0 && store.tab==0 {
                navigationReset+=1
                Task{
                    await store.sync()
                }
                NotificationCenter.default.post(name:.gpixHome,object:nil)
            }
            store.tab=number
        } label: {
            Image(systemName:store.tab==number ? selected:icon).font(.system(size:compact ? 21:25,weight:.medium)).frame(maxWidth:.infinity).padding(.vertical,12).background(store.tab==number ? Color.primary.opacity(0.06):.clear,in:Capsule())
            .overlay(alignment:.bottomTrailing){
                if number==2 && store.threads.contains(where:{
                    store.unread($0)>0
                }
                ) {
                    Circle().fill(.red).frame(width:7,height:7).offset(x:-10,y:-6)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}
extension Notification.Name {
    static let gpixHome=Notification.Name("gpix.home")
}
struct FeedPosition:PreferenceKey {
    static var defaultValue:CGFloat=0
    static func reduce(value:inout CGFloat,nextValue:()->CGFloat){
        value=nextValue()
    }
}
struct IdentifiedRow:Identifiable {
    let row:Row
    var id:String{
        row.id
    }
}
@MainActor
struct AvatarView:View {
    let person:Row
    var size:CGFloat=46
    var ring=false
    var online=false
    var body:some View{
        MediaView(reference:person.s("avatar"),fill:true).frame(width:size,height:size).clipShape(Circle()).padding(ring ? 4:0)
        .overlay(Circle().stroke(ring ? AnyShapeStyle(gpixGradient):AnyShapeStyle(Color.clear),lineWidth:2.5))
        .overlay(alignment:.bottomTrailing){
            if online {
                Circle().fill(.green).frame(width:12,height:12).overlay(Circle().stroke(Color(uiColor:.systemBackground),lineWidth:2))
            }
        }
        .accessibilityLabel(person.s("name"))
    }
}
@MainActor
struct MediaView:View {
    let reference:String
    var fill=false
    var body:some View{
        GeometryReader{
            g in
            Group{
                if let image=localImage(reference){
                    Image(uiImage:image).resizable().aspectRatio(contentMode:fill ? .fill:.fit)
                }
                else if let url=URL(string:reference),url.scheme=="https" {
                    AsyncImage(url:url){
                        phase in if let image=phase.image {
                            image.resizable().aspectRatio(contentMode:fill ? .fill:.fit)
                        }
                        else if phase.error != nil {
                            Image(systemName:"photo").foregroundStyle(.secondary)
                        }
                        else{
                            ProgressView()
                        }
                    }
                }
                else{
                    ZStack{
                        Color.secondary.opacity(0.09)
                        Image(systemName:"person.crop.square").foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width:g.size.width,height:g.size.height).clipped()
        }
    }
}
func localImage(_ reference:String)->UIImage?{
    if reference.hasPrefix("file://"),let url=URL(string:reference){
        return UIImage(contentsOfFile:url.path)
    }
    if let url=Bundle.main.url(forResource:reference,withExtension:nil,subdirectory:"Media"){
        return UIImage(contentsOfFile:url.path)
    }
    return UIImage(named:reference)
}
@MainActor
struct PrimaryButton:View {
    let title:String
    var disabled=false
    let action:()->Void
    var body:some View{
        Button(action:action){
            Text(title).font(.system(size:15,weight:.semibold)).frame(maxWidth:.infinity).padding(.vertical,13).background(gpixPurple,in:RoundedRectangle(cornerRadius:13)).foregroundStyle(.white)
        }
        .disabled(disabled).opacity(disabled ? 0.5:1)
    }
}
@MainActor
struct EmptyViewCard:View {
    let icon:String
    let title:String
    let subtitle:String
    var body:some View{
        VStack(spacing:18){
            Image(systemName:icon).font(.system(size:45,weight:.light)).padding(28).overlay(Circle().stroke(.primary,lineWidth:1.5))
            Text(title).font(.title2.bold()).multilineTextAlignment(.center)
            Text(subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(28).frame(maxWidth:.infinity)
    }
}
@MainActor
struct PersonLine:View {
    let person:Row
    var subtitle=""
    var body:some View{
        HStack(spacing:13){
            AvatarView(person:person,size:52)
            VStack(alignment:.leading,spacing:4){
                Text(person.s("name")).font(.system(size:15,weight:.semibold))
                Text(subtitle.isEmpty ? person.s("username"):subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
        }
        .foregroundStyle(.primary)
    }
}
@MainActor
struct AuthView:View {
    @EnvironmentObject var store:GpixStore
    @State private var register=false
    @State private var name=""
    @State private var username=""
    @State private var email=""
    @State private var password=""
    @State private var busy=false
    @State private var forgot=false
    @State private var appear=false
    var body:some View{
        NavigationStack{
            ScrollView{
                VStack(spacing:23){
                    Spacer(minLength:48)
                    Image("GpixLogo").resizable().scaledToFit().frame(width:225,height:135)
                    Text(register ? "La tua storia inizia qui." : "Bentornato su GPIX.").font(.title2.bold())
                    VStack(spacing:13){
                        if register {
                            field("Nome",$name)
                            field("Nome utente",$username)
                            field("Email",$email)
                        }
                        else{
                            field("Email o nome utente",$username)
                        }
                        SecureField("Password",text:$password).textContentType(register ? .newPassword:.password).padding(16).background(Color.secondary.opacity(0.08),in:RoundedRectangle(cornerRadius:14))
                    }
                    PrimaryButton(title:busy ? "Attendi…":register ? "Crea account":"Accedi",disabled:busy){
                        submit()
                    }
                    if !register {
                        Button("Password dimenticata?"){
                            forgot=true
                        }
                        .font(.subheadline)
                    }
                    Button(register ? "Hai già un account? Accedi":"Non hai un account? Registrati"){
                        withAnimation{
                            register.toggle()
                        }
                    }
                    Divider().padding(.vertical,5)
                    Button("Esplora la demo"){
                        store.loadDemo()
                    }
                    .font(.headline)
                    Text("Continuando accetti i termini e l’informativa sulla privacy.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Link("Privacy e condizioni",destination:URL(string:"https://gpix.cc/privacy")!).font(.caption)
                }
                .padding(28).opacity(appear ? 1:0).offset(y:appear ? 0:20)
            }
            .onAppear{
                withAnimation(.easeOut(duration:0.45)){
                    appear=true
                }
            }
            .sheet(isPresented:$forgot){
                SecurityView(mode:"forgot")
            }
        }
    }
    func field(_ title:String,_ text:Binding<String>)->some View{
        TextField(title,text:text).textInputAutocapitalization(.never).autocorrectionDisabled().padding(16).background(Color.secondary.opacity(0.08),in:RoundedRectangle(cornerRadius:14))
    }
    func submit(){
        busy=true
        Task{
            defer{
                busy=false
            }
            do{
                try await store.login(register ? "register":"login",register ? ["name":name,"username":username,"email":email,"password":password]:["login":username,"password":password])
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
}
