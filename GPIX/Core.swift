import SwiftUI
import Security
import UIKit
typealias Row = [String: Any]
extension Dictionary where Key == String, Value == Any {
    var id: String {
        s("id")
    }
    func s(_ key: String, _ fallback: String = "") -> String {
        self[key] as? String ?? fallback
    }
    func n(_ key: String, _ fallback: Double = 0) -> Double {
        (self[key] as? NSNumber)?.doubleValue ?? fallback
    }
    func b(_ key: String) -> Bool {
        (self[key] as? NSNumber)?.boolValue ?? false
    }
    func row(_ key: String) -> Row {
        self[key] as? Row ?? [:]
    }
    func rows(_ key: String) -> [Row] {
        self[key] as? [Row] ?? []
    }
    func ids(_ key: String) -> [String] {
        self[key] as? [String] ?? []
    }
}
let gpixPurple = Color(red: 0.30, green: 0.32, blue: 1)
let gpixGradient = LinearGradient(colors: [.yellow, .orange, .pink, .purple], startPoint: .bottomLeading, endPoint: .topTrailing)
func ago(_ value: Double) -> String {
    let seconds = max(0, Date().timeIntervalSince1970 - value)
    if seconds < 60 {
        return "Ora"
    }
    if seconds < 3600 {
        return "\(Int(seconds/60)) min"
    }
    if seconds < 86400 {
        return "\(Int(seconds/3600)) h"
    }
    return "\(Int(seconds/86400)) g"
}
func clock(_ value: Double) -> String {
    Date(timeIntervalSince1970:value).formatted(date:.omitted,time:.shortened)
}
struct GError: LocalizedError {
    let message: String
    var errorDescription: String? {
        message
    }
}
enum Vault {
    static let service = "app.gpix.gpix.native"
    static func token() -> String {
        let query: Row = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"token",kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var value: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary,&value) == errSecSuccess,let data=value as? Data else {
            return ""
        }
        return String(data:data,encoding:.utf8) ?? ""
    }
    static func save(_ token: String) {
        let query: Row = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"token"]
        SecItemDelete(query as CFDictionary)
        guard !token.isEmpty else {
            return
        }
        var next=query
        next[kSecValueData as String]=Data(token.utf8)
        next[kSecAttrAccessible as String]=kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(next as CFDictionary,nil)
    }
}
@MainActor final class GpixStore: ObservableObject {
    @Published var state: Row = [:]
    @Published var ready = false
    @Published var demo = false
    @Published var error = ""
    @Published var busy = false
    @Published var tab = 0
    @Published var appearance = UserDefaults.standard.string(forKey:"gpix.native.appearance") ?? "system"
    @Published var foreground = true
    let server = "https://gpix.cc"
    var token = Vault.token()
    private var polling = false
    private var syncing = false
    private var actionInProgress = false
    private var stateGeneration = 0
    var me: Row {
        state.row("me")
    }
    var myID: String {
        me.id
    }
    var users: [Row] {
        state.rows("users")
    }
    var posts: [Row] {
        state.rows("posts")
    }
    var threads: [Row] {
        state.rows("threads").sorted {
            ($0.rows("messages").last?.n("created") ?? 0) > ($1.rows("messages").last?.n("created") ?? 0)
        }
    }
    var preferences: Row {
        state.row("preferences")
    }
    var signedIn: Bool {
        !myID.isEmpty && (demo || !token.isEmpty)
    }
    var colorScheme: ColorScheme? {
        appearance == "dark" ? .dark : appearance == "light" ? .light : nil
    }
    func person(_ id: String) -> Row {
        users.first{
            $0.id==id
        }
        ?? ["id":id,"name":"GPIX","username":"gpix"]
    }
    func post(_ id: String) -> Row {
        posts.first{
            $0.id==id
        }
        ?? [:]
    }
    func thread(_ id: String) -> Row {
        threads.first{
            $0.id==id
        }
        ?? [:]
    }
    func peer(_ thread: Row) -> Row {
        person(thread.ids("members").first{
            $0 != myID
        }
        ?? myID)
    }
    func threadTitle(_ t: Row) -> String {
        t.s("title").isEmpty ? peer(t).s("name") : t.s("title")
    }
    func following(_ id: String) -> Bool {
        state.ids("following").contains(id)
    }
    func pending(_ id: String) -> Bool {
        state.ids("pending").contains(id)
    }
    func visibleStories(_ id: String) -> [Row] {
        posts.filter{
            $0.s("author")==id && $0.s("kind")=="story" && $0.n("expires") > Date().timeIntervalSince1970 && !$0.b("archived")
        }
    }
    func unseenStories(_ id: String) -> Bool {
        visibleStories(id).contains{
            !$0.b("seenByMe") && !$0.ids("viewers").contains(myID)
        }
    }
    func online(_ id: String) -> Bool {
        preferences["activityStatus"] as? Bool != false && person(id).b("online") && person(id).n("onlineUntil",Date().timeIntervalSince1970+1)>Date().timeIntervalSince1970
    }
    func unread(_ t: Row) -> Int {
        t.rows("messages").filter{
            $0.s("author") != myID && !$0.ids("readBy").contains(myID)
        }
        .count
    }
    func request(_ t: Row) -> Bool {
        !["accepted"].contains(t.s("requestDecision")) && !following(peer(t).id) && !t.rows("messages").contains{
            $0.s("author")==myID
        }
    }
    func requestHidden(_ t: Row) -> Bool {
        ["hidden","restricted"].contains(t.s("requestDecision"))
    }
    func endpoint(_ path: String) throws -> URL {
        guard let u=URL(string:path.hasPrefix("https://") ? path : server+path) else {
            throw GError(message:"Indirizzo non valido")
        }
        return u
    }
    func bytes(_ path: String, payload: Row? = nil) async throws -> Data {
        var req=URLRequest(url:try endpoint(path))
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization")
        req.setValue(foreground ? "1" : "0",forHTTPHeaderField:"X-GPIX-Active")
        req.setValue("GPIX iPhone Swift",forHTTPHeaderField:"X-GPIX-Device")
        if let payload=payload {
            req.httpMethod="POST"
            req.setValue("application/json",forHTTPHeaderField:"Content-Type")
            req.httpBody=try JSONSerialization.data(withJSONObject:payload)
        }
        let (data,response)=try await URLSession.shared.data(for:req)
        guard let http=response as? HTTPURLResponse else {
            throw GError(message:"Risposta non valida")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body=(try? JSONSerialization.jsonObject(with:data)) as? Row ?? [:]
            throw GError(message:body.s("detail",body.s("message","Errore \(http.statusCode)")))
        }
        return data
    }
    func api(_ path: String, _ payload: Row? = nil) async throws -> Row {
        let data=try await bytes(path,payload:payload)
        return (try JSONSerialization.jsonObject(with:data)) as? Row ?? [:]
    }
    func boot() async {
        if !token.isEmpty {
            await sync()
        }
        ready=true
        await poll()
    }
    func sync() async {
        guard !demo,!token.isEmpty,!syncing,!actionInProgress else{
            return
        }
        syncing=true
        let generation=stateGeneration
        defer{
            syncing=false
        }
        do {
            let result=try await api("/state")
            if !result.row("state").isEmpty && generation==stateGeneration && !actionInProgress {
                state=result.row("state")
            }
        }
        catch {
            if !signedIn {
                self.error=error.localizedDescription
            }
        }
    }
    func poll() async {
        guard !polling else{
            return
        }
        polling=true
        defer{
            polling=false
        }
        while !Task.isCancelled {
            if foreground {
                await sync()
            }
            try? await Task.sleep(nanoseconds:4_000_000_000)
        }
    }
    func activity(_ active: Bool) async {
        foreground=active
        guard signedIn,!demo else{
            return
        }
        _ = try? await api("/presence",["active":active])
        if active {
            await sync()
        }
    }
    func login(_ action: String, _ payload: Row) async throws {
        let result=try await api("/auth/"+action,payload.merging(["device":"iPhone · Swift","platform":"ios"]){
            a,_ in a
        }
        )
        guard !result.s("token").isEmpty else {
            throw GError(message:"Accesso non riuscito")
        }
        token=result.s("token")
        Vault.save(token)
        demo=false
        state=result.row("state")
    }
    func logout() async {
        if !demo {
            _ = try? await api("/auth/logout",[:])
        }
        Vault.save("")
        token=""
        state=[:]
        demo=false
    }
    func act(_ action: String,_ payload: Row = [:]) async throws {
        while actionInProgress {
            try await Task.sleep(nanoseconds:50_000_000)
        }
        try Task.checkCancellation()
        actionInProgress=true
        stateGeneration+=1
        defer{
            actionInProgress=false
        }
        if demo {
            try demoAction(action,payload)
            return
        }
        let result=try await api("/actions",["action":action,"payload":payload])
        if result.b("deleted") {
            Vault.save("")
            token=""
            state=[:]
        }
        else if !result.row("state").isEmpty {
            state=result.row("state")
        }
    }
    func perform(_ action: String,_ payload: Row = [:]) {
        Task{
            do {
                try await act(action,payload)
            }
            catch{
                self.error=error.localizedDescription
            }
        }
    }
    func upload(_ data: Data,mime: String) async throws -> Row {
        guard data.count<=25*1024*1024 else{
            throw GError(message:"File oltre 25 MB")
        }
        if demo {
            let id=UUID().uuidString
            let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
            let url=folder.appendingPathComponent(id+(mime.hasPrefix("video") ? ".mp4" : mime.hasPrefix("audio") ? ".m4a" : ".jpg"))
            try data.write(to:url)
            return ["id":url.absoluteString,"url":url.absoluteString]
        }
        return try await api("/media",["mime":mime,"data":data.base64EncodedString()])
    }
    func startThread(_ id: String) async throws -> String {
        try await act("thread",["user":id])
        guard let t=threads.first(where:{
            $0.ids("members").count==2 && $0.ids("members").contains(id)
        }
        ) else{
            throw GError(message:"Chat non disponibile")
        }
        return t.id
    }
    func preference(_ key: String,_ value: Any) {
        perform("preferences",["key":key,"value":value])
    }
    func history() -> [String] {
        UserDefaults.standard.stringArray(forKey:"gpix.native.search.\(demo ? "demo" : myID)") ?? []
    }
    func remember(_ text: String) {
        let value=text.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !value.isEmpty else{
            return
        }
        let list=([value]+history().filter{
            $0.localizedCaseInsensitiveCompare(value) != .orderedSame
        }
        ).prefix(20)
        UserDefaults.standard.set(Array(list),forKey:"gpix.native.search.\(demo ? "demo" : myID)")
        objectWillChange.send()
    }
    func clearHistory() {
        UserDefaults.standard.removeObject(forKey:"gpix.native.search.\(demo ? "demo" : myID)")
        objectWillChange.send()
    }
}
