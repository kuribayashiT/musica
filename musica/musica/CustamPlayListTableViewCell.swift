//
//  CustamPlayListTableViewCell.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/08.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import SWTableViewCell

class CustamPlayListTableViewCell: SWTableViewCell {

    @IBOutlet weak var trackNumLabel: UILabel!
    @IBOutlet weak var trackTitleLabel: UILabel!
    @IBOutlet weak var albumTitleLabel: UILabel!
    @IBOutlet var animationGifWebView: WKWebView!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
