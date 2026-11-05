import Foundation

@main enum DomainChecks {
    @MainActor static func main() throws {
        var passed=0
        func check(_ condition:@autoclosure()->Bool,_ message:String) throws { guard condition() else { throw GPIXFailure.message("FAIL: "+message) };passed+=1 }
        try check(Domain.mediaURL("/media/abc?viewer=u&expires=20&sig=xyz")?.absoluteString=="https://gpix.cc/media/abc?viewer=u&expires=20&sig=xyz","Signed relative image URL")
        try check(Domain.mediaURL("https://cdn.example.org/p.jpg")?.host=="cdn.example.org","HTTPS media")
        try check(Domain.mediaURL("/music/audio/original-1")?.path=="/music/audio/original-1","Audio route")
        try check(Domain.mediaURL("abc")?.path=="/media/abc","Media id")
        try check(Domain.mediaURL("")==nil,"Empty media")
        try check(Entity(["mediaItems":["a",["url":"/media/b"]]]).media==["a","/media/b"],"Mixed carousel formats")
        let privateUser=Entity(["id":"b","private":true,"postCount":17,"followers":103,"following":22,"followersList":[] as [String]])
        try check(Domain.counts(privateUser,posts:[])==[17,103,22],"Private account public counters")
        let incoming=Entity(["members":["a","b"],"messages":[["author":"b","text":"Ciao"]]])
        try check(Domain.isRequest(incoming,me:"a",following:[],restricted:[]),"Unsolicited incoming request")
        try check(!Domain.isRequest(incoming.updating(["requestDecision":"accepted"]),me:"a",following:[],restricted:[]),"Accepted request stays accepted")
        try check(!Domain.isRequest(incoming,me:"a",following:["b"],restricted:[]),"Following conversation is inbox")
        try check(Domain.isRequest(incoming,me:"a",following:["b"],restricted:["b"]),"Restricted conversation")
        try check(!Domain.isRequest(incoming.updating(["owner":"a"]),me:"a",following:[],restricted:[]),"Group is not message request")
        try check(Domain.notificationText(Entity(["type":"storyLike"])).contains("storia"),"Story like wording")
        try check(Domain.notificationText(Entity(["type":"messageReaction"])).contains("messaggio"),"Chat reaction wording")
        try check(Domain.socialURL(type:"instagram",value:"@demix.87")?.absoluteString=="https://www.instagram.com/demix.87","Profile handle normalization")
        try check(Domain.socialURL(type:"whatsapp",value:"+39 333 1234567")?.absoluteString=="https://wa.me/393331234567","WhatsApp normalization")
        try check(Domain.socialURL(type:"website",value:"example.org")?.absoluteString=="https://example.org","Website link")
        let now=1000000.0
        var state=Entity(["me":["id":"a","name":"Dmb","username":"dmb"],"users":[["id":"a"],["id":"b","private":true]],"posts":[] as [[String:Any]],"threads":[] as [[String:Any]],"following":[] as [String],"pending":[] as [String],"requests":["b"]])
        state=try DemoReducer.apply(state:state,action:"follow",payload:["user":"b","enabled":true],now:now)
        try check(state.strings("pending")==["b"] && state.strings("following").isEmpty,"Private follow is pending")
        state=try DemoReducer.apply(state:state,action:"follow",payload:["user":"b","enabled":false],now:now)
        try check(state.strings("pending").isEmpty,"Cancel pending request")
        state=try DemoReducer.apply(state:state,action:"accept",payload:["user":"b","enabled":true],now:now)
        try check(state.strings("requests").isEmpty && state.object("me").strings("followersList").contains("b"),"Accept request creates follower")
        state=try DemoReducer.apply(state:state,action:"post",payload:["kind":"story","text":"Un momento"],now:now)
        let story=state.list("posts")[0]
        try check(story.number("expires")==now+86400,"Story duration 24h")
        state=try DemoReducer.apply(state:state,action:"like",payload:["id":story.id,"enabled":true],now:now)
        state=try DemoReducer.apply(state:state,action:"like",payload:["id":story.id,"enabled":true],now:now)
        try check(state.list("posts")[0].strings("likes")==["a"],"Likes are idempotent")
        state=try DemoReducer.apply(state:state,action:"like",payload:["id":story.id,"enabled":false],now:now)
        try check(state.list("posts")[0].strings("likes").isEmpty,"Unlike")
        state=try DemoReducer.apply(state:state,action:"comment",payload:["id":story.id,"text":"Ciao"],now:now)
        let comment=state.list("posts")[0].list("comments")[0]
        state=try DemoReducer.apply(state:state,action:"hideComment",payload:["id":comment.id,"enabled":true],now:now)
        try check(state.list("posts")[0].list("comments")[0].flag("hidden"),"Hide comment")
        state=try DemoReducer.apply(state:state,action:"deleteComment",payload:["id":comment.id],now:now)
        try check(state.list("posts")[0].list("comments").isEmpty,"Delete comment")
        state=try DemoReducer.apply(state:state,action:"thread",payload:["user":"b"],now:now)
        let tid=state.list("threads")[0].id
        state=try DemoReducer.apply(state:state,action:"messageExpiry",payload:["id":tid,"seconds":-1],now:now)
        state=try DemoReducer.apply(state:state,action:"message",payload:["id":tid,"text":"Ciao"],now:now)
        let message=state.list("threads")[0].list("messages")[0]
        try check(message.flag("afterRead"),"After-read temporary message")
        state=try DemoReducer.apply(state:state,action:"react",payload:["id":message.id,"emoji":"❤️"],now:now)
        try check(state.list("threads")[0].list("messages")[0].object("reactions").text("a")=="❤️","Reaction attached to message")
        try check(state.list("notifications")[0].text("type")=="messageReaction","Chat reaction notification shape")
        state=try DemoReducer.apply(state:state,action:"note",payload:["text":"Nuovo giorno","audience":"mutual"],now:now)
        try check(state.list("notes")[0].number("expires")==now+86400,"Note duration 24h")
        let session=Session.shared;session.isDemo=true;session.state=state
        try check(session.person("a").text("name")=="Dmb","Own profile routing")
        try check(session.reactions(session.thread(tid)).count==1,"Reactions scoped to chat")
        try check(session.isRequest(session.thread(tid))==false,"Own message keeps accepted thread")
        try check(session.threads.count==1,"Thread list")
        print("PASS: \(passed) verifiche di dominio, demo e sessione")
    }
}
