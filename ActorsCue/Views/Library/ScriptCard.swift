import SwiftUI

struct ScriptCard: View {
    let script: Script

    private var subtitle: String {
        let chars = script.userCharacters.isEmpty
            ? "No role assigned"
            : script.userCharacters.joined(separator: ", ")
        return chars
    }

    private var lastPracticed: String {
        guard let date = script.lastPracticedAt else { return "Never practiced" }
        return "Last: \(date.formatted(.relative(presentation: .named)))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(script.title)
                .font(.headline)
                .lineLimit(1)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(lastPracticed)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
