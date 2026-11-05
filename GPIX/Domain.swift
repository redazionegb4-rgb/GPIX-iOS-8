import Foundation

/// Immutable boundary for the existing GPIX JSON protocol.
struct Entity: Identifiable {
    let values: [String: Any]
    init(_ values: [String: Any] = [:]) { self.values = values }
    var id: String { text("id") }
    func text(_ key: String, _ fallback: String = "") -> String { values[key] as? String ?? fallback }
    func number(_ key: String, _ fallback: Double = 0) -> Double { (values[key] as? NSNumber)?.doubleValue ?? fallback }
    func flag(_ key: String) -> Bool { (values[key] as? NSNumber)?.boolValue ?? false }
    func enabled(_ key: String) -> Bool { values[key] == nil || flag(key) }
    func strings(_ key: String) -> [String] { values[key] as? [String] ?? [] }
    func object(_ key: String) -> Entity { Entity(values[key] as? [String: Any] ?? [:]) }
    func list(_ key: String) -> [Entity] { (values[key] as? [[String: Any]] ?? []).map(Entity.init) }
    func updating(_ patch: [String: Any]) -> Entity { Entity(values.merging(patch) { _, new in new }) }
    var media: [String] {
        if let list = values["mediaItems"] as? [Any], !list.isEmpty {
            return list.compactMap { item in
                if let s = item as? String { return s.isEmpty ? nil : s }
                if let d = item as? [String: Any] { return d["url"] as? String ?? d["id"] as? String }
                return nil
            }
        }
        let reference = text("media")
        return reference.isEmpty ? [] : [reference]
    }
}

enum GPIXFailure: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): return text } }
}

enum Domain {
    static var server:URL { URL(string:UserDefaults.standard.string(forKey:"gpix.server") ?? "https://gpix.cc") ?? URL(string:"https://gpix.cc")! }
    static func mediaURL(_ reference: String) -> URL? {
        guard !reference.isEmpty else { return nil }
        if let url = URL(string: reference), let scheme = url.scheme { return ["https", "file"].contains(scheme) ? url : nil }
        if reference.hasPrefix("/") { return URL(string: reference, relativeTo: server)?.absoluteURL }
        return server.appendingPathComponent("media").appendingPathComponent(reference)
    }
    static func ago(_ timestamp: Double, now: Double = Date().timeIntervalSince1970) -> String {
        guard timestamp > 0 else { return "" }
        let age = max(0, now - timestamp)
        if age < 60 { return "Ora" }
        if age < 3600 { return "\(Int(age / 60)) min" }
        if age < 86400 { return "\(Int(age / 3600)) h" }
        return "\(Int(age / 86400)) g"
    }
    static func clock(_ timestamp: Double) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "it_IT"); f.timeStyle = .short; return f.string(from: Date(timeIntervalSince1970: timestamp)) }
    static func isRequest(_ thread: Entity, me: String, following: [String], restricted: [String]) -> Bool {
        let other = thread.strings("members").first { $0 != me } ?? ""
        if thread.text("requestDecision") == "restricted" || restricted.contains(other) { return true }
        if !thread.text("owner").isEmpty || thread.text("requestDecision") == "accepted" { return false }
        let messages = thread.list("messages")
        return !messages.isEmpty && messages.first?.text("author") != me && !messages.contains { $0.text("author") == me } && !following.contains(other)
    }
    static func counts(_ person: Entity, posts: [Entity]) -> [Int] {
        let own = posts.filter { $0.text("author") == person.id && $0.text("kind") != "story" && !$0.flag("archived") }.count
        return [Int(person.number("postCount", Double(own))), Int(person.number("followers", Double(person.strings("followersList").count))), Int(person.number("following", Double(person.strings("followingList").count)))]
    }
    static func notificationText(_ n: Entity) -> String {
        switch n.text("type") {
        case "messageReaction": return "Ha reagito a un tuo messaggio"
        case "storyLike": return "Ha messo mi piace alla tua storia"
        case "like": return n.text("postKind") == "story" ? "Ha messo mi piace alla tua storia" : "Ha messo mi piace al tuo post"
        case "comment": return "Ha commentato il tuo post"
        case "follow": return "Ha iniziato a seguirti"
        case "followRequest": return "Vuole seguirti"
        case "followAccepted": return "Ha accettato la tua richiesta"
        case "noteLike": return "Ha messo mi piace alla tua nota"
        default: return n.text("text", "Nuova attività")
        }
    }
    static func socialURL(type: String, value: String) -> URL? {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if type == "website" { return URL(string: v.hasPrefix("https://") ? v : "https://" + v) }
        if type == "whatsapp" { let digits = v.filter(\.isNumber); return digits.isEmpty ? nil : URL(string: "https://wa.me/" + digits) }
        if v.hasPrefix("https://") { return URL(string: v) }
        let bases = ["instagram":"https://www.instagram.com/", "facebook":"https://www.facebook.com/", "threads":"https://www.threads.net/@", "tiktok":"https://www.tiktok.com/@", "telegram":"https://t.me/", "youtube":"https://www.youtube.com/@", "x":"https://x.com/", "linkedin":"https://www.linkedin.com/in/", "snapchat":"https://www.snapchat.com/add/"]
        guard let base = bases[type] else { return nil }
        return URL(string: base + v.trimmingCharacters(in: CharacterSet(charactersIn: "@/")).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)
    }
}
