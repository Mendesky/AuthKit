/// 常數時間字串比較，避免以回應時間差推測祕密值（timing oracle）。
public enum ConstantTime {
    /// 長度不同必不等，但仍走完固定長度迴圈。
    public static func equals(_ a: String, _ b: String) -> Bool {
        let ab = Array(a.utf8)
        let bb = Array(b.utf8)
        let n = Swift.max(ab.count, bb.count)
        guard n > 0 else { return ab.count == bb.count }   // 兩者皆空才算相等
        var diff = ab.count ^ bb.count
        for i in 0..<n {
            let x: Int = i < ab.count ? Int(ab[i]) : 0
            let y: Int = i < bb.count ? Int(bb[i]) : 0
            diff |= x ^ y
        }
        return diff == 0
    }
}
