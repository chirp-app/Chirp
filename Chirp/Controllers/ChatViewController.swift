//
//  ChatViewController.swift
//  Messenger
//
//  Created by Tim Sweeney on 1/12/21.
//

import UIKit
import MessageKit
import InputBarAccessoryView

struct Message: MessageType{
   public var sender: SenderType
   public var messageId: String
   public var sentDate: Date
   public var kind: MessageKind
}

extension MessageKind{
    var messageKindString: String{
        switch self {
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributedText"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .linkPreview(_):
            return "linkPreview"
        case .custom(_):
            return "custom"
        }
    }
    
}

struct Sender: SenderType{
    var photoURL: String
    var senderId: String
    var displayName: String
}


class ChatViewController: MessagesViewController {
    
    private var messages = [Message]()
    public var isNewConversation = false
    public var otherUserEmail: String
    public var otherUserName: String
    
    init(with user: [String: String]){
        self.otherUserEmail = user["email"] ?? "UserEmail-Nil"
        self.otherUserName = user["name"] ?? "UserName-Nil"
        super.init(nibName: nil, bundle: nil)
    }
    
//    public static let dateFormatter: DateFormatter = {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .long
//        formatter.locale = .current
//        return formatter
//    }()
    
    private var selfSender: Sender? = {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        return Sender(photoURL: "",
               senderId: email,
               displayName: "Tim Sweeney")
    }()

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.green
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
    }
    

}

extension ChatViewController: InputBarAccessoryViewDelegate{
    
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String){
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender = self.selfSender,
              let messageId = createMessageId()
              else {
                    return
                }
    
        print(messageId)
        print("Sending: \(text)")
        //send message
        if isNewConversation {
            //create convo in database
            let message = Message(sender: selfSender,
                                  messageId: messageId,
                                  sentDate: Date(), 
                                  kind: .text(text))
            DatabaseManager.shared.createNewConversation(withEmail: otherUserEmail, withName: otherUserName, firstMessage: message, completion: {success in
                if success {
                    print("Message sent")
                }
                else{
                    print("Failed to send")
                }
                
            })
        }
        else {
            //append to existing conversation data
        }
    }

    private func createMessageId() -> String? {
        //date, otherUserEmail, senderEmail, random int
        guard var currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            print ("Test point 1")
            return nil
        }
        currentUserEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        let dateString = Utilities.dateFormatter.string(from: Date())
        let newIdentifier = "\(otherUserEmail)_\(currentUserEmail)_\(dateString)"
        print ("Created message ID: \(newIdentifier)")
        return newIdentifier
    }
}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate{
    
    func currentSender() -> SenderType {
        if let sender = selfSender{
            return sender
        }
        fatalError("SelfSender is nil, email should be cached")
        return Sender(photoURL: "", senderId: "12", displayName: "")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    
}
