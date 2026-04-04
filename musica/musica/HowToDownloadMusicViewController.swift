//
//  HowToDownloadMusicViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2020/08/14.
//  Copyright © 2020 K.T. All rights reserved.
//

import UIKit

var pageC: UIPageControl!

class HowToDownloadMusicViewController: UIViewController {
    @IBOutlet weak var frameView: UIView!
    @IBOutlet weak var clearBtn: UIButton!
    weak var xibView: UIView!
    @IBOutlet weak var pageCollectView: UICollectionView!
    @IBOutlet weak var pageCntl: UIPageControl!
    override func viewDidLoad() {
        super.viewDidLoad()
        pageC = pageCntl
        
        // エフェクトの種類を設定
        view.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0)
        let visualEffectView = UIVisualEffectView(frame: view.frame)
        visualEffectView.effect = UIBlurEffect(style: .dark)
        visualEffectView.frame = view.frame
        view.insertSubview(visualEffectView, at: 0)
        
        // セルの大きさを設定
        let layout = CarouselCollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 300, height: 450)
        layout.scrollDirection = .horizontal
        let hoM = (myAppFrameSize.width - 300)/2
        layout.sectionInset = UIEdgeInsets(top: 0, left: hoM, bottom: 0, right: hoM)
        pageCollectView.collectionViewLayout = layout
        pageCollectView.decelerationRate = .fast
        clearBtn.setTitle(localText(key:"trans_btn_clear"),for: .normal)
    }
    
    @IBAction func closeBtnTapped(_ sender: Any) {
        self.dismiss(animated: true, completion:nil)
    }
}
extension HowToDownloadMusicViewController: UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 3
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "page1", for: indexPath) as! HowToUseCollectionViewCell
        cell.tag = indexPath.row
        switch indexPath.row {
        case 0:
            cell.imgView.image = UIImage(named: "iPhone10_home")!
            cell.lbl.text = localText(key:"how_to_download_page1")
        case 1:
            cell.imgView.image = UIImage(named: "iPhone10_music")!
            cell.lbl.text = localText(key:"how_to_download_page2")
        case 2:
            cell.imgView.image = UIImage(named: "iPhone10_iTunes")!
            cell.lbl.text = localText(key:"how_to_download_page3")
        default:break
        }
        return cell
    }
    // Cellのサイズを画面サイズに合わせる
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 300, height: 450)
    }

}
final class CarouselCollectionViewFlowLayout: UICollectionViewFlowLayout {
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView = collectionView else { return .zero }
        let pageWidth = itemSize.width + minimumLineSpacing
        let currentPage = collectionView.contentOffset.x / pageWidth

        if abs(velocity.x) > 0.2 {
            let nextPage = (velocity.x > 0) ? ceil(currentPage) : floor(currentPage)
            pageC.currentPage = Int(nextPage)
            return CGPoint(x: nextPage * pageWidth, y: proposedContentOffset.y)
        } else {
            let nextPage = (velocity.x > 0) ? ceil(currentPage) : floor(currentPage)
            pageC.currentPage = Int(nextPage)
            return CGPoint(x: round(currentPage) * pageWidth, y: proposedContentOffset.y)
        }
    }
}
