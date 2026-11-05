import Foundation

/// Offline simulation is isolated from networking and uses the production JSON shapes.
enum DemoReducer {
    static func apply(state:Entity,action:String,payload:[String:Any],now:Double=Date().timeIntervalSince1970) throws -> Entity {
        var root=state.values;var me=state.object("me").values;var posts=state.list("posts").map(\.values),threads=state.list("threads").map(\.values)
        let p=Entity(payload),uid=state.object("me").id,id=p.id,user=p.text("user")
        func toggle(_ list:[String],_ value:String,_ enabled:Bool) -> [String] { enabled ? Array(Set(list+[value])):list.filter{$0 != value} }
        func notification(_ type:String,target:String,actor:String) { var items=(root["notifications"] as? [[String:Any]]) ?? [];items.insert(["id":UUID().uuidString,"actor":actor,"type":type,"target":target,"created":now,"seen":false],at:0);root["notifications"]=items }
        switch action {
        case "profile":me.merge(payload){_,b in b}
        case "profileLinks":me["links"]=p.list("links").map(\.values)
        case "preferences":var prefs=state.object("preferences").values;prefs[p.text("key")]=payload["value"];root["preferences"]=prefs
        case "follow":
            let enabled=payload["enabled"] as? Bool ?? true;let privateUser=state.list("users").first{$0.id==user}?.flag("private") ?? false
            root["pending"]=toggle(state.strings("pending"),user,enabled && privateUser);root["following"]=toggle(state.strings("following"),user,enabled && !privateUser)
        case "accept":root["requests"]=state.strings("requests").filter{$0 != user};if payload["enabled"] as? Bool != false { me["followersList"]=toggle(Entity(me).strings("followersList"),user,true);me["followers"]=Entity(me).strings("followersList").count }
        case "block","closeFriend":let key=action=="block" ? "blocks":"closeFriends";root[key]=toggle(state.strings(key),user,payload["enabled"] as? Bool ?? true)
        case "gridOrder":me["gridOrder"]=p.strings("ids")
        case "pinPost":me["pinnedPosts"]=toggle(Entity(me).strings("pinnedPosts"),id,payload["enabled"] as? Bool ?? true)
        case "post":var post=payload;post["id"]=UUID().uuidString;post["author"]=uid;post["created"]=now;post["expires"]=p.text("kind")=="story" ? now+86400:0;post["likes"]=[] as [String];post["comments"]=[] as [[String:Any]];posts.insert(post,at:0)
        case "like","save","see","archivePost","editPost","postOptions","deletePost","comment","pollVote":
            guard let index=posts.firstIndex(where:{Entity($0).id==id}) else { throw GPIXFailure.message("Post non disponibile") };var post=posts[index];let item=Entity(post)
            switch action {
            case "like":post["likes"]=toggle(item.strings("likes"),uid,payload["enabled"] as? Bool ?? true)
            case "save":post["saved"]=p.flag("enabled")
            case "see":if item.text("author") != uid { post["viewers"]=toggle(item.strings("viewers"),uid,true) };post["seenByMe"]=true
            case "archivePost":post["archived"]=p.flag("enabled")
            case "editPost":post["text"]=p.text("text")
            case "postOptions":post["commentsOff"]=p.flag("commentsOff");post["hideLikes"]=p.flag("hideLikes")
            case "comment":var comments=item.list("comments").map(\.values);comments.append(["id":UUID().uuidString,"author":uid,"text":p.text("text"),"created":now]);post["comments"]=comments
            case "pollVote":var style=item.object("style").values;style["poll"]=item.object("style").object("poll").updating(["myVote":p.number("choice")]).values;post["style"]=style
            default:break
            };posts[index]=post;if action=="deletePost" { posts.remove(at:index) }
        case "deleteComment","hideComment","likeComment":
            for i in posts.indices { var comments=Entity(posts[i]).list("comments").map(\.values);if let j=comments.firstIndex(where:{Entity($0).id==id}) { if action=="deleteComment" { comments.remove(at:j) } else if action=="hideComment" { comments[j]["hidden"]=p.flag("enabled") } else { comments[j]["likes"]=toggle(Entity(comments[j]).strings("likes"),uid,payload["enabled"] as? Bool ?? true) };posts[i]["comments"]=comments } }
        case "note":var notes=state.list("notes").filter{$0.text("owner") != uid}.map(\.values);if !p.flag("delete") { notes.insert(["owner":uid,"text":p.text("text"),"audience":p.text("audience"),"created":now,"expires":now+86400],at:0) };root["notes"]=notes
        case "noteReact":root["notes"]=state.list("notes").map { $0.text("owner")==user ? $0.updating(["likedByMe":payload["enabled"] as? Bool ?? true]).values:$0.values }
        case "thread":if !threads.contains(where:{let ids=Entity($0).strings("members");return ids.count==2 && ids.contains(user)}) { threads.insert(["id":UUID().uuidString,"members":[uid,user],"messages":[] as [[String:Any]],"requestDecision":"accepted"],at:0) }
        case "group":threads.insert(["id":UUID().uuidString,"title":p.text("title"),"owner":uid,"members":Array(Set([uid]+p.strings("users"))),"messages":[] as [[String:Any]]],at:0)
        case "message","sharePost","messageExpiry","messageRequest","renameGroup","addMember","removeMember","leaveGroup":
            guard let i=threads.firstIndex(where:{Entity($0).id==id}) else { throw GPIXFailure.message("Chat non disponibile") };let t=Entity(threads[i])
            switch action {
            case "message","sharePost":var messages=t.list("messages").map(\.values);var m=payload;m["id"]=UUID().uuidString;m["author"]=uid;m["created"]=now;m["readBy"]=[uid];m["kind"]=p.text("kind",action=="sharePost" ? "post":"text");m["afterRead"]=t.number("messageTTL")==(-1);m["reactions"]=[:] as [String:String];messages.append(m);threads[i]["messages"]=messages
            case "messageExpiry":threads[i]["messageTTL"]=p.number("seconds")
            case "messageRequest":threads[i]["requestDecision"]=p.text("decision")
            case "renameGroup":threads[i]["title"]=p.text("title")
            case "addMember":threads[i]["members"]=toggle(t.strings("members"),user,true)
            case "removeMember":threads[i]["members"]=toggle(t.strings("members"),user,false)
            case "leaveGroup":threads.remove(at:i)
            default:break
            }
        case "react","read","editMessage","deleteMessage":
            for i in threads.indices { var messages=Entity(threads[i]).list("messages").map(\.values);guard let j=messages.firstIndex(where:{Entity($0).id==id}) else { continue };let m=Entity(messages[j]);switch action {
                case "react":var reactions=m.object("reactions").values;reactions[uid]=p.text("emoji");messages[j]["reactions"]=reactions;notification("messageReaction",target:id,actor:uid)
                case "read":messages[j]["readBy"]=toggle(m.strings("readBy"),uid,true)
                case "editMessage":messages[j]["text"]=p.text("text");messages[j]["edited"]=now
                default:messages.remove(at:j)
                };threads[i]["messages"]=messages }
        case "highlight":var highlights=state.list("highlights").map(\.values);highlights.append(["id":UUID().uuidString,"owner":uid,"title":p.text("title"),"posts":p.strings("posts")]);root["highlights"]=highlights
        case "notificationsRead":root["notifications"]=state.list("notifications").map { id.isEmpty || $0.id==id ? $0.updating(["seen":true]).values:$0.values }
        case "report":break
        case "callStart","liveStart":throw GPIXFailure.message("Per chiamate e dirette accedi con un account reale.")
        case "deleteAccount":root=[:];return Entity(root)
        default:throw GPIXFailure.message("Questa azione richiede un account reale.")
        }
        me["postCount"]=posts.filter{Entity($0).text("author")==uid && Entity($0).text("kind") != "story" && !Entity($0).flag("archived")}.count
        me["following"]=(root["following"] as? [String] ?? []).count;me["followingList"]=root["following"]
        root["me"]=me;root["users"]=state.list("users").map{$0.id==uid ? me:$0.values};root["posts"]=posts;root["threads"]=threads;return Entity(root)
    }
}
