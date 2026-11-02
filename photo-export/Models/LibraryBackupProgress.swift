import Foundation

/// Library-wide backup progress, rolled up from per-year counts. Pure value type so the
/// header that shows it can be tested without PhotoKit or the record stores.
struct LibraryBackupProgress: Equatable {
  struct YearCount: Equatable {
    let year: Int
    let total: Int
    /// Clamped to `total` so a stale record never reports more than the library holds.
    let exported: Int

    init(year: Int, total: Int, exported: Int) {
      self.year = year
      self.total = max(0, total)
      self.exported = min(max(0, exported), self.total)
    }
  }

  struct Decade: Equatable, Identifiable {
    let start: Int
    let total: Int
    let exported: Int

    var id: Int { start }
    var label: String { "\(start)s" }
    var fraction: Double { total > 0 ? Double(exported) / Double(total) : 0 }
    var percent: Int { LibraryBackupProgress.percent(exported: exported, total: total) }
    var isComplete: Bool { total > 0 && exported >= total }
    var remaining: Int { total - exported }
  }

  struct Milestone: Equatable {
    let percent: Int
    let photosAway: Int
  }

  let total: Int
  let exported: Int
  let decades: [Decade]

  /// Years with no photos are dropped, so empty years never produce empty decades.
  init(years: [YearCount]) {
    let populated = years.filter { $0.total > 0 }
    total = populated.reduce(0) { $0 + $1.total }
    exported = populated.reduce(0) { $0 + $1.exported }
    let byDecade = Dictionary(grouping: populated) { $0.year / 10 * 10 }
    decades = byDecade.keys.sorted().map { start in
      let members = byDecade[start] ?? []
      return Decade(
        start: start, total: members.reduce(0) { $0 + $1.total },
        exported: members.reduce(0) { $0 + $1.exported })
    }
  }

  var fraction: Double { total > 0 ? Double(exported) / Double(total) : 0 }
  var percent: Int { Self.percent(exported: exported, total: total) }
  var isComplete: Bool { total > 0 && exported >= total }
  var completeDecades: [Decade] { decades.filter(\.isComplete) }

  /// The next 10% step and how many photos reach it. Nil for an empty or finished library.
  var nextMilestone: Milestone? {
    guard total > 0, !isComplete else { return nil }
    let target = min(100, (percent / 10 + 1) * 10)
    let needed = (total * target + 99) / 100  // ceil(total * target / 100)
    return Milestone(percent: target, photosAway: needed - exported)
  }

  /// Rounds down, so 995 of 1,000 reads 99% rather than claiming a finished backup.
  static func percent(exported: Int, total: Int) -> Int {
    total > 0 ? exported * 100 / total : 0
  }
}
