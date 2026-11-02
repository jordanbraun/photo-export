import Foundation

/// Plain-language explanation of why an item could not be backed up and what to do about it.
/// Pure presentation data: no persistence, scheduling, or PhotoKit access.
extension ExportIssue {
  struct Guidance: Equatable {
    /// What happened, in words a person would use.
    let cause: String
    /// What the person can do, or "Nothing to do." when the item is already covered.
    let nextStep: String
  }

  static let nothingToDo = "Nothing to do."

  var guidance: Guidance {
    // Covered reasons are not lost files, so they win over any retry category.
    switch reason {
    case .editedUnavailableOriginalBackedUp:
      return Guidance(
        cause:
          "Photos couldn't provide the edited version, so the original was saved with _orig added to its name.",
        nextStep: Self.nothingToDo)
    case .pairedVideoUnavailable:
      return Guidance(
        cause: "Photos has no motion video for this Live Photo. The still image was saved.",
        nextStep: Self.nothingToDo)
    default:
      return Self.defaultGuidance(for: category)
    }
  }

  private static func defaultGuidance(for category: AutoSyncFailureCategory) -> Guidance {
    switch category {
    case .destinationUnavailable:
      return Guidance(
        cause: "The backup drive or folder couldn't be reached.",
        nextStep: "Reconnect the drive. This item is tried again on the next Auto Export run.")
    case .destinationPermission:
      return Guidance(
        cause: "Photo Export isn't allowed to write to the backup folder.",
        nextStep: "Choose the backup folder again to restore access, then retry.")
    case .destinationNoSpace:
      return Guidance(
        cause: "The backup drive is full.",
        nextStep: "Free up space on the drive, then retry.")
    case .destinationCollision:
      return Guidance(
        cause: "A different file with the same name is already in the backup folder.",
        nextStep:
          "Photo Export never overwrites existing files. Rename or move the existing file, then retry."
      )
    case .assetMissing:
      return Guidance(
        cause: "This photo is no longer in your Photos library.",
        nextStep: "It may have been deleted. Nothing to do unless you want it back.")
    case .resourceMissing:
      return Guidance(
        cause:
          "Photos couldn't supply the file. It may be an iCloud original that isn't downloaded, or a file type Photos can't export.",
        nextStep: "Find it in Photos and open it so it downloads, then retry.")
    case .photoKitTransient:
      return Guidance(
        cause: "Photos was busy or changed while this item was exporting.",
        nextStep: "It is retried automatically. You can also retry now.")
    case .iCloudTransient:
      return Guidance(
        cause: "iCloud or the network interrupted the download.",
        nextStep: "Check your connection. It is retried automatically.")
    case .unknown:
      return Guidance(
        cause: "Something unexpected stopped this item from exporting.",
        nextStep: "Retry it, or find it in Photos to check that it opens.")
    }
  }

  /// Text to type into the Photos search field to locate this item, or nil without a filename.
  var photosSearchTerm: String? {
    guard let name = Self.nonemptyFilename(filename) else { return nil }
    return name.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

/// Builds the copyable list of items that need attention, for searching in Photos by hand.
enum ExportIssueReport {
  /// One line per distinct file, version and scope, ordered by capture date then filename.
  static func text(for issues: [ExportIssue], timeZone: TimeZone = .current) -> String {
    let rows = distinct(issues)
    guard !rows.isEmpty else { return "No items need attention." }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    let noun = rows.count == 1 ? "item" : "items"
    var lines = ["\(rows.count) \(noun) couldn't be backed up.", ""]
    for row in rows {
      let name = row.photosSearchTerm ?? "Filename unavailable"
      let date = row.creationDate.map(formatter.string(from:)) ?? "Date unavailable"
      lines.append(
        "\(name) | \(date) | \(row.scopeLabel) | \(row.variantLabel) | \(row.guidance.cause)")
    }
    return lines.joined(separator: "\n")
  }

  private static func distinct(_ issues: [ExportIssue]) -> [ExportIssue] {
    var seen = Set<String>()
    let unique = issues.filter { issue in
      // Without a filename two rows can't be shown to be the same file, so keep both.
      let key =
        issue.photosSearchTerm.map { "\($0)|\(issue.variantLabel)|\(issue.scopeLabel)" }
        ?? "\(issue.assetId)|\(issue.id.variantRaw)|\(issue.scopeLabel)"
      return seen.insert(key).inserted
    }
    return unique.sorted {
      switch ($0.creationDate, $1.creationDate) {
      case (let a?, let b?) where a != b: return a < b
      case (nil, _?): return false
      case (_?, nil): return true
      default: break
      }
      let names = ($0.photosSearchTerm ?? "", $1.photosSearchTerm ?? "")
      if names.0 != names.1 { return names.0 < names.1 }
      return $0.scopeLabel < $1.scopeLabel
    }
  }
}
