//
//  OKINIIRICollectionViewCell.swift
//  musica
//
//  Created by 栗林貴大 on 2017/09/02.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit

class OKINIIRICollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var youtubeVideoThumbnail: UIImageView!
    @IBOutlet weak var deleteBtn: UIButton!
    @IBOutlet weak var youtubeVideoTimeLabel: UILabel!
    @IBOutlet weak var youtubeVideoTitle: UILabel!
    @IBOutlet weak var youtubeView: UIView!

    // 字幕保存済みバッジ
    let captionBadge = UIView()
    private let captionBadgeIcon  = UIImageView()
    private let captionBadgeLabel = UILabel()

    override func awakeFromNib() {
        super.awakeFromNib()

        // 字幕バッジ（サムネイル右上）
        captionBadge.backgroundColor = UIColor.systemGreen
        captionBadge.layer.cornerRadius = 10
        captionBadge.layer.masksToBounds = true
        captionBadge.isHidden = true
        captionBadge.translatesAutoresizingMaskIntoConstraints = false

        captionBadgeIcon.image = UIImage(systemName: "text.bubble.fill")
        captionBadgeIcon.tintColor = .white
        captionBadgeIcon.contentMode = .scaleAspectFit
        captionBadgeIcon.translatesAutoresizingMaskIntoConstraints = false

        captionBadgeLabel.text = localText(key: "mv_caption_badge")
        captionBadgeLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        captionBadgeLabel.textColor = .white
        captionBadgeLabel.translatesAutoresizingMaskIntoConstraints = false

        captionBadge.addSubview(captionBadgeIcon)
        captionBadge.addSubview(captionBadgeLabel)
        NSLayoutConstraint.activate([
            captionBadgeIcon.leadingAnchor.constraint(equalTo: captionBadge.leadingAnchor, constant: 6),
            captionBadgeIcon.centerYAnchor.constraint(equalTo: captionBadge.centerYAnchor),
            captionBadgeIcon.widthAnchor.constraint(equalToConstant: 11),
            captionBadgeIcon.heightAnchor.constraint(equalToConstant: 11),

            captionBadgeLabel.leadingAnchor.constraint(equalTo: captionBadgeIcon.trailingAnchor, constant: 3),
            captionBadgeLabel.trailingAnchor.constraint(equalTo: captionBadge.trailingAnchor, constant: -6),
            captionBadgeLabel.centerYAnchor.constraint(equalTo: captionBadge.centerYAnchor),
        ])

        youtubeView.addSubview(captionBadge)
        NSLayoutConstraint.activate([
            captionBadge.topAnchor.constraint(equalTo: youtubeView.topAnchor, constant: 6),
            captionBadge.trailingAnchor.constraint(equalTo: youtubeView.trailingAnchor, constant: -6),
            captionBadge.heightAnchor.constraint(equalToConstant: 20),
        ])
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        // shadow は contentView に（clipsToBounds しないのでシャドウが見える）
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.15
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowRadius = 5

        // カード全体の角丸はここだけ。clipsToBounds でサムネイルも一緒にクリップ
        youtubeView.layer.cornerRadius = 8
        youtubeView.clipsToBounds = true
        youtubeView.backgroundColor = AppColor.surface  // テキストエリアの背景色

        // サムネイルは角丸なし（youtubeView の cornerRadius に委ねる）
        youtubeVideoThumbnail.contentMode = .scaleAspectFill
        youtubeVideoThumbnail.clipsToBounds = true
        youtubeVideoThumbnail.layer.cornerRadius = 0
        youtubeVideoThumbnail.backgroundColor = UIColor(white: 0.12, alpha: 1)

        youtubeVideoTitle.textColor = AppColor.textPrimary
        youtubeVideoTitle.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        youtubeVideoTitle.numberOfLines = 2

        // 再生時間: YouTube スタイルのダークバッジ
        youtubeVideoTimeLabel.textColor = .white
        youtubeVideoTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        youtubeVideoTimeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        youtubeVideoTimeLabel.layer.cornerRadius = 4
        youtubeVideoTimeLabel.layer.masksToBounds = true
        youtubeVideoTimeLabel.textAlignment = .center
    }
}
