# Building Your First Multi-User Realm Mobile Platform iOS App

This tutorial will guide you through the key elements of writing an iOS app that demonstrates a multi-user shared tasks using Realm in Swift.

The rest of this tutorial will show you how to:
  1. Setup a new Realm-based project from scratch using Cocoapods
  2. How to adopt and setup a free Realm utility module called `RealmLoginKit` which allows you to easily created multi-user ready applications with almost zero coding
  3. Learn about the management and application of permissions to Realms and how to introspect permissions for users.
  4. Show the basics of how to implement a sharing system using the user's private Realm file by manipulating permissions to enabling syncing of data without using a central shared Realm.

The bulk of this tutorial will cover some of the salient points surrounding managing Realms, and retrieval of and application of permissions to Realms to allow the sharing of tasks between users.  The fully implemented version of the application source code is too long to capture in a tutorial (and would be very tedious and error prone to type in); a completed version of the Realm SharedTasks application can be downloaded from the the following URL:  [https://github.com/realm-demos/realm-SharedTasks](https://github.com/realm-demos/realm-SharedTasks)

In order to successfully complete this tutorial you will need a Macintosh running macOS 10.12 or later, as well as a copy of Xcode 8.2.3 or later.

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
4. Edit the Podfile,  find the comment line that reads:

  ` # Pods for MultiUserRealmTasksTutorial`
	 And add the following after this line:

    ```ruby
    pod 'RealmSwift'
    pod 'RealmLoginKit'
    ```

5. Save the file
6. At the terminal, type `pod install` - this will cause the Cocoapods system to fetch the RealmSwift and RealmLoginKit modules, as well as create a new Xcode workspace file which enabled these modules to be used in this project.

## 3. Setting Up the Application Delegate
In this section we will configure the application delegate to support a Navigation controller. From the Project Navigator, double-clock the AppDelegate.swift file and edit the file to replace the `func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions` method with the following:

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

1. Open the storyboard property viewer to see the outline view of the contents of both controllers in the storyboard. Then, control-drag from the TasksLoginViewController label to the Table View Controller label and select "show" when the popup menu appears. Select the segue that is created between the two controllers, and set the name of the segue in the property view on the right side to "loginToTasksViewSegue"

2. Do the same from the `TasksLoginViewController` back to the `TasksLoginViewController`.  Here, again, tap the newly created segue (it will be the diagonal line) and name this segue "tasksViewToLoginControllerSegue"

3. You will need to set the class names for each of the view controller objects. To do this select the controllers one at a time, and for the LoginView Controller, set the class name to `TasksLoginViewController` and to the storyboard id to `loginView`.  For the new TableViewController you added, set the class name to `TasksTableViewController` and here set the storyboard id to `tasksView`. A video summary of these tasks can be seen here:



<center> <img src="/Graphics/MUTasks-StoryBoardSetup.gif" /></center></br>


The final configuration will look like this:

<center> <img src="/Graphics/final-storyboard-config.png" /></center>


## 5. Configuring the Login View Controller

In this section we will rename and then configure the TasksLoginViewController that will allow you to log in an existing user account, or create a new account


1. Open the  `view controller` file in the project navigator. Click once on it to enable editing of the file name; change the name to `TasksLoginViewController` and press return to rename the file.

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

From the Project Navigator, right click and select `New File` and when the file selector appears select `Swift File` and name the file `Constants` and press return.  Xcode will create a new Swift file and open it in the editor.

Our first task will be to create some constants and access functions that will make opening and working with Realms easier, then we will define the Task models.

Let's start with the Constants; add the following  to the file:

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

The key things to note here are how the constants are layered together to create a set of accessors that allow you to quickly and easily create references to a Realm.  This example shows a single Realm but in more complex projects one could imagine having a number of such accessors created for a number of special purpose Realms.

Next, we'll add the definitions of our models.  Note that there are three kinds of models here: the Task and taskList models, and a Person oil that represents metadata about users in the system.  This makes it easy to figure out who is who, without having to know people's numeric user IDs. You will also notice there are several utility methods on these Realm model classes to make the management of these objects easier.

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
Bot that the Person model isn't strictly required for our application - authentication is taken care of by the Realm Object Server itself - these models however do allow us to create a profile type object that links together the Realm User identity and some useful metadata that make it easier for the application's users to see whom they are dealing with whnr the decide to share information in their tasks lists with other users.   *Note*: As of Realm Cocoa version 2.9.x the basic user info stored in the Realm username/password system is exposed so a dedicated Person model could be dispensed with; however we will continue using our custom model since it provides a complete example of how to integrate and expanded user metadata model into an application.

At this point, we've created a login system, and defined the data models (`Task` and `Person`) that we'll use to represent our data.

Your app should still build and run.


## 7. Fleshing Out the Application - Permissions, Users and Realms

The fully implemented version of the application source code is too long to capture here in a tutorial (and would be very tedious and error prone to type in).  The remainder of this tutorial will cover some of the salient points surrounding managing Realms, and retrieval of and application of permissions to Realms to allow the sharing of tasks between users; a completed version of the Realm SharedTasks application can be downloaded from the the following URL:  [https://github.com/realm-demos/realm-SharedTasks](https://github.com/realm-demos/realm-SharedTasks)


# The SharedTasks Model

The SharedTasks model is simple: the basic idea is that each user has a collection of tasks in a list; their list can be either private -- it's only accessible using their own account, or it can be shared with one or more other users. Other users can be granted either read-only or read-write access. These access permissions can be changed at any time.

The basic interaction model is shown here:

<center> <img src="/Graphics/SharedRealms.png"  width="50%" height="50%" /></center><br/>

This model takes advantage of the Realm Object Server in an interesting way: it causes the server to sync Realms _between devices_, rather than causing all devices to synchronize with a  common database for these tasks (the common Realm here is used for user profiles). One could write a shares tasks lists using a common Realm but it would have the disadvantage of causing all tasks to sync with all users of the system.  This is both wasteful in terms of bandwidth, but it also guarantees that completely released users will have each others tasks on their devices... which even if the app were coded to now show these users each other's tasks, would represent a pretty poor application and security design.

This model works because every user has a Realm path that represents not a shared Realm, but a private directory on their device.  This is where applications typically put information that doesn't need to be shared with all other users.  However this Realm is no different than other Realms, and if it is opened by another user -- with the right access/permissions -- the Realm server will sync these "private" user Realms. You can thing of this as a "shared-private-Realm."

Iplementing this functionality is quite easy, it's all about managing the permissions on the Realm.

### Checking a User's Permissions

Realm supports 3 basic permissions: read-only, write (which includes 'read') and manage (which allows the enabled user to change all permissions on other Realm). In addition wildcard permissions can be applied to a Realm to allow "all users" any of the above permissions.

The Realm permissions API (as of Realm Cocoa version 2.9.1) supports the introspection of permissions for the current user -- this means that when logged in you can, in effect, ask the Realm Object Server  "_tell me what Realms I have been granted explicit access to, and what those access levels are_."

What is returned is an array of Permission `SyncAccessLevel` objects that describe zero or or more Realms that some other user has granted the current, requesting user.

In order to get the permissions for the current user, a user must be logged in (which means the `SyncUser.current` property isn't nil). The call is always relative to the current user, as in:
```swift
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
        }

```

## Exploring Permissions with Extensions
As mentioned previously, permission objects (`SyncPermissionValue`) themselves are structures that contain the actual permission access values (`SyncAccessLevel`). These structures can be introspected and then reasoned about, but they are, at first blush rather opaque.  The SharedTasks app includes a couple of convenience extensions to the Realm permissions system to help developers examine and work with them more easily.  For example, we can define extensions to help decode a permission value and even print out a human-readable string that can be use to display these values in an application's UI:
```swift
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
```


### Setting permissions

Setting permissions on an Realm is very simple; you need to know is the user identity (the `SyncUser.identy`) of the grantee and the path to the Realm you wish to change the access permissions to:

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
The permission change is, like many Realm calls implemented as a call0back, so you will be called-back at a later time with the results of change, or an error if the change could not be implemented.

Note, unless your account is an admin level account -- which means that you have the admin flag set in the Realm Console of your Realm installation -- you will only be able to modify permissions on Realms you own directly or one which your user id has been granted the `manage` permission.


# Permission Changes in Action
The SharedTasks app is implemented as a (mostly) single view application.  The main content (user profile, and tasks-list view) are all in a single view.

Task creation and the viewing and/or setting permissions for other users is another utility view pushed in as needed.

<center> <img src="/Graphics/SharedTasks-Permissions.png"  width="310" height="552" /><br/>Shared Permissions</center><br/>&nbsp;&nbsp;

Note that any user can only see the task list of users that have  granted them at least read-only access (this makes sense, if a given user's private Realm isn't in your list of permitted Realms, it is, effectively, invisible to you).

It is also worth noting that if a user revokes your permissions, their Realm and its takes become invisible to you, but the content created in their private Realm by while you had access remains.

<center><img src="/Graphics/NewTask.png"  width="310" height="552" /><br/>New Task View</center><br/>

<center><img src="/Graphics/SharedTasks-SetPermissions.png"  width="310" height="552" /><br/>Setting Permissions</center><br/>

Allowing another user to access your private Realm is as easy as selecting the user and then a permission level, and then creating/firing a permission change request.

Remove a permission is the same call, just with the appropriate permission flags unset. The changes from your perspective happen immediately, and will be propagated to the targeted users when they are online.

### A Vew at the Realm Level
A composite view of how these "shared-private-Realms" work together can be seen here, using the [Realm Browser](https://itunes.apple.com/us/app/realm-browser/id1007457278?mt=12):

<center> <img src="/Graphics/SharedTaks-Browser.png"  width="50%" height="50%" /></center>

In this image the iPhone portion screenshot shows the task created by the user "David" while the Realm Browser shows both David's and "Worker 2"'s private Realms showing the task content and the fact that the task show (the "late Sumer party" task) resides in the domain of "Worker2" (id = *f6002d41fd2c72752f0d41f9891844a5*) but was in fact created by user "David" (id = *1a7332940598a2d6349ad414d31daf11*).

# Conclusion
As you will see in the downloaded application, the Realm permission system is very simple yet can be used to create dynamic behaviors in your applications, even complex peer-to-peer like sharing data systems that don't require a central set of shared data models.



## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for more details!

This project adheres to the [Contributor Covenant Code of Conduct](https://realm.io/conduct/). By participating, you are expected to uphold this code. Please report unacceptable behavior to [info@realm.io](mailto:info@realm.io).

## License

Distributed under the Apache 2.0 license. See [LICENSE](LICENSE) for more information.
