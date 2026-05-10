import UIKit
import SwiftUI

// Liste des clips affichée dans l'extension clavier.
// Implémentée en UIKit (UITableView) et non en SwiftUI, car dans une extension clavier
// iOS intercepte les gestes SwiftUI pour les donner au champ de texte en arrière-plan.
// Résultat : les boutons SwiftUI ne reçoivent jamais les taps.
// Un UIButton avec touchUpInside en UIKit reçoit les taps directement au niveau système.

// MARK: - UIViewRepresentable

struct ClipsListView: UIViewRepresentable {
    let clips: [SharedClipItem]
    let onInsert: (String) -> Void
    let onPin: (UUID) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onInsert: onInsert, onPin: onPin)
    }

    func makeUIView(context: Context) -> UITableView {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.register(ClipCell.self, forCellReuseIdentifier: ClipCell.reuseID)
        tv.dataSource = context.coordinator
        tv.delegate = context.coordinator
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 52
        tv.separatorInset = UIEdgeInsets(top: 0, left: 52, bottom: 0, right: 0)
        tv.backgroundColor = .clear
        tv.keyboardDismissMode = .none
        return tv
    }

    func updateUIView(_ tv: UITableView, context: Context) {
        context.coordinator.clips = clips
        context.coordinator.onInsert = onInsert
        context.coordinator.onPin = onPin
        tv.reloadData()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
        var clips: [SharedClipItem]
        var onInsert: (String) -> Void
        var onPin: (UUID) -> Void

        init(onInsert: @escaping (String) -> Void, onPin: @escaping (UUID) -> Void) {
            self.clips = []
            self.onInsert = onInsert
            self.onPin = onPin
        }

        func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
            clips.count
        }

        func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
            let cell = tv.dequeueReusableCell(withIdentifier: ClipCell.reuseID, for: ip) as! ClipCell
            let clip = clips[ip.row]
            cell.configure(clip: clip, onPin: { [weak self] in self?.onPin(clip.id) })
            return cell
        }

        func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
            tv.deselectRow(at: ip, animated: true)
            onInsert(clips[ip.row].text)
        }
    }
}

// MARK: - ClipCell

final class ClipCell: UITableViewCell {
    static let reuseID = "ClipCell"

    private let iconView  = UIImageView()
    private let mainLabel = UILabel()
    private let dateLabel = UILabel()
    private let pinBtn    = UIButton(type: .system)
    private var pinAction: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle  = .default

        iconView.translatesAutoresizingMaskIntoConstraints  = false
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)

        mainLabel.translatesAutoresizingMaskIntoConstraints = false
        mainLabel.font = .systemFont(ofSize: 15)
        mainLabel.numberOfLines = 1

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = .systemFont(ofSize: 11)
        dateLabel.textColor = .secondaryLabel

        pinBtn.translatesAutoresizingMaskIntoConstraints = false
        pinBtn.addTarget(self, action: #selector(pinTapped), for: .touchUpInside)

        contentView.addSubview(iconView)
        contentView.addSubview(mainLabel)
        contentView.addSubview(dateLabel)
        contentView.addSubview(pinBtn)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            pinBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            pinBtn.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            pinBtn.widthAnchor.constraint(equalToConstant: 44),
            pinBtn.heightAnchor.constraint(equalToConstant: 52),

            mainLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            mainLabel.trailingAnchor.constraint(equalTo: pinBtn.leadingAnchor, constant: -4),
            mainLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),

            dateLabel.leadingAnchor.constraint(equalTo: mainLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: mainLabel.trailingAnchor),
            dateLabel.topAnchor.constraint(equalTo: mainLabel.bottomAnchor, constant: 2),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(clip: SharedClipItem, onPin: @escaping () -> Void) {
        pinAction = onPin

        // Icône et couleur selon type/subtype
        let iconName: String
        let iconColor: UIColor
        switch clip.subtype {
        case "email":    iconName = "envelope";    iconColor = .systemBlue
        case "phone":    iconName = "phone";       iconColor = .systemGreen
        case "date":     iconName = "calendar";    iconColor = .systemPurple
        case "colorHex": iconName = "paintpalette"; iconColor = .systemPink
        case "address":  iconName = "map";         iconColor = .systemRed
        default:
            switch clip.type {
            case "url":  iconName = "link";        iconColor = .systemBlue
            case "code": iconName = "chevron.left.forwardslash.chevron.right"; iconColor = .systemOrange
            default:     iconName = "doc.text";    iconColor = UIColor.secondaryLabel
            }
        }
        iconView.image = UIImage(systemName: iconName)
        iconView.tintColor = iconColor

        let text = clip.text
        mainLabel.text = text.count > 60 ? String(text.prefix(60)) + "…" : text
        dateLabel.text = clip.createdAt.formatted()

        backgroundColor = clip.isPinned
            ? UIColor.orange.withAlphaComponent(0.06)
            : .clear

        let pinImage = UIImage(systemName: clip.isPinned ? "pin.fill" : "pin")
        pinBtn.setImage(pinImage, for: .normal)
        pinBtn.tintColor = clip.isPinned ? .orange : .systemGray3
    }

    @objc private func pinTapped() {
        // Feedback visuel immédiat dans la cellule avant que la liste se recharge.
        let willPin = pinBtn.tintColor != .orange
        pinBtn.tintColor          = willPin ? .orange : .systemGray3
        pinBtn.setImage(UIImage(systemName: willPin ? "pin.fill" : "pin"), for: .normal)
        backgroundColor = willPin ? UIColor.orange.withAlphaComponent(0.06) : .clear
        pinAction?()
    }
}
