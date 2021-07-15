//
//  StockChartView.swift
//  StockClone
//
//  Created by Lawson Kelly on 7/14/21.
//

import UIKit

class StockChartView: UIView {

    struct ViewModel {
        let data: [Double]
        let showLegend: Bool
        let showAxis: Bool
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    func reset() {
        
    }

    func configure(with viewModel: ViewModel) {
        
    }
}
