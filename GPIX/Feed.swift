import UIKit
import AVKit

@MainActor final class FeedController: Screen, UITableViewDataSource, UITableViewDelegate {
    private let table=UITableView(frame:.zero,style:.plain)
    private let filterButton = UIButton(type: .system)
    private var followingOnly=false,rows:[Entity]=[],fingerprints:[String:String]=[:],storyFingerprint=""
    override func viewDidLoad() {
        super.viewDidLoad();view.addSubview(table);table.pin(to:view)
        table.dataSource=self;table.delegate=self;table.separatorStyle = .none;table.backgroundColor=Design.background;table.rowHeight=UITableView.automaticDimension;table.estimatedRowHeight=600;table.contentInset.bottom=115;table.alwaysBounceVertical=true
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: Design.icon("plus", size: 30) { [weak self] in
            self?.sheet(CreateMenuController())
        })
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: Design.icon("heart", size: 26) { [weak self] in
            self?.push(ActivityController())
        })
        filterButton.addAction(UIAction { [weak self] _ in self?.chooseFeed() }, for: .touchUpInside)
        navigationItem.titleView = filterButton
        updateFilterTitle()
        let refresh=UIRefreshControl();refresh.tintColor=Design.violet;refresh.addAction(UIAction { [weak self,weak refresh] _ in self?.run { defer { refresh?.endRefreshing() };try await self?.session.sync() } },for:.valueChanged);table.refreshControl=refresh;stateChanged()
    }
    private func updateFilterTitle() {
        var configuration = UIButton.Configuration.plain()
        configuration.title = followingOnly ? "Seguiti" : "Per te"
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = Design.font(23, .bold)
            return attributes
        }
        configuration.image = UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13))
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 5
        configuration.baseForegroundColor = Design.ink
        filterButton.configuration = configuration
    }

    private func chooseFeed() {
        menu(nil, items: [("Per te", false, { self.setFilter(false) }), ("Seguiti", false, { self.setFilter(true) })])
    }

    private func setFilter(_ following: Bool) {
        followingOnly = following
        updateFilterTitle()
        stateChanged()
        scrollToTop()
    }

    func scrollToTop() {
        guard isViewLoaded else { return }
        table.setContentOffset(CGPoint(x: 0, y: -table.adjustedContentInset.top), animated: !UIAccessibility.isReduceMotionEnabled)
    }

    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews();if let header=table.tableHeaderView,header.bounds.width != table.bounds.width { header.frame=CGRect(x:0,y:0,width:table.bounds.width,height:142);table.tableHeaderView=header } }
    override func stateChanged() {
        guard isViewLoaded else { return }
        let next=session.posts.filter { p in p.text("kind")=="post" && !p.flag("archived") && !session.state.strings("blocks").contains(p.text("author")) && !session.preferences.strings("muted").contains(p.text("author")) && (!followingOnly || p.text("author")==session.userID || session.following(p.text("author"))) }
        let hashes=Dictionary(uniqueKeysWithValues:next.map { ($0.id,String(describing:$0.values)) })
        let changed=next.enumerated().compactMap { fingerprints[$0.element.id] != hashes[$0.element.id] ? IndexPath(row:$0.offset,section:0):nil }
        let sameIDs=rows.map(\.id)==next.map(\.id);rows=next;fingerprints=hashes
        let stories=String(describing:session.posts.filter { $0.text("kind")=="story" }.map(\.values))+String(describing:session.users.map(\.values))
        if stories != storyFingerprint || table.tableHeaderView==nil { storyFingerprint=stories;let header=storyStrip();header.frame=CGRect(x:0,y:0,width:table.bounds.width,height:142);table.tableHeaderView=header }
        if !sameIDs { table.reloadData() } else if !changed.isEmpty { UIView.performWithoutAnimation { table.reloadRows(at:changed,with:.none) } }
        if rows.isEmpty { let label=Design.label("Il tuo feed ti aspetta.\nSegui nuove persone o condividi un momento.",size:16,color:Design.muted,lines:0);label.textAlignment = .center;table.backgroundView=label } else { table.backgroundView=nil }
    }
    func scrollViewDidScroll(_ scrollView:UIScrollView) { home?.trackScroll(scrollView, from: self) }
    func tableView(_ tableView:UITableView,numberOfRowsInSection section:Int)->Int { rows.count }
    func tableView(_ tableView:UITableView,cellForRowAt indexPath:IndexPath)->UITableViewCell {
        let cell=tableView.dequeueReusableCell(withIdentifier:"post") ?? UITableViewCell(style:.default,reuseIdentifier:"post");cell.selectionStyle = .none;cell.backgroundColor=Design.background
        for v in cell.contentView.subviews { v.removeFromSuperview() };let card=PostCard(rows[indexPath.row],parent:self);cell.contentView.addSubview(card);card.pin(to:cell.contentView,insets:UIEdgeInsets(top:5,left:0,bottom:14,right:0));return cell
    }
    private func storyStrip() -> UIView {
        let horizontal=UIScrollView();horizontal.showsHorizontalScrollIndicator=false;horizontal.heightAnchor.constraint(equalToConstant:142).isActive=true
        let stack=Design.stack(.horizontal,spacing:13);stack.alignment = .top;horizontal.addSubview(stack);stack.pin(to:horizontal,insets:UIEdgeInsets(top:8,left:12,bottom:12,right:12));stack.heightAnchor.constraint(equalToConstant:122).isActive=true
        var people=[session.me];people += session.users.filter { $0.id != session.userID && !session.stories($0.id).isEmpty && !session.state.strings("blocks").contains($0.id) }
        for person in people {
            let own=person.id==session.userID;let circle=Avatar(person,size:84,story:!session.stories(person.id).isEmpty)
            let name=Design.label(own ? "La tua storia":person.text("username"),size:11);name.textAlignment = .center;name.widthAnchor.constraint(equalToConstant:94).isActive=true
            let item=Design.stack(spacing:7,views:[circle,name]);item.alignment = .center
            item.onTap { [weak self] in guard let self=self else { return };let stories=self.session.stories(person.id);if stories.isEmpty && own { self.sheet(StoryEditorController(),full:true) } else {
                    let queue = stories + people.filter { $0.id != person.id && $0.id != self.session.userID }
                        .flatMap { self.session.stories($0.id) }
                    let firstUnread = own ? nil : stories.firstIndex {
                        !$0.flag("seenByMe") && !$0.strings("viewers").contains(self.session.userID)
                    }
                    self.present(StoryViewer(stories: queue, startAt: firstUnread ?? 0), animated: true)
                } }
            if own {
                let plus = UIButton(type: .system)
                plus.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 19)), for: .normal)
                plus.backgroundColor = Design.ink
                plus.tintColor = Design.background
                plus.layer.cornerRadius = 15
                plus.layer.borderWidth = 2.5
                plus.layer.borderColor = Design.background.cgColor
                plus.accessibilityLabel = "Crea storia"
                plus.addAction(UIAction { [weak self] _ in self?.sheet(StoryEditorController(), full: true) }, for: .touchUpInside)
                item.addSubview(plus)
                plus.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    plus.widthAnchor.constraint(equalToConstant: 30), plus.heightAnchor.constraint(equalToConstant: 30),
                    plus.trailingAnchor.constraint(equalTo: circle.trailingAnchor, constant: 1),
                    plus.bottomAnchor.constraint(equalTo: circle.bottomAnchor)
                ])
            }
            stack.addArrangedSubview(item)
        }
        return horizontal
    }

}

@MainActor final class PostCard: UIView, UIScrollViewDelegate {
    private let post:Entity
    private weak var parent:Screen?
    private let counter=Design.label("",size:11,weight:.semibold,color:.white)
    init(_ post:Entity,parent:Screen) {
        self.post=post;self.parent=parent;super.init(frame:.zero)
        let s=parent.session;let author=s.person(post.text("author"));let vertical=Design.stack(spacing:10);addSubview(vertical);vertical.pin(to:self)
        let avatar=Avatar(author,size:36,story:!s.stories(author.id).isEmpty);avatar.onTap { [weak parent] in parent?.push(ProfileController(id:author.id)) }
        let byline=Design.stack(spacing:3,views:[Design.label(author.text("username"),size:14,weight:.semibold),Design.label(post.text("location"),size:11,color:Design.muted)])
        byline.onTap { [weak parent] in parent?.push(ProfileController(id:author.id)) };byline.arrangedSubviews.last?.isHidden=post.text("location").isEmpty
        let heading=Design.stack(.horizontal,spacing:10,views:[avatar,byline,Design.icon("more") { [weak self] in self?.options() }]);heading.alignment = .center
        vertical.addArrangedSubview(Design.inset(heading,UIEdgeInsets(top:4,left:14,bottom:0,right:8)))
        if !post.media.isEmpty {
            let carousel=UIScrollView();carousel.delegate=self;carousel.isPagingEnabled=true;carousel.showsHorizontalScrollIndicator=false
            let ratio=max(0.65,min(1.5,post.object("style").number("aspect",1)));carousel.heightAnchor.constraint(equalTo:carousel.widthAnchor,multiplier:1/ratio).isActive=true
            let photos=Design.stack(.horizontal);carousel.addSubview(photos);photos.pin(to:carousel);photos.heightAnchor.constraint(equalTo:carousel.frameLayoutGuide.heightAnchor).isActive=true
            for ref in post.media {
                let photo=PhotoView(ref);photo.widthAnchor.constraint(equalTo:carousel.frameLayoutGuide.widthAnchor).isActive=true
                photo.onTap { [weak parent] in parent?.sheet(MediaViewer(reference:ref),full:true) };photos.addArrangedSubview(photo)
                let doubleTap=UITapGestureRecognizer(target:self,action:#selector(doubleLike));doubleTap.numberOfTapsRequired=2;photo.addGestureRecognizer(doubleTap)
                for gesture in photo.gestureRecognizers ?? [] where gesture !== doubleTap { gesture.require(toFail:doubleTap) }
            }
            let wrap=UIView();wrap.addSubview(carousel);carousel.pin(to:wrap);counter.text="1/\(post.media.count)";counter.backgroundColor=UIColor.black.withAlphaComponent(0.5);counter.layer.cornerRadius=10;counter.clipsToBounds=true;counter.textAlignment = .center
            if post.media.count>1 { wrap.addSubview(counter);counter.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([counter.topAnchor.constraint(equalTo:wrap.topAnchor,constant:12),counter.trailingAnchor.constraint(equalTo:wrap.trailingAnchor,constant:-12),counter.widthAnchor.constraint(equalToConstant:43),counter.heightAnchor.constraint(equalToConstant:25)]) };vertical.addArrangedSubview(wrap)
        }
        let liked=post.strings("likes").contains(s.userID)
        let like=Design.icon(liked ? "heart.fill":"heart",color:liked ? Design.danger:nil) { [weak parent] in parent?.action("like",["id":post.id,"enabled":!liked]) }
        let actions=Design.stack(.horizontal,spacing:2,views:[like,Design.icon("bubble.right") { [weak parent] in parent?.sheet(CommentsController(postID:post.id)) },Design.icon("send") { [weak parent] in parent?.sheet(PeopleController(mode:.share(post.id))) },UIView(),Design.icon(post.flag("saved") ? "save.fill":"save") { [weak parent] in parent?.action("save",["id":post.id,"enabled":!post.flag("saved")]) }]);actions.alignment = .center
        vertical.addArrangedSubview(Design.inset(actions,UIEdgeInsets(top:-5,left:5,bottom:-7,right:5)))
        if !post.flag("hideLikes") { vertical.addArrangedSubview(Design.inset(Design.label("\(post.strings("likes").count) Mi piace",size:13,weight:.semibold),UIEdgeInsets(top:0,left:14,bottom:0,right:14))) }
        if !post.text("text").isEmpty { let caption=Design.label(author.text("username")+"  "+post.text("text"),size:14,lines:0);vertical.addArrangedSubview(Design.inset(caption,UIEdgeInsets(top:0,left:14,bottom:0,right:14))) }
        let comments=post.list("comments");if !comments.isEmpty { let link=Design.label("Visualizza tutti i \(comments.count) commenti",size:13,color:Design.muted);link.onTap { [weak parent] in parent?.sheet(CommentsController(postID:post.id)) };vertical.addArrangedSubview(Design.inset(link,UIEdgeInsets(top:0,left:14,bottom:0,right:14))) }
        vertical.addArrangedSubview(Design.inset(Design.label(Domain.ago(post.number("created")),size:10,color:Design.muted),UIEdgeInsets(top:0,left:14,bottom:10,right:14)))
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func doubleLike() { if let parent=parent,!post.strings("likes").contains(parent.session.userID) { parent.action("like",["id":post.id]) };UIView.animate(withDuration:0.15,animations:{ self.transform=CGAffineTransform(scaleX:0.98,y:0.98) }) { _ in UIView.animate(withDuration:0.2) { self.transform = .identity } } }
    func scrollViewDidScroll(_ scrollView:UIScrollView) { guard scrollView.bounds.width>0 else { return };counter.text="\(Int((scrollView.contentOffset.x/scrollView.bounds.width).rounded())+1)/\(post.media.count)" }
    private func options() {
        guard let parent=parent else { return };let own=post.text("author")==parent.session.userID
        var items:[(String,Bool,()->Void)]=[]
        if own {
            items += [("Modifica didascalia",false,{ parent.prompt("Modifica didascalia",value:self.post.text("text")) { parent.action("editPost",["id":self.post.id,"text":$0]) } }),("Archivia",false,{ parent.action("archivePost",["id":self.post.id,"enabled":true]) }),(parent.session.me.strings("pinnedPosts").contains(post.id) ? "Rimuovi dall’alto":"Fissa sul profilo",false,{ parent.action("pinPost",["id":self.post.id,"enabled":!parent.session.me.strings("pinnedPosts").contains(self.post.id)]) }),("Elimina",true,{ parent.menu("Eliminare questo post?",items:[("Elimina definitivamente",true,{ parent.action("deletePost",["id":self.post.id]) })]) })]
        } else { items += [("Segnala",true,{ parent.prompt("Motivo della segnalazione") { parent.action("report",["id":self.post.id,"reason":$0]) } })] }
        parent.menu(nil,items:items,source:self)
    }
}

@MainActor final class CommentsController: StackScreen {
    let postID:String;private let input=Design.field("Aggiungi un commento…");private var replyTo=""
    init(postID:String) { self.postID=postID;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad();title="Commenti"
        let send=Design.icon("send",color:Design.violet) { [weak self] in guard let self=self,let text=self.input.text,!text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return };self.run { try await self.session.action("comment",["id":self.postID,"text":text,"parent":self.replyTo]);self.input.text="";self.replyTo="";self.input.placeholder="Aggiungi un commento…" } }
        let line=Design.stack(.horizontal,spacing:8,views:[input,send]);line.alignment = .center;attachFooter(Design.inset(line,UIEdgeInsets(top:8,left:16,bottom:8,right:16)));render()
    }
    override func stateChanged() { render() }
    private func render() {
        clear();let p=session.post(postID)
        for comment in p.list("comments") {
            let author=session.person(comment.text("author"));let own=comment.text("author")==session.userID;let mine=p.text("author")==session.userID
            if comment.flag("hidden") && !own && !mine { continue }
            let avatar=Avatar(author,size:34);let body=Design.stack(spacing:4,views:[Design.label(author.text("username"),size:13,weight:.semibold),Design.label(comment.text("text"),size:14,lines:0),Design.label(comment.flag("hidden") ? "Nascosto · Visibile a chi l’ha scritto":Domain.ago(comment.number("created")),size:10,color:Design.muted)])
            let respond=Design.label("Rispondi",size:11,weight:.semibold,color:Design.muted);respond.onTap { [weak self] in self?.replyTo=comment.text("parent").isEmpty ? comment.id:comment.text("parent");self?.input.placeholder="Rispondi a "+author.text("username");self?.input.becomeFirstResponder() };body.addArrangedSubview(respond);let liked=comment.strings("likes").contains(session.userID);let line=Design.stack(.horizontal,spacing:11,views:[avatar,body,Design.icon(liked ? "heart.fill":"heart",size:15,color:liked ? Design.danger:Design.muted) { [weak self] in self?.action("likeComment",["id":comment.id,"enabled":!liked]) }]);line.alignment = .top
            let wrap=Design.inset(line,UIEdgeInsets(top:13,left:comment.text("parent").isEmpty ? 18:60,bottom:13,right:12))
            if own || mine { wrap.onTap { [weak self] in guard let self=self else { return };var actions:[(String,Bool,()->Void)]=[("Elimina commento",true,{ self.action("deleteComment",["id":comment.id]) })];if mine && !own { actions.append((comment.flag("hidden") ? "Mostra commento":"Nascondi agli altri",false,{ self.action("hideComment",["id":comment.id,"enabled":!comment.flag("hidden")]) })) };self.menu(nil,items:actions,source:wrap) } };add(wrap)
        }
        input.isEnabled = !p.flag("commentsOff");input.placeholder=p.flag("commentsOff") ? "I commenti sono disattivati":"Aggiungi un commento…"
    }
}
@MainActor final class ActivityController: StackScreen {
    override func viewDidLoad() { super.viewDidLoad();title="Attività";render() }
    override func stateChanged() { render() }
    private func render() {
        clear();row("Richieste di seguirti",subtitle:"\(session.state.strings("requests").count) richieste",icon:"person.badge.plus") { [weak self] in self?.push(FollowRequestsController()) }
        let items=session.state.list("notifications").filter { !["message","messageReaction","call","instant"].contains($0.text("type")) }
        if items.isEmpty { empty("Sei al passo",detail:"Le nuove attività appariranno qui.",symbol:"heart") }
        for n in items { let author=session.person(n.text("actor",n.text("author")));row(author.text("name"),subtitle:Domain.notificationText(n)+" · "+Domain.ago(n.number("created")),accessory:Avatar(author,size:42)) { [weak self] in guard let self=self else { return };self.action("notificationsRead",["id":n.id]);let p=self.session.post(n.text("ref",n.text("target")));if p.text("kind")=="story" { self.present(StoryViewer(stories:[p]),animated:true) } else if !p.id.isEmpty { self.push(PostDetailController(id:p.id)) } else { self.push(ProfileController(id:author.id)) } } }
    }
}
@MainActor final class PostDetailController: StackScreen {
    let id:String
    init(id:String) { self.id=id;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad();title="Post";stateChanged() }
    override func stateChanged() { clear();let p=session.post(id);if !p.id.isEmpty { add(PostCard(p,parent:self)) } }
}
@MainActor final class MediaViewer: Screen {
    let reference:String
    init(reference:String) { self.reference=reference;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad();view.backgroundColor = .black
        guard let url=Domain.mediaURL(reference) else { return }
        if ["mp4","mov","m4v"].contains(url.pathExtension.lowercased()) { let player=AVPlayerViewController();player.player=AVPlayer(url:url);addChild(player);view.addSubview(player.view);player.view.pin(to:view);player.didMove(toParent:self);player.player?.play() }
        else { let photo=PhotoView(reference);photo.contentMode = .scaleAspectFit;photo.backgroundColor = .black;view.addSubview(photo);photo.pin(to:view) }
    }
}
