// MARK: - NetworkCollector
// 网络吞吐：用 netstat -ib 的累计字节数差分计算速度（系统自带，非第三方）

import Foundation

@MainActor
final class NetworkCollector {
    static let shared = NetworkCollector()
    
    private var lastDownBytes: UInt64 = 0
    private var lastUpBytes: UInt64 = 0
    private var lastSampleDate: Date?
    
    private init() {}
    
    /// 用当前累计字节数与上一帧的差值计算 MB/s 并写入 MetricData
    /// netstat 子进程在后台执行，避免模型满载时阻塞主线程/菜单栏 UI。
    func refresh(_ metric: MetricData) async {
        let totals = await Task.detached(priority: .utility) {
            Self.currentTotals()
        }.value
        guard let total = totals else { return }
        
        let now = Date()
        if let lastDate = lastSampleDate {
            let dt = now.timeIntervalSince(lastDate)
            if dt > 0.2, lastDownBytes > 0, total.down >= lastDownBytes {
                let downPerSec = Double(total.down - lastDownBytes) / dt
                let upPerSec = Double(total.up - lastUpBytes) / dt
                metric.netDownload = max(0, downPerSec / 1_000_000) // MB/s
                metric.netUpload = max(0, upPerSec / 1_000_000)
            }
        }
        
        lastDownBytes = total.down
        lastUpBytes = total.up
        lastSampleDate = now
    }
    
    /// 汇总所有活跃 en* 接口的下行/上行累计字节数
    nonisolated private static func currentTotals() -> (down: UInt64, up: UInt64)? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-ib", "-n"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        
        guard let data = try? pipe.fileHandleForReading.readToEnd(),
              let output = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        var down: UInt64 = 0
        var up: UInt64 = 0
        
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ")
            // netstat -ib 的 <Link#> 行才是每个物理接口的累计计数
            guard parts.count > 9,
                  parts[2].hasPrefix("<Link"),
                  Self.isPhysicalInterface(String(parts[0])) else {
                continue
            }
            down += UInt64(parts[6]) ?? 0
            up += UInt64(parts[9]) ?? 0
        }
        
        return down == 0 && up == 0 ? nil : (down, up)
    }
    
    nonisolated private static func isPhysicalInterface(_ name: String) -> Bool {
        // 有线/无线通常是 en0/en1/en7...；虚拟接口一般统计为 0，不影响求和
        return name.hasPrefix("en")
    }
}
