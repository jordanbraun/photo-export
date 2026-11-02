import Foundation
import Testing

@testable import Photo_Export

@MainActor
@Suite(.timeLimit(.minutes(2)))
struct ExportIssueGuidanceTests {
  private let day = Date(timeIntervalSince1970: 1_710_000_000)  // 2024-03-09 UTC
  private let utc = TimeZone(secondsFromGMT: 0)!

  private func retry(_ category: AutoSyncFailureCategory) -> RetryEntry {
    RetryEntry(
      category: category, errorSignature: "sig", attemptCount: 1, firstFailedAt: day,
      lastFailedAt: day, nextEligibleAt: nil)
  }

  private func issue(
    asset: String = "asset", variant: String = "original", scope: String = "Timeline 2024-03",
    category: AutoSyncFailureCategory? = .unknown, reason: ExportVariantReason? = nil,
    filename: String? = "IMG_0001.HEIC", created: Date? = nil
  ) -> ExportIssue {
    ExportIssue(
      id: .init(source: .timeline, assetId: asset, variantRaw: variant), destinationId: "dest",
      scopeLabel: scope, scopeKey: nil, message: "raw error", reason: reason, failedAt: day,
      retry: category.map(retry), filename: filename, creationDate: created)
  }

  // MARK: - Guidance

  @Test func everyCategoryHasPlainCauseAndNextStep() {
    for category in AutoSyncFailureCategory.allCases {
      let guidance = issue(category: category).guidance
      #expect(!guidance.cause.isEmpty, "\(category) needs a cause")
      #expect(!guidance.nextStep.isEmpty, "\(category) needs a next step")
    }
  }

  @Test func missingRetryEntryFallsBackToUnknownGuidance() {
    let unknown = issue(category: .unknown).guidance
    #expect(issue(category: nil).guidance == unknown)
  }

  @Test func coveredReasonsExplainThatNothingIsLost() {
    let edited = issue(reason: .editedUnavailableOriginalBackedUp).guidance
    #expect(edited.cause.contains("original"))
    #expect(edited.nextStep == "Nothing to do.")
    let video = issue(reason: .pairedVideoUnavailable).guidance
    #expect(video.cause.contains("still"))
    #expect(video.nextStep == "Nothing to do.")
  }

  @Test func coveredReasonWinsOverCategory() {
    let guidance = issue(category: .destinationNoSpace, reason: .pairedVideoUnavailable).guidance
    #expect(guidance.nextStep == "Nothing to do.")
  }

  @Test func neverOverwriteRuleIsStatedForCollisions() {
    let guidance = issue(category: .destinationCollision).guidance
    #expect(guidance.nextStep.contains("never overwrites"))
  }

  // MARK: - Find in Photos

  @Test func searchTermIsTheFilenameWhenPresent() {
    #expect(issue(filename: "IMG_0001.HEIC").photosSearchTerm == "IMG_0001.HEIC")
    #expect(issue(filename: "  IMG_0002.JPG \n").photosSearchTerm == "IMG_0002.JPG")
  }

  @Test func searchTermIsNilWithoutUsableFilename() {
    #expect(issue(filename: nil).photosSearchTerm == nil)
    #expect(issue(filename: "  \n").photosSearchTerm == nil)
  }

  // MARK: - Filename list

  @Test func listHeaderCountsItemsAndPluralizes() {
    #expect(
      ExportIssueReport.text(for: [issue()], timeZone: utc)
        .hasPrefix("1 item couldn't be backed up"))
    let two = [issue(asset: "a"), issue(asset: "b", filename: "IMG_0002.HEIC")]
    #expect(
      ExportIssueReport.text(for: two, timeZone: utc).hasPrefix("2 items couldn't be backed up"))
  }

  @Test func listLineHasFilenameDateScopeVersionAndCause() {
    let row = issue(
      scope: "Timeline 2024-03", category: .assetMissing, filename: "IMG_0001.HEIC",
      created: day)
    let text = ExportIssueReport.text(for: [row], timeZone: utc)
    #expect(
      text.contains(
        "IMG_0001.HEIC | 2024-03-09 | Timeline 2024-03 | Original | "
          + "This photo is no longer in your Photos library."))
  }

  @Test func listUsesPlaceholdersForMissingMetadata() {
    let text = ExportIssueReport.text(
      for: [issue(filename: nil, created: nil)], timeZone: utc)
    #expect(text.contains("Filename unavailable | Date unavailable |"))
  }

  @Test func listDropsDuplicateFileVersionScopeRows() {
    let a = issue(asset: "a")
    let sameFileElsewhere = issue(asset: "b")  // same filename, version, scope
    let text = ExportIssueReport.text(for: [a, sameFileElsewhere], timeZone: utc)
    #expect(text.components(separatedBy: "IMG_0001.HEIC").count - 1 == 1)
    #expect(text.hasPrefix("1 item couldn't"))
  }

  @Test func listIsSortedByDateThenFilenameForStableOutput() {
    let late = issue(asset: "1", filename: "B.JPG", created: day.addingTimeInterval(86_400 * 3))
    let earlyB = issue(asset: "2", filename: "B.JPG", created: day, scope: "Other")
    let earlyA = issue(asset: "3", filename: "A.JPG", created: day)
    let lines = ExportIssueReport.text(for: [late, earlyB, earlyA], timeZone: utc)
      .split(separator: "\n").map(String.init).filter { $0.contains(" | ") }
    #expect(lines.map { $0.prefix(5) } == ["A.JPG", "B.JPG", "B.JPG"])
    #expect(lines[2].contains("2024-03-12"))
  }

  @Test func emptyListSaysThereIsNothingToReport() {
    #expect(ExportIssueReport.text(for: [], timeZone: utc) == "No items need attention.")
  }
}
