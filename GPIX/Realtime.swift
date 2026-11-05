import UIKit
import WebKit

/// WebRTC uses WebKit's system media engine; the surrounding interface is UIKit.
@MainActor final class CallController: Screen, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    let callID:String,mode:String
    private var web:WKWebView!
    private let status=Design.label("Connessione…",size:15,color:Design.muted)
    init(callID:String,mode:String="call") { self.callID=callID;self.mode=mode;super.init(nibName:nil,bundle:nil) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad();title=mode=="call" ? "Chiamata GPIX":"Diretta GPIX";isModalInPresentation=true;navigationItem.leftBarButtonItem=nil
        navigationItem.rightBarButtonItem=UIBarButtonItem(title:"Termina",style:.done,target:self,action:#selector(end))
        let config=WKWebViewConfiguration();config.allowsInlineMediaPlayback=true;config.mediaTypesRequiringUserActionForPlayback=[];config.websiteDataStore = .nonPersistent();config.userContentController.add(self,name:"gpix")
        web=WKWebView(frame:.zero,configuration:config);web.navigationDelegate=self;web.uiDelegate=self;web.isOpaque=false;web.backgroundColor = .black
        view.addSubview(web);web.translatesAutoresizingMaskIntoConstraints=false
        let mic=Design.button("Microfono",icon:"mic") { [weak self] in self?.evaluate("toggleAudio()") };let camera=Design.button("Video",icon:"video") { [weak self] in self?.evaluate("toggleVideo()") }
        let controls=Design.stack(.horizontal,spacing:12,views:[mic,camera]);controls.distribution = .fillEqually
        let bottom=Design.stack(spacing:12,views:[status,controls,Design.button("Termina",primary:true,icon:"phone.down") { [weak self] in self?.end() }]);status.textAlignment = .center
        view.addSubview(bottom);bottom.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([web.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),web.leadingAnchor.constraint(equalTo:view.leadingAnchor),web.trailingAnchor.constraint(equalTo:view.trailingAnchor),web.bottomAnchor.constraint(equalTo:bottom.topAnchor,constant:-15),bottom.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:24),bottom.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-24),bottom.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-16)])
        if mode=="live" { let row=Design.button("Commenta",icon:"bubble.right") { [weak self] in self?.prompt("Commento alla diretta") { self?.action("liveComment",["id":self?.callID ?? "","text":$0]) } };bottom.addArrangedSubview(row) }
        guard let url=Bundle.main.url(forResource:"Realtime",withExtension:"html") else { return };web.loadFileURL(url,allowingReadAccessTo:url.deletingLastPathComponent())
    }
    override func viewWillDisappear(_ animated:Bool) { super.viewWillDisappear(animated);evaluate("stop()") }
    override func viewDidDisappear(_ animated:Bool) { super.viewDidDisappear(animated);web.configuration.userContentController.removeScriptMessageHandler(forName:"gpix");web.stopLoading() }
    func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!) {
        run {
            if self.session.isDemo { self.status.text="Le chiamate richiedono due account reali.";return }
            if self.mode=="call" { let call=self.session.state.list("calls").first { $0.id==self.callID } ?? Entity();if call.text("callee")==self.session.userID && call.text("status")=="ringing" { try await self.session.action("callAccept",["id":self.callID]) } }
            let data=try JSONSerialization.data(withJSONObject:["id":self.callID,"mode":self.mode,"me":self.session.userID]);self.evaluate("start("+(String(data:data,encoding:.utf8) ?? "{}")+")")
        }
    }
    func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage) {
        guard message.name=="gpix",let body=message.body as? [String:Any] else { return };let value=Entity(body)
        if value.text("event")=="status" { status.text=value.text("text");return }
        guard let number=body["requestID"] as? Int else { return }
        let path=value.text("path")
        let allowed=path=="/rtc/config" || path.hasPrefix("/rtc/call/\(callID)?") || path.hasPrefix("/live/room/\(callID)?") || path=="/actions"
        guard allowed else { reply(number,error:"Richiesta non consentita");return }
        Task { @MainActor [weak self] in guard let self=self else { return };do {
            let payload=body["payload"] as? [String:Any]
            if path=="/actions",let payload=payload { let p=Entity(payload);let allowedActions=["callSignal","callHeartbeat","callConnected","liveSignal","liveHeartbeat"];guard allowedActions.contains(p.text("action")),p.object("payload").id==self.callID else { self.reply(number,error:"Azione non consentita");return } }
            let r=try await self.session.api(path,payload);self.reply(number,result:r.values)
        } catch { self.reply(number,error:error.localizedDescription) } }
    }
    private func reply(_ id:Int,result:[String:Any]=[:],error:String?=nil) { let object:[String:Any]=["id":id,"result":result,"error":error as Any? ?? NSNull()];guard let data=try? JSONSerialization.data(withJSONObject:object),let text=String(data:data,encoding:.utf8) else { return };evaluate("receive("+text+")") }
    private func evaluate(_ source:String) { Task { @MainActor [weak self] in guard let web=self?.web else { return };_ = try? await web.evaluateJavaScript(source) } }
    func webView(_ webView:WKWebView,requestMediaCapturePermissionFor origin:WKSecurityOrigin,initiatedByFrame frame:WKFrameInfo,type:WKMediaCaptureType,decisionHandler:@escaping(WKPermissionDecision)->Void) { decisionHandler(frame.isMainFrame ? .grant:.deny) }
    func webView(_ webView:WKWebView,decidePolicyFor navigationAction:WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void) { decisionHandler(navigationAction.request.url?.isFileURL == true || navigationAction.request.url?.absoluteString=="about:blank" ? .allow:.cancel) }
    @objc private func end() { evaluate("stop()");run { if !self.session.isDemo { let name=self.mode=="call" ? "callEnd":self.session.state.list("lives").first{$0.id==self.callID}?.text("host")==self.session.userID ? "liveEnd":"liveLeave";try await self.session.action(name,["id":self.callID]) };self.dismiss(animated:true) } }
}
@MainActor final class LiveListController: StackScreen {
    override func viewDidLoad() { super.viewDidLoad();title="Dirette";stateChanged() }
    override func stateChanged() {
        clear();row("Avvia una diretta",subtitle:"Condividi un momento in tempo reale",icon:"dot.radiowaves.left.and.right") { [weak self] in self?.prompt("Titolo della diretta") { text in guard let self=self else { return };self.run { try await self.session.action("liveStart",["title":text]);if let room=self.session.state.list("lives").first(where:{$0.text("host")==self.session.userID}) { self.sheet(CallController(callID:room.id,mode:"live"),full:true) } } } }
        for room in session.state.list("lives") { row(session.person(room.text("host")).text("name"),subtitle:room.text("title")+" · \(Int(room.number("viewers"))) spettatori",icon:"video") { [weak self] in guard let self=self else { return };self.run { try await self.session.action("liveJoin",["id":room.id]);self.sheet(CallController(callID:room.id,mode:"live"),full:true) } } }
    }
}
