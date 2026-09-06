#ifndef SMCBridge_h
#define SMCBridge_h

// SMCBridge — 极简 Apple SMC 温度读取桥
// 仅保留 macmon/MacMonitor 项目中有用的 SMC 温度逻辑，
// 不随包携带任何第三方二进制。

/// 打开并连接 AppleSMC（首个匹配服务），成功返回 1，失败返回 0。
int smcb_connect(void);

/// 断开 AppleSMC 连接。
void smcb_disconnect(void);

/// 启动时枚举一次温度键并缓存键信息，返回 1 表示准备完成。
int smcb_prepare(void);

/// 当前缓存的 CPU 温度键数量。
int smcb_cpu_count(void);

/// 当前缓存的 GPU 温度键数量。
int smcb_gpu_count(void);

/// 读取并平均 CPU 温度（°C），无可读数返回 0。
double smcb_cpu_temp_avg(void);

/// 读取并平均 GPU 温度（°C），无可读数返回 0。
double smcb_gpu_temp_avg(void);

/// 直接读取单个 SMC 键（如 "TCMz"），失败或非温度类型返回 0。
double smcb_read(const char *key);

#endif /* SMCBridge_h */
