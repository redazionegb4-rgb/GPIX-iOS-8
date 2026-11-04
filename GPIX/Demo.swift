import Foundation
extension GpixStore{
    func loadDemo(){
        demo=true
        token=""
        if let saved=UserDefaults.standard.data(forKey:"gpix.swift.demo"),let data=(try? JSONSerialization.jsonObject(with:saved)) as? Row{
            state=data
            return
        }
        guard let url=Bundle.main.url(forResource:"Demo",withExtension:"json"),let data=try? Data(contentsOf:url),var seed=(try? JSONSerialization.jsonObject(with:data)) as? Row else{
            error="Dati demo non disponibili"
            return
        }
        let now=Date().timeIntervalSince1970
        var posts=seed.rows("posts")
        for i in posts.indices{
            posts[i]["created"]=now-posts[i].n("age",1200)
            if posts[i].s("kind")=="story"{
                posts[i]["expires"]=now+86400-posts[i].n("age",1200)
            }
        }
        seed["posts"]=posts
        var threads=seed.rows("threads")
        for i in threads.indices{
            var messages=threads[i].rows("messages")
            for j in messages.indices{
                messages[j]["created"]=now-messages[j].n("age",600)
            }
            threads[i]["messages"]=messages
        }
        seed["threads"]=threads
        var notes=seed.rows("notes")
        for i in notes.indices{
            notes[i]["created"]=now-3600
            notes[i]["expires"]=now+82800
        }
        seed["notes"]=notes
        var instant=seed.row("demoInstants")
        for key in ["received","sent","active"]{
            var rows=instant.rows(key)
            for i in rows.indices{
                rows[i]["created"]=now-7200
                rows[i]["expires"]=now+79200
            }
            instant[key]=rows
        }
        seed["demoInstants"]=instant
        state=seed
        persistDemo()
    }
    func persistDemo(){
        if let data=try? JSONSerialization.data(withJSONObject:state){
            UserDefaults.standard.set(data,forKey:"gpix.swift.demo")
        }
    }
    func demoAction(_ action:String,_ p:Row)throws{
        let now=Date().timeIntervalSince1970,id=p.id,target=p.s("user"),enabled=p["enabled"] as? Bool ?? true
        var posts=state.rows("posts"),threads=state.rows("threads"),users=state.rows("users"),me=state.row("me")
        var changedPosts=false,changedThreads=false,changedUsers=false,changedMe=false
        func postIndex()throws->Int{
            guard let i=posts.firstIndex(where:{
                $0.id==id
            }
            )else{
                throw GError(message:"Post non disponibile")
            }
            return i
        }
        func toggle(_ ids:[String],_ value:String)->[String]{
            enabled ? Array(Set(ids+[value])):ids.filter{
                $0 != value
            }
        }
        switch action{
            case "profile":for (k,v) in p{
                me[k]=v
            }
            changedMe=true
            case "profileLinks":var links:[Row]=[]
            for var link in p.rows("links"){
                let kind=link.s("type"),value=link.s("value")
                var url=link.s("url")
                if kind=="website"{
                    url=value
                }
                else{
                    let handle=value.hasPrefix("@") ? String(value.dropFirst()):value
                    let domains=["instagram":"https://www.instagram.com/","facebook":"https://www.facebook.com/","threads":"https://www.threads.com/@","whatsapp":"https://wa.me/","telegram":"https://t.me/","tiktok":"https://www.tiktok.com/@","youtube":"https://www.youtube.com/@","x":"https://x.com/"]
                    url=(domains[kind] ?? "")+handle
                }
                guard URL(string:url)?.scheme=="https"else{
                    throw GError(message:"Inserisci un collegamento HTTPS valido")
                }
                link["url"]=url
                if link.s("title").isEmpty{
                    link["title"]=value
                }
                links.append(link)
            }
            guard links.count<=5 else{
                throw GError(message:"Massimo 5 collegamenti")
            }
            me["links"]=links
            changedMe=true
            case "preferences":var prefs=state.row("preferences")
            prefs[p.s("key")]=p["value"]
            state["preferences"]=prefs
            case "follow":var ids=state.ids("following"),pending=state.ids("pending")
            if person(target).b("private") && enabled && !ids.contains(target){
                pending=toggle(pending,target)
            }
            else{
                ids=toggle(ids,target)
                pending=pending.filter{
                    $0 != target
                }
            }
            state["following"]=ids
            state["pending"]=pending
            me["following"]=ids.count
            me["followingList"]=ids
            changedMe=true
            case "accept":state["requests"]=state.ids("requests").filter{
                $0 != target
            }
            if enabled{
                let ids=Array(Set(me.ids("followersList")+[target]))
                me["followersList"]=ids
                me["followers"]=ids.count
                changedMe=true
            }
            case "block":state["blocks"]=toggle(state.ids("blocks"),target)
            if enabled{
                state["following"]=state.ids("following").filter{
                    $0 != target
                }
                threads=threads.filter{
                    !$0.ids("members").contains(target)
                }
            }
            changedThreads=true
            case "closeFriend":state["closeFriends"]=toggle(state.ids("closeFriends"),target)
            case "pinPost":let i=try postIndex()
            guard posts[i].s("author")==myID else{
                throw GError(message:"Non è un tuo post")
            }
            var pins=me.ids("pinnedPosts").filter{
                $0 != id
            }
            if enabled{
                guard pins.count<3 else{
                    throw GError(message:"Puoi fissare al massimo 3 post")
                }
                pins.insert(id,at:0)
            }
            me["pinnedPosts"]=pins
            changedMe=true
            case "gridOrder":me["gridOrder"]=p.ids("ids")
            changedMe=true
            case "post":var row=p
            row["id"]=UUID().uuidString
            row["author"]=myID
            row["created"]=now
            row["expires"]=p.s("kind")=="story" ? now+86400:0
            row["likes"]=[] as [String]
            row["comments"]=[] as [Row]
            row["reposts"]=[] as [String]
            row["mediaItems"]=p.ids("mediaItems").map{
                ["id":$0,"url":$0]
            }
            posts.insert(row,at:0)
            changedPosts=true
            case "like","save","see","repost","archivePost","editPost","postOptions","deletePost","comment","pollVote":let i=try postIndex()
            switch action{
                case "like":posts[i]["likes"]=toggle(posts[i].ids("likes"),myID)
                case "save":posts[i]["saved"]=enabled
                case "see":if posts[i].s("author") != myID{
                    posts[i]["seenByMe"]=true
                    posts[i]["viewers"]=Array(Set(posts[i].ids("viewers")+[myID]))
                }
                case "repost":posts[i]["reposts"]=toggle(posts[i].ids("reposts"),myID)
                case "archivePost":posts[i]["archived"]=enabled
                case "editPost":posts[i]["text"]=p.s("text")
                posts[i]["location"]=p.s("location")
                case "postOptions":posts[i]["commentsOff"]=p.b("commentsOff")
                posts[i]["hideLikes"]=p.b("hideLikes")
                case "deletePost":posts.remove(at:i)
                case "comment":var comments=posts[i].rows("comments")
                var comment=p
                comment["id"]=UUID().uuidString
                comment["author"]=myID
                comment["created"]=now
                comment["likes"]=[] as [String]
                comments.append(comment)
                posts[i]["comments"]=comments
                case "pollVote":var style=posts[i].row("style"),poll=posts[i].row("style").row("poll")
                poll["myVote"]=p["choice"]
                style["poll"]=poll
                posts[i]["style"]=style
                default:break
            }
            changedPosts=true
            case "hideComment","deleteComment","likeComment":for i in posts.indices{
                var rows=posts[i].rows("comments")
                if let j=rows.firstIndex(where:{
                    $0.id==id
                }
                ){
                    if action=="deleteComment"{
                        guard rows[j].s("author")==myID || posts[i].s("author")==myID else{
                            throw GError(message:"Operazione non consentita")
                        }
                        rows=rows.filter{
                            $0.id != id && $0.s("parent") != id
                        }
                    }
                    else if action=="hideComment"{
                        guard posts[i].s("author")==myID else{
                            throw GError(message:"Operazione non consentita")
                        }
                        rows[j]["hidden"]=enabled
                    }
                    else{
                        rows[j]["likes"]=toggle(rows[j].ids("likes"),myID)
                    }
                    posts[i]["comments"]=rows
                }
            }
            changedPosts=true
            case "note":var notes=state.rows("notes").filter{
                $0.s("owner") != myID
            }
            if !p.b("delete"){
                guard !p.s("text").isEmpty,p.s("text").count<=60 else{
                    throw GError(message:"Massimo 60 caratteri")
                }
                notes.insert(["id":myID,"owner":myID,"text":p.s("text"),"audience":p.s("audience","mutual"),"created":now,"expires":now+86400],at:0)
            }
            state["notes"]=notes
            case "noteReact":var rows=state.rows("notes")
            if let i=rows.firstIndex(where:{
                $0.s("owner")==target
            }
            ){
                rows[i]["likedByMe"]=enabled
            }
            state["notes"]=rows
            case "thread":if !threads.contains(where:{
                $0.ids("members").count==2 && $0.ids("members").contains(target)
            }
            ){
                threads.insert(["id":UUID().uuidString,"members":[myID,target],"messages":[] as [Row],"messageTTL":0,"requestDecision":"accepted"],at:0)
            }
            changedThreads=true
            case "group":threads.insert(["id":UUID().uuidString,"members":Array(Set(p.ids("users")+[myID])),"title":p.s("title"),"owner":myID,"messages":[] as [Row]],at:0)
            changedThreads=true
            case "message","messageRequest","messageExpiry","sharePost","renameGroup","addMember","removeMember","leaveGroup":guard let i=threads.firstIndex(where:{
                $0.id==id
            }
            )else{
                throw GError(message:"Chat non disponibile")
            }
            switch action{
                case "message","sharePost":var messages=threads[i].rows("messages"),m=p
                m["id"]=UUID().uuidString
                m["author"]=myID
                m["created"]=now
                m["kind"]=action=="sharePost" ? "post":p.s("kind","text")
                m["reactions"]=[:] as Row
                m["readBy"]=[myID]
                if action=="sharePost"{
                    m["story"]=["postId":p.s("post")]
                    m["text"]="Post condiviso"
                }
                messages.append(m)
                threads[i]["messages"]=messages
                threads[i]["requestDecision"]="accepted"
                case "messageRequest":threads[i]["requestDecision"]=p.s("decision")
                case "messageExpiry":threads[i]["messageTTL"]=p.n("seconds")
                case "renameGroup":threads[i]["title"]=p.s("title")
                case "addMember":threads[i]["members"]=Array(Set(threads[i].ids("members")+[target]))
                case "removeMember":threads[i]["members"]=threads[i].ids("members").filter{
                    $0 != target
                }
                case "leaveGroup":threads.remove(at:i)
                default:break
            }
            changedThreads=true
            case "react","read","editMessage","deleteMessage":for i in threads.indices{
                var messages=threads[i].rows("messages")
                if let j=messages.firstIndex(where:{
                    $0.id==id
                }
                ){
                    switch action{
                        case "react":var reactions=messages[j].row("reactions")
                        if p.s("emoji").isEmpty{
                            reactions.removeValue(forKey:myID)
                        }
                        else{
                            reactions[myID]=p.s("emoji")
                        }
                        messages[j]["reactions"]=reactions
                        case "read":messages[j]["readBy"]=Array(Set(messages[j].ids("readBy")+[myID]))
                        case "editMessage":messages[j]["text"]=p.s("text")
                        messages[j]["edited"]=true
                        default:messages.remove(at:j)
                    }
                    threads[i]["messages"]=messages
                }
            }
            changedThreads=true
            case "highlight":var rows=state.rows("highlights")
            rows.append(["id":UUID().uuidString,"owner":myID,"title":p.s("title"),"posts":p.ids("posts")])
            state["highlights"]=rows
            case "deleteHighlight":state["highlights"]=state.rows("highlights").filter{
                $0.id != id
            }
            case "notificationsRead":var rows=state.rows("notifications")
            for i in rows.indices where (id.isEmpty || rows[i].id==id) && rows[i].s("type") != "messageReaction"{
                rows[i]["seen"]=true
            }
            state["notifications"]=rows
            case "report":break
            default:throw GError(message:"Questa funzione richiede un account reale")
        }
        if changedPosts{
            state["posts"]=posts
        }
        if changedThreads{
            state["threads"]=threads
        }
        if changedMe{
            state["me"]=me
            if let i=users.firstIndex(where:{
                $0.id==myID
            }
            ){
                users[i]=me
                changedUsers=true
            }
        }
        if changedUsers{
            state["users"]=users
        }
        persistDemo()
    }
}
