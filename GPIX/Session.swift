import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@MainActor final class Session {
    static let shared = Session()
    static let changed = Notification.Name("GPIX.StateChanged")
    var state = Entity()
    var token = Credentials.load()
    var isDemo = false
    var active = true
    private var generation = 0
    private var synchronizing = false
    private var mutationInProgress = false
    private var timer: Timer?
    var me: Entity { state.object("me") }
    var userID: String { me.id }
    var signedIn: Bool { !userID.isEmpty && (isDemo || !token.isEmpty) }
    var users: [Entity] { state.list("users") }
    var posts: [Entity] { state.list("posts") }
    var preferences: Entity { state.object("preferences") }
    var threads: [Entity] {
        state.list("threads").filter { !($0.strings("members").contains { state.strings("blocks").contains($0) }) }.sorted { latest($0) > latest($1) }
    }
    func person(_ id: String) -> Entity { id == userID ? me : users.first { $0.id == id } ?? Entity(["id": id, "name":"Account non disponibile", "username":"utente"]) }
    func post(_ id: String) -> Entity { posts.first { $0.id == id } ?? Entity() }
    func thread(_ id: String) -> Entity { threads.first { $0.id == id } ?? Entity() }
    func other(_ t: Entity) -> Entity { person(t.strings("members").first { $0 != userID } ?? userID) }
    func threadName(_ t: Entity) -> String { t.text("title").isEmpty ? other(t).text("name") : t.text("title") }
    func following(_ id: String) -> Bool { state.strings("following").contains(id) }
    func pending(_ id: String) -> Bool { state.strings("pending").contains(id) }
    func online(_ id: String) -> Bool { preferences.enabled("activityStatus") && person(id).flag("online") && person(id).number("onlineUntil", Date().timeIntervalSince1970 + 1) > Date().timeIntervalSince1970 }
    func stories(_ id: String) -> [Entity] { posts.filter { $0.text("author") == id && $0.text("kind") == "story" && !$0.flag("archived") && $0.number("expires") > Date().timeIntervalSince1970 } }
    func isRequest(_ t: Entity) -> Bool { Domain.isRequest(t, me: userID, following: state.strings("following"), restricted: preferences.strings("restricted")) }
    func reactions(_ t: Entity) -> [Entity] {
        let ids = Set(t.list("messages").map(\.id))
        return state.list("notifications").filter { $0.text("type") == "messageReaction" && ids.contains($0.text("ref",$0.text("target"))) }.sorted { $0.number("created") > $1.number("created") }
    }
    func latest(_ t: Entity) -> Double { max(t.list("messages").last?.number("created") ?? 0, reactions(t).first?.number("created") ?? 0) }
    func changed() { NotificationCenter.default.post(name: Self.changed, object: nil) }
    func requestData(_ path: String, payload: [String: Any]? = nil) async throws -> Data {
        guard let url = URL(string: path, relativeTo: Domain.server)?.absoluteURL, url.host == Domain.server.host else { throw GPIXFailure.message("Indirizzo non valido") }
        var request = URLRequest(url: url); request.timeoutInterval = 35; request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue(active ? "1" : "0", forHTTPHeaderField: "X-GPIX-Active")
        request.setValue("GPIX iOS Native", forHTTPHeaderField: "X-GPIX-Device")
        if let payload = payload { request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONSerialization.data(withJSONObject: payload) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GPIXFailure.message("Il server non ha risposto") }
        guard (200..<300).contains(http.statusCode) else {
            let body = Entity((try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:])
            if http.statusCode == 401 && signedIn { token = ""; Credentials.save(""); state = Entity(); changed() }
            throw GPIXFailure.message(body.text("detail", body.text("message", "Operazione non riuscita (\(http.statusCode))")))
        }
        return data
    }
    func api(_ path: String, _ payload: [String: Any]? = nil) async throws -> Entity {
        Entity((try JSONSerialization.jsonObject(with: await requestData(path, payload: payload))) as? [String: Any] ?? [:])
    }
    func signIn(mode: String, values: [String: Any]) async throws {
        let response = try await api("/auth/" + mode, values.merging(["device":"iPhone", "platform":"ios"]) { a, _ in a })
        guard !response.text("token").isEmpty else { throw GPIXFailure.message("Accesso non riuscito") }
        token = response.text("token"); Credentials.save(token); isDemo = false; state = response.object("state"); changed()
    }
    func sync() async throws {
        guard !isDemo, !token.isEmpty, !synchronizing, !mutationInProgress else { return }
        synchronizing = true; let revision = generation
        defer { synchronizing = false }
        let response = try await api("/state")
        if revision == generation && !mutationInProgress && !response.object("state").id.isEmpty { state = response.object("state") }
        else if revision == generation && !mutationInProgress && response.object("state").values["me"] != nil { state = response.object("state") }
        changed()
    }
    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in Task { @MainActor in if Session.shared.active { try? await Session.shared.sync() } } }
    }
    func presence(_ foreground: Bool) async {
        active = foreground
        if signedIn && !isDemo { _ = try? await api("/presence", ["active": foreground]); if foreground { try? await sync() } }
    }
    func action(_ name: String, _ payload: [String: Any] = [:]) async throws {
        while mutationInProgress { try await Task.sleep(nanoseconds: 30_000_000) }
        try Task.checkCancellation(); mutationInProgress = true; generation += 1
        defer { mutationInProgress = false }
        if isDemo { try demoAction(name, payload); changed(); return }
        let result = try await api("/actions", ["action":name, "payload":payload])
        if result.flag("deleted") { token = ""; Credentials.save(""); state = Entity() }
        else if result.object("state").values["me"] != nil { state = result.object("state") }
        changed()
    }
    func upload(_ data: Data, mime: String) async throws -> Entity {
        guard data.count <= 25 * 1024 * 1024 else { throw GPIXFailure.message("Il file supera 25 MB") }
        if isDemo {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(UUID().uuidString + (mime.contains("video") ? ".mp4" : mime.contains("audio") ? ".m4a" : ".jpg"))
            try data.write(to: url); return Entity(["id":url.absoluteString,"url":url.absoluteString])
        }
        return try await api("/media", ["mime":mime,"data":data.base64EncodedString()])
    }
    func startThread(_ id: String) async throws -> String {
        try await action("thread", ["user":id])
        guard let found = threads.first(where: { $0.strings("members").count == 2 && $0.strings("members").contains(id) }) else { throw GPIXFailure.message("Chat non disponibile") }
        return found.id
    }
    func logout() async { if !isDemo { _ = try? await api("/auth/logout", [:]) }; state = Entity(); token = ""; isDemo = false; Credentials.save(""); changed() }
    var history: [String] { UserDefaults.standard.stringArray(forKey: "gpix.search.\(isDemo ? "demo" : userID)") ?? [] }
    func remember(_ value: String) {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines); guard !value.isEmpty else { return }
        UserDefaults.standard.set(Array(([value] + history.filter { $0.caseInsensitiveCompare(value) != .orderedSame }).prefix(20)), forKey: "gpix.search.\(isDemo ? "demo" : userID)"); changed()
    }
    func clearHistory() { UserDefaults.standard.removeObject(forKey: "gpix.search.\(isDemo ? "demo" : userID)"); changed() }
}
