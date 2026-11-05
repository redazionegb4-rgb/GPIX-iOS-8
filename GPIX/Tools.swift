import UIKit

@MainActor final class PrivacyPeopleController: StackScreen {
    let key:String
    init(key:String,title:String) { self.key=key;super.init(nibName:nil,bundle:nil);self.title=title }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad();stateChanged() }
    override func stateChanged() {
        clear();let selected=session.preferences.strings(key)
        if key=="restricted" { add(Design.label("Le conversazioni degli account con restrizioni vengono spostate nelle richieste.",size:13,color:Design.muted,lines:0),inset:20) }
        for user in session.users.filter({$0.id != session.userID}) { row(user.text("name"),subtitle:user.text("username"),icon:selected.contains(user.id) ? "checkmark.circle.fill":"circle",accessory:Avatar(user,size:38)) { [weak self] in guard let self=self else { return };let next=selected.contains(user.id) ? selected.filter{$0 != user.id}:selected+[user.id];self.action("preferences",["key":self.key,"value":next]) } }
    }
}
@MainActor final class GridOrderController: Screen, UITableViewDataSource, UITableViewDelegate {
    private let table=UITableView(frame:.zero,style:.plain)
    private var ids:[String]=[]
    override func viewDidLoad() {
        super.viewDidLoad();title="Riordina griglia";let posts=session.posts.filter{$0.text("author")==session.userID && $0.text("kind") != "story" && !$0.flag("archived")}.map(\.id);let saved=session.me.strings("gridOrder").filter{posts.contains($0)};ids=saved+posts.filter{!saved.contains($0)}
        table.dataSource=self;table.delegate=self;table.backgroundColor=Design.background;table.rowHeight=68;table.setEditing(true,animated:false);view.addSubview(table);table.pin(to:view);navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Salva",style:.done,target:self,action:#selector(save))
    }
    func tableView(_ tableView:UITableView,numberOfRowsInSection section:Int)->Int { ids.count }
    func tableView(_ tableView:UITableView,cellForRowAt indexPath:IndexPath)->UITableViewCell { let cell=UITableViewCell(style:.subtitle,reuseIdentifier:nil);let post=session.post(ids[indexPath.row]);cell.backgroundColor=Design.background;cell.textLabel?.text=post.text("text").isEmpty ? "Post":post.text("text");cell.textLabel?.font=Design.font(14);cell.textLabel?.textColor=Design.ink;cell.detailTextLabel?.text=Date(timeIntervalSince1970:post.number("created")).formatted(date:.abbreviated,time:.omitted);cell.showsReorderControl=true;return cell }
    func tableView(_ tableView:UITableView,canMoveRowAt indexPath:IndexPath)->Bool { true }
    func tableView(_ tableView:UITableView,moveRowAt sourceIndexPath:IndexPath,to destinationIndexPath:IndexPath) { let id=ids.remove(at:sourceIndexPath.row);ids.insert(id,at:destinationIndexPath.row) }
    func tableView(_ tableView:UITableView,editingStyleForRowAt indexPath:IndexPath)->UITableViewCell.EditingStyle { .none }
    func tableView(_ tableView:UITableView,shouldIndentWhileEditingRowAt indexPath:IndexPath)->Bool { false }
    @objc private func save() { run { try await self.session.action("gridOrder",["ids":self.ids]);self.navigationController?.popViewController(animated:true) } }
}
@MainActor final class GiphyController: StackScreen {
    var onSelect:((String)->Void)?
    private let search=Design.field("Cerca una GIF")
    private var debounce:Task<Void,Never>?,generation=0,offset=0,more=false,items:[Entity]=[]
    override func viewDidLoad() { super.viewDidLoad();title="GIF";attachHeader(Design.inset(search,UIEdgeInsets(top:8,left:18,bottom:8,right:18)));search.addAction(UIAction { [weak self] _ in self?.debounce?.cancel();self?.debounce=Task { [weak self] in try? await Task.sleep(nanoseconds:350_000_000);guard !Task.isCancelled,let self=self else { return };self.run { try await self.load(next:false) } } },for:.editingChanged);run { try await self.load(next:false) } }
    private func load(next:Bool) async throws {
        generation+=1;let sequence=generation
        if session.isDemo { items=(0..<6).map{Entity(["url":"gif\($0).gif"])};more=false;render();return }
        if !next { offset=0 };var c=URLComponents();c.queryItems=[URLQueryItem(name:"q",value:search.text ?? ""),URLQueryItem(name:"offset",value:String(offset))]
        let response=try await session.api("/giphy"+(c.string ?? ""));guard sequence==generation else { return };let rows=response.list("data").map{$0.object("images").object("fixed_height").updating(["original":$0.object("images").object("original").text("url")])};items=next ? items+rows:rows;offset+=rows.count;more=rows.count>=24;render()
    }
    private func render() {
        clear();for start in stride(from:0,to:items.count,by:2) { let row=Design.stack(.horizontal,spacing:8);row.distribution = .fillEqually;for i in start..<min(start+2,items.count) { let item=items[i];let photo=PhotoView(item.text("url"));photo.heightAnchor.constraint(equalTo:photo.widthAnchor,multiplier:0.8).isActive=true;photo.layer.cornerRadius=14;photo.onTap { [weak self] in guard let self=self else { return };let callback=self.onSelect;self.dismiss(animated:true) { callback?(item.text("original",item.text("url"))) } };row.addArrangedSubview(photo) };add(row,inset:12) };if more { add(Design.button("Mostra altre") { [weak self] in self?.run { try await self?.load(next:true) } },inset:18) }
    }
}
