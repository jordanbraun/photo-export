import SwiftUI

/// Library-wide backup progress: one headline number, the next milestone, and a tile per
/// decade that fills as its photos are backed up. Purely presentational; the caller supplies
/// a `LibraryBackupProgress` built from the existing per-year counts.
struct LibraryProgressHeader: View {
  let progress: LibraryBackupProgress
  /// Photos that couldn't be backed up. Shown as a button only when non-zero.
  var attentionCount: Int = 0
  var onShowIssues: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text("\(progress.percent)%")
          .font(.system(size: 40, weight: .bold, design: .rounded))
          .monospacedDigit()
        VStack(alignment: .leading, spacing: 2) {
          Text("\(progress.exported.formatted()) of \(progress.total.formatted()) photos backed up")
            .font(.headline)
          if let milestone = progress.nextMilestone {
            Text(
              "\(milestone.photosAway.formatted()) more to reach \(milestone.percent)%"
            )
            .font(.callout).foregroundStyle(.secondary)
          } else if progress.isComplete {
            Text("Your whole library is backed up.").font(.callout).foregroundStyle(.secondary)
          }
        }
        Spacer()
        if attentionCount > 0 {
          Button(action: onShowIssues) {
            Label("\(attentionCount) need attention", systemImage: "exclamationmark.triangle")
          }
          .controlSize(.small)
        }
      }
      ProgressView(value: progress.fraction)
        .accessibilityLabel("Library backup progress")
        .accessibilityValue("\(progress.percent) percent")
      if !progress.decades.isEmpty {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
          ForEach(progress.decades) { DecadeTile(decade: $0) }
        }
      }
      if !progress.completeDecades.isEmpty && !progress.isComplete {
        Label(milestoneMessage, systemImage: "checkmark.seal.fill")
          .font(.callout).foregroundStyle(.green)
      }
    }
    .padding()
  }

  private var milestoneMessage: String {
    let names = progress.completeDecades.map(\.label)
    let list = names.formatted(.list(type: .and))
    return "Every photo from the \(list) is backed up."
  }
}

private struct DecadeTile: View {
  let decade: LibraryBackupProgress.Decade

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(decade.label).font(.subheadline.weight(.semibold))
        Spacer(minLength: 0)
        if decade.isComplete {
          Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        }
      }
      Text("\(decade.percent)%").font(.title3.weight(.bold)).monospacedDigit()
        .foregroundStyle(decade.isComplete ? Color.green : Color.primary)
      Text(
        decade.isComplete
          ? "\(decade.total.formatted()) safe" : "\(decade.remaining.formatted()) left"
      )
      .font(.caption).foregroundStyle(.secondary)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    .overlay(alignment: .bottom) {
      GeometryReader { geo in
        Rectangle()
          .fill(decade.isComplete ? Color.green : Color.accentColor)
          .frame(width: geo.size.width * decade.fraction, height: 3)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
      }
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .accessibilityElement(children: .combine)
  }
}

#if DEBUG
  #Preview("Library progress") {
    LibraryProgressHeader(
      progress: LibraryBackupProgress(years: [
        .init(year: 1985, total: 2_917, exported: 2_917),
        .init(year: 2005, total: 1_408, exported: 1_408),
        .init(year: 2015, total: 52_161, exported: 38_904),
        .init(year: 2024, total: 39_509, exported: 12_330),
      ]),
      attentionCount: 12
    )
    .frame(width: 640)
  }
#endif
