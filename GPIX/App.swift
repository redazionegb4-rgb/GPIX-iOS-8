import SwiftUI
@main @MainActor struct GpixNativeApp: App {
    @StateObject private var store = GpixStore()
    @Environment(\.scenePhase) private var phase
    init() {
        let appearance=UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor=UIColor { $0.userInterfaceStyle == .dark ? .black:.white }
        let font=UIFont(name:"Roboto-Regular",size:20) ?? UIFont.systemFont(ofSize:20)
        appearance.titleTextAttributes=[.font:font,.foregroundColor:UIColor(gpixInk)]
        appearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance=appearance
        UINavigationBar.appearance().scrollEdgeAppearance=appearance
        UINavigationBar.appearance().compactAppearance=appearance
        UINavigationBar.appearance().tintColor=UIColor(gpixInk)
    }
    var body: some Scene {
        WindowGroup {
            RootView().font(.gpix(size:14)).listStyle(.plain).environment(\.defaultMinListRowHeight,55).environmentObject(store).tint(gpixPurple).preferredColorScheme(store.colorScheme)
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
    @State private var hideBottomNavigation=false
    @State private var previousScroll:CGFloat=0
    @State private var scrollTravel:CGFloat=0
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
                    TabView(selection:$store.tab) {
                        NavigationStack { FeedView() }.tag(0)
                        NavigationStack { ReelsView() }.tag(1)
                        NavigationStack { InboxView() }.tag(2)
                        NavigationStack { SearchView() }.tag(3)
                        NavigationStack { ProfileView(userID:store.myID) }.tag(4)
                    }
                    .toolbar(.hidden,for:.tabBar)
                    .safeAreaInset(edge:.bottom,spacing:0) {
                        if !hideBottomNavigation { Color.clear.frame(height:74) }
                    }
                    if !hideBottomNavigation {
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
                    .frame(height:compact ? 44:54).padding(5).background(Color(uiColor:.systemBackground).opacity(0.97),in:Capsule()).overlay(Capsule().stroke(Color.primary.opacity(0.07))).padding(.horizontal,compact ? 48:20).padding(.bottom,8).shadow(color:.black.opacity(0.08),radius:20,y:5)
                    }
                }
                
                .onPreferenceChange(HideBottomNavigation.self) { hideBottomNavigation = $0 }
                .onPreferenceChange(FeedPosition.self) { offset in
                    let delta = previousScroll-offset
                    previousScroll=offset
                    guard abs(delta)>0.1,store.tab != 1 else { return }
                    if scrollTravel.sign != delta.sign { scrollTravel=0 }
                    scrollTravel += delta
                    let next = offset >= -8 ? false : scrollTravel>20 ? true : scrollTravel < -12 ? false : compact
                    withAnimation(.easeOut(duration:0.24)) { compact=next }
                }
                .onChange(of:store.tab) { _,_ in compact=false; scrollTravel=0; previousScroll=0 }
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
                Task{
                    await store.sync()
                }
                NotificationCenter.default.post(name:.gpixHome,object:nil)
            }
            store.tab=number
        } label: {
            GpixIcon(systemName:store.tab==number ? selected:icon,size:compact ? 21:25).frame(maxWidth:.infinity).padding(.vertical,12).background(store.tab==number ? Color.primary.opacity(0.06):.clear,in:Capsule())
            .overlay(alignment:.bottomTrailing){
                if number==2 && store.threads.contains(where:{
                    store.unread($0)>0
                }
                ) {
                    Circle().fill(.red).frame(width:7,height:7).offset(x:-10,y:-6)
                }
            }
        }
        .foregroundStyle(gpixInk)
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
    @EnvironmentObject var store: GpixStore
    let reference:String
    var fill=false
    private var resolvedReference: String { store.uploadedURLs[reference] ?? reference }
    var body:some View{
        GeometryReader{
            g in
            Group{
                if let image=localImage(resolvedReference){
                    Image(uiImage:image).resizable().aspectRatio(contentMode:fill ? .fill:.fit)
                }
                else if let url=resolvedRemoteMediaURL(resolvedReference) {
                    AsyncImage(url:url){
                        phase in if let image=phase.image {
                            image.resizable().aspectRatio(contentMode:fill ? .fill:.fit)
                        }
                        else if phase.error != nil {
                            Image(systemName:"photo").foregroundStyle(gpixMuted)
                        }
                        else{
                            ProgressView()
                        }
                    }
                }
                else{
                    ZStack{
                        Color.secondary.opacity(0.09)
                        GpixIcon(systemName:"person.crop.square").foregroundStyle(gpixMuted)
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
    let action: @MainActor () -> Void
    var body:some View{
        Button { action() } label: {
            Text(title).font(.gpix(size:14,weight:.bold)).frame(maxWidth:.infinity,minHeight:47).background(gpixPurple,in:RoundedRectangle(cornerRadius:11)).foregroundStyle(.white)
        }
        .buttonStyle(GpixPressStyle()).disabled(disabled).opacity(disabled ? 0.5:1)
    }
}
@MainActor
struct EmptyViewCard:View {
    let icon:String
    let title:String
    let subtitle:String
    var body:some View{
        VStack(spacing:18){
            GpixIcon(systemName:icon,size:45).padding(28).overlay(Circle().stroke(.primary,lineWidth:1.5))
            Text(title).font(.gpix(size:22,weight:.bold)).multilineTextAlignment(.center)
            Text(subtitle).foregroundStyle(gpixMuted).multilineTextAlignment(.center)
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
                Text(person.s("name")).font(.gpix(size:15,weight:.semibold))
                Text(subtitle.isEmpty ? person.s("username"):subtitle).font(.gpix(size:14,weight:.regular)).foregroundStyle(gpixMuted).lineLimit(1)
            }
            Spacer()
        }
        .foregroundStyle(gpixInk)
    }
}
@MainActor
struct AuthView:View {
    @EnvironmentObject var store:GpixStore
    @State private var form=false
    @State private var register=false
    @State private var name=""
    @State private var username=""
    @State private var email=""
    @State private var password=""
    @State private var confirmation=""
    @State private var showPassword=false
    @State private var showConfirmation=false
    @State private var busy=false
    @State private var forgot=false
    @State private var error=""
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:0) {
                    if form { Button { withAnimation { form=false; error="" } } label: { Image(systemName:"chevron.left").font(.gpix(size:24)).foregroundStyle(gpixInk) }.padding(.bottom,12) }
                    Image("GpixLogo").resizable().scaledToFit().frame(width:form ? 170:255,height:form ? 90:135).frame(maxWidth:.infinity).padding(.bottom,form ? 28:32)
                    if form { loginForm } else { welcome }
                    if !error.isEmpty { Text(error).font(.gpix(size:13)).foregroundStyle(Color.red).padding(.top,16) }
                    Button { store.loadDemo() } label: { Text("Esplora la demo").font(.gpix(size:14,weight:.bold)).frame(maxWidth:.infinity).padding(.vertical,16) }.disabled(busy).padding(.top,18)
                    Text("Continuando accetti i termini e l’informativa sulla privacy.").font(.gpix(size:12)).foregroundStyle(gpixMuted).multilineTextAlignment(.center).frame(maxWidth:.infinity)
                    Link("Privacy e condizioni",destination:URL(string:"https://gpix.cc/privacy")!).font(.gpix(size:12)).frame(maxWidth:.infinity).padding(.top,8)
                }.padding(.horizontal,24).padding(.top,24).padding(.bottom,30).frame(maxWidth:480).frame(maxWidth:.infinity)
            }.background(Color(uiColor:.systemBackground))
            .sheet(isPresented:$forgot) { NavigationStack { SecurityView(mode:"forgot") } }
        }
    }
    private var welcome:some View {
        VStack(spacing:0) {
            Text("Il tuo mondo,\nin ogni sfumatura.").font(.gpix(size:34,weight:.bold)).tracking(-1.2).multilineTextAlignment(.center)
            Text("Storie da condividere. Persone da scoprire.\nUn posto dove essere te stesso.").font(.gpix(size:15)).lineSpacing(5).foregroundStyle(gpixMuted).multilineTextAlignment(.center).padding(.top,18).padding(.bottom,38)
            PrimaryButton(title:"Accedi") { switchForm(false) }
            Button { switchForm(true) } label: { Text("Crea un account").font(.gpix(size:14,weight:.bold)).foregroundStyle(gpixInk).frame(maxWidth:.infinity,minHeight:47).background(gpixSoft,in:RoundedRectangle(cornerRadius:11)) }.padding(.top,12)
        }.frame(maxWidth:.infinity)
    }
    private var loginForm:some View {
        VStack(alignment:.leading,spacing:0) {
            Text(register ? "Crea il tuo account":"Bentornato su GPIX").font(.gpix(size:27,weight:.bold)).tracking(-0.7)
            Text(register ? "Bastano pochi dati per iniziare a condividere.":"Accedi e ritrova le tue persone e le tue storie.").font(.gpix(size:14)).foregroundStyle(gpixMuted).padding(.top,8).padding(.bottom,25)
            if register {
                input("Nome",text:$name,icon:"person")
                input("Nome utente",text:$username,icon:"at")
                input("Email",text:$email,icon:"envelope")
            } else { input("Email o nome utente",text:$username,icon:"person") }
            secret("Password",text:$password,show:$showPassword)
            if register { secret("Conferma password",text:$confirmation,show:$showConfirmation) }
            PrimaryButton(title:busy ? "Attendi…":register ? "Crea account":"Accedi",disabled:busy) { submit() }.padding(.top,8)
            if !register { Button("Password dimenticata?") { forgot=true }.font(.gpix(size:14)).frame(maxWidth:.infinity).padding(.top,16) }
            Button(register ? "Hai già un account? Accedi":"Non hai un account? Registrati") { switchForm(!register) }.font(.gpix(size:14,weight:.semibold)).frame(maxWidth:.infinity).padding(.top,20)
        }
    }
    private func input(_ title:String,text:Binding<String>,icon:String)->some View {
        HStack(spacing:13) {
            Image(systemName:icon).foregroundStyle(gpixMuted).frame(width:21)
            TextField(title,text:text).font(.gpix(size:15)).textInputAutocapitalization(.never).autocorrectionDisabled()
        }.padding(16).background(gpixSoft,in:RoundedRectangle(cornerRadius:14)).padding(.bottom,14).disabled(busy)
    }
    private func secret(_ title:String,text:Binding<String>,show:Binding<Bool>)->some View {
        HStack(spacing:13) {
            Image(systemName:"lock").foregroundStyle(gpixMuted).frame(width:21)
            Group { if show.wrappedValue { TextField(title,text:text) } else { SecureField(title,text:text) } }.font(.gpix(size:15)).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button { show.wrappedValue.toggle() } label: { Image(systemName:show.wrappedValue ? "eye.slash":"eye").foregroundStyle(gpixMuted) }
        }.padding(16).background(gpixSoft,in:RoundedRectangle(cornerRadius:14)).padding(.bottom,14).disabled(busy)
    }
    private func switchForm(_ signUp:Bool) {
        guard !busy else { return }
        withAnimation(.easeInOut(duration:0.24)) { form=true; register=signUp; error=""; password=""; confirmation=""; showPassword=false; showConfirmation=false }
    }
    private func submit() {
        error=""
        guard !username.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,!password.isEmpty else { error="Inserisci le credenziali per continuare."; return }
        if register {
            guard !name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { error="Inserisci il tuo nome."; return }
            guard username.range(of:"^[a-zA-Z0-9_.]{3,30}$",options:.regularExpression) != nil else { error="Nome utente: da 3 a 30 lettere, numeri, punti o trattini bassi."; return }
            guard email.range(of:"^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$",options:.regularExpression) != nil else { error="Inserisci un indirizzo email valido."; return }
            guard password==confirmation else { error="Le password non coincidono."; return }
        }
        busy=true
        Task {
            defer { busy=false }
            do { try await store.login(register ? "register":"login",register ? ["name":name,"username":username,"email":email,"password":password]:["login":username,"password":password]) }
            catch { self.error=error.localizedDescription }
        }
    }
}

struct HideBottomNavigation: PreferenceKey {
    static var defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}
struct GpixPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration:0.16),value:configuration.isPressed)
    }
}
struct GpixSearchField: View {
    @Binding var text: String
    var placeholder = "Cerca"
    var body: some View {
        HStack(spacing:10) {
            GpixIcon(systemName:"magnifyingglass",size:18).foregroundStyle(Color.secondary)
            TextField(placeholder,text:$text).font(.gpix(size:15)).textInputAutocapitalization(.never).autocorrectionDisabled()
            if !text.isEmpty { Button { text="" } label: { Image(systemName:"xmark.circle.fill").foregroundStyle(Color.secondary) } }
        }
        .padding(.horizontal,16).padding(.vertical,13)
        .background(gpixSoft,in:Capsule())
    }
}

// Paths transcribed from Flutter lib/ui/icons.dart, in its original 24-unit coordinate space.
struct GpixGlyph: Shape {
    let kind:String
    func path(in rect:CGRect)->Path {
        var p=Path()
        switch kind.replacingOccurrences(of:"Fill",with:"") {
        case "home":
            p.move(to:CGPoint(x:3,y:10));p.addLine(to:CGPoint(x:12,y:2.8));p.addLine(to:CGPoint(x:21,y:10));p.addLine(to:CGPoint(x:21,y:20));p.addQuadCurve(to:CGPoint(x:20,y:21),control:CGPoint(x:21,y:21));p.addLine(to:CGPoint(x:15.4,y:21));p.addLine(to:CGPoint(x:15.4,y:14));p.addLine(to:CGPoint(x:8.6,y:14));p.addLine(to:CGPoint(x:8.6,y:21));p.addLine(to:CGPoint(x:4,y:21));p.addQuadCurve(to:CGPoint(x:3,y:20),control:CGPoint(x:3,y:21));p.closeSubpath()
        case "heart":
            p.move(to:CGPoint(x:12,y:21));p.addCurve(to:CGPoint(x:2.3,y:8),control1:CGPoint(x:8,y:18),control2:CGPoint(x:2.3,y:13.5));p.addCurve(to:CGPoint(x:12,y:6),control1:CGPoint(x:2.3,y:2.5),control2:CGPoint(x:9,y:1.8));p.addCurve(to:CGPoint(x:21.7,y:8),control1:CGPoint(x:15,y:1.8),control2:CGPoint(x:21.7,y:2.5));p.addCurve(to:CGPoint(x:12,y:21),control1:CGPoint(x:21.7,y:13.5),control2:CGPoint(x:16,y:18));p.closeSubpath()
        case "send":
            p.move(to:CGPoint(x:3,y:9.2));p.addQuadCurve(to:CGPoint(x:3.2,y:10.1),control:CGPoint(x:2.1,y:9.5));p.addLine(to:CGPoint(x:10.2,y:13.5));p.addLine(to:CGPoint(x:13.9,y:20.8));p.addQuadCurve(to:CGPoint(x:15,y:20.6),control:CGPoint(x:14.4,y:21.8));p.addLine(to:CGPoint(x:21.5,y:3.3));p.addQuadCurve(to:CGPoint(x:20.7,y:2.5),control:CGPoint(x:22,y:2));p.addLine(to:CGPoint(x:3,y:9.2));p.closeSubpath();if !kind.hasSuffix("Fill") { p.move(to:CGPoint(x:10.2,y:13.5));p.addLine(to:CGPoint(x:20.9,y:3.2)) }
        case "chat":
            p.move(to:CGPoint(x:12,y:2.8));p.addCurve(to:CGPoint(x:2.4,y:11.6),control1:CGPoint(x:6.6,y:2.8),control2:CGPoint(x:2.4,y:6.6));p.addCurve(to:CGPoint(x:12,y:20.4),control1:CGPoint(x:2.4,y:16.6),control2:CGPoint(x:6.6,y:20.4));p.addQuadCurve(to:CGPoint(x:17,y:19),control:CGPoint(x:14.8,y:20.4));p.addLine(to:CGPoint(x:21.3,y:21.1));p.addLine(to:CGPoint(x:20.1,y:16.2));p.addCurve(to:CGPoint(x:12,y:2.8),control1:CGPoint(x:24,y:10.1),control2:CGPoint(x:19.4,y:2.8));p.closeSubpath()
        case "save":
            p.move(to:CGPoint(x:5,y:3));p.addLine(to:CGPoint(x:19,y:3));p.addLine(to:CGPoint(x:19,y:22));p.addLine(to:CGPoint(x:12,y:16.5));p.addLine(to:CGPoint(x:5,y:22));p.closeSubpath()
        case "search":
            p.addEllipse(in:CGRect(x:2.8,y:2.8,width:15.4,height:15.4));p.move(to:CGPoint(x:16,y:16));p.addLine(to:CGPoint(x:22,y:22))
        case "camera":
            p.addRoundedRect(in:CGRect(x:2,y:5,width:20,height:16),cornerSize:CGSize(width:4,height:4));p.addEllipse(in:CGRect(x:8,y:9,width:8,height:8));p.move(to:CGPoint(x:8,y:5));p.addLine(to:CGPoint(x:9,y:2.5));p.addLine(to:CGPoint(x:15,y:2.5));p.addLine(to:CGPoint(x:16,y:5))
        case "reel":
            p.addRoundedRect(in:CGRect(x:2.8,y:2.8,width:18.4,height:18.4),cornerSize:CGSize(width:4,height:4))
            if !kind.hasSuffix("Fill") { p.move(to:CGPoint(x:3,y:8.5));p.addLine(to:CGPoint(x:21,y:8.5));p.move(to:CGPoint(x:7.4,y:3));p.addLine(to:CGPoint(x:10.7,y:8.5));p.move(to:CGPoint(x:14.3,y:3));p.addLine(to:CGPoint(x:17.6,y:8.5));p.move(to:CGPoint(x:10,y:11.1));p.addLine(to:CGPoint(x:16,y:14.7));p.addLine(to:CGPoint(x:10,y:18.1));p.closeSubpath() }
        case "reelDetails":
            p.move(to:CGPoint(x:3,y:8.5));p.addLine(to:CGPoint(x:21,y:8.5));p.move(to:CGPoint(x:7.4,y:3));p.addLine(to:CGPoint(x:10.7,y:8.5));p.move(to:CGPoint(x:14.3,y:3));p.addLine(to:CGPoint(x:17.6,y:8.5));p.move(to:CGPoint(x:10,y:11.1));p.addLine(to:CGPoint(x:16,y:14.7));p.addLine(to:CGPoint(x:10,y:18.1));p.closeSubpath()
        case "grid":
            for row in 0..<3 { for col in 0..<3 { p.addRoundedRect(in:CGRect(x:3+Double(col)*6.5,y:3+Double(row)*6.5,width:4.7,height:4.7),cornerSize:CGSize(width:0.7,height:0.7)) } }
        case "repeat":
            p.move(to:CGPoint(x:4.4,y:10));p.addLine(to:CGPoint(x:4.4,y:7.5));p.addQuadCurve(to:CGPoint(x:7.2,y:4.8),control:CGPoint(x:4.4,y:4.8));p.addLine(to:CGPoint(x:19.6,y:4.8));p.move(to:CGPoint(x:16.2,y:1.8));p.addLine(to:CGPoint(x:19.6,y:4.8));p.addLine(to:CGPoint(x:16.2,y:8.1));p.move(to:CGPoint(x:19.6,y:14));p.addLine(to:CGPoint(x:19.6,y:16.5));p.addQuadCurve(to:CGPoint(x:16.8,y:19.2),control:CGPoint(x:19.6,y:19.2));p.addLine(to:CGPoint(x:4.4,y:19.2));p.move(to:CGPoint(x:7.8,y:15.9));p.addLine(to:CGPoint(x:4.4,y:19.2));p.addLine(to:CGPoint(x:7.8,y:22.2))
        case "tagPerson":
            p.addRoundedRect(in:CGRect(x:2.5,y:2.5,width:19,height:19),cornerSize:CGSize(width:4,height:4));p.addEllipse(in:CGRect(x:9.1,y:5.1,width:5.8,height:5.8));p.move(to:CGPoint(x:6.2,y:18.2));p.addCurve(to:CGPoint(x:17.8,y:18.2),control1:CGPoint(x:7.2,y:12.6),control2:CGPoint(x:16.8,y:12.6))
        case "more":
            for x in [4.0,12.0,20.0] { p.addEllipse(in:CGRect(x:x-1.5,y:10.5,width:3,height:3)) }
        default: break
        }
        return p.applying(CGAffineTransform(scaleX:rect.width/24,y:rect.height/24))
    }
}
struct GpixIcon:View {
    let systemName:String
    var size:CGFloat=24
    private var kind:String {
        ["house":"home","house.fill":"homeFill","heart":"heart","heart.fill":"heartFill","paperplane":"send","paperplane.fill":"sendFill","bubble.right":"chat","bubble.right.fill":"chatFill","bookmark":"save","bookmark.fill":"saveFill","magnifyingglass":"search","camera":"camera","camera.fill":"camera","play.rectangle":"reel","play.rectangle.fill":"reelFill","ellipsis":"more","square.grid.3x3":"grid","square.grid.2x2":"grid","arrow.2.squarepath":"repeat","person.crop.square":"tagPerson"][systemName] ?? ""
    }
    var body:some View {
        Group {
            if kind.isEmpty { Image(systemName:systemName).resizable().scaledToFit() }
            else if kind.hasSuffix("Fill") || kind=="more" {
                GpixGlyph(kind:kind).fill().overlay {
                    if kind=="reelFill" { GpixGlyph(kind:"reelDetails").stroke(style:StrokeStyle(lineWidth:1.85*size/24,lineCap:.round,lineJoin:.round)).blendMode(.destinationOut) }
                }.compositingGroup()
            } else {
                GpixGlyph(kind:kind).stroke(style:StrokeStyle(lineWidth:(kind=="grid" ? 1.55:1.85)*size/24,lineCap:.round,lineJoin:.round))
            }
        }.frame(width:size,height:size)
    }
}
extension Font {
    static func gpix(size:CGFloat,weight:Font.Weight = .regular)->Font {
        .custom("Roboto-Regular",size:size).weight(weight)
    }
}
let gpixInk=Color(uiColor:UIColor { $0.userInterfaceStyle == .dark ? .white : UIColor(red:21.0/255,green:21.0/255,blue:27.0/255,alpha:1) })
let gpixMuted=Color(red:133.0/255,green:133.0/255,blue:143.0/255)
let gpixSoft=Color(uiColor:UIColor { $0.userInterfaceStyle == .dark ? UIColor(red:37.0/255,green:37.0/255,blue:45.0/255,alpha:1) : UIColor(red:244.0/255,green:244.0/255,blue:247.0/255,alpha:1) })

@MainActor
struct GpixActionRow:View {
    let title:String
    let icon:String
    let action:@MainActor ()->Void
    var body:some View {
        Button { action() } label: {
            HStack(spacing:17) {
                GpixIcon(systemName:icon,size:24)
                Text(title).font(.gpix(size:15))
                Spacer(minLength:0)
            }.foregroundStyle(gpixInk).padding(.horizontal,22).padding(.vertical,12).frame(minHeight:55).contentShape(Rectangle())
        }.buttonStyle(GpixPressStyle())
    }
}
