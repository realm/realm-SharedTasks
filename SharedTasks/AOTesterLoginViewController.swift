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
                    
                    if user.isAdmin == true {
                        // this will make it so non-Admins can log in and see the index realm (and set their own profile record)
                        self.setupDefaultGlobalPermissions(user: user)
                    }
                    
                    if self.useAsyncOpen == true {
                        Realm.asyncOpen(configuration: commonRealmConfig(user:SyncUser.current!)) { realm, error in
                            if let realm = realm {
                                
                                Realm.Configuration.defaultConfiguration = commonRealmConfig(user:SyncUser.current!)
                                self.thePersonRecord = Person.createProfile()
                                
                                // then dismiss the login view, and...
                                self.loginViewController!.dismiss(animated: true, completion: nil)
                                
                                // hop right into the main view for the app
                                self.performSegue(withIdentifier: Constants.kLoginToMainView, sender: nil)
                                
                            } else if let error = error {
                                print("Error on return from AsyncOpen(): \(error)")
                            }
                        } // of asyncOpen()
                    } else {
                        let realm = try! Realm(configuration:commonRealmConfig(user:SyncUser.current!))
                        Realm.Configuration.defaultConfiguration = commonRealmConfig(user:SyncUser.current!)
                        self.thePersonRecord = Person.createProfile()
                        
                        // then dismiss the login view, and...
                        self.loginViewController!.dismiss(animated: true, completion: nil)
                        
                        // hop right into the main view for the app
                        self.performSegue(withIdentifier: Constants.kLoginToMainView, sender: nil)
                    }
                    
                } // of main queue dispatch
            }// of login controller
            
            present(loginViewController, animated: true, completion: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    
    
    func setupDefaultGlobalPermissions(user: SyncUser?) {
        
        let managementRealm = try! user!.managementRealm()
        let theURL = Constants.commonRealmURL.absoluteString
        
        let permissionChange = SyncPermissionChange(realmURL: theURL,    // The remote Realm URL on which to apply the changes
            userID: "*",       // The user ID for which these permission changes should be applied
            mayRead: true,     // Grant read access
            mayWrite: true,    // Grant write access
            mayManage: false)  // Grant management access
        
        token = managementRealm.objects(SyncPermissionChange.self).filter("id = %@", permissionChange.id).addNotificationBlock { notification in
            if case .update(let changes, _, _, _) = notification, let change = changes.first {
                // Object Server processed the permission change operation
                switch change.status {
                case .notProcessed:
                    print("not processed.")
                case .success:
                    print("succeeded.")
                case .error:
                    print("Error.")
                }
                print("change notification: \(change.debugDescription)")
            }
        }
        
        try! managementRealm.write {
            print("Launching permission change request id: \(permissionChange.id)")
            managementRealm.add(permissionChange)
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
