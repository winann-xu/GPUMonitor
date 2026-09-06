// MARK: - MachSystemSampler
// 内存 / Swap / CPU 负载，全部走 Darwin/Mach 公共 API
// 内存公式取自 macmon sources.rs 的 libc_ram。

import Foundation
import Darwin

enum MachSystemSampler {
    // MARK: - 内存
    static func memory() -> (used: UInt64, total: UInt64) {
        var total: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &total, &size, nil, 0)
        
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, total) }
        
        let page = UInt64(getpagesize())
        let usedRaw = (UInt64(stats.active_count) + UInt64(stats.inactive_count)
                       + UInt64(stats.wire_count) + UInt64(stats.speculative_count)
                       + UInt64(stats.compressor_page_count)
                       - UInt64(stats.purgeable_count)
                       - UInt64(stats.external_page_count)) * page
        let used = min(max(usedRaw, 0), total)
        return (used, total)
    }
    
    // MARK: - Swap
    static func swap() -> (used: UInt64, total: UInt64) {
        var xsw = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &xsw, &size, nil, 0)
        guard result == 0 else { return (0, 0) }
        return (xsw.xsu_used, xsw.xsu_total)
    }
    
    // MARK: - CPU 负载（Mach 累计 tick 差分）
    private static var previous: (used: UInt64, total: UInt64)?
    
    static func cpuLoadPercent() -> Double? {
        guard let current = ticks() else { return nil }
        guard let last = previous else {
            previous = current
            return nil
        }
        previous = current
        let used = current.used > last.used ? current.used - last.used : 0
        let total = current.total > last.total ? current.total - last.total : 0
        guard total > 0 else { return nil }
        return min(Double(used) / Double(total) * 100, 100)
    }
    
    private static func ticks() -> (used: UInt64, total: UInt64)? {
        var numCPUs: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                         &numCPUs, &info, &infoCount)
        guard result == KERN_SUCCESS, let info = info else { return nil }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: info),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size))
        }
        
        var used: UInt64 = 0
        var total: UInt64 = 0
        for i in 0..<Int(numCPUs) {
            let base = i * Int(CPU_STATE_MAX)
            let user = UInt64(info[base + Int(CPU_STATE_USER)])
            let system = UInt64(info[base + Int(CPU_STATE_SYSTEM)])
            let idle = UInt64(info[base + Int(CPU_STATE_IDLE)])
            let nice = UInt64(info[base + Int(CPU_STATE_NICE)])
            used += user + system + nice
            total += user + system + nice + idle
        }
        return (used, total)
    }
}
