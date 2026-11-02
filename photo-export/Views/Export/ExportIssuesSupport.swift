import AppKit
import SwiftUI

/// Header for the issues list: how many items need action, how many are already covered,
/// and one button that copies every filename for searching in Photos.
struct ExportIssuesSummarySection: View {
  let rows: [ExportIssue]
  @State private var copied = false

  private var needsAttention: [ExportIssue] { rows.filter { !$0.isCovered } }
  private var coveredCount: Int { rows.count - needsAttention.count }

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 6) {
        Text(headline).font(.headline)
        Text(subline).font(.callout).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        if !needsAttention.isEmpty {
          Button(copied ? "Copied" : "Copy List of Files") {
            ExportIssuesPasteboard.copy(ExportIssueReport.text(for: needsAttention))
            copied = true
          }
          .controlSize(.small)
          .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(2))
            copied = false
          }
          .help("Copies one line per file so you can search for them in Photos.")
        }
      }
      .padding(.vertical, 2)
    }
  }

  private var headline: String {
    switch needsAttention.count {
    case 0: return "Nothing needs your attention"
    case 1: return "1 item needs attention"
    default: return "\(needsAttention.count) items need attention"
    }
  }

  private var subline: String {
    var text = "The rest of your library keeps backing up."
    if coveredCount > 0 {
      text +=
        coveredCount == 1
        ? " 1 more item is already covered and is listed below for reference."
        : " \(coveredCount) more items are already covered and are listed below for reference."
    }
    return text
  }
}

/// Per-row actions for locating a file in Photos. Photos access stays read-only: this only
/// copies text and opens the Photos app.
struct FindInPhotosButtons: View {
  let searchTerm: String
  @State private var copied = false

  var body: some View {
    HStack(spacing: 8) {
      Button("Find in Photos") {
        ExportIssuesPasteboard.copy(searchTerm)
        ExportIssuesPasteboard.openPhotos()
        copied = true
      }
      .help("Copies the filename and opens Photos. Paste it into the Photos search field.")
      Button(copied ? "Copied" : "Copy Filename") {
        ExportIssuesPasteboard.copy(searchTerm)
        copied = true
      }
    }
    .controlSize(.small)
    .task(id: copied) {
      guard copied else { return }
      try? await Task.sleep(for: .seconds(2))
      copied = false
    }
  }
}

enum ExportIssuesPasteboard {
  static func copy(_ string: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
  }

  static func openPhotos() {
    guard
      let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Photos")
    else { return }
    NSWorkspace.shared.openApplication(
      at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
  }
}
