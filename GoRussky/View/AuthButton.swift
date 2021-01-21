//
//  AuthButton.swift
//  GoRussky
//
//  Created by Kartinin Studio on 06.06.2020.
//  Copyright © 2020 Kartinin Studio. All rights reserved.
//

import UIKit

class AuthButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setTitleColor(UIColor(white: 1, alpha: 0.5), for: .normal)
        backgroundColor = .mainBlueTint
        layer.cornerRadius = 5
        titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        heightAnchor.constraint(equalToConstant: 50).isActive = true
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
