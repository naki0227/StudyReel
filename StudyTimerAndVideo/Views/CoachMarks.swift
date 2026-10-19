import SwiftUI

// 初めて使うときに、画面を暗くしてボタンを1つずつ照らし、何をするところかを教える案内
struct CoachStep: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
}

enum CoachTour {
    static let homeKey = "has_seen_home_tour"
    static let recordingKey = "has_seen_recording_tour"

    // 設定の「使い方をもう一度見る」から、次に開いたとき案内を出し直す
    static func reset() {
        UserDefaults.standard.set(false, forKey: homeKey)
        UserDefaults.standard.set(false, forKey: recordingKey)
    }
}

struct CoachAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    // 案内で照らす場所に印をつける
    func coachMark(_ id: String) -> some View {
        anchorPreference(key: CoachAnchorKey.self, value: .bounds) { [id: $0] }
    }

    func coachMarkIf(_ condition: Bool, _ id: String) -> some View {
        anchorPreference(key: CoachAnchorKey.self, value: .bounds) { condition ? [id: $0] : [:] }
    }

    // steps を順に照らす。isPresented が true の間だけ出す
    func coachTour(_ steps: [CoachStep], isPresented: Binding<Bool>, onFinish: @escaping () -> Void = {}) -> some View {
        overlayPreferenceValue(CoachAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if isPresented.wrappedValue {
                    CoachOverlay(
                        steps: steps.filter { anchors[$0.id] != nil },
                        frames: anchors.mapValues { proxy[$0] },
                        containerSize: proxy.size,
                        onFinish: {
                            isPresented.wrappedValue = false
                            onFinish()
                        }
                    )
                    .transition(.opacity)
                }
            }
            .ignoresSafeArea()
        }
    }
}

private struct CoachOverlay: View {
    let steps: [CoachStep]
    let frames: [String: CGRect]
    let containerSize: CGSize
    let onFinish: () -> Void

    @State private var index = 0

    private var step: CoachStep? {
        steps.indices.contains(index) ? steps[index] : nil
    }

    private var hole: CGRect {
        guard let step, let frame = frames[step.id] else { return .zero }
        return frame.insetBy(dx: -10, dy: -8)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 照らす場所だけくり抜いた暗幕
            Color.black.opacity(0.68)
                .mask {
                    Rectangle()
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .frame(width: hole.width, height: hole.height)
                                .position(x: hole.midX, y: hole.midY)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                .frame(width: hole.width, height: hole.height)
                .position(x: hole.midX, y: hole.midY)
                .shadow(color: .white.opacity(0.5), radius: 8)

            if let step {
                callout(step)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { next() }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: index)
        .accessibilityElement(children: .contain)
        .onAppear {
            if steps.isEmpty { onFinish() }
        }
    }

    private func callout(_ step: CoachStep) -> some View {
        let width = min(containerSize.width - 40, 340)
        // 照らす場所が上半分なら下に、下半分なら上に説明を出す
        let showsBelow = hole.midY < containerSize.height * 0.55
        let x = min(max(hole.midX, width / 2 + 20), containerSize.width - width / 2 - 20)

        return VStack(alignment: .leading, spacing: 10) {
            Text(step.title)
                .font(ReelTheme.serif(20))
                .foregroundColor(ReelTheme.ink)
            Text(step.message)
                .font(ReelTheme.sans(14))
                .foregroundColor(ReelTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)

            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { item in
                    Capsule()
                        .fill(item == index ? ReelTheme.accentDeep : ReelTheme.line)
                        .frame(width: item == index ? 16 : 6, height: 6)
                }
                Spacer()
                Button(L10n.string("スキップ")) { onFinish() }
                    .font(ReelTheme.sans(13))
                    .foregroundColor(ReelTheme.secondary)
                    .padding(.trailing, 6)
                Button {
                    next()
                } label: {
                    Text(index == steps.count - 1 ? L10n.string("はじめる") : L10n.string("次へ"))
                        .font(ReelTheme.sans(14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(ReelTheme.accentDeep))
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(width: width, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(ReelTheme.background))
        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
        .position(
            x: x,
            y: showsBelow
                ? min(hole.maxY + 100, containerSize.height - 120)
                : max(hole.minY - 100, 120)
        )
        .id(step.id)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private func next() {
        if index < steps.count - 1 {
            index += 1
        } else {
            onFinish()
        }
    }
}
