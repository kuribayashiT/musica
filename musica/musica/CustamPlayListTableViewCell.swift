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

    private lazy var waveformView: WaveformBarsView = {
        let v = WaveformBarsView(compact: true)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        contentView.addSubview(v)
        // compact: 4棒×3pt + 3gap×3pt = 21pt wide, max height 20pt
        NSLayoutConstraint.activate([
            v.centerXAnchor.constraint(equalTo: trackNumLabel.centerXAnchor),
            v.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            v.widthAnchor.constraint(equalToConstant: 21),
            v.heightAnchor.constraint(equalToConstant: 20),
        ])
        return v
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = AppColor.surface
        trackTitleLabel.textColor = AppColor.textPrimary
        albumTitleLabel.textColor = AppColor.textSecondary
        trackNumLabel.textColor = AppColor.textSecondary
        animationGifWebView.isHidden = true
    }

    func setWaveformAnimating(_ animating: Bool) {
        animationGifWebView.isHidden = true
        if animating {
            trackNumLabel.isHidden = true
            waveformView.isHidden = false
            waveformView.startAnimating()
        } else {
            waveformView.stopAnimating()
            waveformView.isHidden = true
            trackNumLabel.isHidden = false
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setWaveformAnimating(false)
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
    }
}
