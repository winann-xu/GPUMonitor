// MARK: - TemperatureReader
// 温度读取：优先走 SMC（macmon/MacMonitor 提炼的只读实现），
// 若 SMC 不可用则回退 IOHID 温度传感器（同样参考 macmon sources.rs）。

import Foundation
import Darwin
import SMCBridge

final class TemperatureReader: @unchecked Sendable {
    static let shared = TemperatureReader()
    
    private let lock = NSLock()
    private var prepared = false
    private var smcReady = false
    
    private init() {}
    
    /// 启动时准备一次（枚举并缓存温度键）
    func prepare() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if prepared { return smcReady }
        prepared = true
        smcReady = smcb_prepare() == 1
        return smcReady
    }
    
    /// 返回 (CPU 温度, GPU 温度)，单位 °C；某个不可用则为 nil
    func read() -> (cpu: Double?, gpu: Double?) {
        lock.lock()
        defer { lock.unlock() }
        
        if smcb_cpu_count() > 0 || smcb_gpu_count() > 0 {
            let cpu = smcb_cpu_temp_avg()
            let gpu = smcb_gpu_temp_avg()
            return (cpu > 0 ? cpu : nil, gpu > 0 ? gpu : nil)
        }
        return Self.readHID()
    }
}

// MARK: - IOHID 回退（仿 macmon sources.rs 的 IOHIDSensors）
extension TemperatureReader {
    private typealias CreateClient = @convention(c) (CFAllocator?) -> Unmanaged<CFTypeRef>?
    private typealias SetMatching = @convention(c) (CFTypeRef?, CFDictionary?) -> Int32
    private typealias CopyServices = @convention(c) (CFTypeRef?) -> Unmanaged<CFArray>?
    private typealias CopyProperty = @convention(c) (CFTypeRef?, CFString?) -> Unmanaged<CFTypeRef>?
    private typealias CopyEvent = @convention(c) (CFTypeRef?, Int64, Int32, Int64) -> Unmanaged<CFTypeRef>?
    private typealias EventFloat = @convention(c) (CFTypeRef?, Int64) -> Double
    
    private static func readHID() -> (cpu: Double?, gpu: Double?) {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else {
            return (nil, nil)
        }
        defer { dlclose(handle) }
        
        guard let s1 = dlsym(handle, "IOHIDEventSystemClientCreate"),
              let s2 = dlsym(handle, "IOHIDEventSystemClientSetMatching"),
              let s3 = dlsym(handle, "IOHIDEventSystemClientCopyServices"),
              let s4 = dlsym(handle, "IOHIDServiceClientCopyProperty"),
              let s5 = dlsym(handle, "IOHIDServiceClientCopyEvent"),
              let s6 = dlsym(handle, "IOHIDEventGetFloatValue") else {
            return (nil, nil)
        }
        
        let create = unsafeBitCast(s1, to: CreateClient.self)
        let matching = unsafeBitCast(s2, to: SetMatching.self)
        let copyServices = unsafeBitCast(s3, to: CopyServices.self)
        let copyProperty = unsafeBitCast(s4, to: CopyProperty.self)
        let copyEvent = unsafeBitCast(s5, to: CopyEvent.self)
        let eventFloat = unsafeBitCast(s6, to: EventFloat.self)
        
        guard let client = create(kCFAllocatorDefault)?.takeRetainedValue() else {
            return (nil, nil)
        }
        let filter: [String: Int] = [
            "PrimaryUsagePage": 0xff00,
            "PrimaryUsage": 0x0005
        ]
        _ = matching(client, filter as CFDictionary)
        guard let services = copyServices(client)?.takeRetainedValue() else { return (nil, nil) }
        
        var cpuValues: [Double] = []
        var gpuValues: [Double] = []
        for index in 0..<CFArrayGetCount(services) {
            let raw = CFArrayGetValueAtIndex(services, index)
            let service: CFTypeRef = unsafeBitCast(raw, to: CFTypeRef.self)
            guard let product = copyProperty(service, "Product" as CFString)?.takeRetainedValue(),
                  let name = product as? String,
                  let event = copyEvent(service, 15, 0, 0)?.takeRetainedValue() else {
                continue
            }
            let temp = eventFloat(event, 15 << 16)
            guard temp > 0, temp < 150 else { continue }
            
            let lower = name.lowercased()
            if lower.contains("pmu tdie") || lower.contains("pacc") || lower.contains("eacc") || lower.contains("macc") {
                cpuValues.append(temp)
            } else if lower.contains("gpu") {
                gpuValues.append(temp)
            }
        }
        
        func average(_ values: [Double]) -> Double? {
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }
        return (average(cpuValues), average(gpuValues))
    }
}
