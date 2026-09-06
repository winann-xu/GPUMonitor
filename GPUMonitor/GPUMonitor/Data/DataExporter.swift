// MARK: - DataExporter
// 数据导出 — CSV/JSON 格式

import Foundation

@MainActor
class DataExporter {
    static let shared = DataExporter()
    
    func exportToCSV(metricData: MetricData) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        
        let gpuLoad = String(format: "%.1f", metricData.gpuLoad)
        let gpuTemp = String(format: "%.1f", metricData.gpuTemp)
        let cpuLoad = String(format: "%.1f", metricData.cpuLoad)
        let cpuTemp = String(format: "%.1f", metricData.cpuTemp)
        let ramUsed = metricData.ramUsed
        let ramTotal = metricData.ramTotal
        let ramPct = ramTotal > 0 ? String(format: "%.1f", ramUsed / ramTotal * 100) : "0.0"
        let dl = String(format: "%.1f", metricData.netDownload)
        let up = String(format: "%.1f", metricData.netUpload)
        
        let csv = "时间,GPU利用率%,GPU温度°C,CPU利用率%,CPU温度°C,内存使用%,下载MB/s,上传MB/s\n" +
                  "\(timestamp),\(gpuLoad),\(gpuTemp),\(cpuLoad),\(cpuTemp),\(ramPct),\(dl),\(up)\n"
        
        guard let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            return false
        }
        let url = desktop.appendingPathComponent("GPUMonitor_\(timestamp).csv")
        
        do {
            try csv.write(to: url, atomically: true, encoding: String.Encoding.utf8)
            return true
        } catch {
            print("导出失败: \(error)")
            return false
        }
    }
    
    func exportToJSON(metricData: MetricData) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        
        let data: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "gpu": ["load": metricData.gpuLoad, "temp": metricData.gpuTemp,
                    "freq": metricData.gpuFreq, "power": metricData.gpuPower],
            "cpu": ["load": metricData.cpuLoad, "temp": metricData.cpuTemp,
                    "freq": metricData.cpuFreq, "power": metricData.cpuPower],
            "memory": ["ramUsed": metricData.ramUsed, "ramTotal": metricData.ramTotal,
                       "swapUsed": metricData.swapUsed, "swapTotal": metricData.swapTotal],
            "network": ["download": metricData.netDownload, "upload": metricData.netUpload]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let jsonStr = String(data: jsonData, encoding: .utf8),
              let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            return false
        }
        let url = desktop.appendingPathComponent("GPUMonitor_\(timestamp).json")
        
        do {
            try jsonStr.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("导出失败: \(error)")
            return false
        }
    }
}
