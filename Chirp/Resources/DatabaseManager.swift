//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Tim Sweeney on 12/28/20.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    private let database = Database.database().reference()
    
    static func safeEmail(email: String) -> String {
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
}

extension DatabaseManager{
    
    public func getDataForPath(path: String, completion: @escaping(Result<Any, Error>) -> Void){
        self.database.child("\(path)").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
}

// MARK: - Account Management

extension DatabaseManager{
    
    /// Inserts new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        database.child(user.safeEmail).setValue([
                                "first_name": user.firstName,
                                "last_name": user.lastName
        ], withCompletionBlock: { error, _ in
            guard error == nil else {
                print("failed to insert user to database")
                completion(false)
                return
            }
            
            self.database.child("users").observeSingleEvent(of: .value, with: {snapshot in
                //check if there is a "users" directory in database
                if var usersCollection = snapshot.value as? [[String: String]]{
                    // append new user to "users" dictionary
                    let newElement = [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                    ]
                    usersCollection.append(newElement)
                    
                    // upload the new dictionary with the new user
                    self.database.child("users").setValue(usersCollection, withCompletionBlock: {error,_ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
                // if "users" directory doesn't exist (this will only execute on the very first user
                else {
                    //create that array
                    let newCollection: [[String: String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail 
                        ]
                    ]
                    
                    self.database.child("users").setValue(newCollection, withCompletionBlock: {error,_ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
            })
            
            completion(true)
        })
    }
    
    
    //the escaping tag here alerts the compiler that 'Result' will outlive the scope of the function
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        database.child("users").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [[String: String]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            completion(.success(value))
        })
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
    }
    
    /*
     [
        [
            "name":
            "safe_email":
        ],
        [
            "name":
            "safe_email":
        ]
     ]
    */
    
    public func userExists(with email: String, completion: @escaping ((Bool)-> Void) ) {
        
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        
        database.child(safeEmail).observeSingleEvent(of: .value, with: {snapshot in
            guard (snapshot.value as? String) != nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    
    public func convertEmailToName(email: String, completion: @escaping (String)->Void){
        var userName = ""
        database.child("\(email)").getData(completion: { (error, snapshot) in
            if let error = error {
                    print("Error getting data \(error)")
                }
                else if snapshot.exists() {
                    let value = snapshot.value as? NSDictionary
                    userName = "\(value?["first_name"])"+" "+"\(value?["last_name"])"
                }
                else {
                    print("No data available")
                }
        })
        completion(userName)
    }
    
}

// MARK: - Sending messages/conversations


extension DatabaseManager {
    
    /*
     "oi23lkjgalkne2h3oih"{
     "messages": [
     {
     "id": String,
     "type": text, photo, video
     "content": String,
     "date": String,
     "sender_email": String,
     "isRead": true/false
     }
     ]
     }
     
     conversation => [
     [
     "conversation_id": oi23lkjgalkne2h3oih
     "other_user_email":
     "latest_message": => {
     "date":Date()
     "latest_message": "message"
     "is_read": true/false
     ],
     ]
     */
    
    /// Creates a new conversation with target user email and first message sent
    public func createNewConversation(withEmail otherUserEmail: String, withName otherUserName: String, firstMessage: Message, completion: @escaping (Bool) -> Void) -> String?{
        
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            print("Failed to get user email from UserDefaults")
            return nil
        }
        
        //TODO: This function will fail if the user's name is something that breaks Firebase (@, [, ], ., etc.)  We need to fix that so it doesn't break.
        
        let safeEmailCurrentUser = DatabaseManager.safeEmail(email: currentEmail)
        
        let messageDate = firstMessage.sentDate
        let dateString = Utilities.dateFormatter.string(from: messageDate)
        var message = ""
        
        switch firstMessage.kind{
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        //create a conversation ID
        let conversationId = "conversation_\(firstMessage.messageId)"
        
        // Format data for sending user's first message
        let sender_newConversationData: [String: Any] = [
            "id":conversationId,
            "other_user_email": otherUserEmail,
            "other_user_name" : otherUserName,
            "latest_message": [
                "date": dateString,
                "message": message,
                "is_read": false,
            ]
        ]
        
        // Create sending user's conversation entry
        self.database.child("\(safeEmailCurrentUser)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            if var conversations = snapshot.value as? [[String:Any]]{
                //append the new conversation if the conversation node exists
                conversations.append(sender_newConversationData)
                self?.database.child("\(safeEmailCurrentUser)/conversations").setValue(conversations)
                
            }else{
                //create conversation node and first entry
                self?.database.child("\(safeEmailCurrentUser)/conversations").setValue(
                    [sender_newConversationData])
                
            }
        })
        
        // Format data for recipient user first message
        let recipient_newConversationData: [String: Any] = [
            "id":conversationId,
            "other_user_email": safeEmailCurrentUser,
            "other_user_name" : UserDefaults.standard.value(forKey: "name")!,
            "latest_message": [
                "date": dateString,
                "message": message,
                "is_read": false,
            ]
        ]
        
        // Create recipient user conversation entry
        self.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            if var conversations = snapshot.value as? [[String:Any]]{
                //append the new conversation if the conversation node exists
                conversations.append(recipient_newConversationData)
                self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                
            }else{
                //create conversation node and first entry
                self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
            }
        })
        
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": safeEmailCurrentUser,
            "is_read": false,
            "name": firstMessage.sender.displayName
        ]
        
        let value: [String:Any] = [
            "messages": [
                collectionMessage
            ]
        ]

        
        //        what does the _ do?
        self.database.child("\(conversationId)").setValue(value, withCompletionBlock: { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
        
        return conversationId
        
    }
    
    ///Sends a message with target conversation and message
    public func sendMessage(toConvo targetConversationID: String, toUserEmail recipientUserEmail: String, toUserName otherUserName: String, messageData: Message, completion: @escaping(Bool)->Void){
        
        var message = ""
        switch messageData.kind{
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        let dateString = Utilities.dateFormatter.string(from: messageData.sentDate)
        let sendingUserEmail = messageData.sender.senderId
        
        
        //  Appending the new message to the conversation message list
        
        let collectionMessage: [String: Any] = [
            "id": messageData.messageId,
            "type": messageData.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": sendingUserEmail,
            "is_read": false,
            "name": messageData.sender.displayName
        ]
        
        let ref = database.child("\(targetConversationID)/messages")
        
        ref.observeSingleEvent(of: .value, with: { snapshot in
            guard var messageDictionary = snapshot.value as? [[String: Any]] else {
                print("Error downloading messages")
                completion(false)
                return
            }
            messageDictionary.append(collectionMessage)
            ref.setValue(messageDictionary, withCompletionBlock: {error, _ in
                if error != nil{
                    print("Error sending message: \(String(describing: error))")
                    completion(false)
                }
            })
        })
        
        
        //Updating the sending user's latest message value
        
        let sender_newMessageData: [String: Any] = [
            "date": dateString,
            "message": message,
            "is_read": false,
        ]
        
        self.database.child("\(sendingUserEmail)/conversations").observeSingleEvent(of: .value, with: {snapshot in
            guard var currentUserConversations = snapshot.value as? [[String: Any]] else{
                completion(false)
                return
            }
            
            var updateConversation : [String: Any]?
            var position = 0
            for currentLoopConversation in currentUserConversations{
                if let currentID = currentLoopConversation["id"] as? String,
                   currentID == targetConversationID{
                    updateConversation = currentLoopConversation
                    break
                }
                position += 1
            }
            updateConversation?["latest_message"]=sender_newMessageData
            guard let updatedConversation = updateConversation else{
                completion(false)
                return
            }
            currentUserConversations[position] = updatedConversation
            self.database.child("\(sendingUserEmail)/conversations").setValue(currentUserConversations, withCompletionBlock: {error, _ in
                guard error == nil else{
                    completion(false)
                    return
                }
                
            })
        })
        
        
        // Updating the recipient user's latest message value
        
        let recipient_newMessageData: [String: Any] = [
            "date": dateString,
            "message": message,
            "is_read": false,
        ]
        
        self.database.child("\(recipientUserEmail)/conversations").observeSingleEvent(of: .value, with: {snapshot in
            guard var recipientUserConversations = snapshot.value as? [[String: Any]] else{
                completion(false)
                return
            }
            
            var updateConversation : [String: Any]?
            var position = 0
            for currentLoopConversation in recipientUserConversations{
                if let currentID = currentLoopConversation["id"] as? String,
                   currentID == targetConversationID{
                    updateConversation = currentLoopConversation
                    break
                }
                position += 1
            }
            updateConversation?["latest_message"]=recipient_newMessageData
            guard let updatedConversation = updateConversation else{
                completion(false)
                return
            }
            recipientUserConversations[position] = updatedConversation
            
            self.database.child("\(recipientUserEmail)/conversations").setValue(recipientUserConversations, withCompletionBlock: {error, _ in
                guard error == nil else{
                    completion(false)
                    return
                }
                completion(true)
            })
        })

    }
}


// MARK: - Retrieving messages/conversations

extension DatabaseManager {
    ///Fetches and returns all conversation IDs for the user with passed in email
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void ){
        database.child(email+"/conversations").observe(.value, with: {snapshot in
            
            guard let value = snapshot.value as? [[String: Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap({dictionary in
                guard let conversationId = dictionary["id"] as? String,
                      let other_user_name = dictionary["other_user_name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let dateString = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool
                else{
                    return nil
                }
                
                guard let date = Utilities.dateFormatter.date(from: dateString) else{
                    print ("Failed to convert datString to Date object.")
                    return nil
                }
                
                let latestMessageObject = LatestMessage(date: date,
                                                        text: message,
                                                        isRead: isRead)
                
                return Conversation(id: conversationId,
                                    otherUserName: other_user_name,
                                    otherUserEmail: otherUserEmail,
                                    latestMessage: latestMessageObject)
            })
            completion(.success(conversations))
        })
    }
    
    ///Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message],Error>) -> Void){
        database.child("\(id)/messages").observe(.value, with: {snapshot in
            
            guard let value = snapshot.value as? [[String: Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap({ dictionary in
                guard let content = dictionary["content"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = Utilities.dateFormatter.date(from: dateString),
                      let id = dictionary["id"] as? String,
//                      let isRead = dictionary["is_read"] as? Bool,
                      let name = dictionary["name"] as? String,
//                      let type = dictionary["type"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String
                      
                else{
                    return nil
                }
                
                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: id,
                               sentDate: date,
                               kind: .text(content))
            })
            completion(.success(messages))
        })
    }
}


struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    // let profilePicture: String
    
    var safeEmail: String{
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    var profilePictureFileName: String{
        //timsweeney97-gmail-com_profile_picture.png
        return "\(safeEmail)_profile_picture.png"
    }
}

