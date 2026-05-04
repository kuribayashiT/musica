//
//  HomeTableViewCell.swift
//  musica
//
//  Created by 栗林貴大 on 2017/05/20.
//  Copyright © 2017年 K.T. All rights reserved.
//

import UIKit
import WebKit
import SWTableViewCell

class HomeTableViewCell: SWTableViewCell {

    @IBOutlet var animationGifWebView: WKWebView!
    @IBOutlet weak var libraryTitleLabel: UILabel!
    @IBOutlet weak var libraryNumLabel: UILabel!
    @IBOutlet weak var librarySubTitleLabel: UILabel!
    @IBOutlet weak var libraryImage: UIImageView!
    @IBOutlet weak var libraryContentsTypeLabel: UILabel!

    private let iconSize: CGFloat = 46
    private var equalizerContainer: UIView?
    private var equalizerBars: [UIView] = []

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = AppColor.surface

        // ライブラリ名: Apple Music スタイル 17pt Semibold
        libraryTitleLabel.textColor = AppColor.textPrimary
        libraryTitleLabel.font = AppFont.headline

        // 曲数: 小さめ secondary（libraryContentsTypeLabel は非表示にして統合）
        librarySubTitleLabel.textColor = AppColor.textSecondary
        librarySubTitleLabel.font = AppFont.footnote

        // 行番号ラベル（40pt bold）& 種別ラベルは Apple Music スタイルでは不要
        libraryNumLabel.isHidden = true
        libraryContentsTypeLabel.isHidden = true

        animationGifWebView.isHidden = true
        fixIconConstraints()
        buildEqualizerView()
    }

    // MARK: – Layout

    /// Storyboard の top/bottom 制約（セル高に追従して縦伸び）を除去し、
    /// 固定サイズ + centerY に差し替える
    private func fixIconConstraints() {
        // superview の制約のうち libraryImage の top / bottom / height を除去
        if let sv = libraryImage.superview {
            let toRemove = sv.constraints.filter { c in
                let f = c.firstItem as? UIView
                let s = c.secondItem as? UIView
                guard f == libraryImage || s == libraryImage else { return false }
                let stretchAttrs: [NSLayoutConstraint.Attribute] = [.top, .bottom, .height]
                return stretchAttrs.contains(c.firstAttribute) || stretchAttrs.contains(c.secondAttribute)
            }
            NSLayoutConstraint.deactivate(toRemove)
        }
        // libraryImage 自身の height / width 制約も除去
        libraryImage.constraints
            .filter { $0.firstAttribute == .height || $0.firstAttribute == .width }
            .forEach { $0.isActive = false }

        // 固定 46×46 + 縦中央
        NSLayoutConstraint.activate([
            libraryImage.widthAnchor.constraint(equalToConstant: iconSize),
            libraryImage.heightAnchor.constraint(equalToConstant: iconSize),
            libraryImage.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // イコライザーコンテナをアイコンに重ねる
        equalizerContainer?.frame = libraryImage.frame
        equalizerContainer?.layer.cornerRadius = libraryImage.layer.cornerRadius
    }

    // MARK: – Equalizer (native animated bars)

    private func buildEqualizerView() {
        let container = UIView()
        container.backgroundColor = AppColor.accent
        container.layer.cornerRadius = 10
        container.clipsToBounds = true
        container.isHidden = true
        // Frame is managed in layoutSubviews, not Auto Layout
        contentView.addSubview(container)

        let barCount = 4
        let barW: CGFloat = 3.5
        let gap: CGFloat = 3.0
        let totalW = CGFloat(barCount) * barW + CGFloat(barCount - 1) * gap
        let naturalHeights: [CGFloat] = [10, 18, 14, 8]

        for i in 0..<barCount {
            let bar = UIView()
            bar.backgroundColor = .white
            bar.layer.cornerRadius = barW / 2
            bar.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(bar)
            let xOffset = -totalW / 2 + CGFloat(i) * (barW + gap) + barW / 2
            NSLayoutConstraint.activate([
                bar.centerXAnchor.constraint(equalTo: container.centerXAnchor, constant: xOffset),
                bar.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                bar.widthAnchor.constraint(equalToConstant: barW),
                bar.heightAnchor.constraint(equalToConstant: naturalHeights[i]),
            ])
            equalizerBars.append(bar)
        }
        equalizerContainer = container
    }

    func startEqualizer() {
        guard let container = equalizerContainer else { return }
        container.backgroundColor = AppColor.accent
        container.isHidden = false
        libraryImage.isHidden = true
        animationGifWebView.isHidden = true

        let maxScales: [Double] = [0.75, 1.0, 0.85, 0.55]
        for (i, bar) in equalizerBars.enumerated() {
            bar.layer.removeAllAnimations()
            let anim = CABasicAnimation(keyPath: "transform.scale.y")
            anim.fromValue = 0.2
            anim.toValue = maxScales[i]
            anim.duration = Double.random(in: 0.35...0.55)
            anim.beginTime = CACurrentMediaTime() + Double(i) * 0.09
            anim.autoreverses = true
            anim.repeatCount = .infinity
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bar.layer.add(anim, forKey: "equalizer")
        }
    }

    func stopEqualizer() {
        equalizerContainer?.isHidden = true
        libraryImage.isHidden = false
        for bar in equalizerBars {
            bar.layer.removeAllAnimations()
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
