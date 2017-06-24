//
//  TaskManagerViewController.swift
//  AsyncOpenTester
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

extension UIImage {
    /// resize image to fit current frame
    ///
    /// - Parameters:
    ///   - sourceSize: source imagesize
    ///   - destRect: the cgSize of the desination
    /// - Returns: return
    func AspectScaleFit( sourceSize : CGSize,  destRect : CGRect) -> CGFloat  {
        let destSize = destRect.size
        let  scaleW = destSize.width / sourceSize.width
        let scaleH = destSize.height / sourceSize.height
        return fmin(scaleW, scaleH)
    }
    
    /// resize the current iage
    ///
    /// - Parameter targetSize: the target size as a cgSize
    /// - Returns: a new UIImage
    func resizeImage(targetSize: CGSize) -> UIImage {
        let size = self.size
        
        let widthRatio  = targetSize.width  / self.size.width
        let heightRatio = targetSize.height / self.size.height
        
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width:size.width * heightRatio, height:size.height * heightRatio)
        } else {
            newSize = CGSize(width:size.width * widthRatio,  height:size.height * widthRatio)
        }
        
        let rect = CGRect(x:0, y:0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}


extension SyncPermissionResults {
    /// get access level for a given user realm for a specificed path
    ///
    /// - Parameters:
    ///   - userID: the target user identity string
    ///   - realmPath: the path of the realm
    /// - Returns: A SyncAccessLevel value
    func accessLevelForUser(_ userID: String, realmPath: String) -> SyncAccessLevel {
        var rv: SyncAccessLevel = .none
        
        for permission in self {
            if permission.userId == userID && realmPath == permission.path {
                rv = permission.accessLevel
            }
        }
        return rv
    }
}

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
            rv = "Read Only"
        case .write:
            rv = "Read/Write"
        case .admin:
            rv = "Read/Write/Manage"
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
        NotificationCenter.default.addObserver(self, selector: #selector(TaskManagerViewController.reloadUsersSection), name: self.permissionsDidUpdateNotification, object: nil)
        
        self.getPermissions()
        
        people = commonRealm.objects(Person.self)       // all the people in the system
        myPersonRecord = people?.filter(NSPredicate(format: "id = %@", SyncUser.current!.identity!)).first
        self.navigationItem.title = NSLocalizedString("Shared Tasks Demo", comment: "Shared Tasks Demo")
        self.loadForm()
        
        
        // start with our own task list.
        self.openTasksForUser(SyncUser.current!)
        
        
    } // of viewDidLoad
    
    
    override func viewWillAppear(_ animated: Bool) {
        self.setupPeopleNotification()
        self.setupTasksNotification()
        self.reloadTaskSection()
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
                row.title = NSLocalizedString("Logout", comment: "")
                }.onCellSelection({ (sectionName, rowName) in
                    self.handleLogoutPressed(sender: self)
                })
            +++ Section("My Tasks...") { section in
                section.tag = "TaskSection"
        }
        self.reloadTaskSection()
        
        
        self.form   +++ Section("User Task Lists") { section in
            section.tag = "Users"
        }
        self.reloadUsersSection()
        
    }
    
    
    
    
    
    func reloadTaskSection() {
        if let section = self.form.sectionBy(tag: "TaskSection") {
            if section.count > 0 {
                section.removeAll()
            }
            //section.header?.title = sectionTitleForUser(currentRealm?.configuration.syncConfiguration?.user)
            if self.currentRealm != nil {
                let username = sectionTitleForUser(currentRealm?.configuration.syncConfiguration?.user) ?? "Unknown User"
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
                            //row.cell.accessoryType = .disclosureIndicator
                        })
                        .onCellSelection({ (cell, row) in
                            let dict = ["taskID": row.tag]
                            self.performSegue(withIdentifier: Constants.kViewToEditSegue, sender: dict)
                        })
                } // of tasks loop
            }
            
            section <<< ButtonRow(){ row in
                // need to conditionalize this so if you are on someone else's realm it's indicated
                row.title = NSLocalizedString("Add New Task", comment: "")
                }.onCellSelection({ (sectionName, rowName) in
                    self.performSegue(withIdentifier: Constants.kViewToEditSegue, sender: self)
                })
            
        }
    }
    
    
    
    
    func reloadUsersSection() {
        
        // we can get called by a notification on the availability of permissions...
        // if we're not configured, just skip it.
        if self.form.isEmpty {
            return
        }
        
        if let section = self.form.sectionBy(tag: "Users") {
            section.count > 0 ? section.removeAll() : ()
            
            for person in self.people!.sorted(byKeyPath: "lastName") {
                section <<< TextRow(){ row in
                    row.disabled = true
                    row.tag = person.id
                    }
                    .cellUpdate({ (cell, row) in
                        cell.textLabel?.adjustsFontSizeToFitWidth = true
                        
                        if person.id == SyncUser.current?.identity! {
                            row.title = "\(person.fullName()) ← you!"   // do something to higligh our own record
                            row.disabled = true
                        } else {
                            if let accessLevel =  self.myPermissions?.accessLevelForUser(person.id, realmPath: Constants.myTasksRealmURL.relativePath.replacingOccurrences(of: "~", with: person.id)) {
                                print("Access level is \(accessLevel.toText())")
                                row.title = "\(person.fullName()) (\(accessLevel.toText()))"
                                (accessLevel != .write || accessLevel != .write) ?  row.disabled = true : ()
                            } else {
                                // if we can't determine the permission level, then it's assumed to be .none
                                print("self.myPermissions was nil - cannot determine Access level.")
                                row.disabled = true
                                row.title = "\(person.fullName())"
                            }
                        }
                        
                        // lastly, see if the putative path of the person we're looking at is the same as our path.. if so, it's us, so put a check on the row
                        if Constants.myTasksRealmURL.relativePath.replacingOccurrences(of: "~", with: (SyncUser.current?.identity!)!) == Constants.myTasksRealmURL.relativePath.replacingOccurrences(of: "~", with: person.id) {
                            row.cell.accessoryType = .checkmark
                        } else {
                            row.cell.accessoryType = .none
                        }
                    })
                    .onCellSelection({ (cell, row) in
                        print("tap on cell body for \(person.fullName())")
                        //self.performSegue(withIdentifier: Constants.kRealmsToDetailsSegue, sender: self)
                    })
            } // of tasks loop
        } // of section != nil
    } // of reloadUsersSection
    
    
    /// get title for section based on curent user
    ///
    /// - Parameter user: A SyncUser
    /// - Returns: A string prepresenting the current user and hte read/write status
    func sectionTitleForUser(_ user:SyncUser?) ->String? {
        let targetPersonRecord = self.commonRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", (user?.identity)!)).first
        return targetPersonRecord?.fullName()
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
    
    
    
    // MARK: - Permission Hadling
    
    func getPermissions() {
        SyncUser.current?.retrievePermissions { permissions, error in
            if let error = error {
                print("Error retreiving permissions: \(error.localizedDescription)")
                return
            }
            self.myPermissions = permissions
            NotificationCenter.default.post(name: self.permissionsDidUpdateNotification, object: nil)
        }
    }
    
    
    
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Constants.kViewToEditSegue {
            let vc = segue.destination as! TaskDetailsViewController
            vc.newTaskMode = true
            vc.targetRealm = self.currentRealm
            self.peopleNotificationToken?.stop()
            self.currentTaskNotificationToken?.stop()
        }
        
        
        if segue.identifier == Constants.kViewtoDetailsSegue {
            var taskID: String?
            if sender != nil {
                let dict = sender as! Dictionary<String, String>
                taskID = dict["taskID"]
            }
            let vc = segue.destination as! TaskDetailsViewController
            vc.newTaskMode = false
            vc.targetRealm = self.currentRealm
            vc.taskID = taskID
            self.peopleNotificationToken?.stop()
            self.currentTaskNotificationToken?.stop()
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
                tableView.beginUpdates()
                tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: section!.index!) }),
                                     with: .automatic)
                tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: section!.index!)}),
                                     with: .automatic)
                tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: section!.index!) }),
                                     with: .automatic)
                tableView.endUpdates()
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
                tableView.beginUpdates()
                tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: section!.index!) }),
                                     with: .automatic)
                tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: section!.index!)}),
                                     with: .automatic)
                tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: section!.index!) }),
                                     with: .automatic)
                tableView.endUpdates()
                section?.reload() // this forces Eureka to reload
                break
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
                break
            }
        } // of notificationToken
    } // setupTasksNotification
    
    
}

