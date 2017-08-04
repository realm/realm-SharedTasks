### Building Your First Multi-User Realm Mobile Platform iOS App

## DRAFT - 12-July-2017

This tutorial will guide you through the key elements of writing an iOS app that demonstrates a multi-user shared tasks using Realm in Swift.

The rest of this tutorial will show you how to:
  1. Setup a new Realm-based project from scratch using Cocoapods
  2. How to adopt and setup a free Realm utility module called `RealmLoginKit` which allows you to easily created multi-user ready applications with almost zero coding
  3. Learn about the management and application of permissions to Realms and how to intropspect permissions for users.
  4. Demostrate how to implement a sharing system using the user's private Realm file by manipulating permissions to ensbling syncing of data without using a central shared Realm.


The bulk of this tutorial will cover some of the salient points surrounding managing Realms, and retreival of and application of permissions to Realms to alow the sharing of tasks between users.  The fully implemented version of the application source code is too long to capture in a tutorial (and would be very tedious and error prone to type in); a completed verson of the Realm SharedTasks application can be downloaded from the the following URL:  [https://github.com/realm-demos/realm-SharedTasks](https://github.com/realm-demos/realm-SharedTasks)

In order to successfuly complete this tutorial you will need a Macintosh running macOS 10.12 or later, as well as a copy of Xcode 8.2.3 or later.

First, [install the MacOS bundle](get-started/installation/mac) if you haven't yet. This will get you set up with the Realm Mobile Platform including a local copy of the Realm Object Server.

Unless you have already have the Realm Object Server running, you will need to navigate to the downloads folder, open the Realm Object Server folder and double-click on the `start-object-server.command` file. This will start the local copy of the Realm Object Server.  After a few moments your browser will open and you will be prompted to create a new admin account and register your copy of the server.  Once you have completed this setup step, you will be ready to begin the Realm Shared Tasks tutorial, below.

## 1. Create a new Xcode project

In this section we will create the basic iOS iPhone application skeleton needed for this tutorial.

1. Launch Xcode 8.
2. Click "Create a new Xcode project".
3. Select "iOS", then "Application", then "Single View Application", then click "Next".
4. Enter "MultiUserRealmTasksTutorial" in the "Product Name" field.
5. Select "Swift" from the "Language" dropdown menu.
6. Select "iPhone" from the "Devices" dropdown menu.
7. Select your team name (log in via Xcode's preferences, if necessary) and enter an organization name.
8. Click "Next", then select a location on your Mac to create this project, then click "Create".

## 2. Setting Up Cocoapods

In this section we set up the Cocoapod dependency manager and add Realm's Swift bindings and a utility module that allows us to create a multi-user application using a preconfigured login panel

1. Quit Xcode
2. Open a Terminal window and change to the directory/folder where you created the Xcode _RealmTasksTutorial_ project
2. If you have not already done so, install the [Cocoapods system](https://cocoapods.org/)
	 - Full details are available via the Cocopods site, but the simplest instructions are to type ``sudo gem install cocoapods`` in a terminal window
3. Initialize a new Cocoapods Podfile with ```pod init```  A new file called `Podfile` will be created.
4. Edit the Podfile,  find the the comment line that reads:

  ` # Pods for MultiUserRealmTasksTutorial`
	 And add the following after this line:

    ```ruby
    pod 'RealmSwift'
    pod 'RealmLoginKit'
    ```

5. Save the file
6. At the terminal, type `pod install` - this will cause the Cocoapods system to fetch the RealmSwift and RealmLoginKit modules, as well as create a new Xcode workspace file which enabled these modules to be used in this project.

## 3. Setting up the Application Delegate
In this seciton we will configure the applicaiton degelgate to support a Navigation controller. From the Project Navigator, double-clock the AppDelegate.swift file and edit the file to replace the `func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions` method with the following:

```swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions:[UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: ViewController(style: .plain))
        window?.makeKeyAndVisible()
        return true
    }
}
```
## 4. Setting Up the Storyboard & Views

In this section we will set up our login and main view controller's storyboard connections.

1. Reopen Xcode, but rather than open `MultiUserRealmTasksTutorial.xcodeproj` use the newly created `MultiUserRealmTasksTutorial.xcworkspace` file; this was created by the Cocoapods dependency manager and should be used going forward

2. If you have not already, open the `MultiUserRealmTasksTutorial.xcworkspace` with Xcode.

3. In the Xcode project navigator select the `main.storyboard` file. Interface builder (IB) will open and show the default single view layout:

<center><img src="/Graphics/InterfaceBuilder-start.png"> 	</center>

3. Adding the TableViewController - on the lower right of the window is the object browser, type "tableview" to narrow down the possible IB objects. There will be a "TableView Controller" object visible. Drag this onto the canvas. Once you have done this the Storyboard view will resemble this:

<center> <img src="/Graphics/Adding-theTableViewController.png" /></center>


Once you have added the second view controller, you will need to connect the two controllers by a pair of segues, as well as add class names/storyboard IDs for each controller to prepare for the code will be adding in the next sections:

1. Open the storyboard propery viewer to see the ourline view of the contents of both controllers in the sotoryboard. Then, control-drag from the TasksLoginViewController label to the Table View Controller label and select "show" when the popup menu appears. Select the segue that is created between the two controllers, and set the name of ther segue in the property view on the right side to "loginToTasksViewSegue"

2. Do the same from the `TasksLoginViewController` back to the `TasksLoginViewController`.  Here, again, tap the newly created segue (it will be the diagonal line) and name this segue "tasksViewToLoginControllerSegue"

3. You will need to set the class names for each of the view controller objects. To do this select the controllers one at a time, and for the LoginView Controller, set the class name to `TasksLoginViewController` and to the storyboard id to `loginView`.  For the new TableViewController you added, set the class name to `TasksTableViewController` and here set the storyboard id to `tasksView`. A video summary of these tasks can be seen here:



<center> <img src="/Graphics/MUTasks-StoryBoardSetup.gif" /></center></br>


The final configfuration will look like this:

<center> <img src="/Graphics/final-storyboard-config.png" /></center>


## 5. Configuring the Login View Controller

In this section we will rename and then configure the TasksLoginViewController that will allow you to log in an existing user account, or create a new account


1. Open the  `view controller` file in the project naivator. Click once on it to enable editing of the file name; change the name to `TasksLoginViewController` and press return to rename the file.

2. Clicking on the filename should also have opened the newly renamed file in the editor. Here too you should replace all references to `ViewController` in the comments and class name with `TasksLoginViewController`

3. Next, we are going to update the contents of this view controller and take it from a generic, empty controller to one that can display our Login Panel.

4. Start by modifying the imports to read as follows:
    ```swift
    import UIKit
    import RealmSwift
    import RealmLoginKit
    ```

5. Modify the top of the class file so the following properties are declared:

    ```swift
    class TasksLoginViewController: UITableViewController {
    var loginViewController: LoginViewController!
    var token: NotificationToken!
    var myIdentity = SyncUser.current?.identity!

    ```

6. Next, modify the empty `viewWillAppear` method to

        ```swift
        override func viewDidAppear(_ animated: Bool) {
            loginViewController = LoginViewController(style: .lightOpaque)
            loginViewController.isServerURLFieldHidden = false
            loginViewController.isRegistering = true

            if (SyncUser.current != nil) {
                // yup - we've got a stored session, so just go right to the UITabView
                Realm.Configuration.defaultConfiguration = commonRealmConfig(user: SyncUser.current!)

                performSegue(withIdentifier: Constants.kLoginToMainView, sender: self)
            } else {
                // show the RealmLoginKit controller
                if loginViewController!.serverURL == nil {
                    loginViewController!.serverURL = Constants.syncAuthURL.absoluteString
                }
                // Set a closure that will be called on successful login
                loginViewController.loginSuccessfulHandler = { user in
                    DispatchQueue.main.async {
                        // this AsyncOpen call will open the described Realm and wait for it to download before calling its closure
                        Realm.asyncOpen(configuration: commonRealmConfig(user: SyncUser.current!)) { realm, error in
                            if let realm = realm {
                                Realm.Configuration.defaultConfiguration = commonRealmConfig(user: SyncUser.current!)
                                self.loginViewController!.dismiss(animated: true, completion: nil)
                                self.performSegue(withIdentifier: Constants.kLoginToMainView, sender: nil)

                            } else if let error = error {
                                print("An error occurred while logging in: \(error.localizedDescription)")
                            }
                        } // of asyncOpen()

                    } // of main queue dispatch
                }// of login controller

                present(loginViewController, animated: true, completion: nil)
            }
        }
        	```

Optionally, commit your progress in source control.

Your app should now build and run---although so far it doesn't do much, it will show you to login panel you just configured:

<center> <img src="/Graphics/TaskLoginView.png"  width="310" height="552" /></center>


Click the stop button to terminate the app, and we will continue with the rest of the changes needed to create our Realm Tasks app.


## 6. Create the Models and Constants Class File
In this step we are going to create a few constants to help us manage our Realm as well as the class models our Realm will operate on.

From the Project Navigator, right click and select `New File` and when the file selector apprears select `Swift File` and name the file `Constants` and press preturn.  Xcode will create a new Swift file and open it in the editor.

Our first task will be to create some contants and access functions that will make opening and working with Realms easier, then we will define the Task models.

Let's start with the Contants; add the following  to the file:

```swift
//
//  Constants.swift
//  AsyncOpenTester
//

import Foundation
import RealmSwift

struct Constants {

    static let kDefaultRealmNamePrefskey            = "defaultRealmPreference"
    static let kLoginToMainView                     = "loginToMainViewSegue"
    static let kExitToLoginViewSegue                = "segueToLogin"
    static let kViewToNewTaskSegue                  = "viewToNewTaskSegue"
    static let kViewtoDetailsSegue                  = "viewtoDetailsSegue"
    static let kMainToPermissionsSegue              = "mainToPermissionsSegue"

    static let defaultSyncHost                      = "127.0.0.1"
    static let syncRealmPath                        = "SharedTasks"
    static let privateRealm                         = "MyTasks"
    static let ApplicationName                      = "SharedTasks"

    static let syncAuthURL                          = URL(string: "http://\(defaultSyncHost):9080")!
    static let syncServerURL                        = URL(string: "realm://\(defaultSyncHost):9080/\(ApplicationName)-\(syncRealmPath)")
    static let commonRealmURL                       = URL(string: "realm://\(defaultSyncHost):9080/\(ApplicationName)-CommonRealm")!

    static let myTasksRealmURL                      = URL(string: "realm://\(defaultSyncHost):9080/~/\(privateRealm)")!

}

// this propbably could be put in a stand-alone utilites file, but these are such small utils we can keep them here.
func commonRealmConfig(user: SyncUser) -> Realm.Configuration  {
    let config = Realm.Configuration(syncConfiguration: SyncConfiguration(user: user, realmURL: Constants.commonRealmURL), objectTypes: [Person.self])
    return config
}


func privateTasksRealmConfigforUser(_ user: SyncUser) -> Realm.Configuration  {
    var config: Realm.Configuration!
    if user.identity == SyncUser.current?.identity! {
        config = Realm.Configuration(syncConfiguration: SyncConfiguration(user: user, realmURL: Constants.myTasksRealmURL), objectTypes: [Task.self])
    } else {
        let targetURLstring = Constants.myTasksRealmURL.absoluteString.replacingOccurrences(of: "~", with: user.identity!)
        config = Realm.Configuration(syncConfiguration: SyncConfiguration(user: user, realmURL: URL(string: targetURLstring)!), objectTypes: [Task.self])

    }
    return config
}

// Note: We don't need a special config accessor for the on-demand realms this app creates -
// the RealmIndexEntry class has a getter that returns the Realm for it's object.

```

There key things to note here are how the constants are layered together to create a set of accessors that allow you to quickly and easily create references to a Realm.  This example shows a single Realm but in more complex projects one could imagine having a number of such accessors created for a number of special purpose Realms.

Next, we'll add the definitions of our models.  Note that there are two kinds of models here: the Task and taskList models.

```swift
//
//  Models.swift
//  SharedTasks
//
//

import Foundation
import CoreLocation

import Realm
import RealmSwift

// MARK: Person
class Person : Object {

    dynamic var id = ""
    dynamic var creationDate: Date?
    dynamic var lastSeenDate: Date?  // this gets set periodically and is used for presence
    dynamic var lastName = ""
    dynamic var firstName = ""
    dynamic var avatar : Data? // binary image data, stored as a PNG

    // Initializers, accessors & cet.
    override static func primaryKey() -> String? {
        return "id"
    }

    override static func ignoredProperties() -> [String] {
        return ["role"]
    }

    convenience init(realmIdentity: String?) {
        self.init()
        self.id = realmIdentity!
    }

    convenience init(realmIdentity: String?, firstName: String?, lastName: String?) {
        self.init()
        self.id = realmIdentity!
        self.firstName = firstName ?? ""
        self.lastName = lastName ?? ""
    }

    func fullName() -> String {
        return "\(firstName) \(lastName)"
    }


    class func createProfile() -> Person? {
        let commonRealm =  try! Realm(configuration: commonRealmConfig(user:SyncUser.current!))
        var profileRecord = commonRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", SyncUser.current!.identity!)).first
        if profileRecord == nil {
            try! commonRealm.write {
                profileRecord = commonRealm.create(Person.self, value:["id": SyncUser.current!.identity!, "creationDate": Date(),  "lastUpdated": Date()])
                commonRealm.add(profileRecord!, update: true)
            }
        }
        return profileRecord
    }


    class func getPersonForID(id: String?) -> Person? {
        guard id != nil else {
            return nil
        }
        let realm = try! Realm()
        let identityPredicate = NSPredicate(format: "id = %@", id!)
        return realm.objects(Person.self).filter(identityPredicate).first //get the person
    }
} // of Person


class Task : Object {
    dynamic var id = ""
    dynamic var createdBy = ""
    dynamic var lastUpdatedBy = ""
    dynamic var creationDate: Date?
    dynamic var lastUpdate: Date?
    dynamic var dueDate: Date?
    dynamic var taskTitle = ""
    dynamic var taskDetails = ""

    // Initializers, accessors & cet.
    override static func primaryKey() -> String? {
        return "id"
    }

} // of Task

```
Bot that the Person model isn't strictly required for our application - authenication is taken care of by the Realm Object Server itself - these models however do alow us to create a profile type object that links together the Realm User identity and some useful metadata that make it easier for the application's users to see whom they are dealing with whnr the decide to share information in their taks lists with other users.   *Note*: As of Realm Cocoa version 2.9.x the basic user info stored in the Realm username/password system is exposed so a dedicated Person model could be dispensed with; however we will continue using our cusotm model since it provides a complete example of how to integrate and epanded user meta-data model into an application.

At this point, we've created a login system, and defined the data models (`Task` and `Person`) that we'll use to represent our data.

Your app should still build and run.


## 7. Fleshing Out the Application - Permissions, Users and realms

The fully implemented version of the application source code is too long to capture here in a tutorial (and would be very tedious and error prone to type in.  The remainder of this tutorial will cover some of the salient points surrounding managing Realms, and retreival of and application of permissions to Realms to alow the sharing of tasks between users; a completed verson of the Realm SharedTasks application can be downloaded from the the following URL:  [https://github.com/realm-demos/realm-SharedTasks](https://github.com/realm-demos/realm-SharedTasks)

### Checking a User's Permissions

Realm supports 3 basic permissions: read-only, write (which includes 'read') and manage (which allows the enabled user to change all permissions on other Realm). In addition wildcard permissions can be applied to a Realm to allow "all users" any of the above permissions.

The Realm permssions API (as of Realm Cocoa version 2.9.1) suport the introspection of permissions for the current user -- this means that when logged in you can, in effect, ask the Realm Object Server  "_tell me what Realms I have been granted explicit access to, and what those access levels are_."

What is returned is an array of Permission `SyncAccessLevel` objects that describe zero or or more Realms that some other user has granted the currnet, requesting user.

In order to get the permssions for the current user, a user must be logged in (which means the `SyncUser.current` property isn't nil).


### Setting permissions

Setting permissions on an Realm is very simple; you need to know is the user identity (the `SyncUser.identy`) of the grantee and the parth to the Realm you wish to change the access permissions to:

```swift
let permission = SyncPermissionValue(realmPath: realmPath,  // The remote Realm path on which to apply the changes
                                     userID: anotherUserID, // The user ID for which these permission changes should be applied
                                     accessLevel: .write)   // The access level to be granted
user.applyPermission(permission) { error in
  if let error = error {
    // handle error
    return
  }
  // permission was successfully applied
}
```
The permsssion change is, like many Realm calls imeplementeed as a call back, so you will will be called-back at a later time with the results of change, or an error if the change could not be ipemented.

Note, unless your acount is an admin level account -- which means that you have the admin flag set in the Realm Console of your Realm installation -- you will only be able to modify permissions on Realms you own dirdectly or one which your user id has been granted the `manage` permission.

# The SharedTasks Model

The SharedTasks model is simple: the bacic idea is that each user has a collection of tasks in a list; their list can be either private -- it's only accessible sing their own account, or it cane be shared with one or more other users. Other users can be granted either read-inly or read-write access.

The basic model is shown here:

<center> <img src="/Graphics/SharedRealms.png"  width="50%" height="50%" /></center><br/>

This mode takes adavantage of the Realm Object Server in an intersting way: it causes the server to sync Realms _between devices_, rather than causibg all devices to use a shared common database. This
