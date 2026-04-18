import Foundation

extension TimeInterval {
    /// "HH:MM:SS" 格式，超过 1 小时显示 3 段，否则 2 段。
    var clockString: String {
        let total = Int(max(0, self))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    /// 紧凑的 "1h 23m" / "15m" 格式。
    var compactString: String {
        let totalMin = max(0, Int(self / 60))
        let h = totalMin / 60
        let m = totalMin % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
