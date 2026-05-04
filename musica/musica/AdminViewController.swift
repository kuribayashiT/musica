//
//  AdminViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2020/02/11.
//  Copyright © 2020 K.T. All rights reserved.
//

import UIKit
import Firebase

class AdminViewController: UIViewController {

    @IBOutlet weak var waitView: UIView!
    @IBOutlet weak var wardTable: UITableView!
    @IBOutlet weak var MVCollectView: UICollectionView!
    var candidateList:[candidateWd] = []
    var candidateMVList:[candidateMV] = []
    @IBOutlet weak var segment: UISegmentedControl!
    
    var DAY :[String] = []
    var COUNTRY = "ja"
    override func viewDidLoad() {
        super.viewDidLoad()
        wardTable.delegate = self
        wardTable.dataSource = self
        wardTable.isHidden = false
        MVCollectView.delegate = self
        MVCollectView.dataSource = self
        MVCollectView.isHidden = true
        
        wardTable.allowsMultipleSelection = true
        MVCollectView.allowsMultipleSelection = true
        self.DAY = []
        for i in 0 ..< 2 {
            self.DAY.append(_toStringWithDay(prev : i))
        }
        waitView.isHidden = false
        getRecommendWdCandidate()
        MVCollectView.register(UINib(nibName: "RecommendMVCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "mv")
    }
    @IBAction func crashTest(_ sender: Any) {
        fatalError()
    }
    /*******************************************************************
     データ取得の処理
     *******************************************************************/
    func getRecommendWdCandidate(){
//        var ref: DatabaseReference!
//        ref = Database.database().reference()
//        candidateList = []
//        var _count = 0
//        for _day in DAY {
//            ref.child("SEARCH").child(COUNTRY).child(_day).observeSingleEvent(of: .value, with: { (snapshot) in
//                let value = snapshot.value as? NSDictionary
//                _count = _count + 1
//                if value != nil {
//                    for _v in value! {
//                        var cd = candidateWd()
//                        cd.title = (_v.key as! String)
//                        let index = self.isExistWard(ward:cd.title!)
//                        if index != -1 {
//                            self.candidateList[index].num = self.candidateList[index].num + cd.num
//                        }else{
//                            let n = _v.value as? NSDictionary
//                            cd.num = n?["regist_num"] as? Int ?? 0
//                            self.candidateList.append(cd)
//                        }
//                    }
//                }
//                self.candidateList = self.candidateList.sorted(by: { (a, b) -> Bool in
//                    return a.num > b.num
//                })
//                if self.DAY.count == _count{
//                    self.wardTable.reloadData()
//                    self.waitView.isHidden = true
//                }
//            }) { (error) in
//                dlog(error.localizedDescription)
//            }
//        }
    }
    func getRecommendMVCandidate(){
//        var ref: DatabaseReference!
//        ref = Database.database().reference()
//        candidateMVList = []
//        var _count = 0
//        for _day in DAY {
//            ref.child("OKINIIRI").child(COUNTRY).child(_day).observeSingleEvent(of: .value, with: { (snapshot) in
//                let value = snapshot.value as? NSDictionary
//                _count = _count + 1
//                if value != nil {
//                    for _v in value! {
//                        var cd = candidateMV()
//                        cd.videoID = (_v.key as! String)
//                        let index = self.isExistVideoId(videoID:cd.videoID!)
//                        if index != -1 {
//                            self.candidateMVList[index].num = self.candidateMVList[index].num + cd.num
//                        }else{
//                            let n = _v.value as? NSDictionary
//                            cd.title = n?["title"] as? String ?? ""
//                            cd.imgUrl = n?["imageUrl"] as? String ?? ""
//                            cd.num = n?["regist_num"] as? Int ?? 0
//                            cd.time = n?["time"] as? String ?? ""
//                            self.candidateMVList.append(cd)
//                        }
//                    }
//                }
//                self.candidateMVList = self.candidateMVList.sorted(by: { (a, b) -> Bool in
//                    return a.num > b.num
//                })
//                if self.DAY.count == _count{
//                    self.MVCollectView.reloadData()
//                    self.waitView.isHidden = true
//                }
//            }) { (error) in
//                dlog(error.localizedDescription)
//            }
//        }
    }
    func isExistVideoId(videoID:String) -> Int{
        var index = 0
        for item in candidateMVList {
            if item.videoID == videoID{
                return index
            }
            index = index + 1
        }
        return -1
    }
    func isExistWard(ward:String) -> Int{
        var index = 0
        for item in candidateList {
            if item.title == ward{
                return index
            }
            index = index + 1
        }
        return -1
    }
    /*******************************************************************
     ボタンタップ時の処理
     *******************************************************************/
    @IBAction func loadDataBtnTapped(_ sender: Any) {
        waitView.isHidden = false
        if segment.selectedSegmentIndex == 0 {
            getRecommendWdCandidate()
        }else{
            getRecommendMVCandidate()
        }
    }
    @IBAction func countryBtnTapped(_ sender: Any) {
        let alert: UIAlertController = UIAlertController(title: "集計する国", message: "", preferredStyle:  UIAlertController.Style.actionSheet)
        let action1: UIAlertAction = UIAlertAction(title: "日本", style: UIAlertAction.Style.default, handler:{
            (action: UIAlertAction!) -> Void in
            self.COUNTRY = "ja"
        })
        let action2: UIAlertAction = UIAlertAction(title: "アメリカ", style: UIAlertAction.Style.default, handler:{
            (action: UIAlertAction!) -> Void in
            self.COUNTRY = "en"
        })
        let action3: UIAlertAction = UIAlertAction(title: "トルコ", style: UIAlertAction.Style.default, handler:{
            (action: UIAlertAction!) -> Void in
            self.COUNTRY = "tr"
        })
        let cancelAction: UIAlertAction = UIAlertAction(title: "cancel", style: UIAlertAction.Style.cancel, handler:{
            (action: UIAlertAction!) -> Void in
        })
        alert.addAction(action1)
        alert.addAction(action2)
        alert.addAction(action3)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
     }
     @IBAction func termBtnTApped(_ sender: Any) {
        let alert: UIAlertController = UIAlertController(title: "集計期間", message: "", preferredStyle:  UIAlertController.Style.actionSheet)
        let action1: UIAlertAction = UIAlertAction(title: "今日", style: UIAlertAction.Style.default, handler:{
            (action: UIAlertAction!) -> Void in
            self.DAY = []
            self.DAY.append(toStringWithDay())
        })
        let action2: UIAlertAction = UIAlertAction(title: "昨日", style: UIAlertAction.Style.default, handler:{
            (action: UIAlertAction!) -> Void in
            self.DAY = []
            self.DAY.append(toStringWithDay())
            self.DAY.append(_toStringWithDay(prev : 1))
        })
        let action3: UIAlertAction = UIAlertAction(title: "ここ３日間", style: UIAlertAction.Style.default, handler:{
            (action: UIAlertAction!) -> Void in
            self.DAY = []
            for i in 0 ..< 2 {
                self.DAY.append(_toStringWithDay(prev : i))
            }
        })
        let action4: UIAlertAction = UIAlertAction(title: "ここ１週間", style: UIAlertAction.Style.default, handler:{
            (action: UIAlertAction!) -> Void in
            self.DAY = []
            for i in 0 ..< 6 {
                self.DAY.append(_toStringWithDay(prev : i))
            }
        })
        let action5: UIAlertAction = UIAlertAction(title: "ここ一月", style: UIAlertAction.Style.default, handler:{
            (action: UIAlertAction!) -> Void in
            self.DAY = []
            for i in 0 ..< 29 {
                self.DAY.append(_toStringWithDay(prev : i))
            }
        })
        let cancelAction: UIAlertAction = UIAlertAction(title: "cancel", style: UIAlertAction.Style.cancel, handler:{
            (action: UIAlertAction!) -> Void in
        })
        alert.addAction(action1)
        alert.addAction(action2)
        alert.addAction(action3)
        alert.addAction(action4)
        alert.addAction(action5)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
     }
     @IBAction func decideSendBtnTapped(_ sender: Any) {
        if segment!.selectedSegmentIndex == 0 {
            var ref: DatabaseReference!
            ref = Database.database().reference()
            // おすすめ動画を登録
            ref.child("SEARCH").child(COUNTRY).child("NOW_RECOMMEND").removeValue()
            ref.child("SEARCH").child(COUNTRY).child("NOW_RECOMMEND").observeSingleEvent(of: .value, with: { (snapshot) in
                for _wd in self.candidateList {
                    if _wd.checkFlg {
                        ref.child("SEARCH").child(self.COUNTRY).child("NOW_RECOMMEND").child(_wd.title!).setValue([
                            "num": _wd.num
                        ])
                    }
                }
            })
        }else{
            var ref: DatabaseReference!
            ref = Database.database().reference()
            // おすすめ動画を登録
            ref.child("OKINIIRI").child(COUNTRY).child("NOW_RECOMMEND").removeValue()
            ref.child("OKINIIRI").child(COUNTRY).child("NOW_RECOMMEND").observeSingleEvent(of: .value, with: { (snapshot) in
                for _mv in self.candidateMVList {
                    if _mv.checkFlg {
                        ref.child("OKINIIRI").child(self.COUNTRY).child("NOW_RECOMMEND").child(_mv.videoID!).setValue([
                            "title": _mv.title,
                            "time": _mv.time,
                            "imagUrl": _mv.imgUrl
                        ])
                    }
                }
            })
        }
     }
     
     @IBAction func segmentTapped(_ sender: Any) {
         //セグメント番号で条件分岐させる
         switch (sender as AnyObject).selectedSegmentIndex {
         case 0:
            wardTable.isHidden = false
            MVCollectView.isHidden = true
         case 1:
            wardTable.isHidden = true
            MVCollectView.isHidden = false
         default:
             dlog("該当無し")
         }
     }

}
/*******************************************************************
 Ward Table時の処理
 *******************************************************************/
extension AdminViewController: UITableViewDataSource ,UITableViewDelegate{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return candidateList.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "adminwd", for: indexPath) as! AdminWDTableViewCell
        cell.wardLbl.text = candidateList[indexPath.row].title
        cell.countLbl.text = String(candidateList[indexPath.row].num)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        cell?.accessoryType = .checkmark
        candidateList[indexPath.row].checkFlg = true
    }
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at:indexPath)
        cell?.accessoryType = .none
        candidateList[indexPath.row].checkFlg = false
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
}
/*******************************************************************
 MV Collect時の処理
*******************************************************************/
extension AdminViewController :  UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return candidateMVList.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "mv", for: indexPath) as! RecommendMVCollectionViewCell
        cell.titleLabel.text = candidateMVList[indexPath.row].title
        cell.numlabel.text = String(candidateMVList[indexPath.row].num)
        cell.numlabel.isHidden = false
        cell.timeLabel.text = String(candidateMVList[indexPath.row].time!)
        let imgUrl: NSURL = NSURL(string: candidateMVList[indexPath.row].imgUrl!)!
        cell.imageView.sd_setImage(with: imgUrl as URL)
        if candidateMVList[indexPath.row].checkFlg {
            cell.checkmark.isHidden = false
        }else{
            cell.checkmark.isHidden = true
        }
        return cell
    }
    //  タップされた時
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! RecommendMVCollectionViewCell
        if candidateMVList[indexPath.row].checkFlg {
            candidateMVList[indexPath.row].checkFlg = false
            cell.checkmark.isHidden = true
        }else{
            candidateMVList[indexPath.row].checkFlg = true
            cell.checkmark.isHidden = false
        }
    }
}
