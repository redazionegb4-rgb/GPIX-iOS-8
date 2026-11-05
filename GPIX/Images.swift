import UIKit
import AVFoundation
import ImageIO

@MainActor final class PhotoView: UIImageView {
    private var task: Task<Void,Never>?
    private static let cache = NSCache<NSString,UIImage>()
    override init(frame: CGRect) { super.init(frame:frame);contentMode = .scaleAspectFill;clipsToBounds=true;backgroundColor=Design.soft }
    convenience init(_ reference: String) { self.init(frame:.zero);load(reference) }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    func load(_ reference: String) {
        task?.cancel();image=nil
        guard !reference.isEmpty else { return }
        if let cached=Self.cache.object(forKey:reference as NSString) { image=cached;return }
        let name=URL(string:reference)?.lastPathComponent ?? reference
        if let url=Bundle.main.url(forResource:name,withExtension:nil,subdirectory:"Media"),let bytes=try? Data(contentsOf:url),let local=Self.decode(bytes) { image=local;return }
        if reference.hasPrefix("file://"),let url=URL(string:reference) { image=UIImage(contentsOfFile:url.path);return }
        guard let url=Domain.mediaURL(reference) else { return }
        task=Task { [weak self] in
            do {
                if ["mp4","mov","m4v"].contains(url.pathExtension.lowercased()) {
                    let generator=AVAssetImageGenerator(asset:AVURLAsset(url:url));generator.appliesPreferredTrackTransform=true;generator.maximumSize=CGSize(width:1000,height:1200)
                    let result=try await generator.image(at:.zero);guard !Task.isCancelled else { return };let image=UIImage(cgImage:result.image);Self.cache.setObject(image,forKey:reference as NSString);self?.image=image
                } else {
                    var request=URLRequest(url:url);if url.host==Domain.server.host { request.setValue("Bearer "+Session.shared.token,forHTTPHeaderField:"Authorization") }
                    let (data,response)=try await URLSession.shared.data(for:request);guard !Task.isCancelled,(response as? HTTPURLResponse).map({(200..<300).contains($0.statusCode)}) ?? true,let image=Self.decode(data) else { return };Self.cache.setObject(image,forKey:reference as NSString);self?.image=image
                }
            } catch { guard !Task.isCancelled else { return }; self?.image=UIImage(systemName:"photo");self?.tintColor=Design.muted }
        }
    }
    private static func decode(_ data:Data)->UIImage? {
        guard let source=CGImageSourceCreateWithData(data as CFData,nil),CGImageSourceGetCount(source)>1 else { return UIImage(data:data) }
        var frames:[UIImage]=[];var duration:Double=0
        for i in 0..<min(80,CGImageSourceGetCount(source)) { guard let cg=CGImageSourceCreateImageAtIndex(source,i,nil) else { continue };frames.append(UIImage(cgImage:cg));let properties=CGImageSourceCopyPropertiesAtIndex(source,i,nil) as? [CFString:Any];let gif=properties?[kCGImagePropertyGIFDictionary] as? [CFString:Any];duration+=max(0.04,(gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1) }
        return UIImage.animatedImage(with:frames,duration:duration)
    }
    deinit { task?.cancel() }
}
@MainActor final class Avatar: UIView {
    init(_ person: Entity, size: CGFloat = 44, story: Bool = false, online: Bool = false) {
        super.init(frame:.zero);widthAnchor.constraint(equalToConstant:size).isActive=true;heightAnchor.constraint(equalToConstant:size).isActive=true
        if story { let ring=CAGradientLayer();ring.colors=[UIColor.systemYellow.cgColor,UIColor.systemPink.cgColor,Design.violet.cgColor];ring.startPoint=CGPoint(x:0,y:1);ring.endPoint=CGPoint(x:1,y:0);ring.frame=CGRect(x:0,y:0,width:size,height:size);ring.cornerRadius=size/2;layer.addSublayer(ring) }
        let photo=PhotoView(person.text("avatar"));photo.layer.cornerRadius=(size-(story ? 8:0))/2;addSubview(photo);photo.pin(to:self,insets:UIEdgeInsets(top:story ? 4:0,left:story ? 4:0,bottom:story ? 4:0,right:story ? 4:0))
        if person.text("avatar").isEmpty { let initial=Design.label(String(person.text("name","G").prefix(1)),size:size/2,weight:.semibold,color:Design.violet);initial.textAlignment = .center;photo.addSubview(initial);initial.pin(to:photo) }
        if online { let dot=UIView();dot.backgroundColor = .systemGreen;dot.layer.cornerRadius=6;dot.layer.borderColor=Design.background.cgColor;dot.layer.borderWidth=2;addSubview(dot);dot.translatesAutoresizingMaskIntoConstraints=false;NSLayoutConstraint.activate([dot.widthAnchor.constraint(equalToConstant:13),dot.heightAnchor.constraint(equalToConstant:13),dot.trailingAnchor.constraint(equalTo:trailingAnchor),dot.bottomAnchor.constraint(equalTo:bottomAnchor)]) }
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
}
