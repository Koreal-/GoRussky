//
//  SignUpController.swift
//  GoRussky
//
//  Created by Kartinin Studio on 06.06.2020.
//  Copyright © 2020 Kartinin Studio. All rights reserved.
//

import UIKit
import Firebase
import GeoFire

class SignUpController: UIViewController {
    //MARK: - Properties
    
    private var location = LocationHandler.shared.locationManager.location
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "GoRussky"
        label.font = UIFont(name: "Avenir-Light", size: 36)
        label.textColor = UIColor(white: 1, alpha: 0.8)
        return label
    }()
    
       private lazy var emailContainerView: UIView = {
           let view = UIView().inputContainerView(image: #imageLiteral(resourceName: "letter-png-icon-6"), textField: emailTextField)
           view.heightAnchor.constraint(equalToConstant: 50).isActive = true
           return view
       }()
    
      private lazy var fullnameContainerView: UIView = {
          let view = UIView().inputContainerView(image: #imageLiteral(resourceName: "profile-icon"), textField: fullnameTextField)
          view.heightAnchor.constraint(equalToConstant: 50).isActive = true
          return view
      }()
       
       private lazy var passwordContainerView: UIView = {
           let view = UIView().inputContainerView(image: #imageLiteral(resourceName: "img_password"), textField: passwordTextField)
           view.heightAnchor.constraint(equalToConstant: 50).isActive = true
           return view
       }()
    private lazy var accountTypeContainerView: UIView = {
        let view = UIView().inputContainerView(image: #imageLiteral(resourceName: "icon"), segmentedControl: accountTypeSegmentedControl)
        view.heightAnchor.constraint(equalToConstant: 80).isActive = true
        return view
    }()
       private let emailTextField: UITextField = {
           return UITextField().textField(withPlaceholder: "Email", isSecureTextEntry: false)
       }()
    private let fullnameTextField: UITextField = {
        return UITextField().textField(withPlaceholder: "Fullname", isSecureTextEntry: false)
    }()
       private let passwordTextField: UITextField = {
           return UITextField().textField(withPlaceholder: "Password", isSecureTextEntry: true)
       }()
    private let accountTypeSegmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Пассажир", "Водитель"])
        sc.backgroundColor = .backgroundColor
        sc.tintColor = UIColor(white: 1, alpha: 0.87)
        sc.selectedSegmentIndex = 0
        return sc
    }()
    private let signUpButton: AuthButton = {
        let button = AuthButton(type: .system)
        button.setTitle("Зарегистрироваться", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        button.addTarget(self, action: #selector(handleSignUp), for: .touchUpInside)
        return button
    }()
    let alreadyHaveAccountButton: UIButton = {
        let button = UIButton(type: .system)
        let attributedTitle = NSMutableAttributedString(string: "Уже есть акаунт? ", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16), NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        attributedTitle.append(NSAttributedString(string: "Войти", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 16), NSAttributedString.Key.foregroundColor: UIColor.mainBlueTint]))
        
        button.addTarget(self, action: #selector(handleShowLogin), for: .touchUpInside)
        button.setAttributedTitle(attributedTitle, for: .normal)
        return button
    }()
       

       
      
    // MARK: - Lifcycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureUI()
        
    }
    
    //MARK: - Selectors
    
    @objc func handleSignUp(){
        guard let email = emailTextField.text else { return }
        guard let password = passwordTextField.text else { return }
        guard let fullname = fullnameTextField.text else { return }
        let accountTypeIndex = accountTypeSegmentedControl.selectedSegmentIndex
        
        Auth.auth().createUser(withEmail: email, password: password){ (result, error) in
            if let error = error {
                print("Failed to register user with error \(error.localizedDescription)")
                return
            }
            guard let uid = result?.user.uid else { return }
            
            let values = ["email": email,
                          "fullname": fullname,
                          "accountType": accountTypeIndex]
                as [String : Any]
            
            if accountTypeIndex == 1 {
                let geofire = GeoFire(firebaseRef: REF_DRIVER_LOCATIONS)
                
                guard let location = self.location else { return }
                geofire.setLocation(location, forKey: uid, withCompletionBlock:  { (error) in
                    self.uploadUserDataAndShowHomeController(uid: uid, values: values)
                })
            }
            self.uploadUserDataAndShowHomeController(uid: uid, values: values)
        }
    }
    
    @objc func handleShowLogin(){
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - helper function
    
    func uploadUserDataAndShowHomeController(uid: String, values: [String: Any]) {
        REF_USERS.child(uid).updateChildValues(values, withCompletionBlock: { (error, ref) in
             guard let controller = UIApplication.shared.keyWindow?.rootViewController as? ContainerController else{
                 return
             }
             controller.configure()
             self.dismiss(animated: true, completion: nil)
         })
    }
    
    func configureUI(){
        view.backgroundColor = .backgroundColor
        
        view.addSubview(titleLabel)
        titleLabel.anchor(top: view.safeAreaLayoutGuide.topAnchor)
        titleLabel.centerX(inView: view)
        
        let stack = UIStackView(arrangedSubviews: [emailContainerView,
                                                   fullnameContainerView,
                                                   passwordContainerView,
                                                   accountTypeContainerView,
                                                   signUpButton])
        stack.axis = .vertical
        stack.distribution = .fillProportionally
        stack.spacing = 24
        
        view.addSubview(stack)
        stack.anchor(top: titleLabel.bottomAnchor, left: view.leftAnchor, right: view.rightAnchor, paddingTop: 40, paddingLeft: 16, paddingRight: 16)
        
        view.addSubview(alreadyHaveAccountButton)
        alreadyHaveAccountButton.centerX(inView: view)
        alreadyHaveAccountButton.anchor(bottom: view.safeAreaLayoutGuide.bottomAnchor, height: 32)
    }
}
