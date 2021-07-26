//
//  StockDetailsViewController.swift
//  StockClone
//
//  Created by Lawson Kelly on 7/1/21.
//

import UIKit
import SafariServices

class StockDetailsViewController: UIViewController {

    private let symbol: String
    private let companyName: String
    private var candleStickData: [CandleStick]

    private var stories: [NewsStory] = []
    private var metrics: Metrics?
    
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.register(NewsHeaderView.self, forHeaderFooterViewReuseIdentifier: NewsHeaderView.identifier)
        tv.register(NewsStoryTableViewCell.self, forCellReuseIdentifier: NewsStoryTableViewCell.identifier)
        return tv
    }()

    init(
        symbol: String,
        companyName: String,
        candleStickData: [CandleStick] = []
    ) {
        self.symbol = symbol
        self.companyName = companyName
        self.candleStickData = candleStickData
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .systemBackground
        title = companyName
        setUpCloseButton()
        setupTable()
        fetchFinancialData()
        fetchNews()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.frame = view.bounds
    }

    private func setUpCloseButton() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(didTapClose))
    }

    @objc private func didTapClose() {
        dismiss(animated: true, completion: nil)
    }

    private func setupTable() {
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = UIView(
            frame: CGRect(x: 0, y: 0, width: view.width,
                          height: (view.width * 0.7) + 100)
        )
    }

    private func fetchFinancialData() {
        let group = DispatchGroup()
        if candleStickData.isEmpty {
            group.enter()
            APICaller.shared.marketData(for: symbol) { [weak self] result in
                defer {
                    group.leave()
                }
                switch result {
                case .success(let response):
                    self?.candleStickData = response.candleSticks
                case .failure(let error):
                    print(error)
                }
            }
        }
        group.enter()
        APICaller.shared.financialMetrics(for: symbol) { [weak self] result in
            defer {
                group.leave()
            }
            switch result {
            case .success(let response):
                let metrics = response.metric
                self?.metrics = metrics
            case .failure(let error):
                print(error)
            }
        }
        group.notify(queue: .main) { [weak self] in
            self?.renderChart()
        }
    }

    private func fetchNews() {
        APICaller.shared.news(for: .company(symbol: symbol)) { [weak self] result in
            switch result {
            case .success(let stories):
                DispatchQueue.main.async {
                    self?.stories = stories
                    self?.tableView.reloadData()
                }
            case .failure(let error):
                print(error)
            }
        }
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

    private func renderChart() {
        // chart view model
        // financial metric
        let headerView = StockDetailHeaderView(frame: CGRect(x: 0, y: 0, width: view.width, height: (view.width * 0.7) + 100))
        headerView.isUserInteractionEnabled = false
        var viewModels = [MetricCollectionViewCell.ViewModel]()

        if let metrics = metrics {
            viewModels.append(.init(name: "52 WHigh", value: "\(metrics.AnnualWeekHigh)"))
            viewModels.append(.init(name: "52 Low", value: "\(metrics.AnnualWeekLow)"))
            viewModels.append(.init(name: "52W Retrun", value: "\(metrics.AnnualWeekPriceReturnDaily)"))
            viewModels.append(.init(name: "Beta", value: "\(metrics.beta)"))
            viewModels.append(.init(name: "10D Vol", value: "\(metrics.TenDayAverageTradingVolume)"))
        }

        let change = getChangePercentage(symbol: symbol, for: candleStickData)

        headerView.configure(chartViewModel: .init(
                                data: candleStickData.reversed().map { $0.close },
                                showLegend: true,
                                showAxis: true,
                                fillColor: change < 0 ? .systemRed : .systemGreen),
                            metricViewModels: viewModels)

        tableView.tableHeaderView = headerView
    }

    private func open(url: URL) {
        let vc = SFSafariViewController(url: url)
        present(vc, animated: true)
    }
}

extension StockDetailsViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stories.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return NewsStoryTableViewCell.preferredHeight
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: NewsStoryTableViewCell.identifier, for: indexPath) as? NewsStoryTableViewCell else {
            fatalError()
        }

        cell.configure(with: .init(model: stories[indexPath.row]))
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: NewsHeaderView.identifier) as? NewsHeaderView else {
            return nil
        }
        header.delegate = self
        header.configure(
            with: .init(
                title: symbol.uppercased(),
                shouldShowAddButton: !PersistenceManager.shared.watchListContains(symbol: symbol)
            )
        )
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return NewsHeaderView.preferedHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let story = stories[indexPath.row]
        guard let url = URL(string: story.url) else {
            presentFailedToOpenAlert()
            return
        }
        open(url: url)
    }

    private func presentFailedToOpenAlert() {
        let alert = UIAlertController(
            title: "Unable to Open",
            message: "Unable to open article",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
}

extension StockDetailsViewController: NewsHeaderViewDelegate {
    func newsHeaderViewDidTapButton(_ headerView: NewsHeaderView) {
        headerView.button.isHidden = true
        PersistenceManager.shared.addToWatchList(
            symbol: symbol,
            companyName: companyName
        )

        let alert = UIAlertController(title: "Added To Watchlist",
                                      message: "We've added \(companyName) to watchlist",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss",
                                      style: .cancel,
                                      handler: nil))
        present(alert, animated: true)
    }
}
