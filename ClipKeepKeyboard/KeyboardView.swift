import SwiftUI

struct KeyboardView: View {
    let needsNextKeyboard: Bool
    let onInsert: (String) -> Void
    let onDelete: () -> Void
    let onNextKeyboard: () -> Void

    @State private var searchText = ""
    @State private var clips: [SharedClipItem] = []

    private var filtered: [SharedClipItem] {
        guard !searchText.isEmpty else { return clips }
        return clips.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            clipsList
            bottomBar
        }
        .frame(height: 260)
        .background(Color(.systemGroupedBackground))
        .onAppear { clips = SharedClipStore.load() }
    }

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

    private var clipsList: some View {
        Group {
            if filtered.isEmpty {
                Spacer()
                Text(searchText.isEmpty ? "Aucun clip enregistré" : "Aucun résultat")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { clip in
                            ClipKeyboardRow(clip: clip)
                                .onTapGesture { onInsert(clip.text) }
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            if needsNextKeyboard {
                Button(action: onNextKeyboard) {
                    Image(systemName: "globe")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 36)
                }
            }
            Spacer()
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
