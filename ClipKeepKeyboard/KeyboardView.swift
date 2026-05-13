import SwiftUI
import Combine

private func kloc(_ key: String) -> String {
    let lang = UserDefaults(suiteName: "group.com.rafyq.ClipKeep")?.string(forKey: "app_language") ?? "fr"
    guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        return Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }
    return bundle.localizedString(forKey: key, value: key, table: nil)
}

private enum ClipTypeFilter: String, CaseIterable {
    case all  = "filter.all"
    case text = "filter.text"
    case url  = "filter.link"
    case code = "filter.code"

    var label: String { kloc(rawValue) }
}

struct KeyboardView: View {
    let needsNextKeyboard: Bool
    let onInsert: (String) -> Void
    let onDelete: () -> Void
    let onNextKeyboard: () -> Void

    @State private var activeFilter  = ClipTypeFilter.all
    @State private var clips: [SharedClipItem] = []
    // Mémorise les épingles posées localement dans le clavier.
    // Nécessaire car le timer relit clips.json chaque seconde : sans ce dictionnaire,
    // il écraserait l'état local avant que ClipKeep ait écrit la confirmation.
    @State private var pinOverrides: [UUID: Bool] = [:]

    private var filtered: [SharedClipItem] {
        clips.filter { clip in
            switch activeFilter {
            case .all:  return true
            case .text: return clip.type == "text"
            case .url:  return clip.type == "url"
            case .code: return clip.type == "code"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            typeFilter
            clipsList
            bottomBar
        }
        .frame(height: 260)
        .background(Color(.systemGroupedBackground))
        .onAppear { clips = SharedClipStore.load() }
        // Relit clips.json chaque seconde pour recevoir les changements de ClipKeep.
        // Fusionne avec pinOverrides : si ClipKeep a confirmé l'état, l'override est effacé.
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            let fresh = SharedClipStore.load()
            clips = fresh.map { clip in
                if let override = pinOverrides[clip.id] {
                    // ClipKeep a confirmé l'état → override devenu inutile, on le retire.
                    if clip.isPinned == override { pinOverrides.removeValue(forKey: clip.id) }
                    return SharedClipItem(id: clip.id, text: clip.text, type: clip.type,
                                         subtype: clip.subtype, createdAt: clip.createdAt,
                                         isPinned: override)
                }
                return clip
            }
        }
    }

    // MARK: — Type filter pills

    private var typeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ClipTypeFilter.allCases, id: \.self) { filter in
                    Button(filter.label) { activeFilter = filter }
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
                Text(activeFilter == .all ? kloc("empty.no.clips") : kloc("empty.no.results"))
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
                        // 1. Sauvegarde l'état local pour que le timer ne l'écrase pas.
                        pinOverrides[id] = newState
                        // 2. Met à jour l'affichage immédiatement (sans attendre le timer).
                        clips = clips.map { c in
                            guard c.id == id else { return c }
                            return SharedClipItem(id: c.id, text: c.text, type: c.type,
                                                  subtype: c.subtype, createdAt: c.createdAt,
                                                  isPinned: newState)
                        }
                        // 3. Écrit l'UUID dans pending_pins.json pour que ClipKeep
                        //    applique le changement dans SwiftData à la prochaine ouverture.
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
