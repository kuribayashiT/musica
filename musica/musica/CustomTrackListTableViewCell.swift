//
//  CustomTableViewCell.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/03.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import MediaPlayer

class CustomTrackListTableViewCell: UITableViewCell {

    
    var Album : AlbumData = AlbumData()
    
    @IBOutlet weak var TrackTitleLabel: UILabel!
    @IBOutlet weak var TrackSubtitleLabel: UILabel!
    @IBOutlet weak var playBtn: UIButton!
    @IBOutlet weak var hideView: UIView!
    

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

    // Configure the view for the selected state
    }
    // 画像・タイトル・説明文を設定するメソッド
    func setCell(/*imageName: String, */titleText: String, descriptionText: String) {
        TrackTitleLabel.text = titleText
        TrackSubtitleLabel.text = descriptionText
    }
    
}
