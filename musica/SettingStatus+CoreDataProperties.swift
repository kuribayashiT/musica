//
//  SettingStatus+CoreDataProperties.swift
//  
//
//  Created by 栗林貴大 on 2017/08/13.
//
//

import Foundation
import CoreData


extension SettingStatus {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SettingStatus> {
        return NSFetchRequest<SettingStatus>(entityName: "SettingStatus")
    }

    @NSManaged public var displayContentsNum: Int16
    @NSManaged public var latestCancelVersion: String?

}
