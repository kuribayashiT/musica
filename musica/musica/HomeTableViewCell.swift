//
//  HomeTableViewCell.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/20.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import SWTableViewCell

class HomeTableViewCell: SWTableViewCell {

    @IBOutlet var animationGifWebView: WKWebView!
    @IBOutlet weak var libraryTitleLabel: UILabel!
    @IBOutlet weak var libraryNumLabel: UILabel!
    @IBOutlet weak var librarySubTitleLabel: UILabel!
    @IBOutlet weak var libraryImage: UIImageView!
    @IBOutlet weak var libraryContentsTypeLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
