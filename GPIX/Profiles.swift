import UIKit

@MainActor final class ProfileController: StackScreen {
    let id:String
    private var gridKind="post"
    init(id:String) { self.id=id;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad();render() }
    override func stateChanged() { render() }
    private func render() {
        let offset=scroll.contentOffset;clear();let p=session.person(id);let own=id==session.userID;title=p.text("username")
        navigationItem.rightBarButtonItem=UIBarButtonItem(customView:Design.icon(own ? "line.3.horizontal":"more") { [weak self] in guard let self=self else { return };if own { self.push(SettingsController()) } else { self.profileMenu() } })
        if own { navigationItem.leftBarButtonItem=UIBarButtonItem(customView:Design.icon("plus",size:28) { [weak self] in self?.sheet(CreateMenuController()) }) }
        let avatar=Avatar(p,size:80,story:!session.stories(id).isEmpty);avatar.onTap { [weak self] in guard let self=self else { return };let stories=self.session.stories(self.id);if !stories.isEmpty { self.present(StoryViewer(stories:stories),animated:true) } else if own { self.sheet(StoryEditorController(),full:true) } }
        let counts=Domain.counts(p,posts:session.posts);let stats=Design.stack(.horizontal);stats.distribution = .fillEqually
        for (index,title) in ["Post","Follower","Seguiti"].enumerated() { let n=Design.label("\(counts[index])",size:19,weight:.bold);n.textAlignment = .center;let t=Design.label(title,size:12);t.textAlignment = .center;let stat=Design.stack(spacing:4,views:[n,t]);if index>0 { stat.onTap { [weak self] in self?.push(PeopleController(mode:index==1 ? .followers(self?.id ?? ""):.following(self?.id ?? ""))) } };stats.addArrangedSubview(stat) }
        let header=Design.stack(.horizontal,spacing:24,views:[avatar,stats]);header.alignment = .center;add(header,inset:20)
        let name=Design.stack(.horizontal,spacing:7,views:[Design.label(p.text("name"),size:14,weight:.semibold),Design.label(p.text("pronouns"),size:12,color:Design.muted),UIView()]);add(name,inset:18)
        if !p.text("bio").isEmpty { add(Design.label(p.text("bio"),size:14,lines:0),inset:18) }
        let linksScroll=UIScrollView();linksScroll.showsHorizontalScrollIndicator=false;linksScroll.heightAnchor.constraint(equalToConstant:40).isActive=true;let links=Design.stack(.horizontal,spacing:8);links.alignment = .center;linksScroll.addSubview(links);links.pin(to:linksScroll);links.heightAnchor.constraint(equalTo:linksScroll.frameLayoutGuide.heightAnchor).isActive=true
        for link in p.list("links") { let b=Design.button(link.text("title",link.text("value",link.text("url"))),icon:link.text("type")=="website" ? "globe":"link") { if let url=URL(string:link.text("url")) { UIApplication.shared.open(url) } };b.layer.cornerRadius=20;b.layer.borderWidth=1;b.layer.borderColor=Design.line.cgColor;b.backgroundColor=Design.background;links.addArrangedSubview(b) }
        if own { links.addArrangedSubview(Design.button("Aggiungi",icon:"plus") { [weak self] in self?.sheet(LinksController()) }) };if !links.arrangedSubviews.isEmpty { add(linksScroll,inset:18) }
        let buttons=Design.stack(.horizontal,spacing:8);buttons.distribution = .fillEqually
        if own {
            buttons.addArrangedSubview(Design.button("Modifica profilo") { [weak self] in self?.push(EditProfileController()) })
            buttons.addArrangedSubview(Design.button("Condividi profilo") { [weak self] in self?.shareProfile() })
        } else {
            let pending=session.pending(id);let following=session.following(id)
            buttons.addArrangedSubview(Design.button(pending ? "Richiesta inviata":following ? "Segui già":"Segui",primary:!pending && !following) { [weak self] in guard let self=self else { return };self.action("follow",["user":self.id,"enabled":!following && !pending]) })
            buttons.addArrangedSubview(Design.button("Messaggio") { [weak self] in guard let self=self else { return };self.run { let id=try await self.session.startThread(self.id);self.push(ChatController(id:id)) } })
        };add(buttons,inset:18)
        let highlights=session.state.list("highlights").filter { $0.text("owner")==id }
        if !highlights.isEmpty || own {
            let h=Design.stack(.horizontal,spacing:15);h.alignment = .top
            for item in highlights.prefix(4) { let cover=PhotoView(session.post(item.strings("posts").first ?? "").media.first ?? "");cover.layer.cornerRadius=28;cover.widthAnchor.constraint(equalToConstant:56).isActive=true;cover.heightAnchor.constraint(equalToConstant:56).isActive=true;let text=Design.label(item.text("title"),size:10);text.textAlignment = .center;let tile=Design.stack(spacing:5,views:[cover,text]);tile.onTap { [weak self] in guard let self=self else { return };self.present(StoryViewer(stories:item.strings("posts").map(self.session.post)),animated:true) };h.addArrangedSubview(tile) }
            if own { let b=Design.button("Nuova",icon:"plus") { [weak self] in self?.push(HighlightsController()) };h.addArrangedSubview(b) };h.addArrangedSubview(UIView());add(h,inset:18)
        }
        let selectors=Design.stack(.horizontal);selectors.distribution = .fillEqually
        for pair in [("post","square.grid.3x3"),("reel","reel"),("tagged","person.crop.rectangle")] { let b=Design.icon(pair.1,color:gridKind==pair.0 ? Design.ink:Design.muted) { [weak self] in self?.gridKind=pair.0;self?.render() };selectors.addArrangedSubview(b) };add(selectors);add(Design.divider())
        let privateLocked=p.flag("private") && !own && !session.following(id)
        if privateLocked { empty("Questo account è privato",detail:"Segui questo account per vedere foto e video.",symbol:"lock") }
        else {
            var posts=session.posts.filter { $0.text("author")==id && !$0.flag("archived") && $0.text("kind")==gridKind }
            if gridKind=="tagged" { posts=session.posts.filter { $0.strings("tags").contains(id) && !$0.flag("archived") } }
            let pinned=p.strings("pinnedPosts"),order=p.strings("gridOrder")
            posts.sort { a,b in let ai=pinned.firstIndex(of:a.id).map { $0-10000 } ?? order.firstIndex(of:a.id) ?? 10000;let bi=pinned.firstIndex(of:b.id).map { $0-10000 } ?? order.firstIndex(of:b.id) ?? 10000;return ai==bi ? a.number("created")>b.number("created"):ai<bi }
            if posts.isEmpty { empty("Condividi i tuoi momenti",detail:own ? "Le tue foto e i tuoi video appariranno qui.":"Non ci sono ancora contenuti.",symbol:"camera") }
            add(PhotoGrid(posts:posts,parent:self))
        };scroll.setContentOffset(offset,animated:false)
    }
    private func shareProfile() { guard let url=URL(string:"https://gpix.cc/u/"+session.person(id).text("username")) else { return };let share=UIActivityViewController(activityItems:[url],applicationActivities:nil);share.popoverPresentationController?.sourceView=view;present(share,animated:true) }
    private func profileMenu() {
        let blocked=session.state.strings("blocks").contains(id);let close=session.state.strings("closeFriends").contains(id)
        menu(nil,items:[(close ? "Rimuovi dagli amici più stretti":"Aggiungi agli amici più stretti",false,{ self.action("closeFriend",["user":self.id,"enabled":!close]) }),("Silenzia",false,{ self.action("preferences",["key":"muted","value":Array(Set(self.session.preferences.strings("muted")+[self.id]))]) }),(blocked ? "Sblocca":"Blocca",true,{ self.action("block",["user":self.id,"enabled":!blocked]) }),("Segnala profilo",true,{ self.prompt("Motivo della segnalazione") { self.action("report",["user":self.id,"reason":$0]) } })])
    }
}
@MainActor final class PhotoGrid: UIView {
    init(posts:[Entity],parent:Screen) {
        super.init(frame:.zero);let grid=Design.stack(spacing:2);addSubview(grid);grid.pin(to:self)
        for start in stride(from:0,to:posts.count,by:3) {
            let row=Design.stack(.horizontal,spacing:2);row.distribution = .fillEqually
            for i in start..<start+3 {
                let tile=UIView();row.addArrangedSubview(tile);tile.heightAnchor.constraint(equalTo:tile.widthAnchor,multiplier:1.12).isActive=true
                if i<posts.count { let p=posts[i];let photo=PhotoView(p.media.first ?? "");tile.addSubview(photo);photo.pin(to:tile);tile.onTap { [weak parent] in parent?.push(PostDetailController(id:p.id)) } }
            };grid.addArrangedSubview(row)
        }
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
}

enum PeopleMode { case all, followers(String), following(String), share(String), close, blocked, newChat, group(String) }
@MainActor final class PeopleController: StackScreen, UITextFieldDelegate {
    let mode:PeopleMode;let search=Design.field("Cerca nome utente o nome visualizzato")
    init(mode:PeopleMode = .all) { self.mode=mode;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad();title="Persone";attachHeader(Design.inset(search,UIEdgeInsets(top:8,left:18,bottom:8,right:18)));search.delegate=self;search.addAction(UIAction { [weak self] _ in self?.render() },for:.editingChanged);render() }
    override func stateChanged() { render() }
    private func render() {
        clear();let q=(search.text ?? "").lowercased();var users=session.users.filter { $0.id != session.userID }
        switch mode {
        case .followers(let id): title="Follower";let ids=session.person(id).strings("followersList");users=users.filter { ids.contains($0.id) }
        case .following(let id): title="Seguiti";let ids=session.person(id).strings("followingList");users=users.filter { ids.contains($0.id) }
        case .close: title="Amici più stretti"
        case .blocked: title="Account bloccati";users=users.filter { session.state.strings("blocks").contains($0.id) }
        case .newChat: title="Nuovo messaggio"
        default:break
        }
        users=users.filter { q.isEmpty || ($0.text("name")+" "+$0.text("username")).lowercased().contains(q) }
        for user in users {
            let avatar=Avatar(user,size:48);let labels=Design.stack(spacing:4,views:[Design.label(user.text("name"),size:15,weight:.semibold),Design.label(user.text("username"),size:12,color:Design.muted)])
            let row=Design.stack(.horizontal,spacing:12,views:[avatar,labels]);row.alignment = .center
            switch mode {
            case .share(let postID): row.addArrangedSubview(Design.button("Invia",primary:true) { [weak self] in guard let self=self else { return };self.run { let tid=try await self.session.startThread(user.id);try await self.session.action("sharePost",["id":tid,"post":postID]);self.dismiss(animated:true) } })
            case .close: let selected=session.state.strings("closeFriends").contains(user.id);row.addArrangedSubview(Design.icon(selected ? "checkmark.circle.fill":"circle",color:Design.violet) { [weak self] in self?.action("closeFriend",["user":user.id,"enabled":!selected]) })
            case .blocked: row.addArrangedSubview(Design.button("Sblocca") { [weak self] in self?.action("block",["user":user.id,"enabled":false]) })
            case .newChat: row.onTap { [weak self] in guard let self=self else { return };self.run { let id=try await self.session.startThread(user.id);self.push(ChatController(id:id)) } }
            case .group(let id): row.addArrangedSubview(Design.button("Aggiungi") { [weak self] in self?.action("addMember",["id":id,"user":user.id]) })
            default: row.onTap { [weak self] in self?.push(ProfileController(id:user.id)) };let following=session.following(user.id),pending=session.pending(user.id);row.addArrangedSubview(Design.button(pending ? "Richiesta inviata":following ? "Segui già":"Segui",primary:!following && !pending) { [weak self] in self?.action("follow",["user":user.id,"enabled":!following && !pending]) })
            };add(row,inset:18)
        }
        if users.isEmpty { empty("Nessun risultato",detail:"Prova a cercare un’altra persona.",symbol:"magnifyingglass") }
    }
}
@MainActor final class FollowRequestsController: StackScreen {
    private var accepted:Set<String>=[]
    private let search=Design.field("Cerca nome utente o nome visualizzato")
    override func viewDidLoad() { super.viewDidLoad();title="Richieste di seguirti";navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Gestisci",style:.plain,target:self,action:#selector(manage));attachHeader(Design.inset(search,UIEdgeInsets(top:8,left:18,bottom:8,right:18)));search.addAction(UIAction { [weak self] _ in self?.render() },for:.editingChanged);render() }
    override func stateChanged() { render() }
    private func render() {
        clear();row("Scopri altri profili",subtitle:"Vedi suggerimenti non personalizzati",icon:"person.crop.circle.badge.magnifyingglass") { [weak self] in self?.push(PeopleController()) }
        let ids=Array(Set(session.state.strings("requests")+Array(accepted))).sorted();let q=(search.text ?? "").lowercased()
        for id in ids {
            let u=session.person(id);if !q.isEmpty && !(u.text("name")+u.text("username")).lowercased().contains(q) { continue }
            let details=session.state.object("requestDetails").object(id)
            let avatar=Avatar(u,size:58);let labels=Design.stack(spacing:5,views:[Design.label(u.text("name"),size:14,weight:.semibold),Design.label(accepted.contains(id) ? "Richiesta accettata":"\(Int(details.number("mutualCount"))) in comune",size:11,color:Design.muted)])
            let controls=Design.stack(.horizontal,spacing:6)
            if accepted.contains(id) {
                let followed=session.following(id),pending=session.pending(id);controls.addArrangedSubview(Design.button(followed ? "Segui già":pending ? "Richiesta inviata":"Segui anche tu",primary:!followed && !pending) { [weak self] in self?.action("follow",["user":id,"enabled":!followed && !pending]) })
            } else {
                controls.addArrangedSubview(Design.button("Conferma",primary:true) { [weak self] in guard let self=self else { return };self.run { try await self.session.action("accept",["user":id,"enabled":true]);self.accepted.insert(id);self.render() } })
                controls.addArrangedSubview(Design.button("Elimina") { [weak self] in self?.action("accept",["user":id,"enabled":false]) })
            }
            let line=Design.stack(.horizontal,spacing:11,views:[avatar,labels]);line.alignment = .center
            // A single compact row follows the Android requests layout.
            line.addArrangedSubview(controls);controls.setContentHuggingPriority(.required,for:.horizontal);labels.setContentCompressionResistancePriority(.defaultLow,for:.horizontal)
            for button in controls.arrangedSubviews.compactMap({$0 as? UIButton}) { var config=button.configuration;config?.contentInsets=NSDirectionalEdgeInsets(top:12,leading:10,bottom:12,trailing:10);button.configuration=config }
            add(line,inset:18);add(Design.spacer(8));avatar.onTap { [weak self] in self?.push(ProfileController(id:id)) }
        }
        if ids.isEmpty { empty("Nessuna richiesta",detail:"Le richieste di seguirti appariranno qui.",symbol:"person.badge.plus") }
    }
    @objc private func manage() { menu("Gestisci richieste",items:[("Conferma tutte",false,{ self.run { for id in self.session.state.strings("requests") { try await self.session.action("accept",["user":id,"enabled":true]);self.accepted.insert(id) };self.render() } })]) }
}
@MainActor final class SearchController: StackScreen {
    let field=Design.field("Cerca persone, post e luoghi")
    override func viewDidLoad() { super.viewDidLoad();title="Cerca";attachHeader(Design.inset(field,UIEdgeInsets(top:8,left:18,bottom:8,right:18)));field.addAction(UIAction { [weak self] _ in self?.render() },for:.editingChanged);field.addAction(UIAction { [weak self] _ in guard let self=self else { return };self.session.remember(self.field.text ?? "");self.field.resignFirstResponder() },for:.editingDidEndOnExit);render() }
    override func stateChanged() { render() }
    private func render() {
        clear();let q=(field.text ?? "").trimmingCharacters(in:.whitespacesAndNewlines)
        if q.isEmpty {
            row("Ricerche recenti",accessory:Design.button("Cancella") { [weak self] in self?.session.clearHistory() })
            for term in session.history { row(term,icon:"clock.arrow.circlepath") { [weak self] in self?.field.text=term;self?.render() } }
            add(PhotoGrid(posts:session.posts.filter { $0.text("kind") != "story" && !$0.flag("archived") },parent:self))
        } else {
            for u in session.users.filter({($0.text("username")+" "+$0.text("name")).localizedCaseInsensitiveContains(q)}) { row(u.text("name"),subtitle:u.text("username"),accessory:Avatar(u,size:42)) { [weak self] in self?.session.remember(q);self?.push(ProfileController(id:u.id)) } }
            add(PhotoGrid(posts:session.posts.filter { $0.text("kind") != "story" && !$0.flag("archived") && ($0.text("text")+" "+$0.text("location")).localizedCaseInsensitiveContains(q) },parent:self))
        }
    }
}
