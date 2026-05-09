import SwiftUI
import Combine

private enum ClipTypeFilter: String, CaseIterable {
    case all  = "Tout"
    case text = "Texte"
    case url  = "Lien"
    case code = "Code"
}

struct KeyboardView: View {
    let needsNextKeyboard: Bool
    let onInsert: (String) -> Void
    let onDelete: () -> Void
    let onNextKeyboard: () -> Void

    @State private var searchText    = ""
    @State private var activeFilter  = ClipTypeFilter.all
    @State private var clips: [SharedClipItem] = []
    @State private var pinOverrides: [UUID: Bool] = [:]

    private var filtered: [SharedClipItem] {
        clips.filter { clip in
            let matchesType: Bool = {
                switch activeFilter {
                case .all:  return true
                case .text: return clip.type == "text"
                case .url:  return clip.type == "url"
                case .code: return clip.type == "code"
                }
            }()
            let matchesSearch = searchText.isEmpty ||
                clip.text.localizedCaseInsensitiveContains(searchText)
            return matchesType && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            typeFilter
            clipsList
            bottomBar
        }
        .frame(height: 260)
        .background(Color(.systemGroupedBackground))
        .onAppear { clips = SharedClipStore.load() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            let fresh = SharedClipStore.load()
            // Applique pinOverrides par-dessus les données fichier
            // (le clavier ne peut pas écrire le fichier, on préserve l'état local)
            clips = fresh.map { clip in
                if let override = pinOverrides[clip.id] {
                    if clip.isPinned == override { pinOverrides.removeValue(forKey: clip.id) }
                    return SharedClipItem(id: clip.id, text: clip.text, type: clip.type,
                                         subtype: clip.subtype, createdAt: clip.createdAt,
                                         isPinned: override)
                }
                return clip
            }
        }
    }

    // MARK: — Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.subheadline)
            TextField("Rechercher...", text: $searchText)
                .autocorrectionDisabled()
                .font(.subheadline)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: — Type filter pills

    private var typeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ClipTypeFilter.allCases, id: \.self) { filter in
                    Button(filter.rawValue) { activeFilter = filter }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(activeFilter == filter ? Color.accentColor : Color(.systemGray5))
                        .foregroundStyle(activeFilter == filter ? .white : .primary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
    }

    // MARK: — Clips list

    private var clipsList: some View {
        Group {
            if filtered.isEmpty {
                Spacer()
                Text(searchText.isEmpty && activeFilter == .all
                     ? "Aucun clip enregistré"
                     : "Aucun résultat")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Spacer()
            } else {
                ClipsListView(
                    clips: filtered,
                    onInsert: { text in onInsert(text) },
                    onPin: { id in
                        let current = clips.first { $0.id == id }?.isPinned ?? false
                        let newState = !current
                        // Garde l'état local (le timer ne peut pas le reverter)
                        pinOverrides[id] = newState
                        // Mise à jour en mémoire
                        clips = clips.map { c in
                            guard c.id == id else { return c }
                            return SharedClipItem(id: c.id, text: c.text, type: c.type,
                                                  subtype: c.subtype, createdAt: c.createdAt,
                                                  isPinned: newState)
                        }
                        // Enregistre pour que ClipKeep l'applique à l'ouverture
                        SharedClipStore.recordPending(id: id)
                    }
                )
            }
        }
    }

    // MARK: — Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 0) {
            if needsNextKeyboard {
                Button(action: onNextKeyboard) {
                    Image(systemName: "globe")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 36)
                }
            }
            Spacer()
            Button { onInsert("\n") } label: {
                Image(systemName: "return")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 36)
            }
            Button(action: onDelete) {
                Image(systemName: "delete.left")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 36)
            }
        }
        .padding(.horizontal, 4)
        .background(Color(.systemGray6))
    }
}
