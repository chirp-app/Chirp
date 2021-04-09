//
//  ViewController.swift
//  Messenger
//
//  Created by Tim Sweeney on 12/20/20.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

struct Conversation{
    let id: String
    let otherUserName: String
    let otherUserEmail: String
    let latestMessage: LatestMessage
}

struct LatestMessage {
    let date: Date
    let text: String
    let isRead: Bool
}

class ConversationsViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    private var conversations = [Conversation]()
    private let conversationsList: [[String]] = [[""]]

    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return table
    }()
    
    private let noConversationsLabel: UILabel = {
        let label = UILabel()
        label.text = "No Conversations!"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        return label
    }()
    

//    private let userEmail = DatabaseManager.safeEmail(email: UserDefaults.standard.value(forKey: "email") as! String)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(didTapComposeButton))
        view.backgroundColor = .white
        view.addSubview(tableView)
        view.addSubview(noConversationsLabel)
        setupTableView()
        fetchConversations()
        startListeningForConversations()
    }
    
    private func setupTableView(){
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    private func fetchConversations(){
        tableView.isHidden = false
    }
    
    private func startListeningForConversations(){
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return
        }
        print("starting conversation fetch...")
        
        let safeEmail = DatabaseManager.safeEmail(email: email)
        
        DatabaseManager.shared.getAllConversations(for: safeEmail, completion: { [weak self] result in
            switch result{
            case .success(let conversations):
                guard !conversations.isEmpty else{
                    print("No conversations")
                    return
                }
                print("Successfully got conversation models")
                //will be used with fully customized tableView cells
                
                //sort the conversations with the latest conversation at the top
                self?.conversations = conversations.sorted(by: {$0.latestMessage.date > $1.latestMessage.date})
                
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            case .failure(let error):
                print("Failed to get conversations: \(error)")
            }
            
        })
    }
    
    
    @objc private func didTapComposeButton(){
        let vc = NewConversationViewController()
        vc.completion = { [weak self] result in
            print("New convo result: \(result)")
            self?.createNewConversation(result: result)
        }
        let navVC  = UINavigationController(rootViewController: vc)
        present(navVC, animated:true)
    }
    
    
    //TODO: createNewConversation needs to check if the conversation already exists
    private func createNewConversation(result: [String: String]){
        
        let vc = ChatViewController(with: result, id: nil)
        vc.isNewConversation = true
        vc.title = result["name"]
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func checkIfNewConversation(email: String) -> Bool{

        return false
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        validateAuth()
        
    }

    private func validateAuth(){
        if FirebaseAuth.Auth.auth().currentUser == nil{
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }
}
    

extension ConversationsViewController: UITableViewDelegate, UITableViewDataSource{
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let vc = ChatViewController(with: ["email":conversations[indexPath.row].otherUserEmail,
                                           "name":conversations[indexPath.row].otherUserName],
                                            id: conversations[indexPath.row].id)
        vc.title = conversations[indexPath.row].otherUserName
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
    }
    
    //function is used to break up the table view into multiple sections
    func numberOfSections(in tableView: UITableView) -> Int {
        // May be used later if we want to break up convos
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //should be the number of conversations the user has stored in firebase*
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        cell.textLabel?.text = conversations[indexPath.row].otherUserName
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    
}
