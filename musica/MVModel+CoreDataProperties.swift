//
//  MVModel+CoreDataProperties.swift
//  
//
//  Created by 栗林貴大 on 2017/09/02.
//
//

import Foundation
import CoreData


extension MVModel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MVModel> {
        return NSFetchRequest<MVModel>(entityName: "MVModel")
    }

    @NSManaged public var indicatoryNum: Int16
    @NSManaged public var musicLibraryName: String?
    @NSManaged public var thumbnailUrl: String?
    @NSManaged public var videoID: String?
    @NSManaged public var videoTitle: String?
    @NSManaged public var videoTime: String?

}
