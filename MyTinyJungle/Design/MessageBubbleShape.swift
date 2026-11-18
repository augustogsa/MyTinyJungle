import SwiftUI

/// iMessage-style bubble: continuous rounded rect with a small curled tail at the bottom corner.
struct BubbleShape: Shape {
    var fromMe: Bool
    var radius: CGFloat = 18
    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.height / 2)
        let p = Path(roundedRect: rect, cornerRadius: r, style: .continuous)
        // tail
        var t = Path()
        let x = rect.maxX, y = rect.maxY
        t.move(to: CGPoint(x: x - 16, y: y - 18))
        t.addLine(to: CGPoint(x: x - 2, y: y - 18))
        t.addCurve(to: CGPoint(x: x + 6, y: y), control1: CGPoint(x: x - 2, y: y - 8), control2: CGPoint(x: x + 2, y: y - 2))
        t.addCurve(to: CGPoint(x: x - 16, y: y - 4), control1: CGPoint(x: x - 4, y: y + 1), control2: CGPoint(x: x - 11, y: y - 1))
        t.closeSubpath()
        if !fromMe { t = t.applying(CGAffineTransform(translationX: rect.minX + rect.maxX, y: 0).scaledBy(x: -1, y: 1)) }
        return p.union(t)
    }
}

extension View {
    /// Wraps content in a chat bubble. Incoming: tail bottom-left; mine: tail bottom-right.
    func messageBubble(fromMe: Bool = false, fill: Color? = nil) -> some View {
        self
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(BubbleShape(fromMe: fromMe).fill(fill ?? (fromMe ? Jungle.userBubble : Jungle.incoming)))
    }
}
