import UIKit

@MainActor final class MessageDialog: UIViewController {
    private let heading:String,message:String
    init(title:String,message:String) { heading=title;self.message=message;super.init(nibName:nil,bundle:nil);modalPresentationStyle = .overFullScreen;modalTransitionStyle = .crossDissolve }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad();view.backgroundColor=UIColor.black.withAlphaComponent(0.42)
        let title=Design.label(heading,size:18,weight:.bold,lines:0),body=Design.label(message,size:14,color:Design.muted,lines:0);title.textAlignment = .center;body.textAlignment = .center
        let button=Design.button("OK",primary:true) { [weak self] in self?.dismiss(animated:true) }
        let stack=Design.stack(spacing:15,views:[title,body,Design.spacer(3),button]);let card=Design.inset(stack,UIEdgeInsets(top:27,left:24,bottom:18,right:24));card.backgroundColor=Design.background;card.layer.cornerRadius=18;view.addSubview(card);card.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([card.centerXAnchor.constraint(equalTo:view.centerXAnchor),card.centerYAnchor.constraint(equalTo:view.centerYAnchor),card.widthAnchor.constraint(equalTo:view.widthAnchor,constant:-80),card.heightAnchor.constraint(lessThanOrEqualTo:view.safeAreaLayoutGuide.heightAnchor,constant:-40)])
    }
}
@MainActor final class ActionMenu: UIViewController {
    private let heading:String?,items:[(String,Bool,()->Void)]
    init(title:String?,items:[(String,Bool,()->Void)]) { heading=title;self.items=items;super.init(nibName:nil,bundle:nil);modalPresentationStyle = .pageSheet }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad();view.backgroundColor=Design.background;let stack=Design.stack(spacing:3)
        if let title=heading { let l=Design.label(title,size:17,weight:.bold,lines:2);l.textAlignment = .center;stack.addArrangedSubview(Design.inset(l,UIEdgeInsets(top:6,left:8,bottom:12,right:8))) }
        for (title, destructive, action) in items {
            var config = UIButton.Configuration.plain()
            config.title = title
            config.baseForegroundColor = destructive ? Design.danger : Design.ink
            config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = Design.font(16, .semibold)
                return attributes
            }
            let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true, completion: action)
            })
            button.contentHorizontalAlignment = .leading
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
            stack.addArrangedSubview(button)
        }
        stack.addArrangedSubview(Design.button("Annulla") { [weak self] in self?.dismiss(animated:true) });let scroll=UIScrollView();view.addSubview(scroll);scroll.pin(to:view,insets:UIEdgeInsets(top:25,left:16,bottom:16,right:16));scroll.addSubview(stack);stack.pin(to:scroll);stack.widthAnchor.constraint(equalTo:scroll.frameLayoutGuide.widthAnchor).isActive=true
    }
}

@MainActor final class ReactionPicker: UIViewController {
    private let choose:(String)->Void
    init(choose:@escaping(String)->Void) { self.choose=choose;super.init(nibName:nil,bundle:nil);modalPresentationStyle = .pageSheet }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad();view.backgroundColor=Design.background
        if let sheet=sheetPresentationController { sheet.detents=[.custom { _ in 145 }];sheet.prefersGrabberVisible=true;sheet.preferredCornerRadius=28 }
        let row=Design.stack(.horizontal,spacing:0);row.distribution = .fillEqually
        for emoji in ["❤️","😂","😍","🔥","😢","👏"] { let button=UIButton(type:.system);button.setTitle(emoji,for:.normal);button.titleLabel?.font=Design.font(30);button.addAction(UIAction { [weak self] _ in guard let self=self else { return };self.dismiss(animated:true) { self.choose(emoji) } },for:.touchUpInside);row.addArrangedSubview(button) }
        view.addSubview(row);row.pin(to:view,insets:UIEdgeInsets(top:30,left:12,bottom:30,right:12))
    }
}
