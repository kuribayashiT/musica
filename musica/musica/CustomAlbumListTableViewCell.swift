//
//  CustomAlbumListTableViewCell.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/03.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit

class CustomAlbumListTableViewCell: UITableViewCell {

    @IBOutlet weak var AlbumImage: UIImageView!
    @IBOutlet weak var AlbumTitleLabel: UILabel!
    @IBOutlet weak var AlbumSubtitleLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    /// 画像・タイトル・説明文を設定するメソッド
    func setCell(/*imageName: String, */titleText: String, descriptionText: String) {
        //myImageView.image = UIImage(named: imageName)
        AlbumTitleLabel.text = titleText
        AlbumSubtitleLabel.text = descriptionText
    }
}
