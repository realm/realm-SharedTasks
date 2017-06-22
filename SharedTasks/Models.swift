//
//  Models.swift
//  SharedTasks
//
//  Created by David Spector on 6/1/17.
//  Copyright © 2017 Realm. All rights reserved.
//

import Foundation
import CoreLocation

import Realm
import RealmSwift

private var realm: Realm!


// MARK: Person
class Person : Object {
    
    dynamic var id = ""
    dynamic var creationDate: Date?
    dynamic var lastSeenDate: Date?  // this gets set periodically and is used for presence
    dynamic var lastName = ""
    dynamic var firstName = ""
    dynamic var avatar : Data? // binary image data, stored as a PNG
    
    // Initializers, accessors & cet.
    override static func primaryKey() -> String? {
        return "id"
    }
    
    override static func ignoredProperties() -> [String] {
        return ["role"]
    }
    
    convenience init(realmIdentity: String?) {
        self.init()
        self.id = realmIdentity!
    }
    
    convenience init(realmIdentity: String?, firstName: String?, lastName: String?) {
        self.init()
        self.id = realmIdentity!
        self.firstName = firstName ?? ""
        self.lastName = lastName ?? ""
    }
    
    func fullName() -> String {
        return "\(firstName) \(lastName)"
    }
    
    
    class func createProfile() -> Person? {
        let commonRealm =  try! Realm(configuration: commonRealmConfig(user:SyncUser.current!))
        var profileRecord = commonRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", SyncUser.current!.identity!)).first
        if profileRecord == nil {
            try! commonRealm.write {
                profileRecord = commonRealm.create(Person.self, value:["id": SyncUser.current!.identity!, "creationDate": Date(),  "lastUpdated": Date()])
                commonRealm.add(profileRecord!, update: true)
            }
        }
        return profileRecord
    }
    
    
    class func getPersonForID(id: String?) -> Person? {
        guard id != nil else {
            return nil
        }
        let realm = try! Realm()
        let identityPredicate = NSPredicate(format: "id = %@", id!)
        return realm.objects(Person.self).filter(identityPredicate).first //get the person
    }
} // of Person




class Task : Object {
    dynamic var id = ""
    dynamic var createdBy = ""
    dynamic var lastUpdatedBy = ""
    dynamic var creationDate: Date?
    dynamic var lastUpdate: Date?
    dynamic var dueDate: Date?
    dynamic var taskTitle = ""
    dynamic var taskDetails = ""
    
    // Initializers, accessors & cet.
    override static func primaryKey() -> String? {
        return "id"
    }
    
} // of Task



