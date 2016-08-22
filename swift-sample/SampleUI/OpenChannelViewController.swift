//
//  OpenChannelViewController.swift
//  SampleUI
//
//  Created by Jed Kyung on 8/19/16.
//  Copyright © 2016 SendBird. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import MobileCoreServices
import SendBirdSDK
import AVKit
import AVFoundation

protocol OpenChannelViewControllerDelegate {
    func didCloseOpenChannelViewController(vc: UIViewController)
}

class OpenChannelViewController: JSQMessagesViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, SBDConnectionDelegate, SBDChannelDelegate {
    var channel: SBDOpenChannel?
    
    private var avatars: NSMutableDictionary?
    private var users: NSMutableDictionary?
    private var outgoingBubbleImageData: JSQMessagesBubbleImage?
    private var incomingBubbleImageData: JSQMessagesBubbleImage?
    private var neutralBubbleImageData: JSQMessagesBubbleImage?
    private var messages: NSMutableArray?
    
    private var lastMessageTimestamp: Int64 = 0
    private var firstMessageTimestamp: Int64 = INT64_MAX
    
    private var isLoading: Bool = false
    private var hasPrev: Bool = false
    
    private var previousMessageQuery: SBDPreviousMessageListQuery?
    private var delegateIndetifier: String?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.isLoading = false
        self.hasPrev = true
        
        self.avatars = NSMutableDictionary()
        self.users = NSMutableDictionary()
        self.messages = NSMutableArray()
        
        self.lastMessageTimestamp = 0
        self.firstMessageTimestamp = INT64_MAX
        
        self.collectionView.collectionViewLayout.incomingAvatarViewSize = CGSizeMake(kJSQMessagesCollectionViewAvatarSizeDefault, kJSQMessagesCollectionViewAvatarSizeDefault)
        self.collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSizeMake(kJSQMessagesCollectionViewAvatarSizeDefault, kJSQMessagesCollectionViewAvatarSizeDefault)
        
        self.showLoadEarlierMessagesHeader = false
        self.collectionView.collectionViewLayout.springinessEnabled = false
        self.collectionView.bounces = false
        
        let bubbleFactory = JSQMessagesBubbleImageFactory()
        let neutralBubbleFactory = JSQMessagesBubbleImageFactory.init(bubbleImage: UIImage.jsq_bubbleCompactTaillessImage(), capInsets: UIEdgeInsetsZero)
        
        self.inputToolbar.contentView.textView.delegate = self
        
        self.outgoingBubbleImageData = bubbleFactory.outgoingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleLightGrayColor())
        self.incomingBubbleImageData = bubbleFactory.incomingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleGreenColor())
        self.neutralBubbleImageData = neutralBubbleFactory.neutralMessagesBubbleImageWithColor(UIColor.jsq_messageNeutralBubbleColor())

        self.delegateIndetifier = self.description
        
        SBDMain.addChannelDelegate(self, identifier: self.delegateIndetifier!)
        SBDMain.addConnectionDelegate(self, identifier: self.delegateIndetifier!)
        
        self.startSendBird()
    }
    
    override func viewWillDisappear(animated: Bool) {
        if self.navigationController?.viewControllers.indexOf(self) == NSNotFound {
            SBDMain.removeChannelDelegateForIdentifier(self.delegateIndetifier!)
            SBDMain.removeConnectionDelegateForIdentifier(self.delegateIndetifier!)
            
            // TODO:
            self.channel?.exitChannelWithCompletionHandler({ (error) in
                
            })
        }
        
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    private func actionPressed(sender: UIBarButtonItem) {
        print("actionPressed.")
        let alert = UIAlertController.init(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
        
        let closeAction = UIAlertAction.init(title: "Close", style: UIAlertActionStyle.Cancel, handler: nil)
        let seeParticipantAction = UIAlertAction.init(title: "See participant list", style: UIAlertActionStyle.Default) { (action) in
            // TODO:
        }
        let seeBlockedUserListAction = UIAlertAction.init(title: "See blocked user list", style: UIAlertActionStyle.Default) { (action) in
            // TODO:
        }
        let exitAction = UIAlertAction.init(title: "Exit from this channel", style: UIAlertActionStyle.Default) { (action) in
            self.channel?.exitChannelWithCompletionHandler({ (error) in
                dispatch_async(dispatch_get_main_queue(), { 
                    self.dismissViewControllerAnimated(true, completion: nil)
                })
            })
        }

        alert.addAction(closeAction)
        alert.addAction(seeParticipantAction)
        alert.addAction(seeBlockedUserListAction)
        alert.addAction(exitAction)
        
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: nil)
        })
    }
    
    private func invitePressed(sender: UIBarButtonItem) {
        print("invitePressed")
        
        // TODO:
    }

    private func startSendBird() {
        if self.channel != nil {
            self.previousMessageQuery = self.channel?.createPreviousMessageListQuery()
            self.channel?.enterChannelWithCompletionHandler({ (error) in
                if (error == nil) {
                    self.loadMessage(Int64.max, initial: true)
                }
            })
        }
    }
    
    private func loadMessage(ts:Int64, initial:Bool) {
        if self.previousMessageQuery?.isLoading() == true {
            return;
        }
        
        if self.hasPrev == false {
            return;
        }
        
        self.previousMessageQuery?.loadPreviousMessagesWithLimit(30, reverse: !initial, completionHandler: { (messages, error) in
            if error != nil {
                print("Loading previous message error", error)
                
                return
            }
            
            if messages != nil && messages!.count > 0 {
                var msgCount: Int32 = 0
                
                for message: SBDBaseMessage in messages! {
                    if message.isKindOfClass(SBDUserMessage) == true {
                        print("Message type: MESG, Timestamp: ", message.createdAt)
                    }
                    else if message.isKindOfClass(SBDFileMessage) == true {
                        print("Message type: FILE, Timestamp: ", message.createdAt)
                    }
                    else if message.isKindOfClass(SBDAdminMessage) == true {
                        print("Message type: ADMM, Timestamp: ", message.createdAt)
                    }
                    
                    if message.createdAt < self.firstMessageTimestamp {
                        self.firstMessageTimestamp = message.createdAt
                    }
                    
                    var jsqsbmsg: JSQSBMessage?
                    
                    if message.isKindOfClass(SBDUserMessage) == true {
                        let senderId = (message as! SBDUserMessage).sender?.userId
                        let senderImage = (message as! SBDUserMessage).sender?.profileUrl
                        let senderName = (message as! SBDUserMessage).sender?.nickname
                        let msgDate = NSDate.init(timeIntervalSince1970: Double((message as! SBDUserMessage).createdAt) / 1000.0)
                        let messageText = (message as! SBDUserMessage).message
                        
                        var initialName: NSString = ""
                        if senderName?.characters.count > 1 {
                            initialName = (senderName! as NSString).substringWithRange(NSRange(location: 0, length: 2))
                        }
                        else if senderName?.characters.count > 0 {
                            initialName = (senderName! as NSString).substringWithRange(NSRange(location: 0, length: 1))
                        }
                        
                        let placeholderImage = JSQMessagesAvatarImageFactory.circularAvatarPlaceholderImage(initialName as String, backgroundColor: UIColor.lightGrayColor(), textColor: UIColor.darkGrayColor(), font: UIFont.systemFontOfSize(13.0), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
                        let avatarImage = JSQMessagesAvatarImageFactory.avatarImageWithImageURL(senderImage, highlightedImageURL: nil, placeholderImage: placeholderImage, diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
                        
                        self.avatars?.setObject(avatarImage, forKey: senderId!)
                        self.users?.setObject(senderName!, forKey: senderId!)
                        
                        jsqsbmsg = JSQSBMessage(senderId: senderId, senderDisplayName: senderName, date: msgDate, text: messageText)
                        jsqsbmsg!.message = message
                        msgCount += 1
                    }
                    else if message.isKindOfClass(SBDFileMessage) == true {
                        let senderId = (message as! SBDFileMessage).sender?.userId
                        let senderImage = (message as! SBDFileMessage).sender?.profileUrl
                        let senderName = (message as! SBDFileMessage).sender?.nickname
                        let msgDate = NSDate.init(timeIntervalSince1970: Double((message as! SBDFileMessage).createdAt) / 1000.0)
                        let url = (message as! SBDFileMessage).url
                        let type = (message as! SBDFileMessage).type
                        
                        var initialName: NSString = ""
                        if senderName?.characters.count > 1 {
                            initialName = (senderName! as NSString).substringWithRange(NSRange(location: 0, length: 2))
                        }
                        else if senderName?.characters.count > 0 {
                            initialName = (senderName! as NSString).substringWithRange(NSRange(location: 0, length: 1))
                        }
                        
                        let placeholderImage = JSQMessagesAvatarImageFactory.circularAvatarPlaceholderImage(initialName as String, backgroundColor: UIColor.lightGrayColor(), textColor: UIColor.darkGrayColor(), font: UIFont.systemFontOfSize(13.0), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
                        let avatarImage = JSQMessagesAvatarImageFactory.avatarImageWithImageURL(senderImage, highlightedImageURL: nil, placeholderImage: placeholderImage, diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
                        
                        self.avatars?.setObject(avatarImage, forKey: senderId!)
                        self.users?.setObject(senderName!, forKey: senderId!)
                        
                        if type.hasPrefix("image") == true {
                            let photoItem = JSQPhotoMediaItem.init(imageURL: url)
                            jsqsbmsg = JSQSBMessage(senderId: senderId, senderDisplayName: senderName, date: msgDate, media: photoItem)
                        }
                        else if type.hasPrefix("video") == true {
                            let videoItem = JSQVideoMediaItem.init(fileURL: NSURL.init(string: url), isReadyToPlay: true)
                            jsqsbmsg = JSQSBMessage(senderId: senderId, senderDisplayName: senderName, date: msgDate, media: videoItem)
                        }
                        else {
                            let fileItem = JSQFileMediaItem.init(fileURL: NSURL.init(string: url))
                            jsqsbmsg = JSQSBMessage(senderId: senderId, senderDisplayName: senderName, date: msgDate, media: fileItem)
                        }
                        
                        jsqsbmsg!.message = message
                        msgCount += 1
                    }
                    else if message.isKindOfClass(SBDAdminMessage) == true {
                        let msgDate = NSDate.init(timeIntervalSince1970: Double((message as! SBDAdminMessage).createdAt) / 1000.0)
                        let messageText = (message as! SBDAdminMessage).message
                        
                        let jsqsbmsg = JSQSBMessage.init(senderId: "", senderDisplayName: "", date: msgDate, text: messageText)
                        jsqsbmsg.message = message
                        msgCount += 1
                    }
                    
                    if initial == true {
                        self.messages?.addObject(jsqsbmsg!)
                    }
                    else {
                        self.messages?.insertObject(jsqsbmsg!, atIndex: 0)
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), { 
                    self.collectionView.reloadData()
                    
                    if initial == true {
                        self.scrollToBottomAnimated(false)
                    }
                    else {
                        let totalMsgCount = self.collectionView.numberOfItemsInSection(0)
                        if msgCount - 1 > 0 && totalMsgCount > 0 {
                            self.collectionView.scrollToItemAtIndexPath(NSIndexPath.init(forRow: (msgCount - 1), inSection: 0), atScrollPosition: UICollectionViewScrollPosition.Top, animated: false)
                        }
                    }
                })
            }
            else {
                self.hasPrev = false
            }
        })
    }
    
    // MARK: JSQMessages CollectionView DataSource
    override func collectionView(collectionView: JSQMessagesCollectionView!, messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData! {
        return self.messages?.objectAtIndex(indexPath.item) as! JSQMessageData
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, didDeleteMessageAtIndexPath indexPath: NSIndexPath!) {
        self.messages?.removeObjectAtIndex(indexPath.item)
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = self.messages?.objectAtIndex(indexPath.item) as! JSQSBMessage
        
        if message.senderId.characters.count == 0 {
            return self.neutralBubbleImageData
            
        }
        else {
            if message.senderId == self.senderId {
                return self.outgoingBubbleImageData
            }
            else {
                return self.incomingBubbleImageData
            }
        }
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageAvatarImageDataSource! {
        let message = self.messages?.objectAtIndex(indexPath.item) as! JSQSBMessage
        
        return self.avatars?.objectForKey(message.senderId) as! JSQMessageAvatarImageDataSource
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForCellTopLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
        if indexPath.item % 3 == 0 {
            let message = self.messages?.objectAtIndex(indexPath.item) as! JSQSBMessage
            return JSQMessagesTimestampFormatter.sharedFormatter().attributedTimestampForDate(message.date)
        }
        
        return nil
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
        let message = self.messages?.objectAtIndex(indexPath.item) as! JSQSBMessage
        
        if message.senderId == self.senderId {
            return nil
        }
        
        if indexPath.item - 1 > 0{
            let previousMessage = self.messages?.objectAtIndex(indexPath.item - 1) as! JSQSBMessage
            if previousMessage.senderId == message.senderId {
                return nil
            }
        }
        
        return NSAttributedString.init(string: message.senderDisplayName)
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForCellBottomLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
        return nil
    }
    
    // MARK: UICollectionView DataSource
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.messages!.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAtIndexPath: indexPath) as! JSQMessagesCollectionViewCell
        
        let msg = self.messages?.objectAtIndex(indexPath.item) as! JSQSBMessage
        
        if msg.isMediaMessage == false {
            if msg.senderId == self.senderId {
                cell.textView.textColor = UIColor.blackColor()
                cell.setUnreadCount(0)
            }
            else {
                cell.textView.textColor = UIColor.whiteColor()
            }
            
            cell.textView.linkTextAttributes = [NSForegroundColorAttributeName: cell.textView.textColor!, NSUnderlineStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue | NSUnderlineStyle.PatternSolid.rawValue]
        }
        
        cell.setUnreadCount(0)
        
        if indexPath.row == 0 {
            self.loadMessage(self.firstMessageTimestamp, initial: false)
        }
        
        return cell
    }
    
    // MARK: UICollectionView Delegate
    
    // MARK: JSQMessages collection view flow layout delegate
    
    // MARK: Adjusting cell label heights
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellTopLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        if indexPath.item % 3 == 0 {
            return kJSQMessagesCollectionViewCellLabelHeightDefault
        }
        
        return 0.0
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        let currentMessage = self.messages?.objectAtIndex(indexPath.item) as! JSQSBMessage
        if currentMessage.senderId == self.senderId {
            return 0.0
        }
        
        if indexPath.item - 1 > 0 {
            let previousMessage = self.messages?.objectAtIndex(indexPath.item - 1) as! JSQSBMessage
            if previousMessage.senderId == currentMessage.senderId {
                return 0.0
            }
        }
        
        return kJSQMessagesCollectionViewCellLabelHeightDefault
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellBottomLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        return 0.0
    }
    
    // MARK: Responding to collection view tap events
    override func collectionView(collectionView: JSQMessagesCollectionView!, header headerView: JSQMessagesLoadEarlierHeaderView!, didTapLoadEarlierMessagesButton sender: UIButton!) {
        print("Load earlier messages!")
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, didTapAvatarImageView avatarImageView: UIImageView!, atIndexPath indexPath: NSIndexPath!) {
        print("Tapped avater!")
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAtIndexPath indexPath: NSIndexPath!) {
        print("Tapped message bubble! ", indexPath.row)
        let jsqMessage = self.messages?.objectAtIndex(indexPath.row) as! JSQSBMessage
        
        let alert = UIAlertController.init(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
        let closeAction = UIAlertAction.init(title: "Close", style: UIAlertActionStyle.Cancel, handler: nil)
        var deleteMessageAction: UIAlertAction?
        var blockUserAction: UIAlertAction?
        var openFileAction: UIAlertAction?
        
        if jsqMessage.message?.isKindOfClass(SBDBaseMessage) == true {
            let baseMessage = jsqMessage.message
            if baseMessage?.isKindOfClass(SBDUserMessage) == true {
                let sender = (baseMessage as! SBDUserMessage).sender
                
                if sender!.userId == SBDMain.getCurrentUser()!.userId {
                    deleteMessageAction = UIAlertAction.init(title: "Delete the message", style: UIAlertActionStyle.Destructive, handler: { (action) in
                        let selectedMessageIndexPath = indexPath
                        self.channel?.deleteMessage(baseMessage!, completionHandler: { (error) in
                            if error != nil {
                                
                            }
                            else {
                                collectionView.dataSource.collectionView(collectionView, didDeleteMessageAtIndexPath: selectedMessageIndexPath)
                                dispatch_async(dispatch_get_main_queue(), { 
                                    collectionView.deleteItemsAtIndexPaths([selectedMessageIndexPath])
                                    collectionView.collectionViewLayout.invalidateLayout()
                                })
                            }
                        })
                    })
                }
                else {
                    blockUserAction = UIAlertAction.init(title: "Block user", style: UIAlertActionStyle.Destructive, handler: { (action) in
                        SBDMain.blockUser(sender!, completionHandler: { (blocked, error) in
                            if error != nil {
                                
                            }
                            else {
                                
                            }
                        })
                    })
                }
            }
            else if baseMessage?.isKindOfClass(SBDFileMessage) == true {
                let fileMessage = baseMessage as! SBDFileMessage
                let sender = fileMessage.sender
                let type = fileMessage.type
                let url = fileMessage.url
                
                if sender!.userId == SBDMain.getCurrentUser()!.userId {
                    deleteMessageAction = UIAlertAction.init(title: "Delete the message", style: UIAlertActionStyle.Destructive, handler: { (action) in
                        let selectedMessageIndexPath = indexPath
                        self.channel?.deleteMessage(baseMessage!, completionHandler: { (error) in
                            if error != nil {
                                
                            }
                            else {
                                collectionView.dataSource.collectionView(collectionView, didDeleteMessageAtIndexPath: selectedMessageIndexPath)
                                dispatch_async(dispatch_get_main_queue(), { 
                                    collectionView.deleteItemsAtIndexPaths([selectedMessageIndexPath])
                                    collectionView.collectionViewLayout.invalidateLayout()
                                })
                            }
                        })
                    })
                }
                else {
                    blockUserAction = UIAlertAction.init(title: "Block user", style: UIAlertActionStyle.Destructive, handler: { (action) in
                        SBDMain.blockUser(sender!, completionHandler: { (blockedUser, error) in
                            if error != nil {
                                
                            }
                            else {
                                
                            }
                        })
                    })
                }
                
                if type.hasPrefix("video") == true {
                    openFileAction = UIAlertAction.init(title: "Play video", style: UIAlertActionStyle.Default, handler: { (action) in
                        let videoUrl = NSURL.init(string: url)
                        let player = AVPlayer.init(URL: videoUrl!)
                        let vc = AVPlayerViewController()
                        vc.player = player
                        self.presentViewController(vc, animated: true, completion: { 
                            player.play()
                        })
                    })
                }
                else if type.hasPrefix("audio") == true {
                    openFileAction = UIAlertAction.init(title: "Play audio", style: UIAlertActionStyle.Default, handler: { (action) in
                        let audioUrl = NSURL.init(string: url)
                        let player = AVPlayer.init(URL: audioUrl!)
                        let vc = AVPlayerViewController()
                        vc.player = player
                        self.presentViewController(vc, animated: true, completion: {
                            player.play()
                        })
                    })
                }
                else if type.hasPrefix("image") == true {
                    openFileAction = UIAlertAction.init(title: "Open image on Safari", style: UIAlertActionStyle.Default, handler: { (action) in
                        let imageUrl = NSURL.init(string: url)
                        UIApplication.sharedApplication().openURL(imageUrl!)
                    })
                }
                else {
                    // TODO: Download file.
                }
            }
            else if baseMessage?.isKindOfClass(SBDAdminMessage) == true {
                
            }
            
            alert.addAction(closeAction)
            if blockUserAction != nil {
                alert.addAction(blockUserAction!)
            }
            if openFileAction != nil {
                alert.addAction(openFileAction!)
            }
            if deleteMessageAction != nil {
                alert.addAction(deleteMessageAction!)
            }
            
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, didTapCellAtIndexPath indexPath: NSIndexPath!, touchLocation: CGPoint) {
        print("Tapped cell at ", NSStringFromCGPoint(touchLocation), "!")
    }
    
    override func didPressSendButton(button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: NSDate!) {
        if text.characters.count > 0 {
            self.channel?.sendUserMessage(text, completionHandler: { (userMessage, error) in
                if error != nil {
                    print("Error: ", error)
                }
                else {
                    if userMessage?.createdAt > self.lastMessageTimestamp {
                        self.lastMessageTimestamp = userMessage!.createdAt
                    }
                    
                    if userMessage?.createdAt < self.firstMessageTimestamp {
                        self.firstMessageTimestamp = userMessage!.createdAt
                    }
                    
                    var jsqsbmsg: JSQSBMessage?
                    
                    let senderId = userMessage?.sender?.userId
                    let senderImage = userMessage?.sender?.profileUrl
                    let senderName = userMessage?.sender?.nickname
                    let msgDate = NSDate.init(timeIntervalSince1970: Double((userMessage!.createdAt / 1000)))
                    let messageText = userMessage?.message
                    
                    let placeholderImage = JSQMessagesAvatarImageFactory.circularAvatarPlaceholderImage("TC", backgroundColor: UIColor.lightGrayColor(), textColor: UIColor.darkGrayColor(), font: UIFont.systemFontOfSize(13.0), diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
                    let avatarImage = JSQMessagesAvatarImageFactory.avatarImageWithImageURL(senderImage, highlightedImageURL: senderImage, placeholderImage: placeholderImage, diameter: UInt(kJSQMessagesCollectionViewAvatarSizeDefault))
                    
                    self.avatars?.setObject(avatarImage, forKey: senderId!)
                    if senderName != nil {
                        self.users?.setObject(senderName!, forKey: senderId!)
                    }
                    else {
                        self.users?.setObject("UK", forKey: senderId!)
                    }
                    
                    jsqsbmsg = JSQSBMessage(senderId: senderId, senderDisplayName: senderName, date: msgDate, text: messageText)
                    jsqsbmsg!.message = userMessage
                    
                    self.messages?.addObject(jsqsbmsg!)
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(500 * NSEC_PER_USEC)), dispatch_get_main_queue(), { 
                        dispatch_async(dispatch_get_main_queue(), { 
                            self.collectionView.reloadData()
                            self.scrollToBottomAnimated(false)
                            
                            self.inputToolbar.contentView.textView.text = ""
                        })
                    })
                }
            })
        }
    }
    
    override func didPressAccessoryButton(sender: UIButton!) {
        let mediaUI = UIImagePickerController()
        
        mediaUI.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
        mediaUI.mediaTypes = [kUTTypeImage as String, kUTTypeMovie as String]
        mediaUI.delegate = self
        
        self.presentViewController(mediaUI, animated: true, completion: nil)
    }
    
    // MARK: UIImagePickerControllerDelegate
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        let mediaType = info[UIImagePickerControllerMediaType]
        var originalImage: UIImage?
        var editedImage: UIImage?
        var imageToUse: UIImage?
        var imageName: String?
        var imageType: String?
        
        picker.dismissViewControllerAnimated(true) { 
            if CFStringCompare(mediaType as! CFStringRef, kUTTypeImage, CFStringCompareFlags.CompareDiacriticInsensitive) == CFComparisonResult.CompareEqualTo {
                editedImage = info[UIImagePickerControllerEditedImage] as UIImage
                originalImage = info[UIImagePickerControllerOriginalImage] as UIImage
                let refUrl = info[UIImagePickerControllerReferenceURL] as NSURL
                imageName = refUrl.las
            }
        }
    }
}
