import UIKit

@MainActor final class NewConversationController: StackScreen {
    override func viewDidLoad() {
        super.viewDidLoad();title="Nuovo messaggio"
        row("Nuovo gruppo",subtitle:"Parla con più persone",icon:"person.3") { [weak self] in self?.push(NewGroupController()) }
        for user in session.users.filter({$0.id != session.userID}) { row(user.text("name"),subtitle:user.text("username"),accessory:Avatar(user,size:46)) { [weak self] in guard let self=self else { return };self.run { let id=try await self.session.startThread(user.id);self.push(ChatController(id:id)) } } }
    }
}
@MainActor final class NewGroupController: StackScreen {
    private var selected:Set<String>=[]
    private let name=Design.field("Nome del gruppo")
    override func viewDidLoad() { super.viewDidLoad();title="Nuovo gruppo";navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Crea",style:.done,target:self,action:#selector(create));render() }
    private func render() {
        clear();add(name,inset:18);section("\(selected.count) partecipanti selezionati")
        for user in session.users.filter({$0.id != session.userID}) { row(user.text("name"),subtitle:user.text("username"),icon:selected.contains(user.id) ? "checkmark.circle.fill":"circle") { [weak self] in guard let self=self else { return };if self.selected.contains(user.id) { self.selected.remove(user.id) } else { self.selected.insert(user.id) };self.render() } }
    }
    @objc private func create() { guard !(name.text ?? "").isEmpty,!selected.isEmpty else { alert("Completa il gruppo","Scegli un nome e almeno un partecipante.");return };run { try await self.session.action("group",["title":self.name.text ?? "","users":Array(self.selected)]);if let group=self.session.threads.first(where:{$0.text("owner")==self.session.userID && $0.text("title")==self.name.text}) { self.push(ChatController(id:group.id)) } } }
}
