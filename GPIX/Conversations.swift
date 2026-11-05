import UIKit
import AVFoundation

@MainActor final class InboxController: StackScreen {
    private let search=Design.field("Cerca persone e messaggi")
    private let pile=UIButton(type:.system)
    override func viewDidLoad() {
        super.viewDidLoad();title=session.me.text("username");navigationItem.rightBarButtonItem=UIBarButtonItem(customView:Design.icon("square.and.pencil") { [weak self] in self?.push(NewConversationController()) })
        navigationItem.leftBarButtonItem=UIBarButtonItem(customView:Design.icon("camera",color:Design.violet) { [weak self] in self?.push(InstantsController()) })
        attachHeader(Design.inset(search,UIEdgeInsets(top:8,left:16,bottom:8,right:16)));search.addAction(UIAction { [weak self] _ in self?.render() },for:.editingChanged)
        pile.setTitle("Istantanee",for:.normal);pile.setTitleColor(.white,for:.normal);pile.titleLabel?.font=Design.font(12,.bold);pile.backgroundColor=Design.violet;pile.layer.cornerRadius=26;pile.layer.borderColor=Design.background.cgColor;pile.layer.borderWidth=3;pile.layer.shadowOpacity=0.16;pile.layer.shadowRadius=14;pile.layer.shadowOffset=CGSize(width:0,height:5);pile.setImage(Glyph.image("camera",size:25),for:.normal);pile.tintColor = .white
        pile.addAction(UIAction { [weak self] _ in self?.push(InstantsController()) },for:.touchUpInside)
        pile.addGestureRecognizer(UILongPressGestureRecognizer(target:self,action:#selector(pileOptions)))
        view.addSubview(pile);pile.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([pile.widthAnchor.constraint(equalToConstant:110),pile.heightAnchor.constraint(equalToConstant:88),pile.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-14),pile.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-105)])
        render()
    }
    override func stateChanged() { render() }
    private func render() {
        let offset=scroll.contentOffset;clear();title=session.me.text("username");add(noteStrip());add(Design.spacer(15))
        let request=Design.button("Richieste") { [weak self] in self?.push(MessageRequestsController(hidden:false)) }
        let heading=Design.stack(.horizontal,views:[Design.label("Messaggi",size:19,weight:.bold),UIView(),request]);heading.alignment = .center;add(heading,inset:16)
        let q=search.text ?? "";let threads=session.threads.filter { !session.isRequest($0) && $0.text("requestDecision") != "hidden" && (q.isEmpty || session.threadName($0).localizedCaseInsensitiveContains(q)) }
        for t in threads { add(ThreadRow(t,parent:self)) }
        if threads.isEmpty { empty("Inizia una conversazione",detail:"Cerca un amico e condividi un messaggio.",symbol:"bubble.left.and.bubble.right") }
        pile.isHidden = session.preferences.flag("hideInstantBubble");scroll.setContentOffset(offset,animated:false)
    }
    private func noteStrip() -> UIView {
        let horizontal=UIScrollView();horizontal.showsHorizontalScrollIndicator=false;horizontal.heightAnchor.constraint(equalToConstant:154).isActive=true
        let row=Design.stack(.horizontal,spacing:24);row.alignment = .top;horizontal.addSubview(row);row.pin(to:horizontal,insets:UIEdgeInsets(top:12,left:20,bottom:8,right:20));row.heightAnchor.constraint(equalToConstant:134).isActive=true
        let notes=[Entity(["owner":session.userID,"text":session.state.list("notes").first { $0.text("owner")==session.userID }?.text("text") ?? "Condividi una nota…"])]+session.state.list("notes").filter { $0.text("owner") != session.userID }
        for note in notes {
            let user=session.person(note.text("owner")),own=user.id==session.userID;let bubble=Design.label(note.text("text"),size:12,lines:2);bubble.textAlignment = .center;bubble.backgroundColor=Design.background;bubble.layer.cornerRadius=18;bubble.clipsToBounds=true;bubble.heightAnchor.constraint(equalToConstant:48).isActive=true;bubble.widthAnchor.constraint(equalToConstant:82).isActive=true
            let avatar=Avatar(user,size:68,online:session.online(user.id));let label=Design.label(own ? "La tua nota":user.text("username"),size:11,color:own ? Design.muted:Design.ink);label.textAlignment = .center
            let tile=Design.stack(spacing:4,views:[bubble,avatar,label]);tile.alignment = .center;tile.onTap { [weak self] in self?.sheet(NoteController(owner:user.id)) }
            let heart=ClosureTap { [weak self] in guard !own else { return };self?.action("noteReact",["user":user.id,"created":note.number("created"),"enabled":true]) };heart.numberOfTapsRequired=2;tile.addGestureRecognizer(heart);for tap in tile.gestureRecognizers ?? [] where tap !== heart { tap.require(toFail:heart) };row.addArrangedSubview(tile)
        };return horizontal
    }
    @objc private func pileOptions(_ recognizer:UILongPressGestureRecognizer) { guard recognizer.state == .began else { return };menu("Istantanee",items:[("Apri archivio",false,{ self.push(InstantArchiveController()) }),("Pausa per 24 ore",false,{ self.run { _ = try await self.session.api("/instants/preferences",["paused":true]) } }),("Nascondi bolla",false,{ self.action("preferences",["key":"hideInstantBubble","value":true]) })],source:pile) }
}
@MainActor final class ThreadRow: UIView {
    init(_ thread:Entity,parent:Screen) {
        super.init(frame:.zero);let s=parent.session;let peer=s.other(thread);let last=thread.list("messages").last ?? Entity();let unread=thread.list("messages").contains { $0.text("author") != s.userID && !$0.strings("readBy").contains(s.userID) }
        let reactions=s.reactions(thread);let latestReaction=reactions.first;let reacted=(latestReaction?.number("created") ?? 0)>last.number("created")
        let preview=reacted ? "Ha reagito a un tuo messaggio":last.text("text").isEmpty ? (last.text("kind")=="audio" ? "Messaggio vocale":"Foto"):last.text("text")
        let avatar=Avatar(peer,size:62,story:!s.stories(peer.id).isEmpty,online:s.online(peer.id));let labels=Design.stack(spacing:6,views:[Design.label(s.threadName(thread),size:15,weight:unread ? .bold:.semibold),Design.label(preview+" · "+Domain.ago(s.latest(thread)),size:13,weight:unread ? .semibold:.regular,color:unread ? Design.ink:Design.muted)])
        let dot=UIView();dot.backgroundColor=unread ? Design.violet:.clear;dot.layer.cornerRadius=4;dot.widthAnchor.constraint(equalToConstant:8).isActive=true;dot.heightAnchor.constraint(equalToConstant:8).isActive=true
        let row=Design.stack(.horizontal,spacing:13,views:[avatar,labels,dot]);row.alignment = .center;addSubview(row);row.pin(to:self,insets:UIEdgeInsets(top:13,left:18,bottom:13,right:20));onTap { [weak parent] in parent?.push(ChatController(id:thread.id)) }
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
}
@MainActor final class MessageRequestsController: StackScreen {
    let hidden:Bool
    init(hidden:Bool) { self.hidden=hidden;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad();title=hidden ? "Richieste nascoste":"Richieste di messaggi";stateChanged() }
    override func stateChanged() {
        clear();if !hidden { row("Richieste nascoste",subtitle:"\(session.threads.filter { $0.text("requestDecision")=="hidden" }.count)",icon:"eye.slash") { [weak self] in self?.push(MessageRequestsController(hidden:true)) } }
        let rows=session.threads.filter { hidden ? $0.text("requestDecision")=="hidden":session.isRequest($0) && $0.text("requestDecision") != "hidden" }
        if rows.isEmpty { empty("Nessuna richiesta di\nmessaggi recente",detail:"Le nuove richieste appariranno qui.",symbol:"paperplane.circle");row("Mostra tutto",icon:"arrow.down") { [weak self] in self?.run { try await self?.session.sync() } } }
        for t in rows { add(ThreadRow(t,parent:self));let actions=Design.stack(.horizontal,spacing:8);actions.distribution = .fillEqually;actions.addArrangedSubview(Design.button("Accetta",primary:true) { [weak self] in self?.action("messageRequest",["id":t.id,"decision":"accepted"]) });actions.addArrangedSubview(Design.button("Nascondi") { [weak self] in self?.action("messageRequest",["id":t.id,"decision":"hidden"]) });add(actions,inset:18) }
    }
}

@MainActor final class ChatController: Screen, UITextFieldDelegate {
    let id:String
    private let scroll=UIScrollView(),messages=Design.stack(spacing:10),input=Design.field("Messaggio…"),status=Design.label("",size:11,color:Design.muted)
    private var bottom:NSLayoutConstraint!
    private var replyID="",editID=""
    private let replyPreview=Design.stack(.horizontal,spacing:10),replyText=Design.label("",size:12,color:Design.muted,lines:2)
    private var typingTask:Task<Void,Never>?,presenceTask:Task<Void,Never>?
    private var lastSignature=""
    private var reading=false
    private var recorder:AVAudioRecorder?
    private var player:AVPlayer?
    private var picker:MediaPicker?
    private var recording=false
    private var voiceButton: UIButton!
    private var photoButton: UIButton!
    private var attachmentsButton: UIButton!
    private var sendButton: UIButton!
    init(id:String) { self.id=id;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad();scroll.alwaysBounceVertical=true;scroll.keyboardDismissMode = .interactive
        let thread=session.thread(id),peer=session.other(thread);let title=Design.stack(spacing:3,views:[Design.label(session.threadName(thread),size:15,weight:.bold),status]);title.onTap { [weak self] in self?.push(ProfileController(id:peer.id)) };navigationItem.titleView=title
        let video=Design.icon("video") { [weak self] in self?.call(video:true) };let audio=Design.icon("phone") { [weak self] in self?.call(video:false) };navigationItem.rightBarButtonItems=[UIBarButtonItem(customView:video),UIBarButtonItem(customView:audio)]
        navigationItem.leftItemsSupplementBackButton=true;navigationItem.leftBarButtonItem=UIBarButtonItem(customView:Design.icon("more",size:21) { [weak self] in self?.chatOptions() })
        view.addSubview(scroll);scroll.translatesAutoresizingMaskIntoConstraints=false;scroll.addSubview(messages);messages.pin(to:scroll,insets:UIEdgeInsets(top:18,left:14,bottom:18,right:14));messages.widthAnchor.constraint(equalTo:scroll.frameLayoutGuide.widthAnchor,constant:-28).isActive=true
        input.backgroundColor = .clear
        input.layer.cornerRadius = 0
        input.leftView = nil
        input.placeholder = "Scrivi…"
        input.delegate = self
        input.returnKeyType = .send
        input.addAction(UIAction { [weak self] _ in
            self?.updateComposer()
            self?.typingChanged()
        }, for: .editingChanged)
        let camera = composerIcon("camera", size: 22) { [weak self] in self?.choosePhoto(camera: true) }
        camera.tintColor = .white
        camera.backgroundColor = Design.violet
        camera.layer.cornerRadius = 19
        photoButton = composerIcon("photo", size: 24) { [weak self] in self?.choosePhoto(camera: false) }
        voiceButton = composerIcon("mic", size: 23) { [weak self] in self?.voice() }
        attachmentsButton = composerIcon("plus.circle", size: 25) { [weak self] in self?.attachments() }
        sendButton = Design.button("Invia", primary: true) { [weak self] in self?.send() }
        sendButton.layer.cornerRadius = 18
        sendButton.clipsToBounds = true
        let sendWidth = sendButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 54)
        sendWidth.priority = .defaultHigh
        sendWidth.isActive = true
        let composer = Design.stack(.horizontal, spacing: 4, views: [camera, input, photoButton, voiceButton, attachmentsButton, sendButton])
        composer.alignment = .center
        composer.backgroundColor = Design.soft
        composer.layer.cornerRadius = 29
        composer.layer.borderWidth = 1
        composer.layer.borderColor = Design.line.cgColor
        composer.isLayoutMarginsRelativeArrangement = true
        composer.layoutMargins = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
        updateComposer()
        replyPreview.addArrangedSubview(replyText);replyPreview.addArrangedSubview(Design.icon("xmark",size:17) { [weak self] in self?.replyID="";self?.replyPreview.isHidden=true;self?.replyPreview.superview?.isHidden=true });replyPreview.isHidden=true;let dock=Design.stack(spacing:4,views:[Design.inset(replyPreview,UIEdgeInsets(top:4,left:24,bottom:4,right:12)),composer]);replyPreview.superview?.isHidden=true;view.addSubview(dock);dock.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([scroll.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),scroll.leadingAnchor.constraint(equalTo:view.leadingAnchor),scroll.trailingAnchor.constraint(equalTo:view.trailingAnchor),scroll.bottomAnchor.constraint(equalTo:dock.topAnchor,constant:-5),dock.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:11),dock.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-11),dock.bottomAnchor.constraint(equalTo:view.keyboardLayoutGuide.topAnchor,constant:-8)])
        stateChanged()
    }
    private func composerIcon(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: size)), for: .normal)
        button.tintColor = Design.ink
        let width = button.widthAnchor.constraint(equalToConstant: 38)
        width.priority = .defaultHigh
        width.isActive = true
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func updateComposer() {
        let hasDraft = !(input.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        photoButton.isHidden = hasDraft
        voiceButton.isHidden = hasDraft && !recording
        attachmentsButton.isHidden = hasDraft
        sendButton.isHidden = !hasDraft
    }

    override func viewDidAppear(_ animated:Bool) { super.viewDidAppear(animated);presenceTask?.cancel();presenceTask=Task { [weak self] in while !Task.isCancelled { guard let self=self else { return };await self.refreshPresence();try? await Task.sleep(nanoseconds:2_000_000_000) } };markRead() }
    override func viewWillDisappear(_ animated:Bool) { super.viewWillDisappear(animated);presenceTask?.cancel();typingTask?.cancel();if recording { recorder?.stop();recording=false };Task { _ = try? await session.api("/threads/\(id)/typing",["active":false]) } }
    override func stateChanged() {
        let t=session.thread(id);let rows=t.list("messages");let signature=String(describing:rows.map(\.values))+String(describing:session.reactions(t).map(\.values))
        guard signature != lastSignature else { updateStatus();return };lastSignature=signature
        let nearBottom=scroll.contentSize.height-scroll.contentOffset.y-scroll.bounds.height<140 || messages.arrangedSubviews.isEmpty
        let offset=scroll.contentOffset;for item in messages.arrangedSubviews { messages.removeArrangedSubview(item);item.removeFromSuperview() }
        let ttl=t.number("messageTTL");if ttl != 0 { let caption=ttl == -1 ? "I messaggi scompaiono dopo la lettura":"Messaggi temporanei · \(Int(ttl/3600)) h";let label=Design.label(caption,size:11,color:Design.muted);label.textAlignment = .center;messages.addArrangedSubview(label) }
        for m in rows { if m.number("expires")>0 && m.number("expires")<Date().timeIntervalSince1970 { continue };messages.addArrangedSubview(messageView(m)) }
        for reaction in session.reactions(t).filter({ !$0.flag("seen") }) { let label=Design.label(Domain.notificationText(reaction),size:11,color:Design.muted);label.textAlignment = .center;messages.addArrangedSubview(label) }
        view.layoutIfNeeded();if nearBottom { scroll.setContentOffset(CGPoint(x:0,y:max(-scroll.adjustedContentInset.top,scroll.contentSize.height-scroll.bounds.height+scroll.adjustedContentInset.bottom)),animated:false) } else { scroll.setContentOffset(offset,animated:false) };updateStatus()
        if view.window != nil { markRead() }
    }
    private func messageView(_ m:Entity) -> UIView {
        let mine=m.text("author")==session.userID;let bubble=Design.stack(spacing:5);bubble.backgroundColor=mine ? Design.violet:Design.soft;bubble.layer.cornerRadius=20;bubble.isLayoutMarginsRelativeArrangement=true;bubble.layoutMargins=UIEdgeInsets(top:10,left:13,bottom:9,right:13)
        if !m.text("reply").isEmpty { let original=session.thread(id).list("messages").first { $0.id==m.text("reply") } ?? Entity();bubble.addArrangedSubview(Design.label("↪ "+original.text("text","Foto"),size:11,color:mine ? UIColor.white.withAlphaComponent(0.7):Design.muted,lines:2)) }
        if m.text("kind")=="image" || m.text("kind")=="gif" {
            if m.flag("viewOnce") { let b=Design.button(mine ? "① Foto inviata":"① Foto · Visualizza una volta") { [weak self] in if !mine { self?.openOnce(m) } };bubble.addArrangedSubview(b) }
            else { let photo=PhotoView(m.text("media"));photo.layer.cornerRadius=12;photo.heightAnchor.constraint(equalToConstant:220).isActive=true;photo.widthAnchor.constraint(equalToConstant:220).isActive=true;bubble.addArrangedSubview(photo);photo.onTap { [weak self] in self?.sheet(MediaViewer(reference:m.text("media")),full:true) } }
        } else if m.text("kind")=="audio" { bubble.addArrangedSubview(Design.button("▶ Messaggio vocale",icon:"waveform") { [weak self] in guard let url=Domain.mediaURL(m.text("media")) else { return };self?.player=AVPlayer(url:url);self?.player?.play() }) }
        else if ["post","story"].contains(m.text("kind")) { let shared=m.object("story");let p=session.post(shared.text("postId",shared.text("id",m.text("post"))));let preview=PhotoView(p.media.first ?? shared.text("media"));preview.heightAnchor.constraint(equalToConstant:140).isActive=true;preview.widthAnchor.constraint(equalToConstant:190).isActive=true;bubble.addArrangedSubview(preview);preview.onTap { [weak self] in self?.push(PostDetailController(id:p.id)) } }
        if !m.text("text").isEmpty { bubble.addArrangedSubview(Design.label(m.text("text"),size:15,color:mine ? .white:Design.ink,lines:0)) }
        let read=m.strings("readBy").contains { $0 != session.userID };bubble.addArrangedSubview(Design.label(Domain.clock(m.number("created"))+(mine ? (read && session.me.enabled("readReceipts") ? "  ✓✓":"  ✓"):""),size:10,color:mine ? UIColor.white.withAlphaComponent(0.65):Design.muted))
        let reactions=m.object("reactions").values.values.compactMap { $0 as? String }.joined(separator:" ");if !reactions.isEmpty { bubble.addArrangedSubview(Design.label(reactions,size:15)) }
        let container=UIView();container.addSubview(bubble);bubble.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([bubble.topAnchor.constraint(equalTo:container.topAnchor),bubble.bottomAnchor.constraint(equalTo:container.bottomAnchor),bubble.widthAnchor.constraint(lessThanOrEqualTo:container.widthAnchor,multiplier:0.8),mine ? bubble.trailingAnchor.constraint(equalTo:container.trailingAnchor):bubble.leadingAnchor.constraint(equalTo:container.leadingAnchor)])
        bubble.addGestureRecognizer(MessageLongPress { [weak self] in self?.messageOptions(m) });let swipe=MessageSwipe { [weak self] in self?.beginReply(m) };bubble.addGestureRecognizer(swipe)
        let doubleTap=ClosureTap { [weak self] in self?.action("react",["id":m.id,"emoji":"❤️"]) };doubleTap.numberOfTapsRequired=2;bubble.addGestureRecognizer(doubleTap)
        return container
    }
    private func beginReply(_ message:Entity) { replyID=message.id;editID="";replyText.text="Rispondi a "+session.person(message.text("author")).text("name")+"\n"+message.text("text","Foto");replyPreview.isHidden=false;replyPreview.superview?.isHidden=false;input.becomeFirstResponder() }
    private func messageOptions(_ m:Entity) {
        var items:[(String,Bool,()->Void)]=[("Rispondi",false,{ self.beginReply(m) }),("Reagisci",false,{ self.present(ReactionPicker { [weak self] emoji in self?.action("react",["id":m.id,"emoji":emoji]) },animated:true) }),("Copia",false,{ UIPasteboard.general.string=m.text("text") })]
        if m.text("author")==session.userID { items += [("Modifica",false,{ self.editID=m.id;self.input.text=m.text("text");self.updateComposer();self.input.becomeFirstResponder() }),("Elimina",true,{ self.action("deleteMessage",["id":m.id]) })] };menu(nil,items:items)
    }
    private func send() {
        let text=(input.text ?? "").trimmingCharacters(in:.whitespacesAndNewlines);guard !text.isEmpty else { return };let edit=editID,reply=replyID
        run { try await self.session.action(edit.isEmpty ? "message":"editMessage",["id":edit.isEmpty ? self.id:edit,"text":text,"reply":reply]);self.input.text="";self.replyID="";self.editID="";self.replyPreview.isHidden=true;self.replyPreview.superview?.isHidden=true;self.input.placeholder="Scrivi…";self.updateComposer();self.typingChanged() }
    }
    func textFieldShouldReturn(_ textField:UITextField) -> Bool { send();return false }
    private func typingChanged() {
        typingTask?.cancel();let active = !(input.text ?? "").isEmpty
        typingTask=Task { [weak self] in try? await Task.sleep(nanoseconds:250_000_000);guard !Task.isCancelled,let self=self,!self.session.isDemo,self.session.preferences.enabled("activityStatus") else { return };_ = try? await self.session.api("/threads/\(self.id)/typing",["active":active,"kind":"typing"]) }
    }
    private func refreshPresence() async {
        guard !session.isDemo else { updateStatus();return }
        if let result=try? await session.api("/threads/\(id)/presence") {
            var users=session.users;for fresh in result.list("users") { if let i=users.firstIndex(where:{$0.id==fresh.id}) { users[i]=users[i].updating(fresh.values) } else { users.append(fresh) } };let threads=session.state.list("threads").map { $0.id==id ? $0.updating(["typing":result.list("typing").map(\.values)]):$0 };session.state=session.state.updating(["users":users.map(\.values),"threads":threads.map(\.values)]);updateStatus()
        }
    }
    private func updateStatus() {
        guard session.preferences.enabled("activityStatus") else { status.text="";return };let t=session.thread(id),peer=session.other(t);let typing=t.list("typing").first { $0.text("user") != session.userID && $0.number("until")>Date().timeIntervalSince1970 }
        if let typing=typing { status.text=typing.text("kind")=="recording" ? "Sta registrando un vocale…":"Sta scrivendo…";status.textColor=Design.violet }
        else { status.text=session.online(peer.id) ? "● Online":peer.number("lastActive")>0 ? "Ultimo accesso "+Domain.ago(peer.number("lastActive")):"";status.textColor=session.online(peer.id) ? .systemGreen:Design.muted }
    }
    private func markRead() {
        guard !reading else { return }
        let rows=session.thread(id).list("messages").filter { $0.text("author") != session.userID && !$0.strings("readBy").contains(session.userID) && !$0.flag("viewOnce") }
        reading=true
        run { defer { self.reading=false };for m in rows { try await self.session.action("read",["id":m.id]) };for n in self.session.reactions(self.session.thread(self.id)).filter({!$0.flag("seen")}) { try await self.session.action("notificationsRead",["id":n.id]) } }
    }
    private func chatOptions() {
        menu("Conversazione",items:[("Messaggi temporanei",false,{ self.menu("Quando devono scomparire?",items:[("Disattivati",0),("Dopo la lettura",-1),("Dopo 1 ora",3600),("Dopo 24 ore",86400),("Dopo 1 minuto",60)].map { item in (item.0,false,{ self.action("messageExpiry",["id":self.id,"seconds":item.1]) }) }) }),("Conferme di lettura",false,{ self.action("profile",["readReceipts":!self.session.me.enabled("readReceipts")]) }),("Dettagli e partecipanti",false,{ self.push(ThreadDetailsController(id:self.id)) })])
    }
    private func attachments() { menu("Condividi",items:[("Foto",false,{ self.choosePhoto(camera:false) }),("Fotocamera",false,{ self.choosePhoto(camera:true) }),("Foto visualizzabile una volta",false,{ self.choosePhoto(camera:false,once:true) }),("Istantanea",false,{ self.sheet(InstantCameraController(),full:true) }),("GIF",false,{ let gallery=GiphyController();gallery.onSelect={ [weak self] ref in guard let self=self else { return };self.action("message",["id":self.id,"kind":"gif","media":ref,"text":""]) };self.sheet(gallery) }),("Sticker",false,{ self.prompt("Sticker o emoji") { self.action("message",["id":self.id,"kind":"sticker","text":$0]) } })]) }
    private func choosePhoto(camera:Bool,once:Bool=false) {
        picker=MediaPicker(host:self,video:false,camera:camera) { [weak self] data,mime in guard let self=self else { return };self.run { let media=try await self.session.upload(data,mime:mime);try await self.session.action("message",["id":self.id,"kind":"image","media":media.text("id"),"text":"","viewOnce":once,"maxOpens":1,"reply":self.replyID]);self.replyID="" } };picker?.present()
    }
    private func voice() {
        if recording { recorder?.stop();recording=false;voiceButton.tintColor=Design.ink;input.placeholder="Scrivi…";updateComposer();guard let url=recorder?.url else { return };run { let data=try Data(contentsOf:url);let m=try await self.session.upload(data,mime:"audio/mp4");try await self.session.action("message",["id":self.id,"kind":"audio","media":m.text("id"),"text":"","reply":self.replyID]);self.replyID="" };return }
        run {
            let permission=await AVAudioApplication.requestRecordPermission();guard permission else { throw GPIXFailure.message("Consenti l’accesso al microfono nelle impostazioni di iPhone.") }
            let audio=AVAudioSession.sharedInstance();try audio.setCategory(.playAndRecord,mode:.default,options:[.defaultToSpeaker,.allowBluetooth]);try audio.setActive(true)
            let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".m4a");self.recorder=try AVAudioRecorder(url:url,settings:[AVFormatIDKey:kAudioFormatMPEG4AAC,AVSampleRateKey:44100,AVNumberOfChannelsKey:1,AVEncoderAudioQualityKey:AVAudioQuality.high.rawValue]);self.recorder?.record(forDuration:180);self.recording=true;self.voiceButton.tintColor=Design.danger;self.input.placeholder="Registrazione… tocca il microfono per inviare"
            if !self.session.isDemo { _ = try? await self.session.api("/threads/\(self.id)/typing",["active":true,"kind":"recording"]) }
        }
    }
    private func openOnce(_ m:Entity) { run { let data=try await self.session.requestData("/messages/\(m.id)/open",payload:[:]);self.present(PrivatePhotoController(data:data),animated:true) } }
    private func call(video:Bool) { run { try await self.session.action("callStart",["id":self.id,"video":video]);if let c=self.session.state.list("calls").first(where:{$0.text("thread")==self.id && !["ended","declined"].contains($0.text("status"))}) { self.sheet(CallController(callID:c.id),full:true) } } }
}
@MainActor final class MessageLongPress: UILongPressGestureRecognizer {
    private let work:()->Void
    init(_ work:@escaping()->Void) { self.work=work;super.init(target:nil,action:nil);addTarget(self,action:#selector(go)) }
    @objc private func go() { if state == .began { work() } }
}
@MainActor final class MessageSwipe: UISwipeGestureRecognizer {
    private let work:()->Void
    init(_ work:@escaping()->Void) { self.work=work;super.init(target:nil,action:nil);direction = .right;addTarget(self,action:#selector(go)) }
    @objc private func go() { work() }
}
@MainActor final class ThreadDetailsController: StackScreen {
    let id:String
    init(id:String) { self.id=id;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad();title="Dettagli";stateChanged() }
    override func stateChanged() {
        clear();let t=session.thread(id);row(session.threadName(t),icon:"bubble.left.and.bubble.right")
        for user in t.strings("members") { let p=session.person(user);row(p.text("name"),subtitle:p.text("username"),accessory:Avatar(p,size:40)) { [weak self] in self?.push(ProfileController(id:user)) } }
        if t.text("owner")==session.userID { row("Aggiungi partecipante",icon:"person.badge.plus") { [weak self] in guard let self=self else { return };self.push(PeopleController(mode:.group(self.id))) };row("Nome del gruppo",icon:"pencil") { [weak self] in self?.prompt("Nome del gruppo",value:t.text("title")) { self?.action("renameGroup",["id":self?.id ?? "","title":$0]) } } }
        if !t.text("owner").isEmpty { row("Abbandona gruppo",icon:"rectangle.portrait.and.arrow.right") { [weak self] in self?.action("leaveGroup",["id":self?.id ?? ""]) } }
    }
}
