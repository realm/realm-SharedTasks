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
//  AOTesterLoginViewController.swift
//  AsyncOpenTester
//
//  Created by David Spector on 6/1/17.
//  Copyright © 2017 Realm. All rights reserved.
//

import UIKit
import RealmSwift
import RealmLoginKit

class AOTesterLoginViewController: UIViewController {
    var loginViewController: LoginViewController!
    var token: NotificationToken!
    var myIdentity = SyncUser.current?.identity!
    var thePersonRecord: Person?
    
    let useAsyncOpen = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        loginViewController = LoginViewController(style: .lightOpaque)
        loginViewController.isServerURLFieldHidden = false
        loginViewController.isRegistering = true
        
        if (SyncUser.current != nil) {
            // yup - we've got a stored session, so just go right to the UITabView
            Realm.Configuration.defaultConfiguration = commonRealmConfig(user:SyncUser.current!)
            performSegue(withIdentifier: Constants.kLoginToMainView, sender: self)
        } else {
            // show the RealmLoginKit controller
            if loginViewController!.serverURL == nil {
                loginViewController!.serverURL = Constants.syncAuthURL.absoluteString
            }
            
            // Set a closure that will be called on successful login
            loginViewController.loginSuccessfulHandler = { user in
                DispatchQueue.main.async {
                    
                    Realm.asyncOpen(configuration: commonRealmConfig(user:SyncUser.current!)) { realm, error in
                        if let realm = realm {
                            
                            if SyncUser.current?.isAdmin == true { // set the common realm so all users can read/write it
                                self.setPermissionForRealm(realm, accessLevel: .write, personID: "*" )  // we, as an admin are granting global read/write to the common realm
                            }
                            
                            Realm.Configuration.defaultConfiguration = commonRealmConfig(user:SyncUser.current!)
                            let commonRealm =  try! Realm()
                            if let profileRecord = commonRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", SyncUser.current!.identity!)).first {
                                try! commonRealm.write {
                                    profileRecord.lastSeenDate = Date()
                                }
                            } else {
                                self.thePersonRecord = Person.createProfile()
                            }
                            
                            // then dismiss the login view, and...
                            self.loginViewController!.dismiss(animated: true, completion: nil)
                            
                            // hop right into the main view for the app
                            self.performSegue(withIdentifier: Constants.kLoginToMainView, sender: nil)
                            
                        } else if let error = error {
                            print("Error on return from AsyncOpen(): \(error)")
                        }
                    } // of asyncOpen()
                    
                } // of main queue dispatch
            }// of login controller
            
            present(loginViewController, animated: true, completion: nil)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
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
    
    
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}
