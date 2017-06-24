//
//  PermissionsViewController.swift
//  SharedTasks
//
//  Created by David Spector on 6/24/17.
//  Copyright © 2017 Realm. All rights reserved.
//

import UIKit
import Eureka
import RealmSwift

class PermissionsViewController: FormViewController {
    let commonRealm = try! Realm(configuration: commonRealmConfig(user: SyncUser.current!)) // the realm the holds the Person objects
    var myPersonRecord: Person?
    var people: Results<Person>?
    var tasks: Results<Task>?
    var myPermissions: SyncPermissionResults?                   // this is a list fo realms the current user has access to - will need to be periodically refreshed

    override func viewDidLoad() {
        super.viewDidLoad()

        people = commonRealm.objects(Person.self)       // all the people in the system
        myPersonRecord = people?.filter(NSPredicate(format: "id = %@", SyncUser.current!.identity!)).first
        
        
        form = self.loadForm()
}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadForm() -> Form {
        let form = Form()
        
        for person in self.people!.sorted(byKeyPath: "lastName") {
            if person.id != SyncUser.current!.identity! {
                form +++ Section("Permissions for \(person.fullName())...") { section in
                    section.tag = person.id
                    }
                    <<< ButtonRow() { row in
                        row.title = NSLocalizedString("Clear Permissions", comment: "Clear")
                        }.onCellSelection({ (cell, row) in
                            setPermissionForRealmPath(Constants.myTasksRealmURL.relativePath, accessLevel: .none, personID: person.id)
                        })
                    <<< ButtonRow() { row in
                        row.title = NSLocalizedString("Set Read Only", comment: "Clear")
                        }.onCellSelection({ (cell, row) in
                            setPermissionForRealmPath(Constants.myTasksRealmURL.relativePath, accessLevel: .read, personID: person.id)
                        })
                    <<< ButtonRow() { row in
                        row.title = NSLocalizedString("Set Read/Write", comment: "Clear")
                        }.onCellSelection({ (cell, row) in
                            setPermissionForRealmPath(Constants.myTasksRealmURL.relativePath, accessLevel: .write, personID: person.id)
                        })
            }
        } // of people loop
        return form
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
