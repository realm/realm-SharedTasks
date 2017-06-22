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





class TaskManagerViewController: FormViewController {
    
    let commonRealm = try! Realm(configuration: commonRealmConfig(user: SyncUser.current!)) // the realm the holds the Person objects
    var myPersonRecord: Person?
    var people: Results<Person>?
    var tasks: Results<Task>?
    var myTaskRealm: Realm?                                     // this is mly task realm, kept around since is probably tyhe one we'l use most
    var currentRealm: Realm?                                    // this is the current traget realm - might besomeone else's tasks
    var currentTaskNotificationToken: NotificationToken?        // so we are always looked for changes in the currrent tasks realm
    var peopleNotificationToken: NotificationToken?             // So we get any notifications about peple added to or removed from the syste
    var permissionNotificationToken : NotificationToken?        // So we can updte our permissions diplay as peple add or remove us from their task lists
    var selectedRealmName: String?                              // the name of the user whose realm we are displaying

    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        people = commonRealm.objects(Person.self)   // all the people in the system
        myPersonRecord = people?.filter(NSPredicate(format: "id = %@", SyncUser.current!.identity!)).first
        openTaskRealmForUser(SyncUser.current!) // start with our own task list.
        
        self.loadForm()
        
    } // of viewDidLoad
    
    
    override func viewWillAppear(_ animated: Bool) {
        self.setupTasksNotification()
        self.setupPeopleNotification()

        self.tableView.reloadData()
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
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
        
            <<< ButtonRow(){ row in
                // need to conditionalize this so if you are on someone else's realm it's indicated
                row.title = NSLocalizedString("New Task", comment: "")
                }.onCellSelection({ (sectionName, rowName) in
                    self.performSegue(withIdentifier: Constants.kViewToEditSegue, sender: self)
                })
            +++ Section("My Tasks...") { section in
                section.tag = "TasksSection"
        }
        self.reloadTaskSection()
        
        
        self.form   +++ Section("Users & Permissions") { section in
            section.tag = "Users"
        }
        self.reloadUsersSection()
        
    }
    
    
    
    
    
    func reloadTaskSection() {
        if let section = self.form.sectionBy(tag: "TaskSection") {
            if section.count > 0 {
                section.removeAll()
                section.header?.title = "..."
                sectionTitleForUser(currentRealm?.configuration.syncConfiguration?.user,completionHandler: {title in
                    section.header?.title = title
                })
                
                for task in self.tasks! {
                    section <<< TextRow(){ row in
                        row.disabled = true
                        row.tag = task.id
                        }.cellSetup({ (cell, row) in
                            row.title = task.taskTitle
                            //row.cell.accessoryType = .disclosureIndicator
                        })
                    //.onCellSelection({ (cell, row) in
                    //    self.selectedRealmName = row.tag!
                    //    self.performSegue(withIdentifier: Constants.kRealmsToDetailsSegue, sender: self)
                    //})
                } // of tasks loop
            }
        }
    }

    
    
    func reloadUsersSection() {
        if let section = self.form.sectionBy(tag: "Users") {
            section.count > 0 ?             section.removeAll() : ()
            
            for person in self.people!.sorted(byKeyPath: "lastName") {
                section <<< TextRow(){ row in
                    row.disabled = true
                    row.tag = person.id
                    }.cellSetup({ (cell, row) in
                        if person.id == SyncUser.current?.identity! {
                            // do something to higligh our own record
                            row.title = "\(person.fullName()) ← you!"
                            cell.backgroundColor = .green
                            cell.alpha = 0.5
                            row.disabled = true
                        } else {
                            row.title = person.fullName()
                        }
                        //row.cell.accessoryType = .disclosureIndicator
                    })
                    .onCellSelection({ (cell, row) in
                        print("tap on cell body for \(person.fullName())")
                        //self.performSegue(withIdentifier: Constants.kRealmsToDetailsSegue, sender: self)
                    })
            } // of tasks loop
            
            
        }
    }
    
    
    /// get title for section based on curent user
    ///
    /// - Parameter user: A SyncUser
    /// - Returns: A string prepresenting the current user and hte read/write status
    func sectionTitleForUser(_ user:SyncUser?, completionHandler: @escaping (String?) -> Void) {
        
        SyncUser.current?.retrievePermissions { permissions, error in
            if let permissions = permissions {
                let targetPersonRecord = self.commonRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", (user?.identity)!)).first
                completionHandler("\(String(describing: targetPersonRecord?.fullName()))")
            } else {
                if let error = error {
                    // handle error
                    completionHandler(nil)
                }
                
            }
        }
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
    
    
    // MARK: - Realm Access
    func openTaskRealmForUser(_ user:SyncUser) {
        let config = privateTasksRealmConfigforUser(user: user)
        
        Realm.asyncOpen(configuration: config) { realm, error in
            if let realm = realm {
                self.currentRealm = realm
                self.tasks = try! self.currentRealm?.objects(Task.self)
                self.reloadTaskSection()
            } else  if let error = error {
                print("Error opening \(config), error: \(error.localizedDescription)")
            }
        } // of AsyncOpen

        
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
    }
    
    
    
    // MARK: - Realm Notificaiton Handling
    func setupTasksNotification() {
        self.currentTaskNotificationToken =  self.tasks?.addNotificationBlock { (changes: RealmCollectionChange) in
            guard let tableView = self.tableView else { return }
            switch changes {
//            case .initial:
//                // Results are now populated and can be accessed without blocking the UI
//                tableView.reloadData()
//                break
//            case .update(_, let deletions, let insertions, let modifications):
//                // Query results have changed, so apply them to the UITableView
//                tableView.beginUpdates()
//                tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: 0) }),
//                                     with: .automatic)
//                tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 0)}),
//                                     with: .automatic)
//                tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 0) }),
//                                     with: .automatic)
//                tableView.endUpdates()
//                break
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
                break
                
            default:
                tableView.reloadData()
            }
        } // of notificationToken
    } // setupTasksNotification
    

    
    func setupPeopleNotification() {
        self.peopleNotificationToken =  self.people?.addNotificationBlock { (changes: RealmCollectionChange) in
            guard let tableView = self.tableView else { return }
            switch changes {
//            case .initial:
//                // Results are now populated and can be accessed without blocking the UI
//                tableView.reloadData()
//                break
//            case .update(_, let deletions, let insertions, let modifications):
//                // Query results have changed, so apply them to the UITableView
//                tableView.beginUpdates()
//                tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: 0) }),
//                                     with: .automatic)
//                tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 0)}),
//                                     with: .automatic)
//                tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 0) }),
//                                     with: .automatic)
//                tableView.endUpdates()
//                break
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
                break
                
            default:
                tableView.reloadData()
            }
        } // of notificationToken
    } // setupTasksNotification

    
}

