import UIKit
import CoreImage

@MainActor final class StoryEditorController: Screen {
    private let canvas=UIView(),photo=UIImageView(),words=UILabel(),hint=UILabel()
    private var picker:MediaPicker?,original:UIImage?,audience="all",style:[String:Any]=[:],publishing=false
    private let requestKey=UUID().uuidString
    override func viewDidLoad() {
        super.viewDidLoad();title="Crea una storia";view.backgroundColor = .black
        navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Condividi",style:.done,target:self,action:#selector(publish))
        let bar=UINavigationBarAppearance();bar.configureWithOpaqueBackground();bar.backgroundColor = .black;bar.titleTextAttributes=[.foregroundColor:UIColor.white,.font:Design.font(17,.semibold)];navigationController?.navigationBar.standardAppearance=bar;navigationController?.navigationBar.scrollEdgeAppearance=bar;navigationController?.navigationBar.tintColor = .white
        canvas.backgroundColor=Design.violet;canvas.clipsToBounds=true;canvas.layer.cornerRadius=24;view.addSubview(canvas);canvas.translatesAutoresizingMaskIntoConstraints=false
        photo.contentMode = .scaleAspectFit;canvas.addSubview(photo);photo.pin(to:canvas);photo.isUserInteractionEnabled=true;photo.addGestureRecognizer(UIPinchGestureRecognizer(target:self,action:#selector(zoom(_:))))
        words.textColor = .white;words.font=Design.font(32,.bold);words.numberOfLines=0;words.textAlignment = .center;words.isUserInteractionEnabled=true;canvas.addSubview(words);words.frame=CGRect(x:25,y:150,width:300,height:180);words.addGestureRecognizer(UIPanGestureRecognizer(target:self,action:#selector(move(_:))))
        hint.text="Tocca Aa per scrivere\no scegli una foto";hint.textColor=UIColor.white.withAlphaComponent(0.6);hint.numberOfLines=2;hint.font=Design.font(16);hint.textAlignment = .center;canvas.addSubview(hint);hint.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([hint.centerXAnchor.constraint(equalTo:canvas.centerXAnchor),hint.centerYAnchor.constraint(equalTo:canvas.centerYAnchor)])
        let tools=Design.stack(.horizontal,spacing:8,views:[Design.button("Foto",icon:"photo") { [weak self] in self?.pick(camera:false) },Design.button("Camera",icon:"camera") { [weak self] in self?.pick(camera:true) },Design.button("Aa") { [weak self] in self?.write() },Design.button("Sticker",icon:"face.smiling") { [weak self] in self?.stickers() }]);tools.distribution = .fillEqually;for case let button as UIButton in tools.arrangedSubviews { var config=button.configuration;config?.contentInsets=NSDirectionalEdgeInsets(top:10,leading:4,bottom:10,trailing:4);config?.imagePadding=3;config?.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer { attributes in var value=attributes;value.font=Design.font(12,.semibold);return value };button.configuration=config }
        let extra=Design.stack(.horizontal,spacing:8,views:[Design.button("Sfondo",icon:"paintpalette") { [weak self] in self?.backgrounds() },Design.button("Filtro",icon:"camera.filters") { [weak self] in self?.filters() },Design.button("Musica",icon:"music.note") { [weak self] in self?.music() }]);extra.distribution = .fillEqually
        let footer=Design.stack(spacing:10,views:[tools,extra,Design.button("La tua storia",primary:true) { [weak self] in self?.publish() },Design.button("Amici più stretti") { [weak self] in self?.audience="close";self?.publish() }]);view.addSubview(footer);footer.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([canvas.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:8),canvas.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:10),canvas.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-10),canvas.bottomAnchor.constraint(equalTo:footer.topAnchor,constant:-14),footer.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:16),footer.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-16),footer.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-8)])
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews();if words.bounds.width==300 { words.frame=CGRect(x:20,y:canvas.bounds.midY-90,width:max(1,canvas.bounds.width-40),height:180) } }
    @objc private func zoom(_ gesture:UIPinchGestureRecognizer) { photo.transform=photo.transform.scaledBy(x:gesture.scale,y:gesture.scale);gesture.scale=1 }
    @objc private func move(_ gesture:UIPanGestureRecognizer) { guard let view=gesture.view else { return };let translation=gesture.translation(in:canvas);view.center=CGPoint(x:view.center.x+translation.x,y:view.center.y+translation.y);gesture.setTranslation(.zero,in:canvas) }
    private func pick(camera:Bool) { picker=MediaPicker(host:self,video:false,camera:camera) { [weak self] bytes,_ in guard let self=self else { return };self.original=UIImage(data:bytes);self.photo.image=self.original;self.hint.isHidden=true };picker?.present() }
    private func write() { prompt("Testo della storia",value:words.text ?? "") { [weak self] value in self?.words.text=value;self?.hint.isHidden = !value.isEmpty;self?.textStyles() } }
    private func textStyles() { menu("Stile del testo",items:[("Classico",false,{ self.words.font=Design.font(32,.bold) }),("Elegante",false,{ self.words.font=UIFont(name:"Georgia-Bold",size:32) ?? Design.font(32,.bold) }),("Compatto",false,{ self.words.font=UIFont.monospacedSystemFont(ofSize:28,weight:.semibold) }),("Bianco",false,{ self.words.textColor = .white }),("Nero",false,{ self.words.textColor = .black }),("Giallo",false,{ self.words.textColor = .systemYellow })]) }
    private func addSticker(_ text:String) { hint.isHidden=true;let label=Design.label(text,size:48,weight:.semibold,color:.white,lines:0);label.textAlignment = .center;label.frame=CGRect(x:40,y:70,width:max(100,canvas.bounds.width-80),height:100);label.isUserInteractionEnabled=true;label.addGestureRecognizer(UIPanGestureRecognizer(target:self,action:#selector(move(_:))));canvas.addSubview(label) }
    private func stickers() { menu("Sticker",items:[("❤️",false,{ self.addSticker("❤️") }),("🏳️‍🌈",false,{ self.addSticker("🏳️‍🌈") }),("✨",false,{ self.addSticker("✨") }),("Luogo",false,{ self.prompt("Luogo") { self.addSticker("📍 "+$0) } }),("Sondaggio",false,{ self.poll() }),("Collegamento",false,{ self.prompt("Indirizzo HTTPS") { value in guard let url=URL(string:value),url.scheme=="https",url.host != nil else { self.alert("Link non valido","Inserisci un indirizzo HTTPS.");return };self.style["link"]=url.absoluteString;self.addSticker("🔗 "+(url.host ?? "Apri link")) } })]) }
    private func poll() { prompt("Domanda") { question in self.prompt("Prima risposta") { first in self.prompt("Seconda risposta") { second in guard !question.isEmpty,!first.isEmpty,!second.isEmpty else { return };self.style["poll"]=["question":question,"options":[first,second]];self.addSticker(question+"\n"+first+"   |   "+second) } } } }
    private func backgrounds() { menu("Sfondo",items:[("Viola",false,{ self.canvas.backgroundColor=Design.violet }),("Nero",false,{ self.canvas.backgroundColor = .black }),("Rosa",false,{ self.canvas.backgroundColor = .systemPink }),("Blu",false,{ self.canvas.backgroundColor = .systemBlue })]) }
    private func filters() {
        let catalog:[(String,String)]=[("Originale",""),("Bianco e nero","CIPhotoEffectMono"),("Noir","CIPhotoEffectNoir"),("Vivido","CIPhotoEffectChrome"),("Istantaneo","CIPhotoEffectInstant")]
        var items:[(String,Bool,()->Void)]=[]
        for entry in catalog { items.append((entry.0,false,{ [weak self] in self?.applyFilter(entry.1) })) }
        menu("Filtri",items:items)
    }
    private func applyFilter(_ name:String) {
        guard let original=original else { return }
        if name.isEmpty { photo.image=original;return }
        guard let input=CIImage(image:original),let filter=CIFilter(name:name) else { return }
        filter.setValue(input,forKey:kCIInputImageKey)
        guard let output=filter.outputImage,let cg=CIContext().createCGImage(output,from:output.extent) else { return }
        photo.image=UIImage(cgImage:cg)
    }
    private func music() { let picker=MusicController();picker.onSelect={ [weak self] track in self?.style["music"]=track.updating(["start":0,"clipDuration":min(15,track.number("duration",15))]).values;self?.addSticker("♫ "+track.text("title")) };push(picker) }
    @objc private func publish() {
        guard !publishing else { return };guard photo.image != nil || !(words.text ?? "").isEmpty || canvas.subviews.count>3 else { alert("Crea la tua storia","Scegli una foto o aggiungi un testo.");return };publishing=true;navigationItem.rightBarButtonItem?.isEnabled=false;hint.isHidden=true
        let format=UIGraphicsImageRendererFormat();format.scale=2;let rendered=UIGraphicsImageRenderer(size:canvas.bounds.size,format:format).image { context in canvas.layer.render(in:context.cgContext) }
        guard let data=rendered.jpegData(compressionQuality:0.9) else { publishing=false;return }
        run { defer { self.publishing=false;self.navigationItem.rightBarButtonItem?.isEnabled=true };let media=try await self.session.upload(data,mime:"image/jpeg");try await self.session.action("post",["kind":"story","text":"","media":media.text("id"),"mediaItems":[media.text("id")],"style":self.style,"audience":self.audience,"idempotencyKey":self.requestKey]);self.dismiss(animated:true) }
    }
}
