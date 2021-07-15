//
//  SearchResultsViewController.swift
//  StockClone
//
//  Created by Lawson Kelly on 7/1/21.
//

import UIKit

protocol SearchResultsViewControllerDelegate: AnyObject {
    func searchResultsViewControllerDidSelect(searchResult: SearchResult)
}

class SearchResultsViewController: UIViewController {

    weak var delegate: SearchResultsViewControllerDelegate?

    private var results: [SearchResult] = []

    private let tableView: UITableView = {
        let tv = UITableView()
        tv.register(SearchResultTableViewCell.self, forCellReuseIdentifier: SearchResultTableViewCell.identifier)
        tv.isHidden = true
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupTable()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }

    private func setupTable() {
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
    }

    public func update(with results: [SearchResult]) {
        self.results = results
        tableView.isHidden = results.isEmpty
        tableView.reloadData()
    }
}

extension SearchResultsViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: SearchResultTableViewCell.identifier,
                                                 for: indexPath
        )
        let model = results[indexPath.row]

        cell.textLabel?.text = model.displaySymbol
        cell.detailTextLabel?.text = model.description
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let model = results[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.searchResultsViewControllerDidSelect(searchResult: model)
    }
}
