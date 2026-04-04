//
//  RecommendMVCollectionViewCell.swift
//  musica
//
//  Created by 栗林貴大 on 2020/02/10.
//  Copyright © 2020 K.T. All rights reserved.
//

import UIKit

class RecommendMVCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var view: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var checkmark: UIImageView!
    @IBOutlet weak var numlabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        let path = UIBezierPath(roundedRect: imageView.bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 12, height: 12))
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        imageView.layer.mask = mask
        view.layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.6
        view.layer.shadowRadius = 3
    }

}
