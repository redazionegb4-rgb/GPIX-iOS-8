import SwiftUI
import WebKit
@MainActor
struct CallView:View{
    @EnvironmentObject var store:GpixStore
    @Environment(\.dismiss) var dismiss
    let callID:String
    var body:some View{
        NavigationStack{
            RealtimeWeb(mode:"call",id:callID,store:store).ignoresSafeArea(edges:.bottom).navigationTitle("Chiamata GPIX").navigationBarTitleDisplayMode(.inline).toolbar{
                Button("Termina",role:.destructive){
                    store.perform("callEnd",["id":callID])
                    dismiss()
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
@MainActor
struct LiveListView:View{
    @EnvironmentObject var store:GpixStore
    @State private var title=""
    @State private var room:IdentifiedRow?
    var body:some View{
        List{
            Section("In diretta"){
                ForEach(store.state.rows("lives"),id:\.id){
                    live in Button{
                        Task{
                            do{
                                try await store.act("liveJoin",["id":live.id])
                                room=IdentifiedRow(row:live)
                            }
                            catch{
                                store.error=error.localizedDescription
                            }
                        }
                    } label: {
                        PersonLine(person:store.person(live.s("host")),subtitle:live.s("title")+" · \(Int(live.n("viewers"))) spettatori")
                    }
                }
            }
            Section("La tua diretta"){
                TextField("Titolo",text:$title)
                Button("Avvia diretta"){
                    Task{
                        do{
                            try await store.act("liveStart",["title":title])
                            if let live=store.state.rows("lives").first(where:{
                                $0.s("host")==store.myID
                            }
                            ){
                                room=IdentifiedRow(row:live)
                            }
                        }
                        catch{
                            store.error=error.localizedDescription
                        }
                    }
                }
            }
        }
        .navigationTitle("Dirette").fullScreenCover(item:$room){
            r in LiveRoomView(room:r.row)
        }
    }
}
@MainActor
struct LiveRoomView:View{
    @EnvironmentObject var store:GpixStore
    @Environment(\.dismiss) var dismiss
    let room:Row
    var body:some View{
        NavigationStack{
            RealtimeWeb(mode:"live",id:room.id,store:store).navigationTitle(room.s("title","Diretta")).toolbar{
                Button(room.s("host")==store.myID ? "Termina":"Esci"){
                    store.perform(room.s("host")==store.myID ? "liveEnd":"liveLeave",["id":room.id])
                    dismiss()
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
@MainActor
struct RealtimeWeb:UIViewRepresentable{
    let mode:String,id:String
    @ObservedObject var store:GpixStore
    func makeCoordinator()->Coordinator{
        Coordinator(store:store,mode:mode,id:id)
    }
    func makeUIView(context:Context)->WKWebView{
        let c=WKWebViewConfiguration()
        c.websiteDataStore = .nonPersistent()
        c.allowsInlineMediaPlayback=true
        c.mediaTypesRequiringUserActionForPlayback=[]
        c.userContentController.add(context.coordinator,name:"gpix")
        let view=WKWebView(frame:.zero,configuration:c)
        view.uiDelegate=context.coordinator
        view.navigationDelegate=context.coordinator
        view.isOpaque=false
        view.backgroundColor = .black
        context.coordinator.web=view
        guard let url=Bundle.main.url(forResource:"Realtime",withExtension:"html"),let html=try? String(contentsOf:url)else{
            return view
        }
        view.loadHTMLString(html,baseURL:URL(string:"https://gpix.cc"))
        return view
    }
    func updateUIView(_ view:WKWebView,context:Context){
    }
    static func dismantleUIView(_ view:WKWebView,coordinator:Coordinator){
        view.evaluateJavaScript("stopMedia()",completionHandler:nil)
        view.configuration.userContentController.removeScriptMessageHandler(forName:"gpix")
        coordinator.web=nil
    }
    @MainActor
    class Coordinator: NSObject, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate {
        let store: GpixStore
        let mode: String
        let id: String
        weak var web: WKWebView?
        init(store: GpixStore, mode: String, id: String) {
            self.store = store
            self.mode = mode
            self.id = id
        }
        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task {
                @MainActor [weak self, weak webView] in
                guard let self = self, let webView = webView else {
                    return
                }
                let data: Row = ["mode": self.mode, "id": self.id, "me": self.store.myID]
                guard let bytes = try? JSONSerialization.data(withJSONObject: data),
                let text = String(data: bytes, encoding: .utf8) else {
                    return
                }
                _ = try? await webView.evaluateJavaScript("initialize(\(text))")
            }
        }
        nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? Row,
            let requestID = body["requestID"] as? Int else {
                return
            }
            Task {
                @MainActor [weak self] in
                guard let self = self else {
                    return
                }
                let path = body.s("path")
                guard path == "/rtc/config" || path == "/actions"
                || path.hasPrefix("/rtc/call/\(self.id)?")
                || path.hasPrefix("/live/room/\(self.id)?") else {
                    return
                }
                do {
                    let payload = body["payload"] as? Row
                    if path == "/actions" {
                        guard let payload = payload else {
                            return
                        }
                        let allowed = ["callAccept", "callSignal", "callHeartbeat", "callConnected", "callEnd", "liveSignal", "liveHeartbeat", "liveComment", "liveLike", "liveLeave", "liveEnd"]
                        guard allowed.contains(payload.s("action")), payload.row("payload").id == self.id else {
                            return
                        }
                    }
                    let result = try await self.store.api(path, payload)
                    let bytes = try JSONSerialization.data(withJSONObject: result)
                    let json = String(data: bytes, encoding: .utf8) ?? "{}"
                    _ = try? await self.web?.evaluateJavaScript("nativeResult(\(requestID),\(json),null)")
                }
                catch {
                    let data = (try? JSONSerialization.data(withJSONObject: [error.localizedDescription])) ?? Data("[\"Errore\"]".utf8)
                    let json = String(data: data, encoding: .utf8) ?? "[]"
                    _ = try? await self.web?.evaluateJavaScript("nativeResult(\(requestID),null,\(json)[0])")
                }
            }
        }
        nonisolated func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            Task {
                @MainActor in
                decisionHandler(origin.host == "gpix.cc" ? .prompt : .deny)
            }
        }
        nonisolated func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            Task {
                @MainActor in
                let url = navigationAction.request.url
                decisionHandler(url?.host == "gpix.cc" || url?.scheme == "about" ? .allow : .cancel)
            }
        }
    }
}
