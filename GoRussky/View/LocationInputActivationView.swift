//
//  LocationInputActivationView.swift
//  GoRussky
//
//  Created by Kartinin Studio on 09.06.2020.
//  Copyright © 2020 Kartinin Studio. All rights reserved.
//

import UIKit

protocol LocationInputActivationViewDelegate: class {
    func presentLocationInputView()
}

class LocationInputActivationView: UIView {
    
    //MARK:-Properties
    
    weak var delegate: LocationInputActivationViewDelegate?
    
    let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()
    
    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "Куда заказываем русского?"
        label.font = UIFont.systemFont(ofSize: 18)
        label.textColor = .darkGray
        return label
    }()
    
    //MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        backgroundColor = .white
        addShadow()
        
        addSubview(indicatorView)
        indicatorView.centerY(inView: self, leftAnchor: leftAnchor, paddingLeft: 16)
        indicatorView.setDimension(height: 6, width: 6)
        
        addSubview(placeholderLabel)
        placeholderLabel.centerY(inView: self, leftAnchor: indicatorView.rightAnchor, paddingLeft: 20)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(presentLocationInputView))
        addGestureRecognizer(tap)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    //MARK:-Selectors
    @objc func presentLocationInputView(){
        delegate?.presentLocationInputView()
    }
}
