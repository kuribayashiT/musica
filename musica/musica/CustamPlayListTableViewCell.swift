//
//  CustamPlayListTableViewCell.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/08.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import WebKit
import SWTableViewCell

class CustamPlayListTableViewCell: SWTableViewCell {

    @IBOutlet weak var trackNumLabel: UILabel!
    @IBOutlet weak var trackTitleLabel: UILabel!
    @IBOutlet weak var albumTitleLabel: UILabel!
    @IBOutlet var animationGifWebView: WKWebView!
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = AppColor.surface
        trackTitleLabel.textColor = AppColor.textPrimary
        albumTitleLabel.textColor = AppColor.textSecondary
        trackNumLabel.textColor = AppColor.textSecondary
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // タイトル＋アーティストをセル内で垂直中央揃えにする
        guard let titleLbl = trackTitleLabel, let artistLbl = albumTitleLabel else { return }
        let blockH = titleLbl.frame.height + 2 + artistLbl.frame.height
        let originY = (contentView.bounds.height - blockH) / 2
        titleLbl.frame.origin.y  = originY
        artistLbl.frame.origin.y = originY + titleLbl.frame.height + 2
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
