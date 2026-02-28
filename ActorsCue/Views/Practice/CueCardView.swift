import SwiftUI

struct CueCardView: View {
    let cueingLine: Line?       // The preceding line (context)
    let userLine: Line          // The user's line to deliver
    let trainingWheels: Bool    // Whether to show the user's text
    let isListening: Bool
    let onForgotIt: () -> Void
    let onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Cue context
            if let cue = cueingLine {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cue.character)
                        .font(.caption.uppercaseSmallCaps())
                        .foregroundStyle(.secondary)
                    Text(cue.text)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .italic()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial)
            }

            Divider()

            // User's cue
            VStack(alignment: .leading, spacing: 12) {
                Text("Your line")
                    .font(.caption.uppercaseSmallCaps())
                    .foregroundStyle(.tint)

                if trainingWheels {
                    Text(userLine.text)
                        .font(.title3)
                        .fontWeight(.medium)
                } else {
                    Text("Speak your line…")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .italic()
                }

                // Mic indicator
                HStack(spacing: 6) {
                    Image(systemName: isListening ? "mic.fill" : "mic.slash")
                        .foregroundStyle(isListening ? .red : .secondary)
                        .symbolEffect(.pulse, isActive: isListening)
                    Text(isListening ? "Listening…" : "Mic off")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Divider()

            // Action buttons
            HStack(spacing: 16) {
                Button(role: .destructive) {
                    onForgotIt()
                } label: {
                    Label("Forgot It", systemImage: "exclamationmark.bubble")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    onAdvance()
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.regular)
            .padding()
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8)
        .padding()
    }
}
