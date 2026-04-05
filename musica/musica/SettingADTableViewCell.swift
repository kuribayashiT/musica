//
//  SettingADTableViewCell.swift
//  musica
//
//  Created by 栗林貴大 on 2017/07/24.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import GoogleMobileAds

class SettingADTableViewCell: UITableViewCell {

    @IBOutlet weak var ADView: UIView!
    @IBOutlet weak var bannerView: BannerView!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
