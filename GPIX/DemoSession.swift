import Foundation

@MainActor extension Session {
    func loadDemo() {
        guard let url=Bundle.main.url(forResource:"Demo",withExtension:"json"),let bytes=try? Data(contentsOf:url),let root=(try? JSONSerialization.jsonObject(with:bytes)) as? [String:Any] else { return }
        let now=Date().timeIntervalSince1970;var next=Entity(root)
        let posts=next.list("posts").enumerated().map { index,item in item.updating(["created":now-item.number("age",Double(index)*3600),"expires":item.text("kind")=="story" ? now+80000:0,"comments":item.list("comments").map { $0.updating(["created":now-600]).values }]).values }
        let threads=next.list("threads").map { t in t.updating(["messages":t.list("messages").enumerated().map { index,m in m.updating(["created":now-Double(10-index)*70]).values }]).values }
        let notes=next.list("notes").map { $0.updating(["created":now-120,"expires":now+86280]).values }
        let instants=next.object("demoInstants");let sent=instants.list("sent").map{$0.updating(["created":now-10000,"expires":now+76400]).values};let received=instants.list("received").map{$0.updating(["created":now-900,"expires":now+85500]).values}
        next=next.updating(["posts":posts,"threads":threads,"notes":notes,"demoInstants":instants.updating(["sent":sent,"active":sent,"received":received]).values])
        isDemo=true;state=next;changed()
    }
    func demoAction(_ action:String,_ payload:[String:Any]) throws { state=try DemoReducer.apply(state:state,action:action,payload:payload) }
}
