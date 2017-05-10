//
//  AppDelegate.swift
//  Chat
//
//  Created by Pawel Kadluczka on 5/8/17.
//  Copyright © 2017 Pawel Kadluczka. All rights reserved.
//

import Cocoa
import SignalRClient

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {

    @IBOutlet weak var window: NSWindow!
    
    @IBOutlet weak var sendBtn: NSButton!
    @IBOutlet weak var msgTextField: NSTextField!
    @IBOutlet weak var chatTableView: NSTableView!
    @IBOutlet weak var usersOnlineTableView: NSTableView!

    private let dispatchQueue = DispatchQueue(label: "hubsample.queue.dispatcheueuq")
    
    var chatHubConnection: HubConnection?
    var chatHubConnectionDelegate: ChatHubConnectionDelegate?
    var name = ""
    var messages: [String] = []
    var usersOnline: [[String]] = []

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        chatTableView.delegate = self
        chatTableView.dataSource = self
        usersOnlineTableView.delegate = self
        usersOnlineTableView.dataSource = self

        sendBtn.isEnabled = false
        msgTextField.isEnabled = false

        name = getName()

        chatHubConnectionDelegate = ChatHubConnectionDelegate(app: self)

        let invocationSerializer = JSONInvocationSerializer(typeConverter: UserTypeConverter())

        chatHubConnection = HubConnection(url: URL(string:"http://192.168.0.108:5000/chat")!, query: "name=\(name)", invocationSerializer: invocationSerializer)
        chatHubConnection!.delegate = chatHubConnectionDelegate
        chatHubConnection!.on(method: "Send", callback: {args in
            self.appendMessage(message: "\(args[0]!): \(args[1]!)")

        })
        chatHubConnection!.on(method: "SetUsersOnline", callback: {args in
            self.appendUsers(users: self.getUsers(users: args[0] as! [Any]) as! [User])
        })

        chatHubConnection!.on(method: "UsersJoined", callback: {args in
            let users = self.getUsers(users: args[0] as! [Any])
            for u in users {
                self.appendMessage(message: "\(u!.name) joined chat")
            }
            self.appendUsers(users: users as! [User])
        })
        chatHubConnection!.on(method: "UsersLeft", callback: {args in
            let users = self.getUsers(users: args[0] as! [Any])
            for u in users {
                self.appendMessage(message: "\(u!.name) left chat")
            }

            self.removeUsers(users: users as! [User])
        })

        chatHubConnection!.start()
    }

    func getName() -> String {
        let alert = NSAlert()
        alert.messageText = "Enter your Name"
        alert.addButton(withTitle: "OK")

        let textField = NSTextField(string: nil)
        textField.placeholderString = "Name"
        textField.setFrameSize(NSSize(width: 250, height: textField.frame.height))

        alert.accessoryView = textField

        alert.runModal()

        return textField.stringValue
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        chatHubConnection?.stop()
    }
    
    func connectionDidStart() {
        toggleUI(isEnabled: true)
    }
    
    func connectionDidFailToOpen(error: Error)
    {
        appendMessage(message: "Connection failed to start. Error \(error)")
        toggleUI(isEnabled: false)
    }
    
    func connectionDidClose(error: Error?) {
        var message = "Connection closed."
        if error != nil {
            message.append(" Error: \(error)")
        }
        appendMessage(message: message)
        toggleUI(isEnabled: false)
    }
    
    func toggleUI(isEnabled: Bool) {
        sendBtn.isEnabled = isEnabled
        msgTextField.isEnabled = isEnabled
    }
    
    func appendMessage(message: String) {
        self.dispatchQueue.sync {
            self.messages.append(message)
        }
        
        self.chatTableView.beginUpdates()
        let index = IndexSet(integer: self.chatTableView.numberOfRows)
        self.chatTableView.insertRows(at: index)
        self.chatTableView.endUpdates()
        self.chatTableView.scrollRowToVisible(self.chatTableView.numberOfRows - 1)
    }

    func appendUsers(users:[User]) {
        var count = 0
        self.dispatchQueue.sync {
            for u in users {
                if !userTracked(userId: u.connectionId) {
                    usersOnline.append([u.connectionId, u.name])
                    count += 1
                }
            }
        }

        if count == 0 {
            return
        }

        self.usersOnlineTableView.reloadData()
    }

    func removeUsers(users:[User]) {
        var count = 0
        self.dispatchQueue.sync {
            for u in users {
                for i in 0...self.usersOnline.count {
                    if usersOnline[i][0] == u.connectionId {
                        usersOnline.remove(at: i)
                        count += 1
                        break;
                    }
                }
            }
        }

        if count == 0 {
            return
        }

        self.usersOnlineTableView.reloadData()
    }

    func getUsers(users:[Any]) -> [User?] {
        if let usersObject = users as? [[String: Any?]?] {
            let result: [User?] = usersObject.map({userDictionary in
                if userDictionary == nil {
                        return nil
                }

                let user = userDictionary!
                return User(name: user["Name"] as! String, connectionId: user["ConnectionId"] as! String)
            })

            return result
        }

        return[]
    }

    func userTracked(userId: String) -> Bool {
        for u in usersOnline {
            if u[0] == userId {
                return true
            }
        }

        return false
    }
    
    @IBAction func btnSend(sender: AnyObject) {
        let message = msgTextField.stringValue
        if msgTextField.stringValue != "" {
            chatHubConnection?.invoke(method: "Send", arguments: [message], invocationDidComplete:
                {error in
                    if error != nil {
                        self.appendMessage(message: "Error: \(error)")
                    }
            })
            msgTextField.stringValue = ""
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == chatTableView {
            var count = -1
            dispatchQueue.sync {
                count = self.messages.count
            }
            return count
        }

        if tableView == usersOnlineTableView {
            var count = -1
            dispatchQueue.sync {
                count = self.usersOnline.count
            }
            return count
        }
        
        return 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableColumn == chatTableView.tableColumns[0] {
            if let cellView = tableView.make(withIdentifier: "MessageID", owner: self) as? NSTableCellView {
                cellView.textField?.stringValue = messages[row]
                return cellView
            }
        }

        if tableColumn == usersOnlineTableView.tableColumns[0] {
            if let cellView = tableView.make(withIdentifier: "UsersOnlineID", owner: self) as? NSTableCellView {
                cellView.textField?.stringValue = usersOnline[row][1]
                return cellView
            }
        }
        return nil
    }
}

class ChatHubConnectionDelegate: HubConnectionDelegate {
    weak var app: AppDelegate?
    
    init(app: AppDelegate) {
        self.app = app
    }
    
    func connectionDidOpen(hubConnection: HubConnection!) {
        app?.connectionDidStart()
    }
    
    func connectionDidFailToOpen(error: Error) {
        app?.connectionDidFailToOpen(error: error)
    }
    
    func connectionDidClose(error: Error?) {
        app?.connectionDidClose(error: error)
    }
}

