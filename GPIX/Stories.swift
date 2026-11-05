import UIKit
import AVFoundation

@MainActor final class StoryViewer: Screen, UITextFieldDelegate, UIGestureRecognizerDelegate {
    private let stories:[Entity]
    private var index=0,timer:Timer?,elapsed:Double=0,holding=false
    private var audio:AVPlayer?
    private let image=PhotoView(frame:.zero),caption=Design.label("",size:25,weight:.bold,color:.white,lines:0),name=Design.label("",size:14,weight:.bold,color:.white),segments=Design.stack(.horizontal,spacing:4)
    private let reply=Design.field("Rispondi alla storia…"),heart=UIButton(type:.system),link=UIButton(type:.system),views=UIButton(type:.system)
    private var bars:[UIProgressView]=[]
    private let quickReactions = Design.stack(.horizontal, spacing: 4)
    init(stories: [Entity], startAt: Int = 0) {
        self.stories = stories
        self.index = stories.indices.contains(startAt) ? startAt : 0
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad();view.backgroundColor = .black;image.contentMode = .scaleAspectFit;image.backgroundColor = .black;image.clipsToBounds=true;image.layer.cornerRadius=18;view.addSubview(image);image.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([image.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),image.leadingAnchor.constraint(equalTo:view.leadingAnchor),image.trailingAnchor.constraint(equalTo:view.trailingAnchor),image.bottomAnchor.constraint(equalTo:view.keyboardLayoutGuide.topAnchor,constant:-82)])
        segments.distribution = .fillEqually
        for _ in stories { let bar=UIProgressView(progressViewStyle:.bar);bar.progressTintColor = .white;bar.trackTintColor=UIColor.white.withAlphaComponent(0.3);segments.addArrangedSubview(bar);bars.append(bar) }
        let top=Design.stack(spacing:9,views:[segments,Design.stack(.horizontal,views:[name,UIView(),Design.icon("more",color:.white) { [weak self] in self?.options() },Design.icon("xmark",color:.white) { [weak self] in self?.dismiss(animated:true) }])]);view.addSubview(top);top.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([top.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:14),top.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-14),top.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:10)])
        image.addSubview(caption);caption.textAlignment = .center;caption.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([caption.leadingAnchor.constraint(equalTo:image.leadingAnchor,constant:25),caption.trailingAnchor.constraint(equalTo:image.trailingAnchor,constant:-25),caption.centerYAnchor.constraint(equalTo:image.centerYAnchor)])
        reply.delegate=self;reply.textColor = .white;reply.backgroundColor=UIColor.white.withAlphaComponent(0.08);reply.layer.cornerRadius=27;reply.layer.borderColor=UIColor.white.withAlphaComponent(0.4).cgColor;reply.layer.borderWidth=1;reply.attributedPlaceholder=NSAttributedString(string:"Rispondi alla storia…",attributes:[.foregroundColor:UIColor.white.withAlphaComponent(0.75)])
        heart.setImage(UIImage(systemName:"heart",withConfiguration:UIImage.SymbolConfiguration(pointSize:26)),for:.normal);heart.tintColor = .white;heart.widthAnchor.constraint(equalToConstant:44).isActive=true;heart.addAction(UIAction { [weak self] _ in self?.like() },for:.touchUpInside);heart.addGestureRecognizer(UILongPressGestureRecognizer(target:self,action:#selector(reactions(_:))))
        let footer=Design.stack(.horizontal,spacing:8,views:[reply,Design.icon("send",color:.white) { [weak self] in self?.sendReply() },heart]);footer.alignment = .center;view.addSubview(footer);footer.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([footer.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:14),footer.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-10),footer.bottomAnchor.constraint(equalTo:view.keyboardLayoutGuide.topAnchor,constant:-14)])
        quickReactions.distribution = .fillEqually
        for emoji in ["❤️", "😂", "😍", "🔥", "😢", "👏"] {
            let button = UIButton(type: .system)
            button.setTitle(emoji, for: .normal)
            button.titleLabel?.font = Design.font(27)
            button.addAction(UIAction { [weak self] _ in self?.sendReply(emoji) }, for: .touchUpInside)
            quickReactions.addArrangedSubview(button)
        }
        quickReactions.isHidden = true
        view.addSubview(quickReactions)
        quickReactions.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            quickReactions.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            quickReactions.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            quickReactions.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -8),
            quickReactions.heightAnchor.constraint(equalToConstant: 46)
        ])
        views.setTitleColor(.white,for:.normal);views.titleLabel?.font=Design.font(13,.semibold);views.addAction(UIAction { [weak self] _ in guard let self=self,self.stories.indices.contains(self.index) else { return };self.sheet(StoryViewsController(id:self.stories[self.index].id)) },for:.touchUpInside);view.addSubview(views);views.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([views.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:24),views.bottomAnchor.constraint(equalTo:footer.topAnchor,constant:-12)])
        link.setTitle("Apri collegamento ↗",for:.normal);link.backgroundColor=UIColor.black.withAlphaComponent(0.55);link.setTitleColor(.white,for:.normal);link.layer.cornerRadius=14;link.addAction(UIAction { [weak self] _ in guard let self=self else { return };let value=self.current.object("style").text("link");if let url=URL(string:value),url.scheme=="https" { UIApplication.shared.open(url) } },for:.touchUpInside);image.addSubview(link);link.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([link.centerXAnchor.constraint(equalTo:image.centerXAnchor),link.bottomAnchor.constraint(equalTo:image.bottomAnchor,constant:-25),link.widthAnchor.constraint(equalToConstant:220),link.heightAnchor.constraint(equalToConstant:44)])
        image.isUserInteractionEnabled=true;let tap=UITapGestureRecognizer(target:self,action:#selector(tapped(_:)));tap.delegate=self;image.addGestureRecognizer(tap);let hold=UILongPressGestureRecognizer(target:self,action:#selector(hold(_:)));hold.minimumPressDuration=0.15;image.addGestureRecognizer(hold)
        let forward=UISwipeGestureRecognizer(target:self,action:#selector(swiped(_:)));forward.direction = .left;image.addGestureRecognizer(forward);let back=UISwipeGestureRecognizer(target:self,action:#selector(swiped(_:)));back.direction = .right;image.addGestureRecognizer(back);let down=UISwipeGestureRecognizer(target:self,action:#selector(swiped(_:)));down.direction = .down;image.addGestureRecognizer(down)
        load()
    }
    private var current:Entity { guard stories.indices.contains(index) else { return Entity() };let fresh=session.post(stories[index].id);return fresh.id.isEmpty ? stories[index]:fresh }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func textFieldDidBeginEditing(_ textField: UITextField) { quickReactions.isHidden = false }
    func textFieldDidEndEditing(_ textField: UITextField) { quickReactions.isHidden = true }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendReply()
        return false
    }

    override func viewDidDisappear(_ animated:Bool) { super.viewDidDisappear(animated);timer?.invalidate();audio?.pause() }
    private func load() {
        guard stories.indices.contains(index) else { dismiss(animated:true);return };elapsed=0;audio?.pause();audio=nil;let p=current;image.load(p.media.first ?? "");name.text=session.person(p.text("author")).text("username")+" · "+Domain.ago(p.number("created"));caption.text=p.text("text");caption.font=Design.font(CGFloat(p.object("style").number("fontSize",25)),.bold)
        link.isHidden=p.object("style").text("link").isEmpty;let own=p.text("author")==session.userID;views.isHidden = !own;views.setTitle("◉ \(p.strings("viewers").count) visualizzazioni",for:.normal);reply.isEnabled = !own
        updateHeart();for (i,bar) in bars.enumerated() { bar.progress=i<index ? 1:0 }
        let music=p.object("style").object("music");let audioRef=p.object("style").text("audio",music.text("audio",music.text("preview")));if !audioRef.isEmpty,let url=Domain.mediaURL(audioRef) { audio=AVPlayer(url:url);audio?.play() }
        if !own { action("see", ["id":p.id]) }
    }
    private func tick() { guard !holding,!reply.isFirstResponder,presentedViewController==nil,view.window != nil else { audio?.pause();return };audio?.play();elapsed+=0.05;if bars.indices.contains(index) { bars[index].progress=Float(elapsed/6) };if elapsed>=6 { next(1) } }
    private func updateHeart() { let liked=current.strings("likes").contains(session.userID);heart.setImage(UIImage(systemName:liked ? "heart.fill":"heart",withConfiguration:UIImage.SymbolConfiguration(pointSize:26)),for:.normal);heart.tintColor=liked ? Design.danger:.white }
    override func stateChanged() { updateHeart() }
    func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldReceive touch:UITouch)->Bool { var current=touch.view;while let view=current { if view is UIControl { return false };current=view.superview };return true }
    @objc private func tapped(_ recognizer:UITapGestureRecognizer) { next(recognizer.location(in:image).x<image.bounds.width*0.3 ? -1:1) }
    @objc private func swiped(_ gesture:UISwipeGestureRecognizer) { if gesture.direction == .down { dismiss(animated:true) } else { next(gesture.direction == .left ? 1:-1) } }
    @objc private func hold(_ gesture:UILongPressGestureRecognizer) { holding=gesture.state == .began || gesture.state == .changed }
    private func next(_ step:Int) { reply.resignFirstResponder();let target=index+step;if target<0 { elapsed=0;return };guard target<stories.count else { dismiss(animated:true);return };index=target;let transition=CATransition();transition.type = .push;transition.subtype=step>0 ? .fromRight:.fromLeft;transition.duration=UIAccessibility.isReduceMotionEnabled ? 0:0.22;image.layer.add(transition,forKey:"story");load() }
    private func like() { action("like",["id":current.id,"enabled":!current.strings("likes").contains(session.userID)]);UIView.animate(withDuration:0.12,animations:{ self.heart.transform=CGAffineTransform(scaleX:1.25,y:1.25) }) { _ in UIView.animate(withDuration:0.18) { self.heart.transform = .identity } } }
    @objc private func reactions(_ gesture:UILongPressGestureRecognizer) { guard gesture.state == .began else { return };let picker=ReactionPicker { [weak self] emoji in self?.sendReply(emoji) };present(picker,animated:true) }
    private func sendReply(_ reaction:String?=nil) { let text=(reaction ?? reply.text ?? "").trimmingCharacters(in:.whitespacesAndNewlines);guard !text.isEmpty,current.text("author") != session.userID else { return };let p=current;run { let tid=try await self.session.startThread(p.text("author"));try await self.session.action("message",["id":tid,"kind":"story","story":p.id,"text":text]);self.reply.text="";self.reply.resignFirstResponder();self.reply.placeholder="Risposta inviata" } }
    private func options() {
        let p=current;var items:[(String,Bool,()->Void)]=[]
        if p.text("author")==session.userID { items += [("Visualizzazioni",false,{ self.sheet(StoryViewsController(id:p.id)) }),("Aggiungi in evidenza",false,{ self.prompt("Titolo della raccolta") { self.action("highlight",["title":$0,"posts":[p.id]]) } }),("Elimina storia",true,{ self.run { try await self.session.action("deletePost",["id":p.id]);self.next(1) } })] }
        let poll=p.object("style").object("poll");for (i,answer) in poll.strings("options").enumerated() { items.append((answer,false,{ self.action("pollVote",["id":p.id,"choice":i]) })) }
        if items.isEmpty { items.append(("Segnala",true,{ self.prompt("Motivo della segnalazione") { self.action("report",["id":p.id,"reason":$0]) } })) };menu(poll.text("question").isEmpty ? nil:poll.text("question"),items:items)
    }
}
@MainActor final class StoryViewsController: StackScreen {
    let id:String
    init(id:String) { self.id=id;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad();title="Visualizzazioni";stateChanged() }
    override func stateChanged() { clear();let p=session.post(id);for uid in p.strings("viewers") { let u=session.person(uid);row(u.text("name"),subtitle:p.strings("likes").contains(uid) ? "Ha messo mi piace alla tua storia":"",accessory:Avatar(u,size:44)) { [weak self] in self?.push(ProfileController(id:uid)) } };if p.strings("viewers").isEmpty { empty("Nessuna visualizzazione",symbol:"eye") } }
}
@MainActor final class NoteController: StackScreen {
    let owner:String;let field=Design.field("Condividi un pensiero…")
    private var audience="mutual"
    init(owner:String) { self.owner=owner;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad();let owner=self.owner;let own=owner==session.userID;let note=session.state.list("notes").first { $0.text("owner")==owner } ?? Entity();title=own ? "La tua nota":session.person(owner).text("name")
        let avatar=Avatar(session.person(owner),size:90);let centered=Design.stack(views:[avatar]);centered.alignment = .center;add(centered,inset:24)
        if own { field.text=note.text("text");add(field,inset:24);section("Massimo 60 caratteri · Visibile per 24 ore")
            row("Condividi con",subtitle:"Amici che segui anche tu",icon:"person.2") { [weak self] in self?.menu("Pubblico",items:[("Amici che segui anche tu",false,{ self?.audience="mutual" }),("Amici più stretti",false,{ self?.audience="close" })]) }
            add(Design.button("Condividi",primary:true) { [weak self] in guard let self=self,let value=self.field.text,!value.isEmpty,value.count<=60 else { self?.alert("Controlla la nota","Scrivi da 1 a 60 caratteri.");return };self.run { try await self.session.action("note",["text":value,"audience":self.audience]);self.dismiss(animated:true) } },inset:24)
            if !note.text("text").isEmpty { add(Design.button("Elimina nota") { [weak self] in self?.run { try await self?.session.action("note",["delete":true]);self?.dismiss(animated:true) } },inset:24) }
        } else {
            let text=Design.label(note.text("text"),size:25,weight:.semibold,lines:0);text.textAlignment = .center;text.onTap { [weak self] in self?.action("noteReact",["user":owner,"created":note.number("created"),"enabled":true]) };add(text,inset:30);add(Design.button("Mi piace",primary:true,icon:"heart") { [weak self] in self?.action("noteReact",["user":owner,"created":note.number("created"),"enabled":true]) },inset:24)
            field.placeholder="Rispondi alla nota…";add(field,inset:24);add(Design.button("Invia",primary:true) { [weak self] in guard let self=self,let text=self.field.text,!text.isEmpty else { return };self.run { let id=try await self.session.startThread(owner);try await self.session.action("message",["id":id,"text":"Risposta alla tua nota: "+text]);self.dismiss(animated:true) } },inset:24)
        }
    }
}
@MainActor final class HighlightsController: StackScreen {
    private var selected:Set<String>=[]
    override func viewDidLoad() { super.viewDidLoad();title="Nuova storia in evidenza";render() }
    private func render() { clear();for story in session.posts.filter({$0.text("author")==session.userID && $0.text("kind")=="story"}) { row(story.text("text","Storia"),subtitle:Date(timeIntervalSince1970:story.number("created")).formatted(date:.abbreviated,time:.omitted),icon:selected.contains(story.id) ? "checkmark.circle.fill":"circle") { [weak self] in if self?.selected.contains(story.id)==true { self?.selected.remove(story.id) } else { self?.selected.insert(story.id) };self?.render() } };add(Design.button("Crea raccolta",primary:true) { [weak self] in guard let self=self,!self.selected.isEmpty else { return };self.prompt("Nome della raccolta") { self.action("highlight",["title":$0,"posts":Array(self.selected)]) } },inset:20) }
}
