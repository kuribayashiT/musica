//
//  MusicLibraryModel+CoreDataProperties.swift
//  
//
//  Created by 栗林貴大 on 2017/07/24.
//
//

import Foundation
import CoreData


extension MusicLibraryModel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MusicLibraryModel> {
        return NSFetchRequest<MusicLibraryModel>(entityName: "MusicLibraryModel")
    }

    @NSManaged public var creationDate: NSDate?
    @NSManaged public var icomColorName: String?
    @NSManaged public var iconName: String?
    @NSManaged public var indicatoryNum: Int16
    @NSManaged public var lastModifiedDate: NSDate?
    @NSManaged public var musicLibraryName: String?
    @NSManaged public var trackNum: Int16
    @NSManaged public var musicModel: MusicModel?

}
