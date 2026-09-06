// MARK: - GPUSampler
// 从 IORegistry 读取 AGXAccelerator 的 GPU 设备利用率
// 参考 macmon sources.rs 的 IOKit 用法，改为只读原生驱动统计。

import Foundation
import IOKit

enum GPUSampler {
    /// 返回 0...100 的设备利用率（多个加速器取最大值）
    static func utilization() -> Double? {
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("AGXAccelerator") else { return nil }
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }
        
        var result: Double?
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }
            
            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let cfDict = props?.takeRetainedValue(),
                  let dict = cfDict as? [String: Any] else {
                continue
            }
            guard let stats = dict["PerformanceStatistics"] as? [String: Any] else { continue }
            
            let keys = ["Device Utilization %", "Renderer Utilization %"]
            for key in keys {
                if let number = stats[key] as? NSNumber {
                    result = max(result ?? 0, min(number.doubleValue, 100))
                }
            }
        }
        return result
    }
}
