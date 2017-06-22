//
//  RealmDetailsViewController.swift
//  AsyncOpenTester
//
//  Created by David Spector on 6/12/17.
//  Copyright © 2017 Realm. All rights reserved.
//

import Foundation
import UIKit

import Alertift
import Eureka
import ImageRow


import RealmSwift

class RealmDetailsViewController: FormViewController {
    
    let commonRealm = try! Realm(configuration: commonRealmConfig(user:SyncUser.current!))
    var realmName: String?
    var indexEntry: RealmIndexEntry!
    var theRealm: Realm?
    var error: Error?
    var records: Results<OtherData>
    var people: Results<Person>?
    var useAsyncOpen = false
    var token: NotificationToken!

    
    let df = DateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        df.dateStyle = .short
        df.timeStyle = .short
        
        self.people = commonRealm.objects(Person.self)
        
        if realmName != nil {
            indexEntry = RealmIndexEntry.indexEntryForName(realmName!)
            if indexEntry != nil {
                indexEntry!.openRealm(useAsyncOpen: useAsyncOpen, completionHandler: { (realm, error) in
                    if let realm = realm { // success
                        self.theRealm = realm
                        self.error = error
                        self.records = realm.objects(OtherData.self)
                    } else { // something blew up...
                        if let error = error {
                            self.error = error
                        }
                    }
                    self.loadForm()
                    self.tableView.reloadData()
                }) // of openRealm() closure
            } // of indexEntry validity test
        } // of realmName check
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func loadForm() {
        if  self.theRealm != nil {
            form
                +++ Section("My Profile... ")
                <<< TextRow(){ row in
                    row.disabled = true
                    row.tag = "userVisibleName"
                    row.title = "User Visible Name"
                    row.value = indexEntry?.realmName
                }
                <<< TextRow(){ row in
                    row.disabled = true
                    row.tag = "creationDate"
                    row.title = "Created"
                    row.value = df.string(from: indexEntry!.creationDate!)
                }
                <<< ImageRow() { row in
                    
                    row.title = NSLocalizedString("Profile Image", comment: "profile image")
                    row.sourceTypes = [.PhotoLibrary, .SavedPhotosAlbum, .Camera]
                    row.clearAction = .yes(style: UIAlertActionStyle.destructive)
                    }.cellSetup({ (cell, row) in
                        
                        if self.thePersonRecord!.avatar == nil {
                            row.value = UIImage(named: "Circled User Male_30")
                        } else {
                            let imageData = self.thePersonRecord?.avatar!
                            row.value = UIImage(data:imageData! as Data)!       //  this image row for Eureka seems to scale for us.  (was:  .scaleToSize(size: profileImage!.frame.size)  )
                        }
                    }).onChange({ (row) in
                        try! self.realm.write {
                            if row.value != nil {
                                let resizedImage = row.value!.resizeImage(targetSize: CGSize(width: 128, height: 128))
                                self.thePersonRecord?.avatar = UIImagePNGRepresentation(resizedImage) as Data?
                            } else {
                                self.thePersonRecord?.avatar = nil
                                row.value = UIImage(named: "Circled User Male_30")
                            }
                        }
                    })
                
                <<< TextRow(){ row in
                    row.cell.textLabel?.adjustsFontSizeToFitWidth = true
                    row.disabled = true
                    row.tag = "realmURL"
                    row.title = "URL"
                    row.value = indexEntry?.realmURL
                }
                <<< TextRow(){ row in
                    row.disabled = true
                    row.tag = "recordCount"
                    row.title = "Record count"
                    }.cellUpdate({ (cell, row) in
                        row.value = NSLocalizedString("\(self.records?.count ?? 0)", comment: "record count")
                    })
            
            if SyncUser.current!.isAdmin {
                self.form +++ Section("Actions")
                    <<< ButtonRow(){ row in
                        if self.theRealm == nil {
                            row.disabled = true
                        }
                        row.title = NSLocalizedString("Add 100 Records", comment: "")
                        }.onCellSelection({ (sectionName, rowName) in
                            self.handleAddData(count: 100, realm: self.theRealm)
                            self.tableView.reloadData()
                        })
                    
                    +++ Section(NSLocalizedString("Wildcard Permissions", comment: "permissions settings"))
                    <<< ButtonRow() { row in
                        row.tag = "Read"
                        row.title = "Set Read"
                        }.onCellSelection({ (cell, row) in
                            self.setPermissionForRealm(theRealm: self.theRealm!, read:true, write: false, admin: false, personID: "*")
                        })
                    <<< ButtonRow() { row in
                        row.tag = "Write"
                        row.title = "Set Write"
                        }.onCellSelection({ (cell, row) in
                            self.setPermissionForRealm(theRealm: self.theRealm!, read:false, write: true, admin: false, personID: "*")
                        })
                    
                    <<< ButtonRow() { row in
                        row.tag = "Admin"
                        row.title = "Set Admin"
                        }.onCellSelection({ (cell, row) in
                            self.setPermissionForRealm(theRealm: self.theRealm!, read:false, write: false, admin: true, personID: "*")
                        })
                    <<< ButtonRow() { row in
                        row.tag = "clearPerms"
                        row.title = "Clear All Permisssions"
                        }.onCellSelection({ (cell, row) in
                            self.setPermissionForRealm(theRealm: self.theRealm!, read:false, write: false, admin: false, personID: "*")
                        })
                    
                    <<< TextRow() { row in
                        row.tag = "permissionStatus"
                        row.disabled = true
                        row.title = "Perms Status"
                }
            } // admin check for permissions section
            
        } else {
            // some how we have no realm selected
            form
                +++ Section("Unable to load selected realm: \(self.realmName ?? "empty realm name!") \n\n Error: \(self.error?.localizedDescription ?? "Error value was nil!" ) ")
        }
    }
    
    
    
    

    ////////

    
    
    
    func handleAddData(count: Int, realm: Realm?) {
        _ = OtherData.addDummyRecord(count: count, targetRealm: realm!)
        let countRow = self.form.rowBy(tag: "recordCount")
        countRow?.updateCell()
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
