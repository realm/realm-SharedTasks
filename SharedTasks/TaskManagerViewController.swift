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
    
    let commonRealm = try! Realm(configuration: commonRealmConfig(user: SyncUser.current!))
    var personRecord: Person?
    var tasks: Results<Task>?
    var currentRealm: Realm?                    // this is the current traget realm - might besomeone else's tasks
    var notificationToken: NotificationToken?
    var permissionNotificationToken : NotificationToken?
    var selectedRealmName: String?
    var useAsyncOpen = false
    
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        personRecord = commonRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", SyncUser.current!.identity!)).first
        openTaskRealmForUser(SyncUser.current!) // start with our own task list.
        
        self.loadForm()
    } // of viewDidLoad
    
    
    override func viewWillAppear(_ animated: Bool) {
        self.selectedRealmName = nil
        
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
                    
                    if self.personRecord?.avatar == nil {
                        row.value = UIImage(named: "Circled User Male_30")
                    } else {
                        let imageData = self.personRecord?.avatar!
                        row.value = UIImage(data:imageData! as Data)!       //  this image row for Eureka seems to scale for us.  (was:  .scaleToSize(size: profileImage!.frame.size)  )
                    }
                }).onChange({ (row) in
                    try! self.commonRealm.write {
                        if row.value != nil {
                            let resizedImage = row.value!.resizeImage(targetSize: CGSize(width: 128, height: 128))
                            self.personRecord?.avatar = UIImagePNGRepresentation(resizedImage) as Data?
                        } else {
                            self.personRecord?.avatar = nil
                            row.value = UIImage(named: "Circled User Male_30")
                        }
                    }
                })
            <<< TextRow(){ row in
                row.title = NSLocalizedString("First Name", comment:"First Name")
                row.placeholder = "First name"
                if self.personRecord!.firstName != "" {
                    row.value = self.personRecord?.firstName ?? "not set"
                }
                }.onChange({ (row) in
                    try! self.commonRealm.write {
                        if row.value != nil {
                            self.personRecord!.firstName = row.value!
                        } else {
                            self.personRecord!.firstName = ""
                        }
                    }
                })
            <<< TextRow(){ row in
                row.title = NSLocalizedString("Last Name", comment:"Last name")
                row.placeholder = NSLocalizedString("Last name", comment: "Last Name")
                if self.personRecord!.lastName != "" {
                    row.value = self.personRecord!.lastName
                }
                }.onChange({ (row) in
                    try! self.commonRealm.write {
                        if row.value != nil {
                            self.personRecord!.lastName = row.value!
                        } else {
                            self.personRecord!.lastName = ""
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
                // need to donditionalie this so if you are on someone else's realm it's indicated
                row.title = NSLocalizedString("New Task", comment: "")
                }.onCellSelection({ (sectionName, rowName) in
                    self.newTasks(sender: self)
                })
            +++ Section("My Tasks...") { section in
                section.tag = "TasksSection"
        }
        
        //self.form +++ SwitchRow() { row in
        //    row.tag = "useAsyncOpen"
        //    row.title = "Use AsyncOpen()"
        //    }.cellSetup({ (cell, row) in
        //        row.value = self.useAsyncOpen
        //    }).onChange({ (row) in
        //        self.useAsyncOpen = row.value!
        //    }).cellUpdate({ (cell, row) in
        //        row.value = self.useAsyncOpen
        //    })
        //if self.realms?.count == 0 {
        //    self.form +++ TextRow() { (row) in
        //        row.disabled = true
        //        row.tag = "noRealmsInstructions"
        //        row.value = NSLocalizedString("No Realms found! Create one? 👇", comment: "no realms to see :(")
        //    }
        //}
        
        //self.form +++ Section(NSLocalizedString("Available Realms...(tap to see details)", comment: "a comment")){ section in
        //    section.tag = "AvailableRealms"
        //}
        //self.reloadRealmsSection()
    }
    
    
    
    func reloadTaskSection() {
        let section = self.form.sectionBy(tag: "TasksSection")
        if section!.count > 0 {
            section?.removeAll()
            section?.header?.title = "..."
            sectionTitleForUser(currentRealm?.configuration.syncConfiguration?.user,completionHandler: {title in
                section?.header?.title = title
            })
            
            for task in self.tasks! {
                section! <<< TextRow(){ row in
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
        
    
    
    
    
    @IBAction func newTasks(sender: AnyObject) {
        // note - this needs to use whatever "currentTaskRealm" us set to - also needs to check and respond to permisson changes
        
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
        //if segue.identifier == Constants.kRealmsToDetailsSegue{
        //
        //    let vc = segue.destination as! RealmDetailsViewController
        //    vc.realmName = self.selectedRealmName
        //    vc.useAsyncOpen = self.useAsyncOpen
        //}
    }
    
    func setupNotificationToken() {
        self.notificationToken =  self.tasks?.addNotificationBlock { (changes: RealmCollectionChange) in
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
    } // setupNotificationToken
    
    
    
}
// Code Morgue

//        if SyncUser.current?.isAdmin == true {
//            self.form
//                +++ Section("Realm Actions")
//                <<< TextRow() {row in
//                    row.tag = "nameRow"
//                    row.placeholder = "realm name"
//                    }.onChange({ (row) in
//                        let createButton = self.form.rowBy(tag: "activeRow")
//                        if row.value != nil {
//                            if  RealmIndexEntry.exists(row.value!) == false {
//                                createButton?.disabled = false
//                                createButton?.updateCell()
//                                createButton?.reload()
//                            } // of exiting realm name check
//                        } // of value nil check
//                    })
//
//                <<< ButtonRow(){ row in
//                row.tag = "activeRow"
//                row.disabled = true
//                row.title = NSLocalizedString("Create Realm...", comment: "")
//                }.onCellSelection({ (sectionName, rowName) in
//                    let theNameRow = self.form.rowBy(tag: "nameRow") as! TextRow
//                    if theNameRow.value != nil && theNameRow.value!.isEmpty == false {
//                        let (theNewRealm, error) = RealmIndexEntry.newRealmNamed(theNameRow.value!)
//                        if let error = error {
//                            print("Yikes - we got an error trying to create \(theNameRow.value!): \(error.localizedDescription)")
//                        } else {
//                            // No error - relaod the table and clear out the row
//                            theNameRow.value = nil
//                            //let section = self.form.sectionBy(tag: "AvailableRealms")
//                            //section?.reload()
//                            self.reloadRealmsSection()
//                        }
//                    } else {
//                        print("Hmm.. the create Realm but was enabled, but the name row was nil? ")
//                    }
//                })
//        } // of if isAdmin





