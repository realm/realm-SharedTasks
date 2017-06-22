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
    var targetRealm: Realm?
    var targetRecordID: String?     // may be nil of we're creating a new task
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if targetRealm != nil {
            if newTaskMode {
                let leftButton = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .plain, target: self, action: #selector(self.BackCancelPressed) as Selector?)
                let rightButton = UIBarButtonItem(title: NSLocalizedString("Save", comment: "Save"), style: .plain, target: self, action: #selector(self.SavePressed))
                self.navigationItem.leftBarButtonItem = leftButton
                self.navigationItem.rightBarButtonItem = rightButton
            }

            
        } else {
            self.showMissingRealmAlert()
        }
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
        let form =
            TextRow("Task Title") { row in
                row.tag = "Title"
                row.value = task?.taskTitle
                if editable == false {
                    row.disabled = true
                }
                }.cellSetup { cell, row in
                    cell.textField.placeholder = row.tag
                }
                <<< TextAreaRow(){ row in
                    editable == false ? row.disabled = true : ()
                    row.tag = "Description"
                    row.placeholder = "Task Description"
                    row.textAreaHeight = .dynamic(initialTextViewHeight: 100)
                    row.value = task?.taskDetails
        }
         
                <<< DateRow(){ [weak self] row in
                    editable == false ? row.disabled = true : ()
                    
                    row.title = "Due Date"
                    row.value = Date()
                    let formatter = DateFormatter()
                    formatter.locale = .current
                    formatter.dateStyle = .long
                    row.dateFormatter = formatter
                    
                    if let task = self?.task {
                        row.value = task.dueDate
                    }
                    }.onChange({ (row) in
                        try! self.targetRealm?.write {
                            task?.dueDate = row.value
                        }
                    })

        return form
    }
    
    func formIsEditable() -> Bool {
        if self.newTaskMode {
            return true
        }
        return false
    }

    
    // MARK: - Actions
    
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
            
            present(alert, animated: true, completion:nil)  // 11
        } else {
            // Here too, since tasks can be "lived edited," -- and we exit the form editor by just pressing "back" in hte cse of an existing task --
            // if this task has a team assigned, we need to see if this task already exists in the TeamTaskRalm -- where we keep copies of tasks for teams.
            // if it does, we need either update the existing record, or create a new one if it's not there yet.
            if self.task!.team != nil {
                let commonRealm = try! Realm()
                let team = commonRealm.objects(Team.self).filter(NSPredicate(format: "id = %@", self.task!.team!)).first // get the teams task realm
                team!.addOrUpdateTask(taskId:self.task!.id)
            }
            
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
    }
    
    func showMissingRealmAlert() {
        
    }
    
    func performDeleteTask() {        
        try! self.targetRealm?.write {                   // (Note: this wil be the masterTasksRealm
            self.targetRealm?.delete(self.task!)         // and finally delete the master task record itself.
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
