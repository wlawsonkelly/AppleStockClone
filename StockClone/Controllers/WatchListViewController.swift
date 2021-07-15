//
//  ViewController.swift
//  StockClone
//
//  Created by Lawson Kelly on 7/1/21.
//

import UIKit
import FloatingPanel

class WatchListViewController: UIViewController {

    private var searchTimer: Timer?

    private var panel: FloatingPanelController?

    static var maxChangeWidth: CGFloat = 0

    private var watchlistMap: [String: [CandleStick]] = [:]

    private var viewModels = [WatchListTableViewCell.ViewModel]()

    private let tableView: UITableView = {
        let tv = UITableView()
        tv.register(WatchListTableViewCell.self, forCellReuseIdentifier: WatchListTableViewCell.identifier)
        return tv
    }()

    private var observer: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .systemBackground
        setUpSearchController()
        setupTableView()
        fetchWatchlistData()
        setUpFloatingPanel()
        setUpTitleView()
        setUpObserver()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }

    private func setUpObserver() {
        observer = NotificationCenter.default.addObserver(
            forName: .didAddToWatchList,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.viewModels.removeAll()
            self?.fetchWatchlistData()
        }
    }


    private func setupTableView() {
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
    }

    private func fetchWatchlistData() {
        let symbols = PersistenceManager.shared.watchlist
        let group = DispatchGroup()
        for symbol in symbols where watchlistMap[symbol] == nil {
            group.enter()
            APICaller.shared.marketData(for: symbol) { [weak self] result in
                defer {
                    group.leave()
                }
                switch result {
                case .success(let data):
                    let candleSticks = data.candleSticks
                    self?.watchlistMap[symbol] = candleSticks
                case .failure(let error):
                    print(error)
                }
            }
        }
        group.notify(queue: .main) { [weak self] in
            self?.createViewModels()
            self?.tableView.reloadData()
        }
    }

    private func createViewModels() {
        var viewModels = [WatchListTableViewCell.ViewModel]()
        for (symbol, candleSticks) in watchlistMap {
            let changePercentage = getChangePercentage(symbol: symbol, for: candleSticks)
            viewModels.append(
                .init(
                    symbol: symbol,
                    price: getLatestClosingPrice(from: candleSticks),
                    changeColor: changePercentage < 0 ? .systemRed : .systemGreen,
                    changePercentage: String.percentage(from: changePercentage),
                    companyName: UserDefaults.standard.string(forKey: symbol) ?? "Company Name",
                    chartViewModel: .init(
                        data: candleSticks.reversed().map { $0.close },
                        showLegend: false,
                        showAxis: false
                    )
                )
            )
        }

        self.viewModels = viewModels
    }

    private func getLatestClosingPrice(from data: [CandleStick]) -> String {
        guard let closingPrice = data.first?.close else { return "" }

        return String.formatted(number: closingPrice)
    }

    private func getChangePercentage(symbol: String, for data: [CandleStick]) -> Double {
        let latestDate = data[0].date
//        let priorDate = Date().addingTimeInterval(-((3600 * 24 ) * 2))
        guard let latestClose = data.first?.close,
            let priorClose = data.first(where: {
                !Calendar.current.isDate($0.date, inSameDayAs: latestDate)
            })?.close else {
            return 0.0
            }
        let diff = 1 - (priorClose/latestClose)
        return diff
    }

    private func setUpFloatingPanel() {
        let vc = NewsViewController(type: .topStories)
        let panel = FloatingPanelController(delegate: self)
        panel.surfaceView.backgroundColor = .secondarySystemBackground
        panel.set(contentViewController: vc)
        panel.track(scrollView: vc.tableView)
        panel.addPanel(toParent: self)
    }

    private func setUpSearchController() {
        let resultVc = SearchResultsViewController()
        resultVc.delegate = self
        let searchVc = UISearchController(searchResultsController: resultVc)
        searchVc.searchResultsUpdater = self
        navigationItem.searchController = searchVc
    }

    private func setUpTitleView() {
        let titleView = UIView(frame: CGRect(x: 0,
                                             y: 0,
                                             width: view.width,
                                             height: navigationController?.navigationBar.height ?? 100
            )
        )
        let label = UILabel(frame: CGRect(x: 10,
                                          y: 0,
                                          width: titleView.width - 20,
                                          height: titleView.height
            )
        )
        label.text = "Stocks"
        label.font = .systemFont(ofSize: 36, weight: .heavy)
        label.textColor = .white
        titleView.addSubview(label)
        navigationItem.titleView = titleView
    }
}

extension WatchListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let query = searchController.searchBar.text,
              let resultVc = searchController.searchResultsController as? SearchResultsViewController,
              !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }

        searchTimer?.invalidate()
        
        searchTimer = Timer.scheduledTimer(
            withTimeInterval: 0.3,
            repeats: false,
            block: { _ in
                APICaller.shared.search(query: query) { result in
                    switch result {
                    case .success(let response):
                        DispatchQueue.main.async {
                            resultVc.update(with: response.result)
                        }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            resultVc.update(with: [])
                        }
                        print(error)
                    }
                }
            })
    }
}

extension WatchListViewController: SearchResultsViewControllerDelegate {
    func searchResultsViewControllerDidSelect(searchResult: SearchResult) {
        navigationController?.navigationItem.searchController?.resignFirstResponder()
        let detailsVC = StockDetailsViewController()
        let navVC = UINavigationController(rootViewController: detailsVC)
        detailsVC.title = searchResult.description
        present(navVC, animated: true)
    }
}

extension WatchListViewController: FloatingPanelControllerDelegate {
    func floatingPanelDidChangeState(_ fpc: FloatingPanelController) {
        navigationItem.titleView?.isHidden = fpc.state == .full
    }
}

extension WatchListViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: WatchListTableViewCell.identifier, for: indexPath) as? WatchListTableViewCell else {
            fatalError()
        }
        viewModels.sort(by: { $0.companyName < $1.companyName })
        cell.configure(with: viewModels[indexPath.row])
        cell.delegate = self
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return WatchListTableViewCell.preferedHeight
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            tableView.beginUpdates()
            PersistenceManager.shared.removeFromWatchList(symbol: viewModels[indexPath.row].symbol)
            viewModels.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            tableView.endUpdates()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // open details for selection
    }


}

extension WatchListViewController: WatchListTableViewCellDelegate {
    func didUpdateMaxWidth() {
        tableView.reloadData()
    }


}

