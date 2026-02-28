import SwiftUI

struct RunSummaryView: View {
    let script: Script
    let stumbedLineIDs: [UUID]
    let allLines: [Line]
    let duration: TimeInterval
    let onDone: () -> Void

    private var stumbedLines: [Line] {
        let ids = Set(stumbedLineIDs)
        return allLines.filter { ids.contains($0.id) }
    }

    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var confidencePercent: Int {
        guard !allLines.isEmpty else { return 100 }
        let known = allLines.count - stumbedLineIDs.count
        return Int(Double(known) / Double(allLines.count) * 100)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: stumbedLineIDs.isEmpty ? "star.fill" : "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(stumbedLineIDs.isEmpty ? Color.yellow : Color.accentColor)

                    Text("Run Complete")
                        .font(.largeTitle.bold())

                    Text(script.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                // Stats row
                HStack(spacing: 0) {
                    StatCell(value: "\(allLines.count)", label: "Lines")
                    Divider().frame(height: 44)
                    StatCell(value: "\(stumbedLineIDs.count)", label: "Stumbled")
                    Divider().frame(height: 44)
                    StatCell(value: "\(confidencePercent)%", label: "Confidence")
                    Divider().frame(height: 44)
                    StatCell(value: formattedDuration, label: "Duration")
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Stumbled lines list
                if !stumbedLines.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Lines to Review")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(stumbedLines) { line in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(line.character)
                                    .font(.caption.uppercaseSmallCaps())
                                    .foregroundStyle(.secondary)
                                Text(line.text)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal)
                        }
                    }
                }

                Button {
                    onDone()
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden()
    }
}

private struct StatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
