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

    var chatHubConnection: HubConnection?
    var chatHubConnectionDelegate: ChatHubConnectionDelegate?
    var name = ""
    var messages: [String] = []

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        chatTableView.delegate = self
        chatTableView.dataSource = self
        usersOnlineTableView.delegate = self
        usersOnlineTableView.dataSource = self

        sendBtn.isEnabled = false
        msgTextField.isEnabled = false

        name = getName()

        chatHubConnectionDelegate = ChatHubConnectionDelegate(app: self)

        // TODO: query should not be needed
        chatHubConnection = HubConnection(url: URL(string:"http://localhost:5000/chat")!)
        chatHubConnection!.delegate = chatHubConnectionDelegate
        chatHubConnection!.on(method: "NewMessage", callback: {args in
            self.appendMessage(message: "\(args[0]!): \(args[1]!)")

        })
        chatHubConnection!.start()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
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

    func numberOfRows(in tableView: NSTableView) -> Int {
        return 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        return nil
    }
}
