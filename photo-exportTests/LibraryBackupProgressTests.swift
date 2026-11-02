import Foundation
import Testing

@testable import Photo_Export

@Suite(.timeLimit(.minutes(2)))
struct LibraryBackupProgressTests {
  private func progress(_ years: [(Int, Int, Int)]) -> LibraryBackupProgress {
    LibraryBackupProgress(
      years: years.map { LibraryBackupProgress.YearCount(year: $0.0, total: $0.1, exported: $0.2) })
  }

  @Test func emptyLibraryHasNoProgressAndNoDivideByZero() {
    let p = progress([])
    #expect(p.total == 0)
    #expect(p.fraction == 0)
    #expect(p.percent == 0)
    #expect(p.decades.isEmpty)
    #expect(p.nextMilestone == nil)
    #expect(!p.isComplete)
  }

  @Test func totalsAndPercentRoundDownSoWeNeverClaimMoreThanIsSafe() {
    let p = progress([(2020, 1000, 995)])
    #expect(p.total == 1000)
    #expect(p.exported == 995)
    #expect(p.percent == 99)  // 99.5% must not read as 100%
    #expect(!p.isComplete)
  }

  @Test func exportedIsClampedToYearTotal() {
    let p = progress([(2019, 10, 25)])
    #expect(p.exported == 10)
    #expect(p.isComplete)
  }

  @Test func yearsWithNoPhotosAreIgnored() {
    let p = progress([(2001, 0, 0), (2002, 5, 5)])
    #expect(p.total == 5)
    #expect(p.decades.map(\.label) == ["2000s"])
  }

  @Test func yearsGroupIntoDecadesInAscendingOrder() {
    let p = progress([(2021, 100, 40), (1987, 10, 10), (2015, 50, 50), (1989, 5, 5), (2010, 50, 0)])
    #expect(p.decades.map(\.label) == ["1980s", "2010s", "2020s"])
    #expect(p.decades[0].total == 15)
    #expect(p.decades[1].total == 100)
    #expect(p.decades[1].exported == 50)
    #expect(p.decades[2].percent == 40)
  }

  @Test func decadeCompletionFollowsCounts() {
    let p = progress([(1985, 10, 10), (2015, 50, 49)])
    #expect(p.decades[0].isComplete)
    #expect(!p.decades[1].isComplete)
    #expect(p.completeDecades.map(\.label) == ["1980s"])
  }

  @Test func milestoneIsNextTenPercentStepAndCountsPhotosAway() {
    let p = progress([(2020, 1000, 583)])
    let m = p.nextMilestone
    #expect(m?.percent == 60)
    #expect(m?.photosAway == 17)  // 600 - 583
  }

  @Test func milestoneAtExactStepTargetsTheNextOne() {
    let p = progress([(2020, 1000, 600)])
    #expect(p.nextMilestone?.percent == 70)
    #expect(p.nextMilestone?.photosAway == 100)
  }

  @Test func milestoneRoundsPhotosAwayUpForUnevenTotals() {
    let p = progress([(2020, 7, 0)])
    #expect(p.nextMilestone?.percent == 10)
    #expect(p.nextMilestone?.photosAway == 1)  // ceil(0.7)
  }

  @Test func completeLibraryHasNoNextMilestone() {
    let p = progress([(2020, 3, 3)])
    #expect(p.isComplete)
    #expect(p.percent == 100)
    #expect(p.nextMilestone == nil)
  }
}
