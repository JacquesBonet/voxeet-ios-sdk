//
//  Conference.swift
//  VoxeetSDK Sample
//
//  Created by Coco on 28/04/16.
//  Copyright © 2016 Corentin Larroque. All rights reserved.
//

import UIKit
import VoxeetSDK

/*
 *  MARK: - User structure
 */

struct User {
    var userID: String
    var externalID: String?
    var avatarUrl: String?
    var name: String?
}

/*
 *  MARK: - Conference class
 */

class Conference: UIViewController {
    // UI.
    @IBOutlet weak var conferenceIDLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var broadcastMessageTextView: UITextView!
    @IBOutlet weak var screenShareView: VideoRenderer!
    @IBOutlet weak var ownCameraView: VideoRenderer!
    @IBOutlet weak var switchDeviceSpeakerButton: UIButton!
    
    // Current conference ID.
    var conferenceID: String?
    
    // Users' data.
    var users = [User]()
    
    /*
     *  MARK: Load / Unload
     */
    
    override func viewDidLoad() {
        // Setting label.
        conferenceIDLabel.text = conferenceID
        
        // Conference delegate.
        VoxeetSDK.sharedInstance.conference.delegate = self
        
        // Conference media delegate.
        VoxeetSDK.sharedInstance.conference.mediaDelegate = self
        
        // Joining / Launching demo.
        if let confID = conferenceID {
            // Joining Conference.
            VoxeetSDK.sharedInstance.conference.join(conferenceAlias: confID) { (error) in
                if error != nil {
                    // Debug.
                    print("::DEBUG:: <joinConference> \(error)")
                    
                    self.dismissViewControllerAnimated(true, completion: nil)
                }
            }
        } else {
            conferenceIDLabel.text = "Demo"
            
            // Creating Voxeet demo conference.
            VoxeetSDK.sharedInstance.conference.createDemo { (error) in
                if error != nil {
                    // Debug.
                    print("::DEBUG:: <createDemoConference> \(error)")
                    
                    self.dismissViewControllerAnimated(true, completion: nil)
                }
            }
        }
        
        // Select/Deselect the switchDeviceSpeakerButton when an audio session route is changed.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(audioSessionRouteChange), name: AVAudioSessionRouteChangeNotification, object: nil)
    }
    
    deinit {
        // Debug.
        print("::DEBUG:: <deinitConference>")
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    /*
     *  MARK: Actions
     */
    
    @IBAction func sendBroadcastMessage(sender: AnyObject) {
        // Alert view.
        let alertController = UIAlertController(title: "Send Message", message: "Please input the message:", preferredStyle: .Alert)
        
        // Alert actions.
        let confirmAction = UIAlertAction(title: "Send", style: .Default) { (_) in
            if let textField = alertController.textFields?[0],
                let message = textField.text {
                // Sending a broadcast message.
                VoxeetSDK.sharedInstance.conference.sendBroadcastMessage(message, completion: { (error) in
                    // Debug.
                    print("::DEBUG:: <sendBroadcastMessage> \(error)")
                })
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { (_) in }
        
        // Alert textField.
        alertController.addTextFieldWithConfigurationHandler { (textField) in
            textField.placeholder = "Message"
            textField.clearButtonMode = .WhileEditing
        }
        
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    @IBAction func switchDeviceSpeaker(button: UIButton) {
        VoxeetSDK.sharedInstance.conference.switchDeviceSpeaker()
    }
    
    @IBAction func hangUp(sender: AnyObject) {
        VoxeetSDK.sharedInstance.conference.leave { (error) in
            // Debug.
            print("::DEBUG:: <leaveConference> \(error)")
            
            self.dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    @IBAction func switchCamera(sender: AnyObject) {
        VoxeetSDK.sharedInstance.conference.flipCamera()
    }
    
    /*
     *  MARK: Observer
     */
    
    @objc func audioSessionRouteChange() {
        dispatch_async(dispatch_get_main_queue(), {
            self.switchDeviceSpeakerButton.selected = AVAudioSession.sharedInstance().currentRoute.outputs.first?.portType == AVAudioSessionPortBuiltInSpeaker
        })
    }
}

/*
 *  MARK: - Voxeet SDK conference delegate
 */

extension Conference: VTConferenceDelegate {
    func userJoined(userID: String, userInfo: [String: AnyObject]) {
        users.append(User(userID: userID, externalID: userInfo["externalId"] as? String, avatarUrl: userInfo["avatarUrl"] as? String, name: userInfo["name"] as? String))
        tableView.reloadData()
    }
    
    func userLeft(userID: String, userInfo: [String: AnyObject]) {
        users = users.filter({ $0.userID != userID })
        tableView.reloadData()
    }
    
    func messageReceived(userID: String, userInfo: [String: AnyObject], message: String) {
        if let name = users.filter({ $0.userID == userID }).first?.name {
            broadcastMessageTextView.text = "\(name): \(message)"
        } else {
            broadcastMessageTextView.text = "\(userID): \(message)"
        }
    }
}

/*
 *  MARK: - Voxeet SDK conference media delegate
 */

extension Conference: VTConferenceMediaDelegate {
    
    func streamAdded(stream: MediaStream, userID: String) {
        if let ownUserID = VoxeetSDK.sharedInstance.conference.getOwnUser()?.userID where ownUserID == userID {
            // Attaching own user's video stream.
            ownCameraView.hidden = false
            VoxeetSDK.sharedInstance.conference.attachMediaStream(stream, renderer: ownCameraView)
        } else if let index = self.users.indexOf({ $0.userID == userID }), let cell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0)) as? ConferenceTableViewCell {
            // Attaching user's video stream.
            cell.userVideoView.hidden = false
            VoxeetSDK.sharedInstance.conference.attachMediaStream(stream, renderer: cell.userVideoView)
        }
    }
    
    func streamRemoved(userID: String) {
        if let index = self.users.indexOf({ $0.userID == userID }), let cell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0)) as? ConferenceTableViewCell {
            cell.userVideoView.hidden = true
        }
    }
    
    func streamScreenShareAdded(stream: MediaStream, userID: String) {
        // Attaching a video stream to a renderer.
        VoxeetSDK.sharedInstance.conference.attachMediaStream(stream, renderer: screenShareView)
    }
    
    func streamScreenShareRemoved(userID: String) {
    }
}

/*
 *  MARK: - Conference tableView dataSource & delegate
 */

extension Conference: UITableViewDataSource, UITableViewDelegate {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("tableViewCell", forIndexPath: indexPath) as! ConferenceTableViewCell
        
        // Getting the current user.
        let user = users[indexPath.row]
        
        // Setting up the cell.
        cell.setUp(user)
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        // Mutes a user.
        let user = users[indexPath.row]
        VoxeetSDK.sharedInstance.conference.muteUser(!VoxeetSDK.sharedInstance.conference.isUserMuted(userID: user.userID), userID: user.userID)
        
        // Update background color.
        if let cell = tableView.cellForRowAtIndexPath(indexPath) {
            cell.backgroundColor = VoxeetSDK.sharedInstance.conference.isUserMuted(userID: user.userID) ? UIColor.redColor() : UIColor.whiteColor()
        }
    }
}