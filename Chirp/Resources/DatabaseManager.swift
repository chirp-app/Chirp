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

// MARK: - Account Management

extension DatabaseManager{
    
    /// Inserts new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        database.child(user.safeEmail).setValue([
                                "first_name": user.firstName,
                                "last_name": user.lastName
        ], withCompletionBlock: { error, _ in
            guard error == nil else {
                print("failed to write to database")
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
            guard let foundEmail = snapshot.value as? String else {
                completion(false)
                return
            }
            completion(true)
        })
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
    public func createNewConversation(withEmail otherUserEmail: String, withName otherUserName: String, firstMessage: Message, completion: @escaping (Bool) -> Void){
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            return
        }
        
        //TODO: This function will fail if the user's name is something that breaks Firebase (@, [, ], ., etc.)  We need to fix that so it doesn't break.
        
        let safeEmail = DatabaseManager.safeEmail(email: currentEmail)
        
        let ref = database.child("\(safeEmail)")
        
        ref.observeSingleEvent(of: .value, with: {snapshot in
            guard var userNode = snapshot.value as? [String: Any] else{
                completion(false)
                print("user not found")
                return
            }
            
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
            
            let conversationId = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String: Any] = [
                "id":conversationId,
                "other_user_email": otherUserEmail,
                "other_user_name" : otherUserName,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false,
                ]
            ]
            
            if var conversations = userNode["conversations"] as? [[String: Any]]{
                // conversation array exists for a current user
                // you should append
                
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else{
                        //error creating conversations node in database
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationId: conversationId,
                                                    firstMessage: firstMessage,
                                                    completion: completion)
                })
            }
            else{
                //conversation array does not exist
                 //create it
            
                userNode["conversations"] = [
                    newConversationData
                ]
                
                ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationId: conversationId,
                                                    firstMessage: firstMessage,
                                                    completion: completion)
                })
            }
        })
    }
    
    private func finishCreatingConversation(conversationId: String, firstMessage: Message, completion: @escaping(Bool) -> Void){
       // {
       //     "id": String,
       //     "type": text, photo, video
       //     "content": String,
       //     "date": String,
       //     "sender_email": String,
       //     "isRead": true/false
       // }
        
        //time message is sent in UTC form
        let messageDate = firstMessage.sentDate
        print(messageDate)
        //time message is sent in local time
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
        
        //UserDefaults is used to store data on the users iphone.
        //currentUserEmail should be saved in the device as a safe email.
        guard var currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            completion(false)
            return
        }
        currentUserEmail = DatabaseManager.safeEmail(email: currentUserEmail)
    
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false,
            "name": firstMessage.sender.displayName
        ]
        
        let value: [String:Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        
//        what does the _ do?
        database.child("\(conversationId)").setValue(value, withCompletionBlock: { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
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
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<String,Error>) -> Void){
        
    }
    ///Sends a message with target conversation and message
    public func sendMessage(to conversation: String, message: Message, completion: @escaping(Bool)->Void){
        
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

