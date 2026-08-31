import MapKit
import SwiftUI
import UIKit

final class StationPointAnnotation: MKPointAnnotation {
    let station: FuelStation
    var priceCents: Double
    var movement: PriceMovement
    var band: RelativePriceBand

    init(station: FuelStation, priceCents: Double, movement: PriceMovement, band: RelativePriceBand) {
        self.station = station
        self.priceCents = priceCents
        self.movement = movement
        self.band = band
        super.init()
        coordinate = CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)
        title = station.name
        subtitle = PresentationFormat.priceWithUnit(priceCents)
    }

    func apply(priceCents: Double, movement: PriceMovement, band: RelativePriceBand) {
        self.priceCents = priceCents
        self.movement = movement
        self.band = band
        subtitle = PresentationFormat.priceWithUnit(priceCents)
    }

    var accessibilityText: String {
        "\(station.name), \(PresentationFormat.priceWithUnit(priceCents)), \(movement.accessibilityPhrase), \(band.accessibilityPhrase)"
    }
}

final class PriceMarkerView: MKAnnotationView {
    static let reuseID = "PriceMarkerView"

    private let chrome = UIView()
    private let bandView = UIView()
    private let priceLabel = UILabel()
    private let movementLabel = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "servogrid-station"
        collisionMode = .rectangle
        canShowCallout = false
        displayPriority = .defaultHigh
        frame = CGRect(x: 0, y: 0, width: 92, height: 44)
        centerOffset = CGPoint(x: 0, y: -22)
        isAccessibilityElement = true
        accessibilityTraits = [.button]
        setup()
        refreshStyle()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        annotation = nil
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        let changes = {
            self.chrome.layer.borderWidth = selected ? 1.5 : 0.5
            self.chrome.layer.borderColor = selected
                ? UIColor(GridPalette.teal).cgColor
                : GridPalette.hairline.resolvedUIColor.cgColor
            self.transform = selected ? CGAffineTransform(scaleX: 1.06, y: 1.06) : .identity
        }
        if animated, !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.18, animations: changes)
        } else {
            changes()
        }
    }

    func configure(_ annotation: StationPointAnnotation, selected: Bool) {
        priceLabel.text = PresentationFormat.price(annotation.priceCents)
        movementLabel.text = annotation.movement.symbol
        bandView.backgroundColor = GridPalette.uiBand(annotation.band)
        accessibilityLabel = annotation.accessibilityText
        accessibilityIdentifier = AccessibilityID.stationMarker(annotation.station.id)
        setSelected(selected, animated: false)
        refreshStyle()
    }

    private func setup() {
        chrome.translatesAutoresizingMaskIntoConstraints = false
        bandView.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        movementLabel.translatesAutoresizingMaskIntoConstraints = false

        chrome.layer.cornerRadius = 3
        chrome.layer.borderWidth = 0.5
        chrome.clipsToBounds = true

        priceLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        priceLabel.adjustsFontForContentSizeCategory = false
        movementLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        movementLabel.textAlignment = .center

        addSubview(chrome)
        chrome.addSubview(bandView)
        chrome.addSubview(priceLabel)
        chrome.addSubview(movementLabel)

        NSLayoutConstraint.activate([
            chrome.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            chrome.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            chrome.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            chrome.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            chrome.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),

            bandView.leadingAnchor.constraint(equalTo: chrome.leadingAnchor),
            bandView.topAnchor.constraint(equalTo: chrome.topAnchor),
            bandView.bottomAnchor.constraint(equalTo: chrome.bottomAnchor),
            bandView.widthAnchor.constraint(equalToConstant: 4),

            priceLabel.leadingAnchor.constraint(equalTo: bandView.trailingAnchor, constant: 7),
            priceLabel.centerYAnchor.constraint(equalTo: chrome.centerYAnchor),

            movementLabel.leadingAnchor.constraint(equalTo: priceLabel.trailingAnchor, constant: 4),
            movementLabel.trailingAnchor.constraint(equalTo: chrome.trailingAnchor, constant: -7),
            movementLabel.centerYAnchor.constraint(equalTo: chrome.centerYAnchor),
            movementLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 12)
        ])
    }

    private func refreshStyle() {
        let dark = traitCollection.userInterfaceStyle == .dark
        chrome.backgroundColor = dark ? GridPalette.markerFillDark : GridPalette.markerFillLight
        let ink = dark ? GridPalette.markerInkDark : GridPalette.markerInkLight
        priceLabel.textColor = ink
        movementLabel.textColor = ink
        chrome.layer.borderColor = GridPalette.hairline.resolvedUIColor.cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshStyle()
    }
}

final class ClusterMarkerView: MKAnnotationView {
    static let reuseID = "ClusterMarkerView"

    private let chrome = UIView()
    private let countLabel = UILabel()
    private let gridLayer = CAShapeLayer()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .circle
        canShowCallout = false
        displayPriority = .defaultHigh
        frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        isAccessibilityElement = true
        accessibilityTraits = [.button]
        accessibilityIdentifier = AccessibilityID.clusterMarker
        setup()
        refreshStyle()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(_ cluster: MKClusterAnnotation) {
        let count = cluster.memberAnnotations.count
        countLabel.text = "\(count)"
        accessibilityLabel = "\(count) stations. Double tap to zoom in."
        refreshStyle()
    }

    private func setup() {
        chrome.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        chrome.layer.cornerRadius = 3
        chrome.layer.borderWidth = 0.5
        countLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        countLabel.textAlignment = .center

        gridLayer.fillColor = UIColor.clear.cgColor
        gridLayer.lineWidth = 0.5
        chrome.layer.addSublayer(gridLayer)

        addSubview(chrome)
        chrome.addSubview(countLabel)
        NSLayoutConstraint.activate([
            chrome.centerXAnchor.constraint(equalTo: centerXAnchor),
            chrome.centerYAnchor.constraint(equalTo: centerYAnchor),
            chrome.widthAnchor.constraint(equalToConstant: 36),
            chrome.heightAnchor.constraint(equalToConstant: 36),
            countLabel.centerXAnchor.constraint(equalTo: chrome.centerXAnchor),
            countLabel.centerYAnchor.constraint(equalTo: chrome.centerYAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset: CGFloat = 6
        let rect = chrome.bounds.insetBy(dx: inset, dy: inset)
        let path = UIBezierPath()
        let thirdW = rect.width / 3
        let thirdH = rect.height / 3
        for index in 1...2 {
            path.move(to: CGPoint(x: rect.minX + thirdW * CGFloat(index), y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + thirdW * CGFloat(index), y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + thirdH * CGFloat(index)))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + thirdH * CGFloat(index)))
        }
        gridLayer.path = path.cgPath
        gridLayer.frame = chrome.bounds
    }

    private func refreshStyle() {
        let dark = traitCollection.userInterfaceStyle == .dark
        chrome.backgroundColor = dark ? GridPalette.markerFillDark : GridPalette.markerFillLight
        let ink = dark ? GridPalette.markerInkDark : GridPalette.markerInkLight
        countLabel.textColor = ink
        chrome.layer.borderColor = UIColor(GridPalette.teal).cgColor
        gridLayer.strokeColor = UIColor(GridPalette.teal).withAlphaComponent(0.55).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshStyle()
    }
}

private extension Color {
    var resolvedUIColor: UIColor { UIColor(self) }
}
