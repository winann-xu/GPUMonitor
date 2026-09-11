// MARK: - TokenSpeedCollector
// llama.cpp token 速率采集：轮询 /slots，用 next_token.n_decoded 差分计算实时 t/s。
// 不修改 llama-server，也不经过代理；只在本地回环上做轻量 HTTP GET。
//
// 修复说明（2026-09-06）：
// 1. 端点超时/失败时保留最后有效速率，不再清零 baselines → 防止"频繁消失"
// 2. 平滑系数调整为 dt/0.8（原 dt/1.5），稀疏采样时响应更快
// 3. 生成结束检测放宽至 4 秒（原 6 秒），避免短暂间隙误判

import Foundation

@MainActor
final class TokenSpeedCollector {
    static let shared = TokenSpeedCollector()

    private struct SlotBaseline {
        let date: Date
        let decoded: Int
    }

    private struct SlotDTO: Decodable {
        let id: Int
        let isProcessing: Bool
        let nextToken: [NextTokenDTO]?

        enum CodingKeys: String, CodingKey {
            case id
            case isProcessing = "is_processing"
            case nextToken = "next_token"
        }
    }

    private struct NextTokenDTO: Decodable {
        let nDecoded: Int?

        enum CodingKeys: String, CodingKey {
            case nDecoded = "n_decoded"
        }
    }

    private var slotsURL: URL {
        let port = max(SettingsStore.shared.llamaPort, 0)
        let base = port > 0 ? "http://127.0.0.1:\(port)" : "http://127.0.0.1:18080"
        return URL(string: "\(base)/slots")!
    }
    private let session = URLSession(configuration: .ephemeral)

    private var baselines: [Int: SlotBaseline] = [:]
    private var smoothedRate: Double = 0
    private var hasSmoothedSample = false
    private var lastActiveDate: Date?

    // 记录端点连续失败次数，超过阈值才彻底重置
    private var consecutiveFailures = 0
    // 最后一次有效速率（端点失败时作为兜底）
    private var lastKnownRate: Double = 0

    private init() {}

    /// 读取当前各 slot 解码进度并更新 MetricData 中的实时 token 速率。
    func refresh(_ metric: MetricData) async {
        guard let slots = await fetchSlots() else {
            // 端点不可用（超时/网络错误/非 200）：保留最后有效速率，
            // 不重置 baselines 和 smoothedRate，避免"频繁消失"。
            consecutiveFailures += 1
            // 连续失败超过 30 次（约 30 秒），才认为服务已离线
            if consecutiveFailures > 30 {
                metric.isLlamaGenerating = false
                metric.tokenSpeed = 0
                baselines.removeAll()
                smoothedRate = 0
                hasSmoothedSample = false
                lastActiveDate = nil
                lastKnownRate = 0
                consecutiveFailures = 0
                #if DEBUG
                print("[TokenSpeed] slots endpoint down >30s, fully reset")
                #endif
            }
            // 未超阈值：保持上次刷新值不变
            return
        }

        // 成功获取数据，重置失败计数器
        if consecutiveFailures > 0 {
            #if DEBUG
            print("[TokenSpeed] slots recovered after \(consecutiveFailures) failures")
            #endif
            consecutiveFailures = 0
        }

        let now = Date()
        var activeCount = 0

        for slot in slots where slot.isProcessing {
            guard let decoded = slot.nextToken?.first?.nDecoded, decoded >= 0 else {
                // next_token 为空或 n_decoded 无效
                if let prev = baselines[slot.id] {
                    #if DEBUG
                    print("[TokenSpeed] slot \(slot.id): next_token nil/invalid (prev decoded \(prev.decoded)), keeping baseline")
                    #endif
                }
                continue
            }
            activeCount += 1

            if let previous = baselines[slot.id], previous.decoded <= decoded {
                let dt = now.timeIntervalSince(previous.date)
                if dt >= 0.15, dt <= 10 {
                    let instant = Double(decoded - previous.decoded) / dt
                    updateSmoothedRate(instant, dt: dt)
                    #if DEBUG
                    print("[TokenSpeed] slot \(slot.id): decoded \(previous.decoded)->\(decoded), dt=\(String(format:"%.2f",dt)), instant=\(String(format:"%.1f",instant)), smoothed=\(String(format:"%.1f",smoothedRate))")
                    #endif
                } else {
                    #if DEBUG
                    print("[TokenSpeed] slot \(slot.id): delta skipped dt=\(String(format:"%.2f",dt))")
                    #endif
                }
            } else if let previous = baselines[slot.id] {
                // decoded 比之前小（slot 被重置/重启），保留旧 smoothedRate
                #if DEBUG
                print("[TokenSpeed] slot \(slot.id): decoded decreased \(previous.decoded)->\(decoded), keeping smoothed=\(String(format:"%.1f",smoothedRate))")
                #endif
            }
            baselines[slot.id] = SlotBaseline(date: now, decoded: decoded)
        }

        if activeCount == 0 {
            // 没有活跃 slot：不立刻清 baselines，等 4 秒后再确认
            if let lastActive = lastActiveDate, now.timeIntervalSince(lastActive) > 4 {
                smoothedRate = 0
                hasSmoothedSample = false
                lastKnownRate = 0
                #if DEBUG
                print("[TokenSpeed] no active slots >4s, rate cleared")
                #endif
            }
        } else {
            lastActiveDate = now
        }

        metric.isLlamaGenerating = activeCount > 0
        // 有有效采样用平滑值，否则用最后已知速率（兜底）
        metric.tokenSpeed = hasSmoothedSample ? smoothedRate : lastKnownRate
    }

    private func fetchSlots() async -> [SlotDTO]? {
        var request = URLRequest(url: slotsURL, timeoutInterval: 1)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                #if DEBUG
                if let http = response as? HTTPURLResponse {
                    print("[TokenSpeed] slots HTTP \(http.statusCode)")
                }
                #endif
                return nil
            }
            return try? JSONDecoder().decode([SlotDTO].self, from: data)
        } catch {
            return nil
        }
    }

    /// 指数滑动平均，采样间隔越小跟随越快（原 dt/1.5 改为 dt/0.8）。
    private func updateSmoothedRate(_ instant: Double, dt: TimeInterval) {
        guard instant > 0 else { return }

        // 更新最后已知速率（用于端点失败时兜底）
        lastKnownRate = hasSmoothedSample ? smoothedRate : instant

        let alpha = hasSmoothedSample ? min(0.8, dt / 0.8) : 1.0
        if hasSmoothedSample {
            smoothedRate = smoothedRate * (1 - alpha) + instant * alpha
        } else {
            smoothedRate = instant
        }
        hasSmoothedSample = true
    }
}
