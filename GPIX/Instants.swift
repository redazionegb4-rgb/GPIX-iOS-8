import UIKit

@MainActor extension Session {
    func instantList() async throws -> Entity { isDemo ? state.object("demoInstants") : try await api("/instants") }
    func instantBytes(_ item:Entity,mode:String) async throws -> Data {
        if isDemo {
            let ref=item.text("media");let name=URL(string:ref)?.lastPathComponent ?? ref
            if let url=Bundle.main.url(forResource:name,withExtension:nil,subdirectory:"Media") { return try Data(contentsOf:url) }
            if let url=URL(string:ref),url.isFileURL { return try Data(contentsOf:url) }
            throw GPIXFailure.message("Foto non disponibile")
        }
        return try await requestData("/instants/\(item.id)/\(mode)",payload:mode=="open" ? [:]:nil)
    }
    func instantArchive(cursor:String="") async throws -> Entity {
        if isDemo { return Entity(["items":state.object("demoInstants").list("sent").map(\.values),"nextCursor":""]) }
        var parts=URLComponents();parts.queryItems=[URLQueryItem(name:"cursor",value:cursor)]
        return try await api("/instants/archive"+(parts.string ?? ""))
    }
    func sendInstant(media:String,caption:String,audience:String,key:String) async throws {
        if isDemo { let item=Entity(["id":UUID().uuidString,"owner":userID,"media":media,"caption":caption,"created":Date().timeIntervalSince1970,"expires":Date().timeIntervalSince1970+86400,"viewsCount":0]);let i=state.object("demoInstants");state=state.updating(["demoInstants":i.updating(["sent":([item]+i.list("sent")).map(\.values),"active":([item]+i.list("active")).map(\.values)]).values]);changed();return }
        _ = try await api("/instants/send",["media":media,"caption":caption,"audience":audience,"requestKey":key]);changed()
    }
    func deleteInstant(_ id:String) async throws {
        if isDemo { let i=state.object("demoInstants");state=state.updating(["demoInstants":i.updating(["sent":i.list("sent").filter{$0.id != id}.map(\.values),"active":i.list("active").filter{$0.id != id}.map(\.values)]).values]);changed();return }
        _ = try await api("/instants/\(id)/delete",[:]);changed()
    }
}
@MainActor final class InstantsController: StackScreen {
    private var snapshot=Entity(),filter=0
    private var loading=false
    override func viewDidLoad() {
        super.viewDidLoad();title="Istantanee";navigationItem.rightBarButtonItem=UIBarButtonItem(customView:Design.icon("clock.arrow.circlepath") { [weak self] in self?.push(InstantArchiveController()) })
        let refresh=UIRefreshControl();refresh.addAction(UIAction { [weak self,weak refresh] _ in self?.run { defer { refresh?.endRefreshing() };try await self?.load() } },for:.valueChanged);scroll.refreshControl=refresh;render();run { try await self.load() }
    }
    override func viewWillAppear(_ animated:Bool) { super.viewWillAppear(animated);run { try await self.load() } }
    override func stateChanged() { run { try await self.load() } }
    private func load() async throws { guard !loading else { return };loading=true;defer { loading=false };snapshot=try await session.instantList();render() }
    private func render() {
        let offset=scroll.contentOffset;clear()
        add(Design.label("Nuovi momenti.",size:30,weight:.bold),inset:20)
        add(Design.label("Uno scatto vero, da condividere adesso.\nLe istantanee scadono dopo 24 ore.",size:14,color:Design.muted,lines:2),inset:20)
        let create=Design.stack(.horizontal,spacing:16,views:[Design.icon("camera",size:30,color:.white) { [weak self] in self?.sheet(InstantCameraController(),full:true) },Design.stack(spacing:6,views:[Design.label("Crea un’istantanea",size:18,weight:.bold,color:.white),Design.label("Scatta e condividi il tuo momento",size:12,color:UIColor.white.withAlphaComponent(0.8))]),UIView(),Design.icon("plus",color:.white) { [weak self] in self?.sheet(InstantCameraController(),full:true) }]);create.alignment = .center
        let hero=Design.inset(create,UIEdgeInsets(top:22,left:14,bottom:22,right:14));hero.backgroundColor=Design.violet;hero.layer.cornerRadius=24;hero.onTap { [weak self] in self?.sheet(InstantCameraController(),full:true) };add(hero,inset:18)
        let filters=UISegmentedControl(items:["Tutte","Nuove","Le mie"]);filters.selectedSegmentIndex=filter;filters.selectedSegmentTintColor=Design.violet;filters.setTitleTextAttributes([.foregroundColor:UIColor.white,.font:Design.font(13,.semibold)],for:.selected);filters.setTitleTextAttributes([.foregroundColor:Design.ink,.font:Design.font(13)],for:.normal);filters.addAction(UIAction { [weak self,weak filters] _ in self?.filter=filters?.selectedSegmentIndex ?? 0;self?.render() },for:.valueChanged);add(filters,inset:20)
        var cards:[(Entity,[Entity],Bool)]=[]
        if filter != 2 { let groups=Dictionary(grouping:snapshot.list("received"),by:{$0.text("owner")});for owner in groups.keys.sorted() { let items=groups[owner] ?? [];if let first=items.first { cards.append((first,items,false)) } } }
        if filter != 1 { for item in snapshot.list("active") { cards.append((item,[item],true)) } }
        if cards.isEmpty { empty(filter==2 ? "Il tuo prossimo istante":"Nessuna nuova istantanea",detail:"Puoi creare un’istantanea anche se non hai ancora amici.",symbol:"camera") }
        for start in stride(from:0,to:cards.count,by:2) {
            let row=Design.stack(.horizontal,spacing:12);row.distribution = .fillEqually
            for index in start..<start+2 {
                if index>=cards.count { row.addArrangedSubview(UIView());continue }
                let tuple=cards[index];let card=InstantCard(item:tuple.0,own:tuple.2,count:tuple.1.count,session:session)
                card.onTap { [weak self] in guard let self=self else { return };let deck=InstantDeck(items:tuple.1,archive:tuple.2);deck.onFinish={ [weak self] in self?.run { try await self?.load() } };self.present(deck,animated:true) };row.addArrangedSubview(card)
            };add(row,inset:18)
        }
        row("Archivio delle istantanee",subtitle:"I tuoi scatti e chi li ha visti",icon:"clock.arrow.circlepath") { [weak self] in self?.push(InstantArchiveController()) };scroll.setContentOffset(offset,animated:false)
    }
}
@MainActor final class InstantCard: UIView {
    private var task:Task<Void,Never>?
    init(item:Entity,own:Bool,count:Int,session:Session) {
        super.init(frame:.zero);heightAnchor.constraint(equalTo:widthAnchor).isActive=true;layer.cornerRadius=24;clipsToBounds=true;backgroundColor=Design.soft
        let photo=PhotoView(frame:.zero);addSubview(photo);photo.pin(to:self)
        let shade=UIView();shade.backgroundColor=UIColor.black.withAlphaComponent(0.22);addSubview(shade);shade.pin(to:self)
        let name=Design.label(own ? (item.text("caption").isEmpty ? "Il tuo istante":item.text("caption")):session.person(item.text("owner")).text("username",item.text("username")),size:14,weight:.bold,color:.white,lines:2)
        let sub=Design.label(own ? "Scade tra \(max(1,Int(ceil((item.number("expires")-Date().timeIntervalSince1970)/3600)))) h":"Tocca per aprire",size:11,color:UIColor.white.withAlphaComponent(0.8))
        let labels=Design.stack(spacing:4,views:[name,sub]);addSubview(labels);labels.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([labels.leadingAnchor.constraint(equalTo:leadingAnchor,constant:13),labels.trailingAnchor.constraint(equalTo:trailingAnchor,constant:-13),labels.bottomAnchor.constraint(equalTo:bottomAnchor,constant:-15)])
        let badge=Design.label(own ? "La tua":"\(count) nuove",size:10,weight:.semibold,color:Design.ink);badge.backgroundColor = .white;badge.layer.cornerRadius=11;badge.clipsToBounds=true;badge.textAlignment = .center;addSubview(badge);badge.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([badge.leadingAnchor.constraint(equalTo:leadingAnchor,constant:12),badge.topAnchor.constraint(equalTo:topAnchor,constant:12),badge.widthAnchor.constraint(equalToConstant:65),badge.heightAnchor.constraint(equalToConstant:24)])
        task=Task { [weak photo] in if let data=try? await session.instantBytes(item,mode:own ? "archive-photo":"preview"),!Task.isCancelled { photo?.image=UIImage(data:data) } }
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { task?.cancel() }
}
@MainActor class PrivatePhotoController: Screen {
    let photo=UIImageView(),cover=UIView()
    private var privacyObservers:[NSObjectProtocol]=[]
    private let initialData:Data?
    init(data:Data?=nil) { initialData=data;super.init(nibName:nil,bundle:nil);modalPresentationStyle = .fullScreen }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad();view.backgroundColor = .black;photo.contentMode = .scaleAspectFit;view.addSubview(photo);photo.pin(to:view);if let data=initialData { photo.image=UIImage(data:data) }
        cover.backgroundColor = .black;view.addSubview(cover);cover.pin(to:view);let label=Design.label("Contenuto protetto\n\nLa registrazione dello schermo è attiva.",size:23,weight:.bold,color:.white,lines:0);label.textAlignment = .center;cover.addSubview(label);label.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([label.centerYAnchor.constraint(equalTo:cover.centerYAnchor),label.leadingAnchor.constraint(equalTo:cover.leadingAnchor,constant:35),label.trailingAnchor.constraint(equalTo:cover.trailingAnchor,constant:-35)])
        let close=Design.icon("xmark",color:.white) { [weak self] in self?.dismiss(animated:true) };view.addSubview(close);close.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([close.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:8),close.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:12)])
        for name in [UIScreen.capturedDidChangeNotification,UIApplication.willResignActiveNotification,UIApplication.didBecomeActiveNotification] { privacyObservers.append(NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.updateProtection() } }) };updateProtection()
    }
    private func updateProtection() { cover.isHidden = !(view.window?.screen ?? UIScreen.main).isCaptured && UIApplication.shared.applicationState == .active;view.bringSubviewToFront(cover);if let button=view.subviews.compactMap({$0 as? UIButton}).first { view.bringSubviewToFront(button) } }
    deinit { for observer in privacyObservers { NotificationCenter.default.removeObserver(observer) } }
}
@MainActor final class InstantDeck: PrivatePhotoController {
    private let items:[Entity],archive:Bool
    private var index=0,loading=false
    private var currentTask:Task<Void,Never>?
    private let caption=Design.label("",size:17,weight:.semibold,color:.white,lines:3),progress=UIPageControl(),owner=Design.label("",size:15,weight:.bold,color:.white)
    private var loaded:[String:UIImage]=[:]
    var onFinish:(()->Void)?
    init(items:[Entity],archive:Bool,index:Int=0) { self.items=items;self.archive=archive;self.index=index;super.init() }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad();let footer=Design.stack(spacing:12,views:[caption,progress]);progress.numberOfPages=items.count;caption.textAlignment = .center
        if !archive { footer.addArrangedSubview(Design.button("Rispondi",icon:"bubble.right") { [weak self] in self?.feedback() }) }
        else { footer.addArrangedSubview(Design.button("Visualizzazioni",icon:"eye") { [weak self] in guard let self=self,self.items.indices.contains(self.index) else { return };self.sheet(InstantViewersController(id:self.items[self.index].id)) }) }
        view.addSubview(footer);footer.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([footer.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:24),footer.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-24),footer.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-18)])
        view.addSubview(owner);owner.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([owner.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:25),owner.centerXAnchor.constraint(equalTo:view.centerXAnchor)])
        let tap=ClosureTap { [weak self] in self?.advance(1) };photo.isUserInteractionEnabled=true;photo.addGestureRecognizer(tap)
        let left=MessageSwipe { [weak self] in self?.advance(1) };left.direction = .left;photo.addGestureRecognizer(left)
        let right=MessageSwipe { [weak self] in self?.advance(-1) };photo.addGestureRecognizer(right);load()
    }
    override func viewDidDisappear(_ animated:Bool) { super.viewDidDisappear(animated);currentTask?.cancel();photo.image=nil;loaded.removeAll();onFinish?() }
    private func load() {
        guard items.indices.contains(index) else { finish();return };loading=true;let item=items[index];progress.currentPage=index;owner.text=session.person(item.text("owner")).text("username");caption.text=item.text("caption");photo.image=nil
        if let cached=loaded[item.id] { photo.image=cached;loading=false;return }
        currentTask=Task { [weak self] in guard let self=self else { return };do { let data=try await self.session.instantBytes(item,mode:self.archive ? "archive-photo":"open");guard !Task.isCancelled else { return };let image=UIImage(data:data);self.photo.image=image;if self.archive,let image=image { self.loaded[item.id]=image };self.loading=false;if self.session.isDemo && !self.archive { let list=self.session.state.object("demoInstants");self.session.state=self.session.state.updating(["demoInstants":list.updating(["received":list.list("received").filter{$0.id != item.id}.map(\.values)]).values]) } } catch { self.loading=false;self.alert("Istantanea non disponibile",error.localizedDescription) } }
    }
    private func advance(_ direction:Int) {
        guard !loading else { return };if direction<0 && !archive { return };let target=index+direction
        guard items.indices.contains(target) else { finish();return }
        index=target
        var transform=CATransform3DIdentity;transform.m34 = -1/850;let angle:CGFloat=direction>0 ? -.pi/2:.pi/2
        guard !UIAccessibility.isReduceMotionEnabled else { load();return }
        UIView.animate(withDuration:0.16,animations:{ self.photo.layer.transform=CATransform3DRotate(transform,angle,0,1,0);self.photo.alpha=0.15 }) { _ in self.photo.layer.transform=CATransform3DRotate(transform,-angle,0,1,0);self.load();UIView.animate(withDuration:0.23,delay:0,options:.curveEaseOut) { self.photo.layer.transform=CATransform3DIdentity;self.photo.alpha=1 } }
    }
    private func finish() { dismiss(animated:true) }
    private func feedback() { guard items.indices.contains(index) else { return };let item=items[index];menu("Rispondi all’istantanea",items:[("❤️",false,{ self.sendFeedback(item,text:"❤️",kind:"reaction") }),("Scrivi un messaggio",false,{ self.prompt("Risposta") { self.sendFeedback(item,text:$0,kind:"reply") } }),("Rispondi con uno scatto",false,{ self.sheet(InstantCameraController(replyTo:item.id),full:true) })]) }
    private func sendFeedback(_ item:Entity,text:String,kind:String) { guard !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return };run { if !self.session.isDemo { _ = try await self.session.api("/instants/\(item.id)/feedback",["text":text,"kind":kind,"requestKey":UUID().uuidString]) };self.alert("Inviato","La risposta è nella conversazione.") } }
}
@MainActor final class InstantArchiveController: StackScreen {
    private var items:[Entity]=[],cursor="",loading=false,selection:Set<String>=[]
    override func viewDidLoad() { super.viewDidLoad();title="Archivio istantanee";navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Seleziona",style:.plain,target:self,action:#selector(selectMode));run { try await self.load(reset:true) } }
    override func viewWillAppear(_ animated:Bool) { super.viewWillAppear(animated);if !items.isEmpty { run { try await self.load(reset:true) } } }
    private var selecting=false
    @objc private func selectMode() { selecting.toggle();selection=[];navigationItem.rightBarButtonItem?.title=selecting ? "Annulla":"Seleziona";render() }
    private func load(reset:Bool) async throws { guard !loading else { return };loading=true;defer { loading=false };let page=try await session.instantArchive(cursor:reset ? "":cursor);items=reset ? page.list("items"):items+page.list("items");cursor=page.text("nextCursor");render() }
    private func render() {
        let offset=scroll.contentOffset;clear();add(Design.label("I tuoi istanti,\nnel tempo.",size:29,weight:.bold,lines:2),inset:20);add(Design.label("Solo tu puoi vedere questo archivio.\nApri uno scatto per vedere chi l’ha visualizzato.",size:13,color:Design.muted,lines:2),inset:20)
        if selecting { add(Design.button("Crea una storia riepilogo · \(selection.count)",primary:true) { [weak self] in self?.recap() },inset:18) }
        if items.isEmpty { empty("Ogni istante conta",detail:"Le istantanee che crei saranno conservate qui.",symbol:"clock.arrow.circlepath") }
        let formatter=DateFormatter();formatter.locale=Locale(identifier:"it_IT");formatter.dateFormat="MMMM yyyy"
        var currentMonth=""
        for start in stride(from:0,to:items.count,by:3) {
            let month=formatter.string(from:Date(timeIntervalSince1970:items[start].number("created")))
            if month != currentMonth { section(month.capitalized);currentMonth=month }
            let row=Design.stack(.horizontal,spacing:3);row.distribution = .fillEqually
            for index in start..<start+3 {
                let tile=UIView();tile.backgroundColor=Design.soft;tile.clipsToBounds=true;tile.layer.cornerRadius=10;tile.heightAnchor.constraint(equalTo:tile.widthAnchor,multiplier:1.35).isActive=true;row.addArrangedSubview(tile)
                guard index<items.count else { tile.backgroundColor = .clear;continue };let item=items[index];let photo=PhotoView(frame:.zero);tile.addSubview(photo);photo.pin(to:tile)
                let date=Date(timeIntervalSince1970:item.number("created"));let day=Calendar.current.component(.day,from:date)
                let badge=Design.label("\(day)\n\(date.formatted(.dateTime.month(.abbreviated)))",size:12,weight:.bold,color:.white,lines:2);badge.textAlignment = .center;badge.backgroundColor=UIColor.black.withAlphaComponent(0.3);badge.layer.cornerRadius=9;badge.clipsToBounds=true;tile.addSubview(badge);badge.translatesAutoresizingMaskIntoConstraints=false
                let views=Design.label((selection.contains(item.id) ? "✓ ":"")+"◉ \(Int(item.number("viewsCount")))",size:11,weight:.semibold,color:.white);views.backgroundColor=UIColor.black.withAlphaComponent(0.45);views.textAlignment = .center;tile.addSubview(views);views.translatesAutoresizingMaskIntoConstraints=false
                NSLayoutConstraint.activate([badge.topAnchor.constraint(equalTo:tile.topAnchor,constant:8),badge.leadingAnchor.constraint(equalTo:tile.leadingAnchor,constant:7),badge.widthAnchor.constraint(equalToConstant:40),badge.heightAnchor.constraint(equalToConstant:38),views.bottomAnchor.constraint(equalTo:tile.bottomAnchor),views.leadingAnchor.constraint(equalTo:tile.leadingAnchor),views.trailingAnchor.constraint(equalTo:tile.trailingAnchor),views.heightAnchor.constraint(equalToConstant:26)])
                tile.onTap { [weak self] in guard let self=self else { return };if self.selecting { if self.selection.contains(item.id) { self.selection.remove(item.id) } else if self.selection.count<9 { self.selection.insert(item.id) };self.render() } else { self.present(InstantDeck(items:self.items,index:index),animated:true) } }
                tile.addGestureRecognizer(MessageLongPress { [weak self] in self?.menu("Istantanea",items:[("Visualizzazioni",false,{ self?.sheet(InstantViewersController(id:item.id)) }),("Elimina",true,{ self?.run { try await self?.session.deleteInstant(item.id);try await self?.load(reset:true) } })],source:tile) })
                Task { [weak photo] in if let bytes=try? await Session.shared.instantBytes(item,mode:"archive-photo") { photo?.image=UIImage(data:bytes) } }
            };add(row,inset:4)
        }
        if !cursor.isEmpty { add(Design.button("Carica altri istanti") { [weak self] in self?.run { try await self?.load(reset:false) } },inset:18) };scroll.setContentOffset(offset,animated:false)
    }
    private func recap() {
        guard !selection.isEmpty else { alert("Scegli gli scatti","Seleziona da 1 a 9 istantanee.");return };run {
            guard !self.session.isDemo else { self.alert("Riepilogo demo","Il riepilogo sarà creato dal server con il tuo account.");return }
            let key=UUID().uuidString;let media=try await self.session.api("/instants/recap",["ids":Array(self.selection),"requestKey":key]);try await self.session.action("post",["kind":"story","media":media.text("media"),"text":"","idempotencyKey":key]);self.selecting=false;self.selection=[];self.render();self.alert("Storia pubblicata","Il riepilogo è nella tua storia.")
        }
    }
}
@MainActor extension InstantDeck {
    convenience init(items:[Entity],index:Int) { self.init(items:items,archive:true,index:index) }
}
@MainActor final class InstantViewersController: StackScreen {
    let id:String;private var offset=0,items:[Entity]=[],more=true
    init(id:String) { self.id=id;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad();title="Visualizzazioni";run { try await self.load() } }
    private func load() async throws {
        let r:Entity
        if session.isDemo { r=Entity(["items":session.users.prefix(2).map { $0.updating(["user":$0.id,"opened":Date().timeIntervalSince1970]).values },"total":2]) }
        else { r=try await session.api("/instants/\(id)/viewers?offset=\(offset)") };items += r.list("items");more=r.values["nextOffset"] is NSNumber;offset=Int(r.number("nextOffset"));title="\(Int(r.number("total"))) visualizzazioni";clear()
        for user in items { row(user.text("name"),subtitle:"Vista "+Domain.ago(user.number("opened")),accessory:Avatar(user,size:42)) { [weak self] in if !user.text("user").isEmpty { self?.push(ProfileController(id:user.text("user"))) } } }
        if items.isEmpty { empty("Nessuna visualizzazione",detail:"Qui vedrai chi ha aperto questa istantanea.",symbol:"eye") };if more { add(Design.button("Mostra altre") { [weak self] in self?.run { try await self?.load() } },inset:18) }
    }
}
