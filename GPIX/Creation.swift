import UIKit
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import CoreImage.CIFilterBuiltins

@MainActor final class MediaPicker: NSObject, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    weak var host:UIViewController?
    let video:Bool,camera:Bool
    let completion:(Data,String)->Void
    init(host:UIViewController,video:Bool,camera:Bool,completion:@escaping(Data,String)->Void) { self.host=host;self.video=video;self.camera=camera;self.completion=completion }
    func present() {
        if camera {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { (host as? Screen)?.alert("Fotocamera non disponibile","La fotocamera richiede un iPhone reale.");return }
            let picker=UIImagePickerController();picker.sourceType = .camera;picker.mediaTypes=video ? [UTType.movie.identifier]:[UTType.image.identifier];picker.videoMaximumDuration=90;picker.delegate=self;host?.present(picker,animated:true)
        } else { var config=PHPickerConfiguration();config.selectionLimit=1;config.filter=video ? .videos:.images;let picker=PHPickerViewController(configuration:config);picker.delegate=self;host?.present(picker,animated:true) }
    }
    func picker(_ picker:PHPickerViewController,didFinishPicking results:[PHPickerResult]) {
        picker.dismiss(animated:true);guard let item=results.first?.itemProvider else { return }
        if video {
            item.loadFileRepresentation(forTypeIdentifier:UTType.movie.identifier) { [weak self] url,error in
                guard let url=url,let data=try? Data(contentsOf:url) else { Task { @MainActor in if let error=error { (self?.host as? Screen)?.showError(error) } };return }
                Task { @MainActor in self?.completion(data,"video/mp4") }
            }
        } else { item.loadObject(ofClass:UIImage.self) { [weak self] image,error in guard let image=image as? UIImage,let data=image.jpegData(compressionQuality:0.88) else { Task { @MainActor in if let error=error { (self?.host as? Screen)?.showError(error) } };return };Task { @MainActor in self?.completion(data,"image/jpeg") } } }
    }
    func imagePickerController(_ picker:UIImagePickerController,didFinishPickingMediaWithInfo info:[UIImagePickerController.InfoKey:Any]) {
        picker.dismiss(animated:true)
        if let url=info[.mediaURL] as? URL,let data=try? Data(contentsOf:url) { completion(data,"video/mp4") }
        else if let image=info[.originalImage] as? UIImage,let data=image.jpegData(compressionQuality:0.88) { completion(data,"image/jpeg") }
    }
    func imagePickerControllerDidCancel(_ picker:UIImagePickerController) { picker.dismiss(animated:true) }
}
@MainActor final class CreateMenuController: StackScreen {
    override func viewDidLoad() {
        super.viewDidLoad();title="Crea"
        for choice in [("post","Post","Condividi foto e caroselli","square.on.square"),("story","Storia","Un momento che dura 24 ore","plus.circle"),("reel","Reel","Esprimi la tua creatività in video","play.rectangle"),("instant","Istantanea","Uno scatto spontaneo, solo adesso","camera"),("live","Diretta","Connettiti in tempo reale","dot.radiowaves.left.and.right")] {
            row(choice.1,subtitle:choice.2,icon:choice.3) { [weak self] in guard let self=self else { return };let parent=self.navigationController?.presentingViewController ?? self.presentingViewController;self.dismiss(animated:true) {
                let c:UIViewController
                if choice.0=="instant" { c=InstantCameraController() } else if choice.0=="live" { c=LiveListController() } else if choice.0=="story" { c=StoryEditorController() } else { c=PublishController(kind:choice.0) }
                let nav=UINavigationController(rootViewController:c);nav.modalPresentationStyle = .fullScreen;c.navigationItem.leftBarButtonItem=UIBarButtonItem(systemItem:.close,primaryAction:UIAction { [weak nav] _ in nav?.dismiss(animated:true) });parent?.present(nav,animated:true)
            } }
        }
    }
}
@MainActor final class PublishController: StackScreen {
    let kind:String
    private let caption=UITextView(),location=Design.field("Aggiungi luogo"),preview=UIImageView()
    private var images:[Data]=[],videoData:Data?,picker:MediaPicker?,audience="all",style:[String:Any]=[:],selectedFilter="Originale"
    private var key=UUID().uuidString
    private var publishing=false
    private var music=Entity()
    init(kind:String) { self.kind=kind;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad();title=kind=="post" ? "Nuovo post":kind=="story" ? "Nuova storia":"Nuovo reel";navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Condividi",style:.done,target:self,action:#selector(publish))
        caption.font=Design.font(16);caption.textColor=Design.ink;caption.backgroundColor=Design.soft;caption.layer.cornerRadius=16;caption.heightAnchor.constraint(equalToConstant:115).isActive=true;caption.textContainerInset=UIEdgeInsets(top:15,left:12,bottom:15,right:12)
        preview.backgroundColor=Design.soft;preview.contentMode = .scaleAspectFit;preview.clipsToBounds=true;preview.layer.cornerRadius=20;preview.heightAnchor.constraint(equalTo:preview.widthAnchor,multiplier:1.1).isActive=true
        render()
    }
    private func render() {
        clear();add(preview,inset:18);if !images.isEmpty { section("\(images.count) \(images.count==1 ? "foto":"foto nel carosello")") }
        let buttons=Design.stack(.horizontal,spacing:10);buttons.distribution = .fillEqually
        buttons.addArrangedSubview(Design.button(kind=="reel" ? "Scegli video":"Scegli foto",icon:"photo") { [weak self] in self?.choose(camera:false) })
        buttons.addArrangedSubview(Design.button("Fotocamera",icon:"camera") { [weak self] in self?.choose(camera:true) });add(buttons,inset:18)
        section(kind=="story" ? "Testo della storia":"Didascalia");add(caption,inset:18);add(location,inset:18)
        row("Pubblico",subtitle:audience=="close" ? "Amici più stretti":"Tutti",icon:"person.2") { [weak self] in self?.menu("Condividi con",items:[("Tutti",false,{ self?.audience="all";self?.render() }),("Amici più stretti",false,{ self?.audience="close";self?.render() })]) }
        if kind != "reel" { row("Filtro",subtitle:selectedFilter,icon:"camera.filters") { [weak self] in self?.filters() } }
        if kind=="story" {
            row("Colore di sfondo",icon:"paintpalette") { [weak self] in self?.menu("Sfondo",items:[("Viola",false,{ self?.style["background"]="#7145E8";self?.preview.backgroundColor=Design.violet }),("Rosa",false,{ self?.style["background"]="#E94F9A";self?.preview.backgroundColor = .systemPink }),("Nero",false,{ self?.style["background"]="#000000";self?.preview.backgroundColor = .black })]) }
            row("Sticker e testo",icon:"face.smiling") { [weak self] in self?.prompt("Aggiungi testo o emoji") { text in self?.caption.text += (self?.caption.text.isEmpty == false ? "\n":"")+text } }
            row("Sondaggio",icon:"chart.bar") { [weak self] in self?.poll() }
        }
        row("Musica",subtitle:music.text("title","Aggiungi un brano"),icon:"music.note") { [weak self] in let picker=MusicController();picker.onSelect={ [weak self] track in self?.music=track;self?.style["music"]=track.updating(["start":0,"clipDuration":min(15,track.number("duration",15))]).values;self?.render() };self?.push(picker) }
        row("Salva bozza",icon:"square.and.arrow.down") { [weak self] in self?.saveDraft() }
        if images.count>1 { row("Rimuovi ultima foto",icon:"trash") { [weak self] in self?.images.removeLast();self?.preview.image=self?.images.first.flatMap(UIImage.init(data:));self?.render() } }
    }
    private func choose(camera:Bool) { picker=MediaPicker(host:self,video:kind=="reel",camera:camera) { [weak self] data,mime in guard let self=self else { return };if mime.hasPrefix("video") { self.videoData=data;self.preview.image=UIImage(systemName:"play.rectangle.fill");self.preview.tintColor=Design.violet } else { if self.kind=="post" { if self.images.count<10 { self.images.append(data) } } else { self.images=[data] };self.preview.image=self.images.first.flatMap(UIImage.init(data:)) };self.render() };picker?.present() }
    private func filters() {
        let names=["Originale","Mono","Noir","Vivido","Caldo","Freddo","Istantaneo"]
        menu("Filtri",items:names.map { name in (name,false,{ self.selectedFilter=name;if let data=self.images.first,let image=self.filtered(data) { self.preview.image=image };self.render() }) })
    }
    private func filtered(_ data:Data) -> UIImage? {
        guard let input=CIImage(data:data) else { return UIImage(data:data) };let name=["Mono":"CIPhotoEffectMono","Noir":"CIPhotoEffectNoir","Vivido":"CIPhotoEffectChrome","Caldo":"CIPhotoEffectTransfer","Freddo":"CIPhotoEffectTonal","Istantaneo":"CIPhotoEffectInstant"][selectedFilter]
        guard let name=name,let filter=CIFilter(name:name) else { return UIImage(data:data) };filter.setValue(input,forKey:kCIInputImageKey);guard let output=filter.outputImage,let cg=CIContext().createCGImage(output,from:output.extent) else { return nil };return UIImage(cgImage:cg)
    }
    private func poll() { prompt("Domanda del sondaggio") { question in self.prompt("Prima risposta") { first in self.prompt("Seconda risposta") { second in self.style["poll"]=["question":question,"options":[first,second]];self.alert("Sondaggio aggiunto",question) } } } }
    private func saveDraft() {
        let id=UUID().uuidString;let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Drafts",isDirectory:true)
        do { try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);var files:[String]=[];for (index,data) in images.enumerated() { let url=folder.appendingPathComponent(id+"-\(index).jpg");try data.write(to:url);files.append(url.absoluteString) };if let data=videoData { let url=folder.appendingPathComponent(id+".mp4");try data.write(to:url);files.append(url.absoluteString) };var drafts=UserDefaults.standard.array(forKey:"gpix.drafts.\(session.userID)") as? [[String:Any]] ?? [];drafts.insert(["id":id,"kind":kind,"text":caption.text ?? "","location":location.text ?? "","files":files,"created":Date().timeIntervalSince1970],at:0);UserDefaults.standard.set(drafts,forKey:"gpix.drafts.\(session.userID)");alert("Bozza salvata","La trovi nelle impostazioni, alla voce Bozze.") } catch { showError(error) }
    }
    func restore(_ draft:Entity) { loadViewIfNeeded();caption.text=draft.text("text");location.text=draft.text("location");for ref in draft.strings("files") { if let url=URL(string:ref),let data=try? Data(contentsOf:url) { if url.pathExtension=="mp4" { videoData=data } else { images.append(data) } } };preview.image=images.first.flatMap(UIImage.init(data:));render() }
    @objc private func publish() {
        guard !publishing else { return };guard kind=="story" ? (!images.isEmpty || !caption.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty):(kind=="reel" ? videoData != nil:!images.isEmpty) else { alert("Aggiungi un contenuto",kind=="reel" ? "Seleziona un video per il tuo reel.":"Scegli una foto o scrivi una storia.");return }
        publishing=true;navigationItem.rightBarButtonItem?.isEnabled=false
        run { defer { self.publishing=false;self.navigationItem.rightBarButtonItem?.isEnabled=true };var media:[String]=[]
            if let data=self.videoData { let m=try await self.session.upload(data,mime:"video/mp4");media.append(m.text("id")) }
            for data in self.images { let bytes=self.filtered(data)?.jpegData(compressionQuality:0.88) ?? data;let m=try await self.session.upload(bytes,mime:"image/jpeg");media.append(m.text("id")) }
            try await self.session.action("post",["kind":self.kind,"text":self.caption.text ?? "","location":self.location.text ?? "","media":media.first ?? "","mediaItems":media,"style":self.style,"audience":self.audience,"idempotencyKey":self.key]);self.dismiss(animated:true)
        }
    }
}

@MainActor final class InstantCameraController: Screen, AVCapturePhotoCaptureDelegate {
    private let capture=AVCaptureSession(),output=AVCapturePhotoOutput(),preview=UIView(),shot=UIImageView(),caption=Design.field("Aggiungi una didascalia…")
    private var layer:AVCaptureVideoPreviewLayer?,photoData:Data?,front=false,audience="friends",busy=false
    private let replyTo:String,key=UUID().uuidString
    private var send:UIButton!,shutter:UIButton!
    init(replyTo:String="") { self.replyTo=replyTo;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad();view.backgroundColor = .black;title="Nuova istantanea";navigationController?.navigationBar.tintColor = .white;let bar=UINavigationBarAppearance();bar.configureWithOpaqueBackground();bar.backgroundColor = .black;bar.titleTextAttributes=[.foregroundColor:UIColor.white,.font:Design.font(17,.bold)];navigationController?.navigationBar.standardAppearance=bar;navigationController?.navigationBar.scrollEdgeAppearance=bar
        preview.backgroundColor=UIColor(white:0.1,alpha:1);preview.layer.cornerRadius=30;preview.clipsToBounds=true;view.addSubview(preview);preview.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([preview.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:12),preview.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:12),preview.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-12),preview.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-250)])
        shot.contentMode = .scaleAspectFit;shot.backgroundColor = .black;shot.isHidden=true;preview.addSubview(shot);shot.pin(to:preview)
        let explanation=Design.label("Uno scatto nuovo. Visibile per 24 ore.",size:12,color:.white);explanation.textAlignment = .center
        shutter=Design.icon("circle.inset.filled",size:48,color:.white) { [weak self] in self?.takePhoto() };shutter.constraints.forEach { if $0.firstAttribute == .height { $0.constant=60 } }
        let flip=Design.icon("arrow.triangle.2.circlepath.camera",color:.white) { [weak self] in self?.front.toggle();self?.configure() }
        let controls=Design.stack(.horizontal,spacing:25,views:[Design.button("Riprova") { [weak self] in self?.photoData=nil;self?.shot.isHidden=true },shutter,flip]);controls.alignment = .center;controls.distribution = .equalCentering
        send=Design.button("Condividi",primary:true) { [weak self] in self?.publish() }
        let audienceButton=Design.button(replyTo.isEmpty ? "Amici ⌄":"Risposta privata") { [weak self] in self?.audienceMenu() }
        let footer=Design.stack(spacing:8,views:[explanation,controls,caption,Design.stack(.horizontal,spacing:8,views:[audienceButton,send])]);view.addSubview(footer);footer.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([footer.topAnchor.constraint(equalTo:preview.bottomAnchor,constant:10),footer.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:20),footer.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-20),footer.bottomAnchor.constraint(lessThanOrEqualTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-5)])
        run { let allowed=await AVCaptureDevice.requestAccess(for:.video);guard allowed else { throw GPIXFailure.message("Consenti l’accesso alla fotocamera nelle impostazioni di iPhone.") };self.configure() }
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews();layer?.frame=preview.bounds }
    override func viewWillDisappear(_ animated:Bool) { super.viewWillDisappear(animated);let capture=capture;DispatchQueue.global(qos:.userInitiated).async { capture.stopRunning() } }
    private func configure() {
        guard let camera=AVCaptureDevice.default(.builtInWideAngleCamera,for:.video,position:front ? .front:.back) else { alert("Fotocamera non disponibile","Per scattare un’istantanea usa un iPhone reale.");return }
        do {
            capture.beginConfiguration();defer { capture.commitConfiguration() };capture.sessionPreset = .photo;for input in capture.inputs { capture.removeInput(input) };let input=try AVCaptureDeviceInput(device:camera);guard capture.canAddInput(input) else { return };capture.addInput(input);if capture.outputs.isEmpty && capture.canAddOutput(output) { capture.addOutput(output) }
            if layer==nil { let l=AVCaptureVideoPreviewLayer(session:capture);l.videoGravity = .resizeAspectFill;preview.layer.insertSublayer(l,at:0);layer=l };layer?.frame=preview.bounds
        } catch { showError(error);return }
        let capture=capture;DispatchQueue.global(qos:.userInitiated).async { capture.startRunning() }
    }
    private func takePhoto() { guard !busy else { return };guard capture.isRunning,!capture.inputs.isEmpty else { alert("Fotocamera non pronta","Attendi l’avvio della fotocamera.");return };guard photoData==nil else { photoData=nil;shot.isHidden=true;return };if let connection=output.connection(with:.video),connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle=90 };let settings=AVCapturePhotoSettings();settings.flashMode = .off;output.capturePhoto(with:settings,delegate:self) }
    nonisolated func photoOutput(_ output:AVCapturePhotoOutput,didFinishProcessingPhoto photo:AVCapturePhoto,error:Error?) {
        let data=photo.fileDataRepresentation();Task { @MainActor [weak self] in guard let self=self else { return };if let error=error { self.showError(error);return };guard let data=data,let image=UIImage(data:data),let jpeg=image.jpegData(compressionQuality:0.9) else { return };self.photoData=jpeg;self.shot.image=image;self.shot.isHidden=false }
    }
    private func audienceMenu() { guard replyTo.isEmpty else { return };menu("Condividi con",items:[("Amici",false,{ self.audience="friends";self.send.setTitle("Condividi con gli amici",for:.normal) }),("Amici più stretti",false,{ self.audience="close";self.send.setTitle("Condividi con gli amici più stretti",for:.normal) })]) }
    private func publish() { guard let data=photoData,!busy else { return };guard (caption.text ?? "").count<=120 else { alert("Didascalia troppo lunga","Usa al massimo 120 caratteri.");return };busy=true;send.isEnabled=false
        run { defer { self.busy=false;self.send.isEnabled=true };let media=try await self.session.upload(data,mime:"image/jpeg");if self.replyTo.isEmpty { try await self.session.sendInstant(media:media.text("id"),caption:self.caption.text ?? "",audience:self.audience,key:self.key) } else if !self.session.isDemo { _ = try await self.session.api("/instants/send",["media":media.text("id"),"caption":self.caption.text ?? "","replyTo":self.replyTo,"requestKey":self.key]) };self.dismiss(animated:true) }
    }
}
@MainActor final class MusicController: StackScreen {
    var onSelect:((Entity)->Void)?
    private var player:AVPlayer?
    override func viewDidLoad() { super.viewDidLoad();title="Musica";run { let r=try await self.session.api("/music");for track in r.list("tracks") { self.row(track.text("title"),subtitle:track.text("artist"),icon:"music.note",accessory:Design.icon("play.fill",size:16) { [weak self] in if let url=Domain.mediaURL(track.text("audio")) { self?.player=AVPlayer(url:url);self?.player?.play() } }) { [weak self] in self?.player?.pause();self?.onSelect?(track);self?.navigationController?.popViewController(animated:true) } } } }
    override func viewWillDisappear(_ animated:Bool) { super.viewWillDisappear(animated);player?.pause() }
}
