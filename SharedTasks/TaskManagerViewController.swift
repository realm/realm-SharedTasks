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
//  TaskManagerViewController.swift
//  SharedTasks
//
//  Created by David Spector on 6/9/17.
//  Copyright © 2017 Realm. All rights reserved.
//

import Foundation
import UIKit

import RealmSwift
import Eureka
import ImageRow
import Alertift
import PKHUD

extension UIColor {
    
    class func fromHex(hexString: String, alpha : Float = 1.0) -> UIColor {
        var newColor = UIColor.clear // this compensates for a bug in Swift2.x
        let scan = Scanner(string: hexString)
        var hexValue : UInt32 = 0
        if scan.scanHexInt32(&hexValue) {
            let r : CGFloat = CGFloat( hexValue >> 16 & 0x0ff) / 255.0
            let g : CGFloat = CGFloat( hexValue >> 8 & 0x0ff) / 255.0
            let b : CGFloat = CGFloat( hexValue      & 0x0ff) / 255.0
            newColor = UIColor(red: r , green: g,	blue:  b , alpha: CGFloat(alpha))
        }
        
        return newColor
    }
}

// Start-Example: "Examine-Permission-Results"
extension SyncPermissionResults {
    /// get access level for a given user realm for a specificed path
    ///
    /// - Parameters:
    ///   - userID: the target user identity string
    ///   - realmPath: the path of the realm
    /// - Returns: A SyncAccessLevel value
    func accessLevelForUser(_ targetUserID: String, realmPath: String) -> SyncAccessLevel {
        var rv: SyncAccessLevel = .none
        for permission in self {
            if permission.userId! == targetUserID && permission.path == realmPath {
                rv = permission.accessLevel
            }
        }
        return rv
    }
}
// End-Example: "Examine-Permission-Results"

// Start-Example: "Human-Readable-Access-string"
extension SyncAccessLevel {
    /// Get human readable string for sync access level
    ///
    /// - Returns: Simple description of acces level
    func toText() -> String {
        var rv = "No Access"
        switch (self) {
        case .none:
            rv = "No Access"
        case .read:
            rv = "Read-Only Access"
        case .write:
            rv = "Read/Write Access"
        case .admin:
            rv = "Admin"
        }
        return rv
    }
}
// End-Example: "Human-Readable-Access-string"

extension SyncPermissionValue {
    func decode(peopleRealm: Realm) -> String {
        var rv = ""
        var targetUserString: String?
        
        let targetUserId = self.path.replacingOccurrences(of: "MyTasks", with: "").replacingOccurrences(of: "/", with: "")
        if let tmpTargetPerson = peopleRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", targetUserId)).first {
            targetUserString = tmpTargetPerson.fullName()
        }

        
        if let person = peopleRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", self.userId!)).first {
            rv = "\(person.fullName()) (\(self.userId!)) has \(self.accessLevel.toText()) to \(targetUserString != nil ? "\(targetUserString!)'s" : "") Realm at \(self.path)\n"
        } else {
            rv = "\(self.userId!) has \(self.accessLevel.toText()) to the Realm at \(self.path)\n"
        }
        return rv
    }
}

class TaskManagerViewController: FormViewController {
    
    let commonRealm = try! Realm(configuration: commonRealmConfig(user: SyncUser.current!)) // the realm the holds the Person objects
    var myPersonRecord: Person?
    var people: Results<Person>?
    var tasks: Results<Task>?
    var myPermissions: SyncPermissionResults?                   // this is a list fo realms the current user has access to - will need to be periodically refreshed
    var myTaskRealm: Realm?                                     // this is mly task realm, kept around since is probably tyhe one we'l use most
    var currentRealm: Realm?                                    // this is the current traget realm - might besomeone else's tasks
    var currentTaskNotificationToken: NotificationToken?        // so we are always looked for changes in the currrent tasks realm
    var peopleNotificationToken: NotificationToken?             // So we get any notifications about peple added to or removed from the syste
    var selectedRealmName: String?                              // the name of the user whose realm we are displaying
    
    let permissionsDidUpdateNotification = Notification.Name("permissionsDidUpdateNotification")
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        self.navigationItem.title = NSLocalizedString("Shared Tasks Demo", comment: "Shared Tasks Demo")

        NotificationCenter.default.addObserver(self, selector: #selector(TaskManagerViewController.reloadUsersSection), name: self.permissionsDidUpdateNotification, object: nil)
        self.getPermissions()                           // fire this off ASAP - might take a moment to complete
        people = commonRealm.objects(Person.self)       // get all the people in the system
        myPersonRecord = people?.filter(NSPredicate(format: "id = %@", SyncUser.current!.identity!)).first
        self.loadForm()
        
        
        // start with our own task list.
        self.openTasksForUser(SyncUser.current!)
        
    } // of viewDidLoad
    
    
    override func viewWillAppear(_ animated: Bool) {
        self.getPermissions() // ger permsissions again to catch the case where we are returning from either some other view controller
        self.reloadTaskSection()
        self.reloadUsersSection()
        self.setupPeopleNotification()
        self.setupTasksNotification()
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self, name: self.permissionsDidUpdateNotification, object: nil);
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    // MARK: - Form & Form Section Management
    func loadForm() {
        form
            +++ Section("Your Profile Info")
            <<< ImageRow() { row in
                
                row.title = NSLocalizedString("Profile Image", comment: "profile image")
                row.sourceTypes = [.PhotoLibrary, .SavedPhotosAlbum, .Camera]
                row.clearAction = .yes(style: UIAlertActionStyle.destructive)
                }.cellSetup({ (cell, row) in
                    
                    if self.myPersonRecord?.avatar == nil {
                        row.value = UIImage(named: "Circled User Male_30")
                    } else {
                        let imageData = self.myPersonRecord?.avatar!
                        row.value = UIImage(data:imageData! as Data)!       //  this image row for Eureka seems to scale for us.  (was:  .scaleToSize(size: profileImage!.frame.size)  )
                    }
                }).onChange({ (row) in
                    try! self.commonRealm.write {
                        if row.value != nil {
                            let resizedImage = row.value!.resizeImage(targetSize: CGSize(width: 128, height: 128))
                            self.myPersonRecord?.avatar = UIImagePNGRepresentation(resizedImage) as Data?
                        } else {
                            self.myPersonRecord?.avatar = nil
                            row.value = UIImage(named: "Circled User Male_30")
                        }
                    }
                })
            <<< TextRow(){ row in
                row.title = NSLocalizedString("First Name", comment:"First Name")
                row.placeholder = "First name"
                if self.myPersonRecord!.firstName != "" {
                    row.value = self.myPersonRecord?.firstName ?? "not set"
                }
                }.onChange({ (row) in
                    try! self.commonRealm.write {
                        if row.value != nil {
                            self.myPersonRecord!.firstName = row.value!
                        } else {
                            self.myPersonRecord!.firstName = ""
                        }
                    }
                })
            <<< TextRow(){ row in
                row.title = NSLocalizedString("Last Name", comment:"Last name")
                row.placeholder = NSLocalizedString("Last name", comment: "Last Name")
                if self.myPersonRecord!.lastName != "" {
                    row.value = self.myPersonRecord!.lastName
                }
                }.onChange({ (row) in
                    try! self.commonRealm.write {
                        if row.value != nil {
                            self.myPersonRecord!.lastName = row.value!
                        } else {
                            self.myPersonRecord!.lastName = ""
                        }
                    }
                })
            
            +++ Section("App Actions")
            <<< ButtonRow(){ row in
                row.title = NSLocalizedString("Set Permissions on My Task List...", comment: "")
                }.onCellSelection({ (sectionName, rowName) in
                    self.showPermissionSelector()
                })
            <<< ButtonRow(){ row in
                row.title = NSLocalizedString("Logout", comment: "")
                }.onCellSelection({ (sectionName, rowName) in
                    self.handleLogoutPressed(sender: self)
                })
            
            +++ Section("My Tasks...") { section in
                section.tag = "TaskSection"
        }
        self.reloadTaskSection()
        
        
        self.form   +++ Section("User Task Lists (& your access)\nTap to Switch Lists") { section in
            section.tag = "Users"
        }
        self.reloadUsersSection()
        
    }
    
    
    
    
    
    func reloadTaskSection() {
        if let section = self.form.sectionBy(tag: "TaskSection") {
            if section.count > 0 {
                self.currentTaskNotificationToken?.stop()
                self.currentTaskNotificationToken = nil
                section.removeAll()
            }
            if self.currentRealm != nil {
                let targetUserID = currentRealm!.configuration.syncConfiguration!.realmURL.relativePath.replacingOccurrences(of: "MyTasks", with: "").replacingOccurrences(of: "/", with: "")
                let username = self.fullNameForUserID(targetUserID) //sectionTitleForUser(currentRealm?.configuration.syncConfiguration?.user) ?? "Unknown User"
                section.header?.title = "\(username)'s Tasks..."
            } else {
                section.header?.title = "Tasks"
            }
            if self.tasks != nil {
                for task in self.tasks! {
                    section <<< TextRow(){ row in
                        row.disabled = true
                        row.tag = task.id
                        }.cellSetup({ (cell, row) in
                            row.title = task.taskTitle
                        })
                        .onCellSelection({ (cell, row) in
                            let personId = self.currentRealm?.configuration.syncConfiguration?.user.identity!   //the person ID of the realm we're checking access to...
                            let accessLevel =  self.myPermissions?.accessLevelForUser(SyncUser.current!.identity!, realmPath: Constants.myTasksRealmURL.relativePath.replacingOccurrences(of: "~", with: personId!))
                            let dict = ["taskID": row.tag!, "accessLevel": accessLevel!] as [String : Any]
                            self.performSegue(withIdentifier: Constants.kViewtoDetailsSegue, sender: dict)
                        })
                } // of tasks loop
                self.setupTasksNotification()
            }
            
            section <<< ButtonRow(){ row in
                // need to conditionalize this so if you are on someone else's realm it's indicated
                row.title = NSLocalizedString("Add New Task", comment: "")
                }.onCellSelection({ (sectionName, rowName) in
                    self.performSegue(withIdentifier: Constants.kViewToNewTaskSegue, sender: self)
                })
        }
    }
    
    
    
    
    func reloadUsersSection() {
        // we can get called by a notification on the availability of permissions... if we're not yet configured, just skip it.
        if self.form.isEmpty {
            return
        }
        
        if let section = self.form.sectionBy(tag: "Users") {
            section.count > 0 ? section.removeAll() : ()
            
            for person in self.people!.sorted(byKeyPath: "lastName") {
                section <<< TextRow(){ row in
                    row.disabled = true
                    row.tag = person.id
                    }.cellUpdate({ (cell, row) in
                        cell.textLabel?.adjustsFontSizeToFitWidth = true
                        
                        if person.id == SyncUser.current?.identity! {
                            row.title = "\(person.fullName()) ← you!"   // do something to higlight our own record
                            row.disabled = true
                        } else {
                            if let accessLevel =  self.myPermissions?.accessLevelForUser(SyncUser.current!.identity!, realmPath: Constants.myTasksRealmURL.relativePath.replacingOccurrences(of: "~", with: person.id)) {
                                row.title = "\(person.fullName()) (You have \(accessLevel.toText()))"
                                if (accessLevel == .write || accessLevel == .write) {
                                    row.disabled = false
                                } else {
                                    row.disabled = true
                                }
                            } else {
                                // if we can't determine the permission level, then it's assumed to be .none
                                print("self.myPermissions was nil - cannot determine Access level.")
                                row.disabled = true
                                row.title = "\(person.fullName())"
                            }
                        }
                        
                        // lastly, see if the putative path of the person we're looking at is the same as our path.. if so, it's us, so put a check on the row
                        if Constants.myTasksRealmURL.relativePath.replacingOccurrences(of: "~", with: (SyncUser.current?.identity!)!) == Constants.myTasksRealmURL.relativePath.replacingOccurrences(of: "~", with: person.id) {
                            cell.backgroundColor = UIColor.fromHex(hexString: "5190f8", alpha: 0.1)
                        } else {
                            //row.cell.accessoryType = .none
                            cell.backgroundColor = .white
                        }
                    })
                    .onCellSelection({ (cell, row) in
                        print("tap on cell body for \(person.fullName())")
                        HUD.show(.progress)
                        // @TODO - needs a swichtToReramForPersonID(person.Id)
                        self.switchToRealmWithPath(Constants.myTasksRealmURL.absoluteString.replacingOccurrences(of: "~", with: person.id), completionHandler: { (realm, error) in
                            if let realm = realm {
                                self.currentRealm = realm // switch to the new realm...
                                self.currentTaskNotificationToken?.stop() // stop tracking the old taks
                                self.tasks = try! self.currentRealm?.objects(Task.self) // get the new tasks
                                self.setupTasksNotification()   // and reset the tasks notification token
                                DispatchQueue.main.async {
                                    self.reloadTaskSection() // now redraw the sections
                                }
                            } else {
                            if let error = error {
                                print("An error occurred opening the Realm: \(error.localizedDescription) ")
                                }
                            }
                            HUD.hide()
                        })

                    })
            } // of people loop
        } // of section != nil
    } // of reloadUsersSection
    
    
    func fullNameForUserID(_ targetUserId: String) -> String {
        //NB: if we are looking ar our own private realm the user ID string will be "~" so we have to turn that back into a usable ID 
        if let tmpTargetPerson = self.commonRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", (targetUserId != "~" ? targetUserId : SyncUser.current!.identity!))).first {
            return tmpTargetPerson.fullName()
        }
        return "unknown"
    }
    
    
    /// Take the user to the permissions mod view controller
    func showPermissionSelector() {
        // do something cool here
        performSegue(withIdentifier: Constants.kMainToPermissionsSegue, sender: self)
    }
    
    
    @IBAction func handleLogoutPressed(sender: AnyObject) {
        let alert = UIAlertController(title: NSLocalizedString("Logout", comment: "Logout"), message: NSLocalizedString("Really Log Out?", comment: "Really Log Out?"), preferredStyle: .alert)
        
        // Logout button
        let OKAction = UIAlertAction(title: NSLocalizedString("Logout", comment: "logout"), style: .default) { (action:UIAlertAction!) in
            print("Logout button tapped");
            SyncUser.current?.logOut()
            //Now we need to segue to the login view controller
            self.performSegue(withIdentifier: Constants.kExitToLoginViewSegue, sender: self)
        }
        alert.addAction(OKAction)
        
        // Cancel button
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action:UIAlertAction!) in
            print("Cancel button tapped");
        }
        alert.addAction(cancelAction)
        
        // Present Dialog message
        present(alert, animated: true, completion:nil)
    }
    
    
    // MARK: - Realm Access Methods
    

    func openTasksForUser(_ user: SyncUser) {
        openTaskRealmForUser(user) { (realm, error) in
            if let realm = realm {
                self.currentRealm = realm
                self.tasks = try! self.currentRealm?.objects(Task.self)
                self.setupTasksNotification()
                self.reloadTaskSection()
            } else {
                if let error = error {
                    print("An error occurred opening Realm for ID \(user.identity!): \(error.localizedDescription)")
                }
            }
        }
    }
    
    
    func openTaskRealmForUser(_ user:SyncUser, completionHandler:@escaping(Realm?,Error?) -> Void) {
        let config = privateTasksRealmConfigforUser(user: user)
        
        Realm.asyncOpen(configuration: config) { realm, error in
            if let realm = realm {
                self.currentRealm = realm
            } else  if let error = error {
                print("Error opening \(config), error: \(error.localizedDescription)")
            }
            completionHandler(realm, error)
        } // of AsyncOpen
    }
    
    
    func switchToRealmWithPath(_ path:String, completionHandler: @escaping(Realm?, Error?) -> Void)  {
        let teamURL = URL(string: path)
        let config = Realm.Configuration(syncConfiguration: SyncConfiguration(user: SyncUser.current!, realmURL: teamURL!))
        Realm.asyncOpen(configuration: config) { (realm, error) in
            completionHandler(realm, error)
        }
    }
    
    
    // MARK: - Permission Hadling
    
    func getPermissions() {
        SyncUser.current?.retrievePermissions { permissions, error in
            if let error = error {
                print("Error retreiving permissions: \(error.localizedDescription)")
                return
            }
            self.myPermissions = permissions
            print("Permissions updated:")
            permissions!.forEach({ (perm) in
                print("\(perm.decode(peopleRealm: self.commonRealm))")
            })
            NotificationCenter.default.post(name: self.permissionsDidUpdateNotification, object: nil)
            DispatchQueue.main.async {
                self.reloadUsersSection()
            }
        }
    }
    
    
    
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Constants.kViewToNewTaskSegue {
            let vc = segue.destination as! TaskDetailsViewController
            vc.newTaskMode = true
            vc.targetRealm = self.currentRealm
            self.peopleNotificationToken?.stop()
            self.currentTaskNotificationToken?.stop()
        }
        
        
        if segue.identifier == Constants.kViewtoDetailsSegue {
            var taskID: String?
            var accessLevel: SyncAccessLevel?
            let vc = segue.destination as! TaskDetailsViewController
            
            if sender != nil {
                let dict = sender as! Dictionary<String, Any>
                taskID = (dict["taskID"] as! String)
                accessLevel = (dict["accessLevel"] as! SyncAccessLevel)
                
                vc.taskID = taskID
                vc.accessLevel = accessLevel
            }
            vc.newTaskMode = false
            vc.targetRealm = self.currentRealm
            self.peopleNotificationToken?.stop()
            self.currentTaskNotificationToken?.stop()
        }
        
        if segue.identifier == Constants.kMainToPermissionsSegue {
            // nothing to do here - if you needed to poass something you;d do it here
        }
        
    }
    
    
    
    // MARK: - Realm Notificaiton Handling
    func setupTasksNotification() {
        self.currentTaskNotificationToken =  self.tasks?.addNotificationBlock { (changes: RealmCollectionChange) in
            guard let tableView = self.tableView else { return }
            let section = self.form.sectionBy(tag: "TaskSection")
            
            switch changes {
            case .initial:
                // Results are now populated and can be accessed without blocking the UI
                section?.reload() // this forces Eureka to reload
                break
            case .update(_, let deletions, let insertions, let modifications):
                // Query results have changed, so apply them to the UITableView
                //tableView.beginUpdates()
                //tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: section!.index!) }),
                //                     with: .automatic)
                //tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: section!.index!)}),
                //                     with: .automatic)
                //tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: section!.index!) }),
                //                     with: .automatic)
                //tableView.endUpdates()
                section?.reload() // this forces Eureka to reload
                break
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
                break
            }
        } // of notificationToken
    } // setupTasksNotification
    
    
    
    func setupPeopleNotification() {
        self.peopleNotificationToken =  self.people?.addNotificationBlock { (changes: RealmCollectionChange) in
            guard let tableView = self.tableView else { return }
            let section = self.form.sectionBy(tag: "Users")
            
            switch changes {
            case .initial:
                // Results are now populated and can be accessed without blocking the UI
                section?.reload() // this forces Eureka to reload
                break
            case .update(_, let deletions, let insertions, let modifications):
                // Query results have changed, so apply them to the UITableView
                //tableView.beginUpdates()
                //tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: section!.index!) }),
                //                     with: .automatic)
                //tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: section!.index!)}),
                //                     with: .automatic)
                //tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: section!.index!) }),
                //                     with: .automatic)
                //tableView.endUpdates()
                section?.reload() // this forces Eureka to reload
                break
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
                break
            }
        } // of notificationToken
    } // setupPeopleNotification
    
    
}

