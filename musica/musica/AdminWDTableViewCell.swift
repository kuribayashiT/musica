//
//  AdminWDTableViewCell.swift
//  musica
//
//  Created by 栗林貴大 on 2020/02/11.
//  Copyright © 2020 K.T. All rights reserved.
//

import UIKit

class AdminWDTableViewCell: UITableViewCell {

    @IBOutlet weak var wardLbl: UILabel!
    @IBOutlet weak var countLbl: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
