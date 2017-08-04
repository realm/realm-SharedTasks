////////////////////////////////////////////////////////////////////////////
//
// Copyright 2017 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////
//
//  Constants.swift
//  SharedTasks
//
//  Created by David Spector on 6/1/17.
//  Copyright © 2017 Realm. All rights reserved.
//

import Foundation
import RealmSwift




struct Constants {
    
    static let kDefaultRealmNamePrefskey            = "defaultRealmPreference"
    static let kLoginToMainView                     = "loginToMainViewSegue"
    static let kExitToLoginViewSegue                = "segueToLogin"
    static let kViewToNewTaskSegue                  = "viewToNewTaskSegue"
    static let kViewtoDetailsSegue                  = "viewtoDetailsSegue"
    static let kMainToPermissionsSegue              = "mainToPermissionsSegue"
    
    static let defaultSyncHost                      = "127.0.0.1"
    static let syncRealmPath                        = "SharedTasks"
    static let privateRealm                         = "MyTasks"
    static let ApplicationName                      = "SharedTasks"

    static let syncAuthURL                          = URL(string: "http://\(defaultSyncHost):9080")!
    static let syncServerURL                        = URL(string: "realm://\(defaultSyncHost):9080/\(ApplicationName)-\(syncRealmPath)")
    static let commonRealmURL                       = URL(string: "realm://\(defaultSyncHost):9080/\(ApplicationName)-CommonRealm")!
    
    static let myTasksRealmURL                      = URL(string: "realm://\(defaultSyncHost):9080/~/\(privateRealm)")!

}

// this propbably could be put in a sytand-alone utilites file... but this is just a debugging demo. soo.......
func commonRealmConfig(user: SyncUser) -> Realm.Configuration  {
    let config = Realm.Configuration(syncConfiguration: SyncConfiguration(user: user, realmURL: Constants.commonRealmURL), objectTypes: [Person.self])
    return config
}


func privateTasksRealmConfigforUser(user: SyncUser) -> Realm.Configuration  {
    var config: Realm.Configuration!
    if user.identity == SyncUser.current?.identity! {
        config = Realm.Configuration(syncConfiguration: SyncConfiguration(user: user, realmURL: Constants.myTasksRealmURL), objectTypes: [Task.self])
    } else {
        let targetURLstring = Constants.myTasksRealmURL.absoluteString.replacingOccurrences(of: "~", with: user.identity!)
        config = Realm.Configuration(syncConfiguration: SyncConfiguration(user: user, realmURL: URL(string: targetURLstring)!), objectTypes: [Task.self])
   
    }
    return config
}

// Note: We don't need a special config accessor for the on-demand realms this app creates - the RealmIndexEntry class has a getter that returns the Realm
//      for it's object. 


