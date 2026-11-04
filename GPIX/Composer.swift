import SwiftUI
import PhotosUI
import CoreImage.CIFilterBuiltins
import AVFoundation
struct Draft:Codable,Identifiable{
    var id:String
    var kind:String
    var caption:String
    var location:String
    var mediaFiles:[String]
    var styleData:Data
    var created:Double
}
@MainActor enum DraftVault{
    static var folder:URL{
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("GpixDrafts")
        try? FileManager.default.createDirectory(at:url,withIntermediateDirectories:true)
        return url
    }
    static func list(_ owner:String)->[Draft]{
        guard let data=try? Data(contentsOf:folder.appendingPathComponent(owner+".json")),let drafts=try? JSONDecoder().decode([Draft].self,from:data)else{
            return []
        }
        return drafts.sorted{
            $0.created>$1.created
        }
    }
    static func put(_ draft:Draft,owner:String)throws{
        var rows=list(owner).filter{
            $0.id != draft.id
        }
        rows.insert(draft,at:0)
        try JSONEncoder().encode(rows).write(to:folder.appendingPathComponent(owner+".json"),options:.atomic)
    }
    static func remove(_ id:String,owner:String){
        let rows=list(owner)
        if let row=rows.first(where:{
            $0.id==id
        }
        ){
            for file in row.mediaFiles{
                try? FileManager.default.removeItem(at:folder.appendingPathComponent(file))
            }
        }
        if let data=try? JSONEncoder().encode(rows.filter{
            $0.id != id
        }
        ){
            try? data.write(to:folder.appendingPathComponent(owner+".json"),options:.atomic)
        }
    }
}
@MainActor
struct DraftsView:View{
    @EnvironmentObject var store:GpixStore
    @State private var drafts:[Draft]=[]
    @State private var selected:Draft?
    var body:some View{
        List{
            ForEach(drafts){
                draft in Button{
                    selected=draft
                } label: {
                    HStack{
                        Image(systemName:draft.kind=="reel" ? "play.rectangle":"photo").font(.title2)
                        VStack(alignment:.leading){
                            Text(draft.caption.isEmpty ? draft.kind.capitalized:draft.caption).lineLimit(2)
                            Text(ago(draft.created)+" fa").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .swipeActions{
                    Button("Elimina",role:.destructive){
                        DraftVault.remove(draft.id,owner:store.demo ? "demo":store.myID)
                        load()
                    }
                }
            }
            if drafts.isEmpty{
                Text("Non hai ancora bozze salvate").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Bozze").onAppear{
            load()
        }
        .sheet(item:$selected,onDismiss:{
            load()
        }
        ){
            draft in ComposerView(kind:draft.kind,draft:draft)
        }
    }
    func load(){
        drafts=DraftVault.list(store.demo ? "demo":store.myID)
    }
}
@MainActor
struct ComposerView:View{
    @EnvironmentObject var store:GpixStore
    @Environment(\.dismiss) var dismiss
    let kind:String
    var draft:Draft?=nil
    @State private var selected:[PhotosPickerItem]=[]
    @State private var images:[UIImage]=[]
    @State private var videoURL:URL?
    @State private var caption=""
    @State private var location=""
    @State private var overlay=""
    @State private var filter="Normal"
    @State private var adjustments:[String:Double]=[:]
    @State private var textX=0.5
    @State private var textY=0.5
    @State private var textSize=28.0
    @State private var textColor=Color.white
    @State private var page=0
    @State private var camera=false
    @State private var adjust=false
    @State private var music=false
    @State private var busy=false
    @State private var confirmClose=false
    @State private var saveInfo=false
    @State private var audience="all"
    @State private var musicTrack:Row=[:]
    @State private var draftID=UUID().uuidString
    @State private var pollQuestion=""
    @State private var pollA=""
    @State private var pollB=""
    @State private var poll=false
    @State private var filterMode=false
    @State private var cropAspect=0.0
    @State private var tagIDs:Set<String>=[]
    @State private var tagging=false
    private var owner:String{
        store.demo ? "demo":store.myID
    }
    private var current:UIImage?{
        images.indices.contains(page) ? images[page]:images.first
    }
    var body:some View{
        NavigationStack{
            ScrollView{
                VStack(spacing:18){
                    Picker("Tipo",selection:.constant(kind)){
                        Text(kind=="story" ? "Storia":kind=="reel" ? "Reel":"Post").tag(kind)
                    }
                    .pickerStyle(.segmented).disabled(true)
                    if let image=current{
                        photoPreview(PhotoEffects.crop(image,aspect:cropAspect))
                    }
                    else if let url=videoURL{
                        NativeVideo(reference:url.absoluteString).frame(height:340)
                    }
                    else{
                        EmptyViewCard(icon:kind=="reel" ? "video":"photo",title:kind=="reel" ? "Crea un reel":"Condividi un momento",subtitle:"Seleziona un contenuto o apri la fotocamera.")
                    }
                    HStack(spacing:18){
                        PhotosPicker(selection:$selected,maxSelectionCount:kind=="post" ? 10:1,matching:kind=="reel" ? .videos:.images){
                            Label("Galleria",systemImage:"photo.on.rectangle")
                        }
                        Button{
                            camera=true
                        } label: {
                            Label("Fotocamera",systemImage:"camera")
                        }
                    }
                    .font(.subheadline.bold())
                    if images.count>1{
                        Picker("Foto",selection:$page){
                            ForEach(0..<images.count,id:\.self){
                                Text("\($0+1)").tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    if current != nil{
                        Picker("Formato",selection:$cropAspect){
                            Text("Originale").tag(0.0)
                            Text("1:1").tag(1.0)
                            Text("4:5").tag(0.8)
                            Text("16:9").tag(16.0/9.0)
                        }
                        .pickerStyle(.segmented)
                        TextField("Testo sulla foto",text:$overlay).textFieldStyle(.roundedBorder)
                        HStack{
                            ColorPicker("Colore",selection:$textColor, supportsOpacity:false).labelsHidden()
                            Image(systemName:"textformat.size")
                            Slider(value:$textSize,in:14...72)
                            Button{
                                adjust=true
                            } label: {
                                Label("Modifica",systemImage:"slider.horizontal.3")
                            }
                        }
                        Text("Trascina il testo in qualsiasi punto della foto.").font(.caption).foregroundStyle(.secondary)
                        ScrollView(.horizontal,showsIndicators:false){
                            HStack(spacing:12){
                                ForEach(PhotoEffects.filters,id:\.self){
                                    name in Button{
                                        filter=name
                                    } label: {
                                        VStack(spacing:6){
                                            Image(uiImage:PhotoEffects.render(image:current!,filter:name,adjustments:[:],thumbnail:true)).resizable().scaledToFill().frame(width:64,height:70).clipped().clipShape(RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).stroke(filter==name ? gpixPurple:Color.clear,lineWidth:2))
                                            Text(name).font(.system(size:10)).foregroundStyle(.primary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    TextField(kind=="story" ? "Testo della storia":"Scrivi una didascalia…",text:$caption,axis:.vertical).lineLimit(2...6).padding(12).background(Color.secondary.opacity(0.07),in:RoundedRectangle(cornerRadius:12))
                    TextField("Aggiungi luogo",text:$location).textFieldStyle(.roundedBorder)
                    Button{
                        tagging=true
                    } label: {
                        Label("Tagga persone · \(tagIDs.count)",systemImage:"person.crop.square")
                    }
                    Button{
                        music=true
                    } label: {
                        Label(musicTrack.isEmpty ? "Aggiungi musica":musicTrack.s("artist")+" · "+musicTrack.s("title"),systemImage:"music.note")
                    }
                    if !musicTrack.isEmpty{
                        HStack{
                            Text("Inizio \(Int(musicTrack.n("start"))) s").font(.caption)
                            Slider(value:Binding(get:{
                                musicTrack.n("start")
                            }
                            ,set:{
                                musicTrack["start"]=$0
                            }
                            ),in:0...max(1,musicTrack.n("duration",30)-musicTrack.n("clipDuration",15)))
                        }
                        Button("Rimuovi musica"){
                            musicTrack=[:]
                        }
                        .font(.caption)
                    }
                    Picker("Pubblico",selection:$audience){
                        Text("Tutti").tag("all")
                        Text("Amici più stretti").tag("close")
                    }
                    .pickerStyle(.segmented)
                    if kind=="story"{
                        Toggle("Aggiungi sondaggio",isOn:$poll)
                        if poll{
                            TextField("Domanda",text:$pollQuestion).textFieldStyle(.roundedBorder)
                            TextField("Prima risposta",text:$pollA).textFieldStyle(.roundedBorder)
                            TextField("Seconda risposta",text:$pollB).textFieldStyle(.roundedBorder)
                        }
                    }
                    PrimaryButton(title:busy ? "Pubblicazione…":"Condividi",disabled:busy){
                        publish()
                    }
                    Button{
                        saveDraft()
                    } label: {
                        Label("Salva come bozza",systemImage:"square.and.arrow.down")
                    }
                    .disabled(busy)
                }
                .padding(18)
            }
            .navigationTitle(kind=="reel" ? "Nuovo reel":kind=="story" ? "Nuova storia":"Nuovo post").navigationBarTitleDisplayMode(.inline).toolbar{
                ToolbarItem(placement:.cancellationAction){
                    Button("Chiudi"){
                        confirmClose=true
                    }
                }
            }
            .interactiveDismissDisabled(true)
            .confirmationDialog("Vuoi salvare prima di uscire?",isPresented:$confirmClose){
                Button("Salva bozza"){
                    saveDraft(close:true)
                }
                Button("Esci senza salvare",role:.destructive){
                    dismiss()
                }
            }
            .alert("Bozza salvata",isPresented:$saveInfo){
                Button("OK"){
                }
            } message: {
                Text("La trovi in Impostazioni e attività → Bozze.")
            }
            .sheet(isPresented:$camera){
                CameraPicker(video:kind=="reel"){
                    image,url in if let image=image{
                        images=[image]
                    }
                    if let url=url{
                        videoURL=url
                    }
                    camera=false
                }
            }
            .sheet(isPresented:$music){
                MusicPicker{
                    track in musicTrack=track
                    music=false
                }
            }
            .sheet(isPresented:$adjust){
                AdjustmentSheet(values:$adjustments)
            }
            .sheet(isPresented:$tagging){
                NavigationStack{
                    List{
                        ForEach(store.users.filter{
                            $0.id != store.myID
                        }
                        ,id:\.id){
                            person in Button{
                                if tagIDs.contains(person.id){
                                    tagIDs.remove(person.id)
                                }
                                else{
                                    tagIDs.insert(person.id)
                                }
                            } label: {
                                HStack{
                                    PersonLine(person:person)
                                    Image(systemName:tagIDs.contains(person.id) ? "checkmark.circle.fill":"circle")
                                }
                            }
                        }
                    }
                    .navigationTitle("Tagga persone").toolbar{
                        Button("Fine"){
                            tagging=false
                        }
                    }
                }
            }
            .onChange(of:selected){
                _, items in Task{
                    busy=true
                    defer{
                        busy=false
                    }
                    var next:[UIImage]=[]
                    for item in items{
                        if kind=="reel"{
                            if let data=try? await item.loadTransferable(type:Data.self){
                                let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".mov")
                                try? data.write(to:url)
                                videoURL=url
                            }
                        }
                        else if let data=try? await item.loadTransferable(type:Data.self),let image=UIImage(data:data){
                            next.append(PhotoEffects.resized(image,limit:2400))
                        }
                    }
                    if !next.isEmpty{
                        images=next
                        page=0
                    }
                }
            }
            .onAppear{
                restore()
            }
        }
    }
    func photoPreview(_ image:UIImage)->some View{
        GeometryReader{
            g in ZStack{
                Image(uiImage:PhotoEffects.render(image:image,filter:filter,adjustments:adjustments)).resizable().scaledToFit()
                if !overlay.isEmpty{
                    Text(overlay).font(.system(size:textSize,weight:.semibold)).foregroundStyle(textColor).shadow(radius:2).fixedSize(horizontal:false,vertical:true).frame(maxWidth:g.size.width*0.95).position(x:textX*g.size.width,y:textY*g.size.height).gesture(DragGesture(coordinateSpace:.named("photoEdit")).onChanged{
                        v in textX=min(0.98,max(0.02,v.location.x/g.size.width))
                        textY=min(0.98,max(0.02,v.location.y/g.size.height))
                    }
                    )
                }
            }
            .coordinateSpace(name:"photoEdit")
        }
        .aspectRatio(image.size.width/image.size.height,contentMode:.fit).clipped().clipShape(RoundedRectangle(cornerRadius:14))
    }
    func rendered(_ image:UIImage)->UIImage{
        let result=PhotoEffects.render(image:PhotoEffects.crop(image,aspect:cropAspect),filter:filter,adjustments:adjustments)
        guard !overlay.isEmpty else{
            return result
        }
        let format=UIGraphicsImageRendererFormat()
        format.scale=1
        return UIGraphicsImageRenderer(size:result.size,format:format).image{
            _ in result.draw(in:CGRect(origin:.zero,size:result.size))
            let font=UIFont.systemFont(ofSize:textSize*result.size.width/350,weight:.semibold)
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 3
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.3)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(textColor),
                .shadow: shadow
            ]
            let size=(overlay as NSString).boundingRect(with:CGSize(width:result.size.width*0.95,height:result.size.height),options:.usesLineFragmentOrigin,attributes:attrs,context:nil).size
            let x=max(0,min(result.size.width-size.width,result.size.width*textX-size.width/2)),y=max(0,min(result.size.height-size.height,result.size.height*textY-size.height/2))
            (overlay as NSString).draw(in:CGRect(x:x,y:y,width:size.width,height:size.height),withAttributes:attrs)
        }
    }
    func publish(){
        busy=true
        Task{
            defer{
                busy=false
            }
            do{
                var media:[String]=[]
                if kind=="reel"{
                    guard let url=videoURL else{
                        throw GError(message:"Seleziona un video")
                    }
                    let m=try await store.upload(Data(contentsOf:url),mime:"video/quicktime")
                    media=[m.s("id")]
                }
                else{
                    for image in images{
                        guard let data=rendered(image).jpegData(compressionQuality:0.9)else{
                            continue
                        }
                        let m=try await store.upload(data,mime:"image/jpeg")
                        media.append(m.s("id"))
                    }
                }
                guard !media.isEmpty || kind=="story" && !caption.isEmpty else{
                    throw GError(message:"Aggiungi un contenuto")
                }
                var style:Row=["aspect":cropAspect>0 ? cropAspect:(images.first.map{
                    Double($0.size.width/$0.size.height)
                }
                ?? 1),"taggedUsers":Array(tagIDs)]
                if !musicTrack.isEmpty{
                    style["music"]=musicTrack
                }
                if poll{
                    style["poll"]=["question":pollQuestion,"options":[pollA,pollB]]
                }
                try await store.act("post",["kind":kind,"text":caption,"location":location,"media":media.first ?? "","mediaItems":media,"style":style,"audience":audience,"idempotencyKey":draftID])
                DraftVault.remove(draftID,owner:owner)
                dismiss()
            }
            catch{
                store.error=error.localizedDescription
            }
        }
    }
    func saveDraft(close:Bool=false){
        do{
            var files:[String]=[]
            for (index,image) in images.enumerated(){
                let name=draftID+"-\(index).jpg"
                try image.jpegData(compressionQuality:0.95)?.write(to:DraftVault.folder.appendingPathComponent(name),options:.atomic)
                files.append(name)
            }
            if let url=videoURL{
                let name=draftID+".mov",dest=DraftVault.folder.appendingPathComponent(draftID+".mov")
                if url != dest{
                    try? FileManager.default.removeItem(at:dest)
                    try FileManager.default.copyItem(at:url,to:dest)
                }
                files.append(name)
            }
            let style:Row=["cropAspect":cropAspect,"tagIDs":Array(tagIDs),"filter":filter,"adjustments":adjustments,"overlay":overlay,"textX":textX,"textY":textY,"textSize":textSize,"color":UIColor(textColor).hexString,"audience":audience,"music":musicTrack,"poll":poll,"pollQuestion":pollQuestion,"pollA":pollA,"pollB":pollB]
            let data=try JSONSerialization.data(withJSONObject:style)
            try DraftVault.put(Draft(id:draftID,kind:kind,caption:caption,location:location,mediaFiles:files,styleData:data,created:Date().timeIntervalSince1970),owner:owner)
            if close{
                dismiss()
            }
            else{
                saveInfo=true
            }
        }
        catch{
            store.error=error.localizedDescription
        }
    }
    func restore(){
        guard let draft=draft else{
            return
        }
        draftID=draft.id
        caption=draft.caption
        location=draft.location
        let style=(try? JSONSerialization.jsonObject(with:draft.styleData)) as? Row ?? [:]
        cropAspect=style.n("cropAspect")
        tagIDs=Set(style.ids("tagIDs"))
        filter=style.s("filter","Normal")
        adjustments=style["adjustments"] as? [String:Double] ?? [:]
        overlay=style.s("overlay")
        textX=style.n("textX",0.5)
        textY=style.n("textY",0.5)
        textSize=style.n("textSize",28)
        textColor=Color(uiColor:UIColor(hex:style.s("color","FFFFFF")))
        audience=style.s("audience","all")
        musicTrack=style.row("music")
        poll=style.b("poll")
        pollQuestion=style.s("pollQuestion")
        pollA=style.s("pollA")
        pollB=style.s("pollB")
        for name in draft.mediaFiles{
            let url=DraftVault.folder.appendingPathComponent(name)
            if name.hasSuffix(".mov"){
                videoURL=url
            }
            else if let image=UIImage(contentsOfFile:url.path){
                images.append(image)
            }
        }
    }
}
extension UIColor{
    var hexString:String{
        var r:CGFloat=0,g:CGFloat=0,b:CGFloat=0,a:CGFloat=0
        getRed(&r,green:&g,blue:&b,alpha:&a)
        return String(format:"%02X%02X%02X",Int(r*255),Int(g*255),Int(b*255))
    }
    convenience init(hex:String){
        let number=UInt32(hex,radix:16) ?? 0xFFFFFF
        self.init(red:CGFloat((number>>16)&255)/255,green:CGFloat((number>>8)&255)/255,blue:CGFloat(number&255)/255,alpha:1)
    }
}
@MainActor
struct AdjustmentSheet:View{
    @Environment(\.dismiss) var dismiss
    @Binding var values:[String:Double]
    @State private var initial:[String:Double]=[:]
    let names=["Regola","Lux","Luminosità","Contrasto","Saturazione","Colore","Sfumatura","Alte luci","Ombre","Vignettatura","Tilt-Shift","Nitidezza"]
    var body:some View{
        NavigationStack{
            List{
                ForEach(names,id:\.self){
                    name in VStack(alignment:.leading){
                        HStack{
                            Label(name,systemImage:icon(name))
                            Spacer()
                            Text("\(Int(values[name] ?? 0))").foregroundStyle(.secondary)
                        }
                        Slider(value:Binding(get:{
                            values[name] ?? 0
                        }
                        ,set:{
                            values[name]=$0
                        }
                        ),in:name=="Regola" ? -45...45:-100...100)
                    }
                }
                Button("Ripristina"){
                    values=[:]
                }
            }
            .navigationTitle("Modifica").toolbar{
                ToolbarItem(placement:.cancellationAction){
                    Button("Annulla"){
                        values=initial
                        dismiss()
                    }
                }
                ToolbarItem(placement:.confirmationAction){
                    Button("Fine"){
                        dismiss()
                    }
                }
            }
            .onAppear{
                initial=values
            }
        }
    }
    func icon(_ name:String)->String{
        ["Regola":"rotate.right","Lux":"wand.and.stars","Luminosità":"sun.max","Contrasto":"circle.lefthalf.filled","Saturazione":"drop","Colore":"rainbow","Sfumatura":"cloud","Alte luci":"sun.max.fill","Ombre":"moon","Vignettatura":"circle.circle","Tilt-Shift":"circle.dashed","Nitidezza":"triangle"][name] ?? "slider.horizontal.3"
    }
}
enum PhotoEffects{
    static let context=CIContext(options:[.cacheIntermediates:false])
    static let filters=["Normal","Fade","Fade warm","Fade cool","Simple warm","Simple cool","Boost","Boost warm","Boost cool","Gritty","Halo","Color leak","Soft light","Jaipur","Cairo","Tokyo","Rio De Janeiro","Oslo","Paris","Melbourne"]
    static func crop(_ image:UIImage,aspect:Double)->UIImage {
        guard aspect>0 else{
            return image
        }
        let normalized=resized(image,limit:2400)
        let original=normalized.size.width/normalized.size.height
        let width=original>aspect ? normalized.size.height*aspect:normalized.size.width
        let height=original>aspect ? normalized.size.height:normalized.size.width/aspect
        let rect=CGRect(x:(normalized.size.width-width)/2,y:(normalized.size.height-height)/2,width:width,height:height)
        guard let cg=normalized.cgImage?.cropping(to:rect)else{
            return image
        }
        return UIImage(cgImage:cg)
    }
    static func resized(_ image:UIImage,limit:CGFloat)->UIImage{
        let factor=min(1,limit/max(image.size.width,image.size.height))
        let size=CGSize(width:image.size.width*factor,height:image.size.height*factor)
        let f=UIGraphicsImageRendererFormat()
        f.scale=1
        return UIGraphicsImageRenderer(size:size,format:f).image{
            _ in image.draw(in:CGRect(origin:.zero,size:size))
        }
    }
    static func render(image:UIImage,filter:String,adjustments:[String:Double],thumbnail:Bool=false)->UIImage{
        let source=thumbnail ? resized(image,limit:140):image
        guard var ci=CIImage(image:source)else{
            return source
        }
        let rect=ci.extent
        let index=filters.firstIndex(of:filter) ?? 0
        func apply(_ name:String,_ values:[String:Any]=[:]){
            ci=ci.applyingFilter(name,parameters:values)
        }
        if index>0{
            switch index{
                case 1...3:apply("CIPhotoEffectFade")
                if index==2{
                    apply("CITemperatureAndTint",["inputNeutral":CIVector(x:7200,y:0),"inputTargetNeutral":CIVector(x:6500,y:0)])
                }
                if index==3{
                    apply("CITemperatureAndTint",["inputNeutral":CIVector(x:5200,y:0),"inputTargetNeutral":CIVector(x:6500,y:0)])
                }
                case 4,5:apply("CITemperatureAndTint",["inputNeutral":CIVector(x:index==4 ? 7600:4800,y:0),"inputTargetNeutral":CIVector(x:6500,y:0)])
                case 6...8:apply("CIColorControls",[kCIInputSaturationKey:1.25,kCIInputContrastKey:1.12])
                if index != 6{
                    apply("CITemperatureAndTint",["inputNeutral":CIVector(x:index==7 ? 7600:4900,y:0),"inputTargetNeutral":CIVector(x:6500,y:0)])
                }
                case 9:apply("CIPhotoEffectNoir")
                case 10:apply("CIBloom",[kCIInputRadiusKey:7,kCIInputIntensityKey:0.4])
                case 11:apply("CISepiaTone",[kCIInputIntensityKey:0.25])
                apply("CIColorControls",[kCIInputSaturationKey:1.35,kCIInputBrightnessKey:0.025])
                case 12:apply("CIColorControls",[kCIInputContrastKey:0.90,kCIInputBrightnessKey:0.04])
                case 13:apply("CIPhotoEffectTransfer")
                case 14:apply("CIPhotoEffectInstant")
                case 15:apply("CIPhotoEffectMono")
                case 16:apply("CIPhotoEffectChrome")
                case 17:apply("CIPhotoEffectTonal")
                case 18:apply("CISepiaTone",[kCIInputIntensityKey:0.4])
                default:apply("CIPhotoEffectProcess")
            }
        }
        let a=adjustments
        apply("CIColorControls",[kCIInputBrightnessKey:(a["Luminosità"] ?? 0)/250,kCIInputContrastKey:1+(a["Contrasto"] ?? 0)/150,kCIInputSaturationKey:1+(a["Saturazione"] ?? 0)/100])
        if let lux=a["Lux"],lux != 0{
            apply("CIExposureAdjust",[kCIInputEVKey:lux/160])
        }
        if let color=a["Colore"],color != 0{
            apply("CITemperatureAndTint",["inputNeutral":CIVector(x:6500+color*25,y:0),"inputTargetNeutral":CIVector(x:6500,y:0)])
        }
        if let fade=a["Sfumatura"],fade != 0{
            apply("CIColorControls",[kCIInputContrastKey:1-fade/400,kCIInputBrightnessKey:fade/1500])
        }
        apply("CIHighlightShadowAdjust",["inputHighlightAmount":1-(a["Alte luci"] ?? 0)/150,"inputShadowAmount":(a["Ombre"] ?? 0)/100])
        if let v=a["Vignettatura"],v != 0{
            apply("CIVignette",[kCIInputIntensityKey:abs(v)/60,kCIInputRadiusKey:min(rect.width,rect.height)/2])
        }
        if let sharp=a["Nitidezza"],sharp != 0{
            apply("CISharpenLuminance",[kCIInputSharpnessKey:abs(sharp)/50])
        }
        if let shift=a["Tilt-Shift"],shift != 0{
            let radius=abs(shift)/8
            let blurred=ci.clampedToExtent().applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:radius]).cropped(to:rect)
            let mask=CIFilter(name:"CIRadialGradient",parameters:["inputCenter":CIVector(x:rect.midX,y:rect.midY),"inputRadius0":rect.width*0.15,"inputRadius1":rect.width*0.5,"inputColor0":CIColor.white,"inputColor1":CIColor.black])?.outputImage
            if let mask=mask{
                ci=ci.applyingFilter("CIBlendWithMask",parameters:[kCIInputBackgroundImageKey:blurred,kCIInputMaskImageKey:mask])
            }
        }
        if let angle=a["Regola"],angle != 0{
            let transform=CGAffineTransform(translationX:rect.midX,y:rect.midY).rotated(by:angle * .pi/180).translatedBy(x:-rect.midX,y:-rect.midY)
            ci=ci.transformed(by:transform)
        }
        guard let cg=context.createCGImage(ci.cropped(to:rect),from:rect)else{
            return source
        }
        return UIImage(cgImage:cg)
    }
}
