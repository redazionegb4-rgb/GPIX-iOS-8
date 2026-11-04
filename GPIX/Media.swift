import SwiftUI
import UIKit
import PhotosUI
import AVKit
import WebKit
// Shared URL rules match the original Flutter GpixStore.url implementation.
func resolvedRemoteMediaURL(_ reference: String, server: String = "https://gpix.cc") -> URL? {
    let value = reference.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return nil }
    if let url = URL(string: value), url.scheme == "https", url.host != nil { return url }
    guard value.hasPrefix("/media/") || value.hasPrefix("/music/audio/") else { return nil }
    return URL(string: server.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + value)
}
func postMediaReferences(_ post: Row) -> [String] {
    let values = (post["mediaItems"] as? [Any] ?? []).compactMap { item -> String? in
        if let text = item as? String, !text.isEmpty { return text }
        if let row = item as? Row, !row.s("url").isEmpty { return row.s("url") }
        return nil
    }
    if !values.isEmpty { return values }
    return post.s("media").isEmpty ? [] : [post.s("media")]
}
func mediaURL(_ reference: String) -> URL {
    if let url = resolvedRemoteMediaURL(reference) { return url }
    if reference.hasPrefix("file://"), let url = URL(string: reference) { return url }
    if let url = Bundle.main.url(forResource: reference, withExtension: nil, subdirectory: "Media") { return url }
    return URL(fileURLWithPath: "/unavailable-gpix-media")
}
@MainActor
struct NativeVideo:View{
    let reference:String
    var autoplay=true
    @State private var player:AVPlayer?
    var body:some View{
        VideoPlayer(player:player).onAppear{
            player=AVPlayer(url:mediaURL(reference))
            if autoplay{
                player?.play()
            }
        }
        .onChange(of:autoplay){
            _, value in if value{
                player?.play()
            }
            else{
                player?.pause()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for:.AVPlayerItemDidPlayToEndTime)){
            notification in if let item=notification.object as? AVPlayerItem,item === player?.currentItem,autoplay{
                player?.seek(to:.zero)
                player?.play()
            }
        }
        .onDisappear{
            player?.pause()
            player=nil
        }
    }
}
@MainActor
struct ReelsView:View {
    @EnvironmentObject var store:GpixStore
    @State private var create=false
    @State private var active:String?
    var reels:[Row]{
        store.posts.filter{
            $0.s("kind")=="reel" && !$0.b("archived")
        }
    }
    var body:some View {
        ScrollView(.vertical){
            LazyVStack(spacing:0){
                ForEach(reels,id:\.id){
                    post in
                    ReelPage(post:post,active:active==post.id || active==nil).containerRelativeFrame(.vertical).id(post.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging).scrollPosition(id:$active).scrollIndicators(.hidden)
        .navigationTitle("Reel").navigationBarTitleDisplayMode(.inline).toolbar{
            Button{
                create=true
            } label: {
                GpixIcon(systemName:"camera")
            }
        }
        .sheet(isPresented:$create){
            ComposerView(kind:"reel")
        }
    }
}
@MainActor
struct ReelPage:View {
    @EnvironmentObject var store:GpixStore
    let post:Row
    let active:Bool
    var body:some View {
        ZStack(alignment:.bottom){
            NativeVideo(reference:post.s("media"),autoplay:active)
            HStack(alignment:.bottom){
                VStack(alignment:.leading,spacing:10){
                    NavigationLink{
                        ProfileView(userID:post.s("author"))
                    } label: {
                        HStack{
                            AvatarView(person:store.person(post.s("author")),size:33)
                            Text(store.person(post.s("author")).s("username")).bold()
                        }
                    }
                    Text(post.s("text")).font(.gpix(size:14,weight:.regular))
                }
                Spacer()
                VStack(spacing:23){
                    Button{
                        store.perform("like",["id":post.id,"enabled":!post.ids("likes").contains(store.myID)])
                    } label: {
                        Image(systemName:post.ids("likes").contains(store.myID) ? "heart.fill":"heart").font(.gpix(size:28,weight:.regular)).foregroundStyle(post.ids("likes").contains(store.myID) ? Color.red:Color.white)
                    }
                    Text("\(post.ids("likes").count)").font(.gpix(size:12,weight:.regular))
                    NavigationLink{
                        CommentsView(postID:post.id)
                    } label: {
                        GpixIcon(systemName:"bubble.right").font(.gpix(size:28,weight:.regular))
                    }
                    NavigationLink{
                        SharePostView(postID:post.id)
                    } label: {
                        GpixIcon(systemName:"paperplane").font(.gpix(size:28,weight:.regular))
                    }
                    PostOptions(post:post)
                }
            }
            .padding(20).foregroundStyle(.white).shadow(radius:4)
        }
    }
}
@MainActor
struct GIFView:UIViewRepresentable{
    let reference:String
    func makeUIView(context:Context)->WKWebView{
        let config=WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript=false
        let view=WKWebView(frame:.zero,configuration:config)
        view.isOpaque=false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled=false
        return view
    }
    func updateUIView(_ view:WKWebView,context:Context){
        let url=mediaURL(reference).absoluteString.replacingOccurrences(of:"&",with:"&amp;").replacingOccurrences(of:"\"",with:"&quot;")
        view.loadHTMLString("<meta name='viewport' content='width=device-width,initial-scale=1'><style>body{margin:0;background:transparent}img{width:100%;height:100%;object-fit:contain}</style><img src=\"\(url)\">",baseURL:Bundle.main.resourceURL)
    }
}
@MainActor
struct GiphyPicker:View{
    @EnvironmentObject var store:GpixStore
    let select:(String)->Void
    @State private var query=""
    @State private var items:[Row]=[]
    @State private var loading=false
    @State private var offset=0
    @State private var message=""
    var body:some View{
        NavigationStack{
            ScrollView{
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())]){
                    ForEach(items,id:\.id){
                        gif in Button{
                            select(gif.row("images").row("original").s("url"))
                        } label: {
                            GIFView(reference:gif.row("images").row("fixed_height").s("url")).frame(height:150).clipShape(RoundedRectangle(cornerRadius:12))
                        }
                    }
                }
                if !message.isEmpty{
                    Text(message).foregroundStyle(gpixMuted).padding()
                }
                if loading{
                    ProgressView()
                }
                else if !items.isEmpty{
                    Button("Carica altre GIF"){
                        Task{
                            await load(more:true)
                        }
                    }
                }
            }
            .searchable(text:$query,prompt:"Cerca GIF").onSubmit(of:.search){
                Task{
                    await load(more:false)
                }
            }
            .navigationTitle("GIF · GIPHY").task{
                await load(more:false)
            }
        }
    }
    func load(more:Bool)async{
        loading=true
        defer{
            loading=false
        }
        do{
            if store.demo{
                items=(0..<6).map{
                    ["id":"gif\($0)","images":["original":["url":"gif\($0).gif"],"fixed_height":["url":"gif\($0).gif"]]]
                }
                return
            }
            if !more{
                offset=0
            }
            var components=URLComponents()
            components.queryItems=[URLQueryItem(name:"q",value:query),URLQueryItem(name:"offset",value:"\(offset)")]
            let r=try await store.api("/giphy?"+(components.percentEncodedQuery ?? ""))
            if more{
                items+=r.rows("data")
            }
            else{
                items=r.rows("data")
            }
            offset=items.count
            message=items.isEmpty ? "Nessuna GIF trovata":""
        }
        catch{
            message=error.localizedDescription
        }
    }
}
@MainActor
struct CameraPicker:UIViewControllerRepresentable{
    let video:Bool
    let completion:(UIImage?,URL?)->Void
    @Environment(\.dismiss) var dismiss
    func makeCoordinator()->Coordinator{
        Coordinator(self)
    }
    func makeUIViewController(context:Context)->UIImagePickerController{
        let picker=UIImagePickerController()
        picker.delegate=context.coordinator
        picker.sourceType=UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera:.photoLibrary
        picker.mediaTypes=video ? ["public.movie"]:["public.image"]
        picker.videoMaximumDuration=60
        picker.videoQuality = .typeHigh
        return picker
    }
    func updateUIViewController(_ uiViewController:UIImagePickerController,context:Context){
    }
    class Coordinator:NSObject,UINavigationControllerDelegate,UIImagePickerControllerDelegate{
        let parent:CameraPicker
        init(_ parent:CameraPicker){
            self.parent=parent
        }
        func imagePickerControllerDidCancel(_ picker:UIImagePickerController){
            parent.dismiss()
        }
        func imagePickerController(_ picker:UIImagePickerController,didFinishPickingMediaWithInfo info:[UIImagePickerController.InfoKey:Any]){
            parent.completion(info[.originalImage] as? UIImage,info[.mediaURL] as? URL)
            parent.dismiss()
        }
    }
}
@MainActor final class VoiceRecorder:ObservableObject{
    @Published var recording=false
    @Published var seconds=0.0
    private var recorder:AVAudioRecorder?,timer:Timer?,url:URL?
    func start()async throws{
        let allowed = await AVAudioApplication.requestRecordPermission()
        guard allowed else{
            throw GError(message:"Autorizza il microfono nelle impostazioni")
        }
        let session=AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,mode:.default,options:[.defaultToSpeaker,.allowBluetooth])
        try session.setActive(true)
        let path=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".m4a")
        url=path
        let r=try AVAudioRecorder(url:path,settings:[AVFormatIDKey:kAudioFormatMPEG4AAC,AVSampleRateKey:44100,AVNumberOfChannelsKey:1,AVEncoderAudioQualityKey:AVAudioQuality.high.rawValue])
        recorder=r
        seconds=0
        r.record(forDuration:180)
        recording=true
        timer=Timer.scheduledTimer(withTimeInterval:0.5,repeats:true){
            [weak self] _ in
            guard let recorder = self else { return }
            Task { @MainActor [weak recorder] in
                recorder?.seconds += 0.5
            }
        }
    }
    func stop()throws->Data{
        recorder?.stop()
        recording=false
        timer?.invalidate()
        timer=nil
        guard let url=url else{
            throw GError(message:"Registrazione non disponibile")
        }
        let data=try Data(contentsOf:url)
        try? FileManager.default.removeItem(at:url)
        self.url=nil
        try? AVAudioSession.sharedInstance().setActive(false)
        return data
    }
    deinit{
        timer?.invalidate()
        recorder?.stop()
    }
}
@MainActor
struct MusicPicker:View{
    @EnvironmentObject var store:GpixStore
    let select:(Row)->Void
    @State private var query=""
    @State private var tracks:[Row]=[]
    @State private var message=""
    @State private var player:AVPlayer?
    var body:some View{
        NavigationStack{
            List{
                if !message.isEmpty{
                    Text(message).foregroundStyle(gpixMuted)
                }
                ForEach(tracks,id:\.id){
                    track in HStack{
                        Button{
                            player?.pause()
                            player=AVPlayer(url:mediaURL(track.s("audio")))
                            player?.play()
                        } label: {
                            Image(systemName:"play.circle").font(.gpix(size:28,weight:.regular))
                        }
                        VStack(alignment:.leading){
                            Text(track.s("title")).bold()
                            Text(track.s("artist")).font(.gpix(size:12,weight:.regular)).foregroundStyle(gpixMuted)
                        }
                        Spacer()
                        Button("Aggiungi"){
                            var t=track
                            t["start"]=0
                            t["clipDuration"]=min(15,track.n("duration",15))
                            select(t)
                        }
                    }
                }
                .navigationTitle("Musica").searchable(text:$query).onSubmit(of:.search){
                    Task{
                        await load()
                    }
                }
                .task{
                    await load()
                }
                .onDisappear{
                    player?.pause()
                }
            }
        }
    }
    func load()async{
        if store.demo{
            message="Il catalogo reale è disponibile dopo l’accesso."
            return
        }
        do{
            var c=URLComponents()
            c.queryItems=[URLQueryItem(name:"q",value:query)]
            tracks=try await store.api("/music?"+(c.percentEncodedQuery ?? "")).rows("tracks")
            message=tracks.isEmpty ? "Nessun brano disponibile":""
        }
        catch{
            message=error.localizedDescription
        }
    }
}

@MainActor
struct ProfilePostMedia: View {
    let post: Row
    var body: some View {
        if post.s("kind") == "reel" {
            VideoThumbnail(reference: post.s("media"))
        } else {
            MediaView(reference: postMediaReferences(post).first ?? "", fill: true)
        }
    }
}
@MainActor
struct VideoThumbnail: View {
    let reference: String
    @State private var image: UIImage?
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.secondary.opacity(0.09)
                if let image = image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "play.rectangle").foregroundStyle(Color.secondary)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .task(id: reference) {
            image = nil
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: mediaURL(reference)))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 600, height: 600)
            if let result = try? await generator.image(at: CMTime(seconds: 0, preferredTimescale: 600)), !Task.isCancelled {
                image = UIImage(cgImage: result.image)
            }
        }
    }
}
