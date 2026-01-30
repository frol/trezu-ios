import SwiftUI

struct TreasurySearchBar: View {
    @Binding var text: String
    let onSubmit: () -> Void
    var isSearching: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                }

                TextField("Search treasury (e.g., dao.sputnik-dao.near)", text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(onSubmit)

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !text.isEmpty {
                Button("Search") {
                    onSubmit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSearching)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TreasurySearchBar(text: .constant(""), onSubmit: {})
        TreasurySearchBar(text: .constant("testing-astradao"), onSubmit: {})
        TreasurySearchBar(text: .constant("searching..."), onSubmit: {}, isSearching: true)
    }
    .padding()
}
