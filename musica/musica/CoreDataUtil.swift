//
//  CoreDataUtil.swift
//  musica
//
//  Created by 栗林貴大 on 2019/07/22.
//  Copyright © 2019 K.T. All rights reserved.
//

import Foundation
import CoreData
import Firebase

/// CoreData に保存された URL 文字列を解決する。
/// file:// スキームで保存先が存在しない場合、同一ファイル名を
/// 現在の Documents ディレクトリで再検索してコンテナ移行を吸収する。
private func resolvedFileURL(from stored: String) -> URL? {
    guard let url = URL(string: stored) else { return nil }
    guard url.scheme == "file" else { return url }          // ipod-library:// 等はそのまま
    if FileManager.default.fileExists(atPath: url.path) { return url }
    // ファイルが存在しない → コンテナUUIDが変わった可能性。ファイル名で再検索
    let filename = url.lastPathComponent
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let candidate = docs.appendingPathComponent(filename)
    return FileManager.default.fileExists(atPath: candidate.path) ? candidate : url
}

/*******************************************************************
 MusicLibraryの作成
 *******************************************************************/

//func registNewMusicLibrary(appdelegate:AppDelegate ,libraryName:String,trackList:[TrackData],progress:UIProgressView? = nil,vc:UIViewController? = nil) {
func registNewMusicLibrary(appdelegate:AppDelegate ,libraryName:String,trackList:[TrackData],progress:UIProgressView? = nil,vc:UIViewController? = nil ,completion: @escaping (_ rs : Bool)->Void) {
    // Music Library
    let tempContext: NSManagedObjectContext = NSManagedObjectContext.init(concurrencyType: .privateQueueConcurrencyType)
    tempContext.parent = appdelegate.managedObjectContext
    tempContext.perform {
        let musicLibraryModel:MusicLibraryModel = NSEntityDescription.insertNewObject(forEntityName: "MusicLibraryModel", into: tempContext) as! MusicLibraryModel
        musicLibraryModel.musicLibraryName = libraryName
        musicLibraryModel.trackNum = Int16(trackList.count)
        musicLibraryModel.creationDate = Date() as Date
        musicLibraryModel.iconName = "onpu_BL"
        musicLibraryModel.icomColorName = colorChoicesNameArray[0] // 実質使われてない。。。

        let fetchRequest:NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
        let fetchData = try! tempContext.fetch(fetchRequest)
        if(!fetchData.isEmpty){
            musicLibraryModel.indicatoryNum = Int16(fetchData.count)
        }else{
            musicLibraryModel.indicatoryNum = 0
        }
        
        do {
            try tempContext.save()
        } catch {
            completion(false)
        }
        
        for (index, musicData) in trackList.enumerated(){
            registNewMusic(appdelegate:appdelegate,tempContext:tempContext ,libraryName:libraryName,musicData:musicData,index:index, completion: {(_rs: Bool)  -> Void in
                if _rs {
                    CUSTOM_LYBRARY_NAME = ""
                    if progress != nil {
                        DispatchQueue.main.async {
                            progress!.setProgress( Float(index) / Float(trackList.count), animated: true)
                        }
                    }
                    if index == trackList.count - 1{
                        completion(true)
                    }
                }else{
                    completion(false)
                }
            })
        }
    }
}

// クラッシュ対策
private final class PersistanceContainerProvider  {
    var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Test")
        container.loadPersistentStores(completionHandler: { storeDescription, error in
            if let error = error as NSError? {
                //fatalError("Unable to load persistance store")
            }
        })
        return container
    }()
}
 // imageデータの変換の処理
func topng(img : UIImage) throws -> Data{
    do {
        var imageData = Data()
        imageData = img.pngData()! as Data
        return imageData
    }
}
/*******************************************************************
 MusicLibraryの更新
 *******************************************************************/
func updateMusicLibrary(appdelegate:AppDelegate ,oldLibraryName:String,newLibraryName:String,trackList:[TrackData],progress:UIProgressView? = nil,vc:UIViewController? = nil ,completion: @escaping (_ rs : Bool)->Void) {
    // ライブラリ名およびトラック数変更
    changeTrackList = trackList
    let tempContext: NSManagedObjectContext = NSManagedObjectContext.init(concurrencyType: .privateQueueConcurrencyType)
    tempContext.parent = appdelegate.managedObjectContext
    tempContext.perform {
        DispatchQueue.main.async {
            if changeMusicLibraryName(appdelegate:appdelegate,newName:newLibraryName,nowName:oldLibraryName,trackList:changeTrackList) == false{
                completion(false)
            }
        }
        for (index, musicData) in trackList.enumerated(){
            // すでに登録済みだったらスキップ
            if !sortTrackExist(tempContext:tempContext,checkUrl:String(describing: musicData.url!), musicLibraryName: newLibraryName, index: index){
                registNewMusic(appdelegate:appdelegate,tempContext:tempContext ,libraryName:newLibraryName,musicData:musicData,index:index, completion: {(_rs: Bool)  -> Void in
                    if _rs {
                        CUSTOM_LYBRARY_NAME = ""
                    }else{
                        completion(false)
                    }
                })
            }
            if progress != nil {
                DispatchQueue.main.async {
                    progress!.setProgress( Float(index + changeTrackList.count) / Float(changeTrackList.count * 2), animated: true)
                }
            }
            if index == trackList.count - 1{
                completion(true)
            }
        }
    }
}
func registNewMusic(appdelegate:AppDelegate ,tempContext:NSManagedObjectContext ,libraryName:String,musicData:TrackData,index:Int, completion : @escaping (_ rs : Bool)->Void) {

    let MusicModelentity = NSEntityDescription.entity(forEntityName: "MusicModel", in: tempContext)
    let musiclyModel = NSManagedObject(entity:MusicModelentity!,insertInto:tempContext) as! MusicModel
    musiclyModel.musicLibraryName = libraryName
    musiclyModel.albumTitle = musicData.albumName
    musiclyModel.artist = musicData.artist
    musiclyModel.lyric = musicData.lyric
    musiclyModel.trackTitle = musicData.title
    musiclyModel.url = String(describing: musicData.url!)
    musiclyModel.indicatoryNum = Int16(index)
    if musicData.artworkImg == nil {
        musiclyModel.artworkData = nil
    } else{
        do{
            try musiclyModel.artworkData = topng(img:musicData.artworkImg!)
        }catch{
            musiclyModel.artworkData = nil
        }
    }
    do{
        try tempContext.save()
        completion(true)
    }catch{
        completion(false)
    }
}
/*******************************************************************
 全MusicLibraryのデータを読み込む(最新化)
 *******************************************************************/
func getNowMusicLibraryData() -> [(musicLibraryName:String, trackNum:Int , iconName : String , iconColorName : String)]{
    var mLibraryList: [(musicLibraryName:String, trackNum:Int , iconName : String , iconColorName : String)] = []
    let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
    let context:NSManagedObjectContext = appDelegate.managedObjectContext
    let fetchRequest:NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "indicatoryNum", ascending: true)]
    var _:Array<String> = []
    let fetchData = try! context.fetch(fetchRequest)
    if(!fetchData.isEmpty){
        for i in 0..<fetchData.count{
            mLibraryList.append((musicLibraryName:fetchData[i].musicLibraryName! ,trackNum:Int(fetchData[i].trackNum), iconName:fetchData[i].iconName! , iconColorName : fetchData[i].icomColorName!))
            // 登録ライブラリ数をUserPropatyにSet
            if i == 0{
                Analytics.setUserProperty(String(fetchData[i].trackNum), forName: fetchData[i].musicLibraryName!)
            }
        }
        // 登録ライブラリ数をUserPropatyにSet
        Analytics.setUserProperty(String(fetchData.count - 1), forName: "登録音楽ライブラリ数")
    }
    return mLibraryList
}

/*******************************************************************
 MusicLibraryのTrackデータを読み込む
 *******************************************************************/
func getMusicLibraryTrackData(musicLibraryName:String) -> [TrackData]{
    var trackData : [TrackData] = []
    let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
    let context:NSManagedObjectContext = appDelegate.managedObjectContext
    let fetchRequest:NSFetchRequest<MusicModel> = MusicModel.fetchRequest()
    let predicate = NSPredicate(format:"%K = %@","musicLibraryName",musicLibraryName)
    fetchRequest.predicate = predicate
    /* TODO indicatoryNum って使う？？*/
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "indicatoryNum", ascending: true)]
    let fetchData = try! context.fetch(fetchRequest)
    if(!fetchData.isEmpty){
        for i in 0..<fetchData.count{
            trackData.append(TrackData())
            trackData[i].albumName = fetchData[i].albumTitle!
            trackData[i].title = fetchData[i].trackTitle!
            trackData[i].artist = fetchData[i].artist!
            trackData[i].url = resolvedFileURL(from: fetchData[i].url!)
            trackData[i].lyric = fetchData[i].lyric!
            
            if fetchData[i].artworkData == nil {
                trackData[i].artworkImg = nil
            } else {
                trackData[i].artworkImg = UIImage(data: fetchData[i].artworkData! as Data)
            }
        }
    }
    return trackData
}
/*******************************************************************
 MusicLibraryの名前被りチェック
 *******************************************************************/
func checkMusicLibraryNameExistence(checkName:String) -> Bool{
    let appDelegateC:AppDelegate = UIApplication.shared.delegate as! AppDelegate
    let contextC:NSManagedObjectContext = appDelegateC.managedObjectContext
    let fetchRequestC:NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
    let fetchDataC = try! contextC.fetch(fetchRequestC)
    if(!fetchDataC.isEmpty){
        for i in 0..<fetchDataC.count{
            if fetchDataC[i].musicLibraryName == checkName {
                return true
            }
        }
    }
    if checkName == localText(key:"home_okiniiri_title"){
        return true
    }
    return false
}
/*******************************************************************
 Trackの削除
 *******************************************************************/
func deleteTrack(appdelegate:AppDelegate,deleteTrackUrl:String,musicLibraryName:String) -> Bool{
    
    //let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
    let musicContext:NSManagedObjectContext = appdelegate.managedObjectContext
    let musicFetchRequest:NSFetchRequest<MusicModel> = MusicModel.fetchRequest()
    
    var musicPredicate = [NSPredicate]()
    musicPredicate.append(NSPredicate(format:"%K = %@","url",deleteTrackUrl))
    musicPredicate.append(NSPredicate(format:"%K = %@","musicLibraryName",musicLibraryName))
    musicFetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: musicPredicate)
    let musicFetchData = try! musicContext.fetch(musicFetchRequest)
    if(!musicFetchData.isEmpty){
        for i in 0..<musicFetchData.count{
            let deleteObject = musicFetchData[i] as MusicModel
            musicContext.delete(deleteObject)
        }
        do{
            try musicContext.save()
        }catch{
            return false
        }
    }
    return true
}
/*******************************************************************
 Track存在確認
 *******************************************************************/
func checkTrackExist(appdelegate:AppDelegate,checkUrl:String,musicLibraryName:String) -> Bool{
    let contextT:NSManagedObjectContext = appdelegate.managedObjectContext
    let fetchRequestT:NSFetchRequest<MusicModel> = MusicModel.fetchRequest()
    var predicates = [NSPredicate]()
    predicates.append(NSPredicate(format:"%K = %@","url",checkUrl))
    predicates.append(NSPredicate(format:"%K = %@","musicLibraryName",musicLibraryName))
    fetchRequestT.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    let fetchDataT = try! contextT.fetch(fetchRequestT)
    if(fetchDataT.isEmpty){
        return false
    }else{
        return true
    }
}
/*******************************************************************
 Track順番入れ替え
 *******************************************************************/
func sortTrackExist(tempContext:NSManagedObjectContext,checkUrl:String,musicLibraryName:String,index:Int) -> Bool{
    let fetchRequestT:NSFetchRequest<MusicModel> = MusicModel.fetchRequest()
    var predicates = [NSPredicate]()
    predicates.append(NSPredicate(format:"%K = %@","url",checkUrl))
    predicates.append(NSPredicate(format:"%K = %@","musicLibraryName",musicLibraryName))
    fetchRequestT.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    let fetchDataT = try! tempContext.fetch(fetchRequestT)
    if(fetchDataT.isEmpty){
        return false
    }else{
        do{
            fetchDataT[0].indicatoryNum = Int16(index)
            try tempContext.save()
        }catch{
            // エラーだったらスキップさせる
            return true
        }
        return true
    }
}
/*******************************************************************
 MusicLibraryの名前変更
 *******************************************************************/
func changeMusicLibraryName(appdelegate:AppDelegate,newName:String,nowName:String,trackList:[TrackData] = []) -> Bool{
    // MusicLibraryModel を更新する
    let context:NSManagedObjectContext = appdelegate.managedObjectContext
    let fetchRequest:NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
    let predicate = NSPredicate(format:"%K = %@","musicLibraryName",nowName)
    fetchRequest.predicate = predicate
    let fetchData = try! context.fetch(fetchRequest)
    if(!fetchData.isEmpty){
        for i in 0..<fetchData.count{
            fetchData[i].musicLibraryName = newName
            fetchData[i].lastModifiedDate = Date() as Date
            if trackList.count != 0 {
                fetchData[i].trackNum = Int16(trackList.count)
            }
        }
        do{
            try context.save()
        }catch{
            return false
        }
    }
    // MusicModel を更新する
    let contextT:NSManagedObjectContext = appdelegate.managedObjectContext
    let fetchRequestT:NSFetchRequest<MusicModel> = MusicModel.fetchRequest()
    let predicateT = NSPredicate(format:"%K = %@","musicLibraryName",nowName)
    fetchRequestT.predicate = predicateT
    let fetchDataT = try! contextT.fetch(fetchRequestT)
    var deleteNum = 0
    if(!fetchDataT.isEmpty){
        for i in 0..<fetchDataT.count{
            fetchDataT[i].musicLibraryName = newName
            if trackList.count != 0 {
                // 未選択なTrackは削除
                if serchTrackInList(trackList:trackList,keyUrl:fetchDataT[i].url!) == false{
                    if NowPlayingMusicLibraryData.nowPlaying != NOW_NOT_PLAYING && nowName == NowPlayingMusicLibraryData.nowPlayingLibrary{
                        // 再生中だった場合は曲を止める
                        if SHUFFLE_FLG {
                            if NowPlayingMusicLibraryData.trackDataShuffled[NowPlayingMusicLibraryData.nowPlaying].url! == URL(string: fetchDataT[i].url!) {
                                NowPlayingMusicLibraryData.nowPlaying = NOW_NOT_PLAYING
                                audioPlayer = nil
                                NowPlayingMusicLibraryData.musicLibraryCode = NOW_NONE_MUSICLIBRARY_CODE
                            }
                        }else{
                            if NowPlayingMusicLibraryData.trackData[NowPlayingMusicLibraryData.nowPlaying].url! == URL(string: fetchDataT[i].url!) {
                                NowPlayingMusicLibraryData.nowPlaying = NOW_NOT_PLAYING
                                audioPlayer = nil
                                NowPlayingMusicLibraryData.musicLibraryCode = NOW_NONE_MUSICLIBRARY_CODE
                            }
                        }
                    }
                    let deleteObject = fetchDataT[i] as MusicModel
                    contextT.delete(deleteObject)
                    deleteNum = deleteNum + 1
                }
            }
        }
        do{
            try contextT.save()
        }catch{
            return false
        }
    }
    return true
}
func serchTrackInList(trackList:[TrackData],keyUrl:String) -> Bool{
    for track in trackList{
        if track.url == URL(string: keyUrl){
            return true
        }
    }
    return false
}
/*******************************************************************
 MusicLibrary削除時の処理
 *******************************************************************/
func deleteMusicLibrary(deleteMusicLibraryName:String) -> Bool{
    //MusicLibraryを削除する
    let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
    let musicContext:NSManagedObjectContext = appDelegate.managedObjectContext
    let musicFetchRequest:NSFetchRequest<MusicModel> = MusicModel.fetchRequest()
    let musicPredicate = NSPredicate(format:"%K = %@","musicLibraryName",deleteMusicLibraryName)
    musicFetchRequest.predicate = musicPredicate
    let musicFetchData = try! musicContext.fetch(musicFetchRequest)
    
    //MusicLibraryのデータを削除する
    let musicLibraryContext:NSManagedObjectContext = appDelegate.managedObjectContext
    let musicLibraryFetchRequest:NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
    let musicLibraryPredicate = NSPredicate(format:"%K = %@","musicLibraryName",deleteMusicLibraryName)
    musicLibraryFetchRequest.predicate = musicLibraryPredicate
    let musicLibraryFetchData = try! musicLibraryContext.fetch(musicLibraryFetchRequest)
    
    if(!musicFetchData.isEmpty){
        for i in 0..<musicFetchData.count{
            let deleteObject = musicFetchData[i] as MusicModel
            musicContext.delete(deleteObject)
        }
    }
    if(!musicLibraryFetchData.isEmpty){
        for i in 0..<musicLibraryFetchData.count{
            let deleteObject = musicLibraryFetchData[i] as MusicLibraryModel
            musicLibraryContext.delete(deleteObject)
        }
    }
    do{
        try musicContext.save()
        try musicLibraryContext.save()
        return true
    }catch{
        return false
    }
}
