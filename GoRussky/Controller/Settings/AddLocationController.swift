//
//  AddLocationController.swift
//  GoRussky
//
//  Created by Kartinin Studio on 17.08.2020.
//  Copyright © 2020 Kartinin Studio. All rights reserved.
//

import UIKit
import MapKit

private let reuseIdentifier = "Cell"

protocol AddLocationControllerDelegate: class {
    func updateLocation(locationString: String, type: LocationType)
}

class AddLocationController: UITableViewController {
    
    //MARK: - Properties
    weak var delegate: AddLocationControllerDelegate?
    
    private let searchBar = UISearchBar()
    private let searchCompleter = MKLocalSearchCompleter()
    private var searchResults = [MKLocalSearchCompletion]() {
        didSet { tableView.reloadData() }
    }
    private let type: LocationType
    private let location: CLLocation
    
    //MARK: - Lifecycle
    
    init(type: LocationType, location: CLLocation) {
        self.type = type
        self.location = location
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        configureTableView()
        configureSearchBar()
        configureSearchCompleter()
    }
    
    //MARK: - Helper Functions
    
    func configureTableView() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
        tableView.tableFooterView = UIView()
        tableView.rowHeight = 60
        
        tableView.addShadow()
    }
    
    func configureSearchBar() {
        searchBar.sizeToFit()
        searchBar.delegate = self
        navigationItem.titleView = searchBar
    }
    
    func configureSearchCompleter() {
        let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000)
        searchCompleter.region = region
        searchCompleter.delegate = self
    }
}

//MARK: - UITableViewDelegate/DataSourse

extension AddLocationController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: reuseIdentifier)
        let result = searchResults[indexPath.row]
        cell.textLabel?.text = result.title
        cell.detailTextLabel?.text = result.subtitle
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let result = searchResults[indexPath.row]
        let title = result.title
        let subtitle = result.subtitle
        var locationString = title + " " + subtitle
        let trimmedLocation = locationString.replacingOccurrences(of: ", Australia", with: "")
        delegate?.updateLocation(locationString: locationString, type: type)
    }
}

//MARK: - UISearchBarDelegate
// -33,8674
// 151,211

extension AddLocationController:UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar,textDidChange searchText: String) {
        searchCompleter.queryFragment = searchText
    }
}

//MARK: - MKLocalSearchCompletionDelegate

extension AddLocationController: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchResults = completer.results
        
        //print("DEBUG: Search results \(searchResults)")
        
        //tableView.reloadData()
    }
}
