import SwiftUI

struct EmojiPickerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (String) -> Void

    private let categories: [(title: String, emojis: [String])] = [
        ("Sık Kullanılan", ["😂", "❤️", "🔥", "🎉", "👍", "😍", "🙌", "✈️"]),
        ("Yüzler", ["😀", "😄", "😅", "😊", "🥳", "😎", "🤩", "🥰", "😉", "🤔", "😴", "🤗"]),
        ("Seyahat", ["✈️", "🏝️", "🏨", "🧳", "🗺️", "🚕", "🛂", "🌍", "🏖️", "🍹", "🎶", "🌅"]),
        ("Jestler", ["👍", "🙌", "👏", "🤝", "🙏", "✌️", "🤙", "👋"]),
        ("Kutlama", ["🎉", "🎊", "🥂", "🍾", "💃", "🕺", "🔥", "✨"]),
    ]

    private let columns = Array(repeating: GridItem(.flexible()), count: 6)

    var body: some View {
        NavigationStack {
            ZStack {
                NightclubBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(categories, id: \.title) { category in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(category.title.uppercased())
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.textTertiary)

                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(category.emojis, id: \.self) { emoji in
                                        Button {
                                            onSelect(emoji)
                                            dismiss()
                                        } label: {
                                            Text(emoji)
                                                .font(.system(size: 30))
                                                .frame(maxWidth: .infinity, minHeight: 44)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Emoji Gönder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    EmojiPickerView { _ in }
        .preferredColorScheme(.dark)
}
