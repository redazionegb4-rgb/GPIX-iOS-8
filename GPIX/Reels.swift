import UIKit
import AVFoundation

@MainActor final class ReelCell: UICollectionViewCell {
    static let reuse="Reel"
    let playerLayer=AVPlayerLayer(),overlay=UIView()
    var player:AVPlayer?
    private var loop:NSObjectProtocol?
    override init(frame:CGRect) { super.init(frame:frame);contentView.backgroundColor = .black;playerLayer.videoGravity = .resizeAspectFill;contentView.layer.addSublayer(playerLayer);contentView.addSubview(overlay);overlay.pin(to:contentView) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() { super.layoutSubviews();playerLayer.frame=contentView.bounds }
    override func prepareForReuse() { super.prepareForReuse();player?.pause();if let loop=loop { NotificationCenter.default.removeObserver(loop) };loop=nil;for v in overlay.subviews { v.removeFromSuperview() };for g in overlay.gestureRecognizers ?? [] { overlay.removeGestureRecognizer(g) };player=nil;playerLayer.player=nil }
    func configure(post:Entity,parent:Screen) {
        prepareForReuse();if let url=post.media.first.flatMap(Domain.mediaURL) { let player=AVPlayer(url:url);self.player=player;playerLayer.player=player;loop=NotificationCenter.default.addObserver(forName:.AVPlayerItemDidPlayToEndTime,object:player.currentItem,queue:.main) { [weak player] _ in Task { @MainActor in player?.seek(to:.zero);player?.play() } } }
        let s=parent.session,author=s.person(post.text("author"));let avatar=Avatar(author,size:34)
        let profile=Design.stack(.horizontal,spacing:9,views:[avatar,Design.label(author.text("username"),size:15,weight:.bold,color:.white)]);profile.alignment = .center;profile.onTap { [weak parent] in parent?.push(ProfileController(id:author.id)) }
        let text=Design.label(post.text("text"),size:14,color:.white,lines:3);let footer=Design.stack(spacing:12,views:[profile,text]);overlay.addSubview(footer);footer.translatesAutoresizingMaskIntoConstraints=false
        let liked=post.strings("likes").contains(s.userID);let controls=Design.stack(spacing:11,views:[Design.icon(liked ? "heart.fill":"heart",size:29,color:liked ? Design.danger:.white) { [weak parent] in parent?.action("like",["id":post.id,"enabled":!liked]) },Design.label("\(post.strings("likes").count)",size:12,color:.white),Design.icon("bubble.right",size:27,color:.white) { [weak parent] in parent?.sheet(CommentsController(postID:post.id)) },Design.icon("send",size:27,color:.white) { [weak parent] in parent?.sheet(PeopleController(mode:.share(post.id))) },Design.icon(post.flag("saved") ? "save.fill":"save",size:26,color:.white) { [weak parent] in parent?.action("save",["id":post.id,"enabled":!post.flag("saved")]) }]);controls.alignment = .center
        overlay.addSubview(controls);controls.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([footer.leadingAnchor.constraint(equalTo:overlay.leadingAnchor,constant:18),footer.trailingAnchor.constraint(equalTo:controls.leadingAnchor,constant:-8),footer.bottomAnchor.constraint(equalTo:overlay.bottomAnchor,constant:-110),controls.trailingAnchor.constraint(equalTo:overlay.trailingAnchor,constant:-8),controls.bottomAnchor.constraint(equalTo:overlay.bottomAnchor,constant:-125)])
        overlay.onTap { [weak self] in guard let player=self?.player else { return };if player.timeControlStatus == .playing { player.pause() } else { player.play() } }
    }
    deinit { if let loop=loop { NotificationCenter.default.removeObserver(loop) } }
}
@MainActor final class ReelsController: Screen, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private var items:[Entity]=[]
    private var collection:UICollectionView!
    override func viewDidLoad() {
        super.viewDidLoad();title="Reel";let layout=UICollectionViewFlowLayout();layout.scrollDirection = .vertical;layout.minimumLineSpacing=0
        collection=UICollectionView(frame:.zero,collectionViewLayout:layout);collection.backgroundColor = .black;collection.isPagingEnabled=true;collection.showsVerticalScrollIndicator=false;collection.dataSource=self;collection.delegate=self;collection.register(ReelCell.self,forCellWithReuseIdentifier:ReelCell.reuse);view.addSubview(collection);collection.pin(to:view);stateChanged()
    }
    override func viewWillAppear(_ animated:Bool) { super.viewWillAppear(animated);navigationController?.setNavigationBarHidden(true,animated:animated);playVisible() }
    override func viewWillDisappear(_ animated:Bool) { super.viewWillDisappear(animated);for cell in collection.visibleCells.compactMap({$0 as? ReelCell}) { cell.player?.pause() };navigationController?.setNavigationBarHidden(false,animated:animated) }
    override func stateChanged() { let next=session.posts.filter { $0.text("kind")=="reel" && !$0.flag("archived") };if String(describing:next.map(\.values)) != String(describing:items.map(\.values)) { items=next;collection.reloadData() };collection.backgroundView=items.isEmpty ? Design.label("I reel appariranno qui",size:18,color:Design.muted):nil }
    func collectionView(_ collectionView:UICollectionView,numberOfItemsInSection section:Int)->Int { items.count }
    func collectionView(_ collectionView:UICollectionView,cellForItemAt indexPath:IndexPath)->UICollectionViewCell { let cell=collectionView.dequeueReusableCell(withReuseIdentifier:ReelCell.reuse,for:indexPath) as! ReelCell;cell.configure(post:items[indexPath.item],parent:self);return cell }
    func collectionView(_ collectionView:UICollectionView,layout collectionViewLayout:UICollectionViewLayout,sizeForItemAt indexPath:IndexPath)->CGSize { collectionView.bounds.size }
    func collectionView(_ collectionView:UICollectionView,willDisplay cell:UICollectionViewCell,forItemAt indexPath:IndexPath) { if view.window != nil { (cell as? ReelCell)?.player?.play() } }
    func collectionView(_ collectionView:UICollectionView,didEndDisplaying cell:UICollectionViewCell,forItemAt indexPath:IndexPath) { (cell as? ReelCell)?.player?.pause() }
    func scrollViewDidEndDecelerating(_ scrollView:UIScrollView) { playVisible() }
    private func playVisible() { for cell in collection?.visibleCells.compactMap({$0 as? ReelCell}) ?? [] { cell.player?.play() } }
}
