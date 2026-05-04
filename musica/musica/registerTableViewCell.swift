//
//  registerTableViewCell.swift
//  musica
//
//  Created by 栗林貴大 on 2018/07/16.
//  Copyright © 2018年 K.T. All rights reserved.
//

import UIKit

// ホームタブのガイドカード表示状態
enum LibraryGuideState {
    case hidden       // ユーザーが自分のライブラリを追加済み
    case noData       // ライブラリが全くない（初回起動直後）
    case sampleOnly   // サンプルデータのみ存在
}

class registerTableViewCell: UITableViewCell {

    @IBOutlet weak var tutorialBtn: UIButton!
    @IBOutlet weak var registerBtn: UIButton!
    @IBOutlet weak var tutorialImg: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = AppColor.background

        // ── Primary CTA ───────────────────────────────────────────────
        registerBtn.backgroundColor = AppColor.accent
        registerBtn.setTitleColor(.white, for: .normal)
        registerBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        registerBtn.layer.cornerRadius = 14
        registerBtn.layer.masksToBounds = true
        if let img = UIImage(systemName: "plus.circle.fill") {
            registerBtn.setImage(img, for: .normal)
            registerBtn.tintColor = .white
        }

        // ── 旧吹き出し画像は非表示 ──────────────────────────────────
        tutorialImg.isHidden = true

        // ── ガイドカード（tutorialBtn を流用）──────────────────────
        // Storyboard の固定 width=220 / height=32 を外す
        tutorialBtn.constraints
            .filter { $0.firstAttribute == .width || $0.firstAttribute == .height }
            .forEach { tutorialBtn.removeConstraint($0) }
        NSLayoutConstraint.activate([
            tutorialBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tutorialBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])

        tutorialBtn.backgroundColor = AppColor.accentMuted
        tutorialBtn.layer.cornerRadius = 14
        tutorialBtn.layer.masksToBounds = true
        tutorialBtn.titleLabel?.numberOfLines = 0
        tutorialBtn.titleLabel?.lineBreakMode = .byWordWrapping
        tutorialBtn.contentEdgeInsets = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        tutorialBtn.isUserInteractionEnabled = false
        tutorialBtn.isHidden = true
    }

    /// ガイドカードの表示状態を切り替える
    func setGuideState(_ state: LibraryGuideState) {
        switch state {
        case .hidden:
            tutorialBtn.isHidden = true

        case .noData:
            tutorialBtn.isHidden = false
            setCardText(
                title: "🎵  まずは音楽ライブラリを作ろう",
                sub:   "上の「＋ ライブラリを追加する」をタップして\n曲を登録してみてください"
            )

        case .sampleOnly:
            tutorialBtn.isHidden = false
            setCardText(
                title: "🎧  まずサンプルで練習してみよう！",
                sub:   "「📖 使い方ガイド＆練習曲」でディクテーションを体験できます。\n慣れたら「＋」で自分の曲を追加してみてください。"
            )
        }
    }

    private func setCardText(title: String, sub: String) {
        let para = NSMutableParagraphStyle()
        para.alignment  = .center
        para.lineSpacing = 3
        let attrStr = NSMutableAttributedString()
        attrStr.append(NSAttributedString(string: title + "\n", attributes: [
            .font:           UIFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: AppColor.textPrimary,
            .paragraphStyle: para,
        ]))
        attrStr.append(NSAttributedString(string: sub, attributes: [
            .font:           UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: AppColor.textSecondary,
            .paragraphStyle: para,
        ]))
        tutorialBtn.setAttributedTitle(attrStr, for: .normal)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
