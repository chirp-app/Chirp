//
//  LoginViewController.swift
//  Messenger
//
//  Created by Tim Sweeney on 12/20/20.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import JGProgressHUD

class LoginViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named:"logo")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let emailField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Email Address..."
        field.leftView = UIView(frame: CGRect(x: 0, y:0, width:5, height:0))
        field.leftViewMode = .always
        field.backgroundColor = .white
        return field
    }()
    
    private let passwordField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Password..."
        field.leftView = UIView(frame: CGRect(x: 0, y:0, width:5, height:0))
        field.leftViewMode = .always
        field.backgroundColor = .white
        field.isSecureTextEntry = true
        return field
    }()
    
    private let loginButton: UIButton = {
        let button = UIButton()
        button.setTitle("Log In", for: .normal)
        button.backgroundColor = .link
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    private let invalidLogin: UIAlertController = {
        let alert = UIAlertController()
        alert.title = "Invalid Login"
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: {_ in
            alert.dismiss(animated: true, completion: {})
        }))
        return alert
    }()
    
    
    private let facebookLoginButton: FBLoginButton = {
        let button = FBLoginButton()
        button.permissions = ["email, public_profile"]
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Log In"
        view.backgroundColor = .white
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title:"Register",
                            style: .done,
                            target: self,
                            action: #selector(didTapRegister))
        
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        
        emailField.delegate = self
        passwordField.delegate = self
        
        facebookLoginButton.delegate = self
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        scrollView.addSubview(facebookLoginButton)
    }
    
    // gives the layout for the view controller 
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        
        let size = scrollView.width/3
        imageView.frame = CGRect(x: (scrollView.width-size)/2,
                                 y: 20,
                                 width: size,
                                 height: size)
        emailField.frame = CGRect(x: 30,
                                  y: imageView.bottom+10,
                                  width: scrollView.width-60,
                                  height: 52)
        passwordField.frame = CGRect(x: 30,
                                  y: emailField.bottom+10,
                                  width: scrollView.width-60,
                                  height: 52)
        loginButton.frame = CGRect(x: 30,
                                   y: passwordField.bottom+10,
                                   width: scrollView.width-60,
                                   height:52)
        facebookLoginButton.frame = CGRect(x: 30,
                                           y: loginButton.bottom+20,
                                           width: scrollView.width-60,
                                           height:52)
    }
    
    @objc private func loginButtonTapped(){
        
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        guard let email = emailField.text, let password = passwordField.text, !email.isEmpty, !password.isEmpty, password.count >= 6 else{
            alertIncompleteUserLoginError()
            return
        }
        
        spinner.show(in: view)
        
        // firebase login
        
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password, completion: { [weak self] authResult, error in
            
            guard let strongSelf = self else{
                return
            }
            
            DispatchQueue.main.async {
                strongSelf.spinner.dismiss()
            }
            strongSelf.spinner.dismiss()
        
            guard let result = authResult, error == nil else {
                print("Failed to log in user with email: \(email)")
                self?.alertIncorrectUserLoginError()
                return
            }
            
            let user = result.user
            
            let safeEmail = DatabaseManager.safeEmail(email: email)
            
            DatabaseManager.shared.getDataForPath(path: "\(safeEmail)", completion: { result in
                switch result{
                case .success(let value):
                    guard let userData = value as? [String: Any] else{
                        return
                    }
                    let firstName = userData["first_name"] as! String
                    let lastName = userData["last_name"] as! String
                    UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")

                case .failure(let error):
                    print("Failed to read data with error: \(error)")
                }
            })
            
            UserDefaults.standard.set(email, forKey: "email")
            
            print("Logged in user: \(user)")
            strongSelf.navigationController?.dismiss(animated: true, completion: nil)
        })
            
        
        
    }
    
    func alertIncompleteUserLoginError(){
        let alert = UIAlertController(title: "Woops", message: "Please enter all information to log in.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title:"Dismiss", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    
    func alertIncorrectUserLoginError(){
        let alert = UIAlertController(title: "Invalid login", message: "Please enter a valid email and password to log in.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title:"Dismiss", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    
    @objc private func didTapRegister(){
        let vc = RegisterViewController()
        vc.title = "Create Account"
        navigationController?.pushViewController(vc, animated: true)
    }

}

extension LoginViewController: UITextFieldDelegate{
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailField{
            passwordField.becomeFirstResponder()
        }
        else if textField == passwordField{
            loginButtonTapped()
        }
        return true
    }
}

extension LoginViewController: LoginButtonDelegate{
    
    func loginButtonDidLogOut(_ loginButton: FBLoginButton){
        // no operation
    }
    
    func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?){
        guard let token = result?.token?.tokenString else{
            print("User failed to log in with facebook")
            return
        }
        
            let FacebookRequest = FBSDKLoginKit.GraphRequest(graphPath: "me",
                                                             parameters: ["fields": "email, name"],
                                                             tokenString: token,
                                                             version: nil,
                                                             httpMethod: .get)
            
            FacebookRequest.start(completionHandler: { _, result, error in
                guard let result = result as? [String: Any],
                    error == nil else {
                        print("Failed to make facebook graph request")
                        return
                    }
                
                print("\(result)")
                guard let userName = result["name"] as? String,
                      let email = result["email"] as? String else{
                    print("Failed to get email and name from fb result")
                    return
                }
                
                let nameComponents = userName.components(separatedBy: " ")
                guard nameComponents.count == 2 else {
                    return
                }
                
                let firstName = nameComponents[0]
                let lastName = nameComponents[1]
                
                DatabaseManager.shared.userExists(with: email, completion: { exists in
                    if !exists {
                        
                        let chatUser = ChatAppUser(firstName: firstName,
                                                   lastName: lastName,
                                                   emailAddress: email)
                        
                        DatabaseManager.shared.insertUser(with: chatUser, completion: { success in
                            if success {
                                //upload profile pic
                            }
                        })
                    }
                
                })
                
                let credential = FacebookAuthProvider.credential(withAccessToken: token)
                
                FirebaseAuth.Auth.auth().signIn(with: credential, completion: { [weak self] authResult, error in
                    guard let strongSelf = self else{
                        return
                    }
                    
                    guard authResult != nil, error == nil else{
                        if let error = error{
                            print("Facebook credential login failed, MFA may be needed - \(error)")
                        }
                        return
                    }
    
                    print("Successfully logged user in")
                    strongSelf.navigationController?.dismiss(animated: true, completion: nil)
            })
            
        })
    }
}
