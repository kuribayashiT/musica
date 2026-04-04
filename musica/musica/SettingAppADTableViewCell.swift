//
//  SettingAppADTableViewCell.swift
//  musica
//
//  Created by 栗林貴大 on 2019/04/29.
//  Copyright © 2019 K.T. All rights reserved.
//

import UIKit

class SettingAppADTableViewCell: UITableViewCell {

    @IBOutlet weak var appImage: UIImageView!
    @IBOutlet weak var appName: UILabel!
    @IBOutlet weak var appInfo: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
