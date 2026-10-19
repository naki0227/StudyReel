import SwiftUI

// 目標まわりの見た目（方眼の紙、マスキングテープ、ポラロイド、ピル）。ホーム・目標の画面・共有カードで使う
struct GoalTheme {
    // 紙の地、薄い面、主役の色、文字に使う濃い色、2本目のテープの色
    let paper: Color
    let soft: Color
    let accent: Color
    let deep: Color
    let tape: Color

    static let sky = GoalTheme(
        paper: Color(red: 0.969, green: 0.973, blue: 0.980),   // #F7F8FA
        soft: ReelTheme.accentSoft,
        accent: ReelTheme.accent,
        deep: ReelTheme.accentDeep,
        tape: Color(red: 0.949, green: 0.796, blue: 0.816)     // #F2CBD0
    )

    // テープの3色（空色・ピンク・黄色）
    static let tapeBlue = Color(red: 0.620, green: 0.765, blue: 0.886).opacity(0.6)
    static let tapePink = Color(red: 0.949, green: 0.796, blue: 0.816).opacity(0.85)
    static let tapeYellow = Color(red: 0.965, green: 0.886, blue: 0.659).opacity(0.85)
}

// 方眼の線
struct GridPaper: Shape {
    var spacing: CGFloat = 20

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x: CGFloat = 0
        while x <= rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += spacing
        }
        var y: CGFloat = 0
        while y <= rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
        }
        return path
    }
}

// 方眼ノートの地。上から下へ少しずつ線を薄くする
struct GridPaperBackground: View {
    var color: Color = GoalTheme.sky.paper
    var spacing: CGFloat = 20

    var body: some View {
        ZStack {
            color
            GridPaper(spacing: spacing)
                .stroke(ReelTheme.line, lineWidth: 0.6)
            LinearGradient(colors: [color.opacity(0.5), color.opacity(0.85)], startPoint: .top, endPoint: .bottom)
        }
    }
}

// 両端がギザギザのマスキングテープ
struct TapeShape: Shape {
    var teeth = 4

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let depth = min(rect.width * 0.05, 4)
        let step = rect.height / CGFloat(teeth * 2)
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        for index in 1...(teeth * 2) {
            let x = index.isMultiple(of: 2) ? rect.width : rect.width - depth
            path.addLine(to: CGPoint(x: x, y: step * CGFloat(index)))
        }
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        for index in (0..<(teeth * 2)).reversed() {
            let x = index.isMultiple(of: 2) ? 0 : depth
            path.addLine(to: CGPoint(x: x, y: step * CGFloat(index)))
        }
        path.closeSubpath()
        return path
    }
}

struct Tape: View {
    var color: Color = GoalTheme.tapeBlue
    var width: CGFloat = 78
    var angle: Double = -4

    var body: some View {
        TapeShape()
            .fill(color)
            .frame(width: width, height: 20)
            .rotationEffect(.degrees(angle))
            .accessibilityHidden(true)
    }
}

// テープで貼った白い紙
struct TapedPaper<Content: View>: View {
    var tape: Color = GoalTheme.tapeBlue
    var tapeAlignment: Alignment = .topLeading
    var tapeAngle: Double = -4
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: ReelTheme.ink.opacity(0.08), radius: 10, y: 6)
            )
            .overlay(alignment: tapeAlignment) {
                Tape(color: tape, angle: tapeAngle)
                    .padding(.horizontal, 22)
                    .offset(y: -10)
            }
    }
}

// ポラロイド風の写真。下の余白に手書き風の一言
struct Polaroid: View {
    let image: UIImage?
    var caption: String = ""
    var badge: String = ""
    var tape: Color = GoalTheme.tapePink
    var angle: Double = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        LinearGradient(colors: [ReelTheme.accentSoft, ReelTheme.background], startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipped()
                if !badge.isEmpty {
                    Text(badge)
                        .font(ReelTheme.sans(10, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 3)
                        .padding(6)
                }
            }
            Text(caption)
                .font(ReelTheme.serif(13).italic())
                .foregroundColor(ReelTheme.ink)
                .padding(.leading, 2)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.white.shadow(.drop(color: ReelTheme.ink.opacity(0.18), radius: 8, y: 6)))
        .overlay(alignment: .top) {
            Tape(color: tape, width: 64, angle: 6).offset(y: -10)
        }
        .rotationEffect(.degrees(angle))
    }
}

// 白いピル（「300h 勉強する」）
struct GoalPill: View {
    let value: String
    let label: String
    var theme: GoalTheme = .sky

    var body: some View {
        HStack(spacing: 5) {
            Text(value)
                .font(ReelTheme.sans(11, weight: .medium))
                .foregroundColor(theme.deep)
            Text(label)
                .font(ReelTheme.sans(11))
                .foregroundColor(ReelTheme.ink)
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(Capsule().fill(Color.white).shadow(color: ReelTheme.line, radius: 0, y: 1))
    }
}

// 太めの丸いメーター
struct GoalMeter: View {
    let ratio: Double
    var height: CGFloat = 7
    var theme: GoalTheme = .sky

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.soft)
                Capsule().fill(theme.accent)
                    .frame(width: max(geometry.size.width * min(max(ratio, 0), 1), ratio > 0 ? height : 0))
            }
        }
        .frame(height: height)
    }
}

// 斜体の小文字の英字ラベル（「my goal ✦」）
struct GoalScript: View {
    let text: String
    var size: CGFloat = 15
    var color: Color = ReelTheme.secondary

    var body: some View {
        Text(text)
            .font(ReelTheme.serif(size).italic())
            .foregroundColor(color)
    }
}

// 大きな「D-56」
struct DDayText: View {
    let goal: StudyGoal
    var size: CGFloat = 58
    var theme: GoalTheme = .sky
    var now: Date = Date()

    var body: some View {
        let left = goal.daysLeft(from: now)
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            if left == 0 {
                Text("D-day").font(ReelTheme.serif(size * 0.8))
            } else {
                Text(left > 0 ? "D-" : "D+")
                    .font(ReelTheme.serif(size * 0.48))
                    .foregroundColor(theme.deep)
                Text("\(abs(left))")
                    .font(ReelTheme.serif(size))
                    .kerning(-size * 0.04)
            }
        }
        .foregroundColor(ReelTheme.ink)
        .monospacedDigit()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(goal.dDayText(from: now))
    }
}
