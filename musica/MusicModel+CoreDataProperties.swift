//
//  MusicModel+CoreDataProperties.swift
//  
//
//  Created by 栗林貴大 on 2017/07/30.
//
//

import Foundation
import CoreData


extension MusicModel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MusicModel> {
        return NSFetchRequest<MusicModel>(entityName: "MusicModel")
    }

    @NSManaged public var albumTitle: String?
    @NSManaged public var artist: String?
    @NSManaged public var indicatoryNum: Int16
    @NSManaged public var lyric: String?
    @NSManaged public var musicLibraryName: String?
    @NSManaged public var trackTitle: String?
    @NSManaged public var url: String?
    @NSManaged public var artworkData: NSData?

}
