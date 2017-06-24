//
//  TaskDetailsViewController.swift
//  SharedTasks
//
//  Created by David Spector on 6/22/17.
//  Copyright © 2017 Realm. All rights reserved.
//

import UIKit
import Eureka
import RealmSwift
import Alertift


class TaskDetailsViewController: FormViewController {
    var newTaskMode = false
    var editMode = false
    var task: Task?
    var taskID: String?
    var targetRealm: Realm?
    var accessLevel: SyncAccessLevel?
    var targetRecordID: String?     // may be nil of we're creating a new task
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if targetRealm != nil  {
            if newTaskMode {
                let leftButton = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .plain, target: self, action: #selector(self.BackCancelPressed) as Selector?)
                let rightButton = UIBarButtonItem(title: NSLocalizedString("Save", comment: "Save"), style: .plain, target: self, action: #selector(self.SavePressed))
                self.navigationItem.leftBarButtonItem = leftButton
                self.navigationItem.rightBarButtonItem = rightButton
                self.task = createNewTaskInRealm(targetRealm: targetRealm!)
            } else {
                if self.targetRealm != nil && self.taskID != nil {
                    self.task = targetRealm?.objects(Task.self).filter(NSPredicate(format: "id = %@", self.taskID!)).first
                    // Now, let see if there shld be an edit button here.
                    if self.accessLevel != nil && (self.accessLevel! == .write && self.accessLevel! == .admin ) {
                        let leftButton = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .plain, target: self, action: #selector(self.BackCancelPressed) as Selector?)
                        let rightButton = UIBarButtonItem(title: NSLocalizedString("Edit", comment: "Edit"), style: .plain, target: self, action: #selector(self.toggleEditMode))
                        self.navigationItem.leftBarButtonItem = leftButton
                        self.navigationItem.rightBarButtonItem = rightButton
                    }
                }
            }
            form = self.createForm(editable: self.newTaskMode, task: task)
        } else {
            self.showMissingRealmAlert()
        }
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func toggleEditMode() {
        self.editMode = true
        self.navigationItem.leftBarButtonItem = nil
        let rightButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: "Done"), style: .plain, target: self, action: #selector(self.SavePressed))
        self.navigationItem.rightBarButtonItem = rightButton
        self.form = createForm(editable: true, task: task)
    }
    
    func createNewTaskInRealm(targetRealm: Realm) -> Task? {
        var newTask: Task?

        try! targetRealm.write {
            let initialValues = [ "id":  UUID().uuidString, "createdBy" : SyncUser.current?.identity! ?? "", "lastUpdatedBy" : SyncUser.current?.identity! ?? "", "creationDate": Date() ] as [String : Any]
            newTask = targetRealm.create(Task.self, value:initialValues)
            targetRealm.add(newTask!, update: true)
        }
        return newTask
    }
    
    
    
    /*

     dynamic var id = ""
     dynamic var createdBy = ""
     dynamic var lastUpdatedBy = ""
     dynamic var creationDate: Date?
     dynamic var lastUpdate: Date?
     dynamic var dueDate: Date?
     dynamic var taskTitle = ""
     dynamic var taskDetails = ""
    
     */
    func createForm(editable: Bool = false, task: Task?) -> Form {
        let form = Form()
        form +++ TextRow("Task Title") { row in
            row.tag = "Title"
            row.value = task?.taskTitle
            if editable == false {
                row.disabled = true
            }
            }.cellSetup { cell, row in
                cell.textField.placeholder = row.tag
            }.onChange({ (row) in
                try! self.targetRealm?.write {
                    task?.taskTitle = row.value ?? ""
                }
            })
            
            <<< TextAreaRow(){ row in
                editable == false ? row.disabled = true : ()
                row.tag = "Description"
                row.placeholder = "Task Description"
                row.textAreaHeight = .dynamic(initialTextViewHeight: 100)
                row.value = task?.taskDetails
                }.onChange({ (row) in
                    try! self.targetRealm?.write {
                        task?.taskDetails = row.value ?? ""
                    }
                })
            
            <<< DateRow(){ [weak self] row in
                editable == false ? row.disabled = true : ()
                
                row.title = "Due Date"
                row.value = Date()
                let formatter = DateFormatter()
                formatter.locale = .current
                formatter.dateStyle = .long
                row.dateFormatter = formatter
                row.value = task?.dueDate
                }.onChange({ (row) in
                    try! self.targetRealm?.write {
                        task?.dueDate = row.value ?? nil
                    }
                })
        if self.editMode == true && (self.accessLevel != nil && (self.accessLevel! == .write || self.accessLevel! == .admin)) {
            form +++ ButtonRow() { row in
                row.title = NSLocalizedString("Delete Task", comment: "Delete")
                }.onCellSelection({ (cell, row) in
                    self.confirmDelteTask(sender: self)
                })
            
        }
        
        return form
    }
    
    func formIsEditable() -> Bool {
        if self.newTaskMode {
            return true
        }
        return false
    }

    
    // MARK: - Actions
    
    
    @IBAction func confirmDelteTask(sender: AnyObject) {
        let alert = UIAlertController(title: NSLocalizedString("Delete Task Record?", comment: "Delete record"), message: NSLocalizedString("Really Delte this task?", comment: "really really?"), preferredStyle: .alert)
        
        let confrimAction = UIAlertAction(title: NSLocalizedString("Delete", comment: "Delete"), style: .default) { (action:UIAlertAction!) in
            self.performDeleteTask()
            _ = self.navigationController?.popViewController(animated: true)
        }
        alert.addAction(confrimAction)
        
        // Cancel button
        let cancelAction = UIAlertAction(title: "Delete", style: .cancel) { (action:UIAlertAction!) in
            print("Cancel button tapped");
        }
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion:nil)

    }
    
    
    @IBAction func BackCancelPressed(sender: AnyObject) {
        
        if newTaskMode == true {
            let alert = UIAlertController(title: NSLocalizedString("Discard New Task Record?", comment: "Discard new record"), message: NSLocalizedString("Abandon these changes?", comment: "really bail out?"), preferredStyle: .alert)
            
            let AbandonAction = UIAlertAction(title: NSLocalizedString("Abandon", comment: "Abandon"), style: .default) { (action:UIAlertAction!) in
                self.performDeleteTask()
                _ = self.navigationController?.popViewController(animated: true)
            }
            alert.addAction(AbandonAction)
            
            // Cancel button
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action:UIAlertAction!) in
                print("Cancel button tapped");
            }
            alert.addAction(cancelAction)
            
            present(alert, animated: true, completion:nil)
        } else {
            // since our record can be live edited -- cancel here for exiitn tashs is just "back"
            _ = navigationController?.popViewController(animated: true)
        }
    }
    
    
    
    @IBAction func EditTaskPressed(sender: AnyObject) {
        print("Edit Tasks Pressed")
        if editMode == true {
            //we're here because the user clicked edit (which now says "save") ... so we're going to save the record with whatever they've changed
            self.SavePressed(sender: self)
            editMode = false
        } else {
            self.navigationItem.rightBarButtonItem?.title = NSLocalizedString("Save", comment: "Save")
            editMode = true
            
            form = createForm(editable: formIsEditable(), task: task)
        }
    }

    
    @IBAction func SavePressed(sender: AnyObject) {
        _ = self.navigationController?.popViewController(animated: true)
    }

    
    
    func showMissingRealmAlert() {
            let alert = UIAlertController(title: NSLocalizedString("Missing Realm", comment: "bad arguments"), message: NSLocalizedString("No Realm passed to us - bailing out!", comment: "bail out"), preferredStyle: .alert)
            // Cancel button
            let cancelAction = UIAlertAction(title: "OK", style: .cancel) { (action:UIAlertAction!) in
                _ = self.navigationController?.popViewController(animated: true)
            }
            alert.addAction(cancelAction)
            present(alert, animated: true, completion:nil)
    }
    
    func performDeleteTask() {        
        try! self.targetRealm?.write {
            self.targetRealm?.delete(self.task!)
        }
        self.task = nil
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
