//
//  RealmUtils.swift
//  SharedTasks
//
//  Created by David Spector on 6/21/17.
//  Copyright © 2017 Realm. All rights reserved.
//

import Foundation
import RealmSwift


func setPermissionForRealm(_ realm: Realm?, accessLevel: SyncAccessLevel, personID: String) {
    if let realm = realm {
        let permission = SyncPermissionValue(realmPath: realm.configuration.syncConfiguration!.realmURL.path,  // The remote Realm path on which to apply the changes
            userID: personID,           // The user ID for which these permission changes should be applied, or "*" for wildcard
            accessLevel: accessLevel)   // The access level to be granted
        SyncUser.current?.applyPermission(permission) { error in
            if let error = error {
                print("Error when attempting to set permissions: \(error.localizedDescription)")
                return
            } else {
                print("Permissions successfully set")
            }
        }
    }
}



func setPermissionForRealmPath(_ path: String, accessLevel: SyncAccessLevel, personID: String) {
    let permission = SyncPermissionValue(realmPath: path,  // The remote Realm path on which to apply the changes
        userID: personID,           // The user ID for which these permission changes should be applied, or "*" for wildcard
        accessLevel: accessLevel)   // The access level to be granted
    SyncUser.current?.applyPermission(permission) { error in
        if let error = error {
            print("Error when attempting to set permissions: \(error.localizedDescription)")
            return
        } else {
            print("Permissions successfully set")
        }
    }
    
}


