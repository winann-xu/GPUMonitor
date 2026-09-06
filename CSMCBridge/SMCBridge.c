// SMCBridge.c — 从 macmon(0.8.2)/MacMonitor(MIT) 提炼的 SMC 只读实现
// 原工程：https://github.com/vladkens/macmon
//          https://github.com/ryyansafar/MacMonitor

#include "SMCBridge.h"

#include <IOKit/IOKitLib.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define KERNEL_INDEX_SMC 2
#define SMC_CMD_READ_BYTES 5
#define SMC_CMD_READ_INDEX 8
#define SMC_CMD_READ_KEYINFO 9

#define TYPE_FLT 1718383648u  /* "flt " */
#define TYPE_SP78 1936734008u /* "sp78" */

typedef struct {
  uint32_t key;
  uint32_t size;
  uint32_t type;
} SMCKeyEntry;

static io_connect_t g_conn = 0;
static int g_prepared = 0;
static SMCKeyEntry g_cpu[512];
static int g_cpu_count = 0;
static SMCKeyEntry g_gpu[512];
static int g_gpu_count = 0;

// MARK: - 底层 struct 与调用（与公开 SMC 实现一致）

typedef struct {
  char major;
  char minor;
  char build;
  char reserved[1];
  unsigned short release;
} SMCKeyData_vers_t;

typedef struct {
  unsigned short version;
  unsigned short length;
  unsigned int cpuPLimit;
  unsigned int gpuPLimit;
  unsigned int memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
  unsigned int dataSize;
  unsigned int dataType;
  char dataAttributes;
} SMCKeyData_keyInfo_t;

typedef unsigned char SMCBytes_t[32];

typedef struct {
  unsigned int key;
  SMCKeyData_vers_t vers;
  SMCKeyData_pLimitData_t pLimitData;
  SMCKeyData_keyInfo_t keyInfo;
  char result;
  char status;
  char data8;
  unsigned int data32;
  SMCBytes_t bytes;
} SMCKeyData_t;

static kern_return_t smc_call(SMCKeyData_t *input, SMCKeyData_t *output) {
  size_t inSize = sizeof(SMCKeyData_t);
  size_t outSize = sizeof(SMCKeyData_t);
  return IOConnectCallStructMethod(g_conn, KERNEL_INDEX_SMC, input, inSize,
                                   output, &outSize);
}

static unsigned int encode_key(const char *key) {
  return ((unsigned char)key[0] << 24) | ((unsigned char)key[1] << 16) |
         ((unsigned char)key[2] << 8) | (unsigned char)key[3];
}

static void decode_key(unsigned int key, char out[5]) {
  out[0] = (char)((key >> 24) & 0xFF);
  out[1] = (char)((key >> 16) & 0xFF);
  out[2] = (char)((key >> 8) & 0xFF);
  out[3] = (char)(key & 0xFF);
  out[4] = '\0';
}

// 读取 keyInfo 并缓存
static int read_key_info(const char *key, SMCKeyData_keyInfo_t *out) {
  SMCKeyData_t in;
  SMCKeyData_t outData;
  memset(&in, 0, sizeof(in));
  memset(&outData, 0, sizeof(outData));
  in.key = encode_key(key);
  in.data8 = SMC_CMD_READ_KEYINFO;
  if (smc_call(&in, &outData) != KERN_SUCCESS) return 0;
  *out = outData.keyInfo;
  return 1;
}

// 直接读取 key 原始字节
static int read_key(const char *key, SMCKeyData_keyInfo_t info,
                    unsigned char bytes[32]) {
  SMCKeyData_t in;
  SMCKeyData_t outData;
  memset(&in, 0, sizeof(in));
  memset(&outData, 0, sizeof(outData));
  memset(bytes, 0, 32);

  in.key = encode_key(key);
  in.data8 = SMC_CMD_READ_BYTES;
  in.keyInfo.dataSize = info.dataSize;
  in.keyInfo.dataType = info.dataType;
  if (smc_call(&in, &outData) != KERN_SUCCESS) return 0;
  memcpy(bytes, outData.bytes, 32);
  return 1;
}

static double value_to_double(uint32_t type, const unsigned char bytes[32]) {
  if (type == TYPE_FLT) {
    float f;
    memcpy(&f, bytes, sizeof(f));
    return (double)f;
  }
  if (type == TYPE_SP78) {
    int16_t raw =
        (int16_t)(((unsigned short)bytes[0] << 8) | (unsigned short)bytes[1]);
    return (double)raw / 256.0;
  }
  return 0.0;
}

// MARK: - 公开接口

int smcb_connect(void) {
  if (g_conn != 0) return 1;
  io_iterator_t iterator = 0;
  io_object_t device = 0;
  kern_return_t kr;

  CFMutableDictionaryRef match = IOServiceMatching("AppleSMC");
  if (!match) return 0;
  kr = IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator);
  if (kr != KERN_SUCCESS) return 0;
  device = IOIteratorNext(iterator);
  IOObjectRelease(iterator);
  if (device == 0) return 0;

  kr = IOServiceOpen(device, mach_task_self(), 0, &g_conn);
  IOObjectRelease(device);
  return (kr == KERN_SUCCESS && g_conn != 0) ? 1 : 0;
}

void smcb_disconnect(void) {
  if (g_conn != 0) {
    IOServiceClose(g_conn);
    g_conn = 0;
  }
  g_prepared = 0;
  g_cpu_count = 0;
  g_gpu_count = 0;
}

int smcb_prepare(void) {
  if (g_prepared) return 1;
  if (!smcb_connect()) return 0;

  SMCKeyData_keyInfo_t keyInfo;
  unsigned char bytes[32];
  g_cpu_count = 0;
  g_gpu_count = 0;

  // #KEY -> 键总数
  if (!read_key_info("#KEY", &keyInfo)) return 0;
  if (!read_key("#KEY", keyInfo, bytes)) return 0;
  unsigned int total = ((unsigned int)bytes[0] << 24) |
                       ((unsigned int)bytes[1] << 16) |
                       ((unsigned int)bytes[2] << 8) | (unsigned int)bytes[3];
  if (total == 0 || total > 10000) return 0;

  for (unsigned int i = 0; i < total; i++) {
    SMCKeyData_t in;
    SMCKeyData_t outData;
    memset(&in, 0, sizeof(in));
    memset(&outData, 0, sizeof(outData));
    in.data8 = SMC_CMD_READ_INDEX;
    in.data32 = i;
    if (smc_call(&in, &outData) != KERN_SUCCESS) continue;

    char name[5];
    decode_key(outData.key, name);
    if (name[0] != 'T') continue;

    char kind = name[1];
    int isCpu = (kind == 'p' || kind == 'e');
    int isGpu = (kind == 'g' || (kind == 'R' && name[2] == 'D'));
    if (!isCpu && !isGpu) continue;

    if (!read_key_info(name, &keyInfo)) continue;
    if (keyInfo.dataType != TYPE_FLT && keyInfo.dataType != TYPE_SP78) continue;

    SMCKeyEntry entry;
    entry.key = encode_key(name);
    entry.size = keyInfo.dataSize;
    entry.type = keyInfo.dataType;
    if (isCpu && g_cpu_count < 512) g_cpu[g_cpu_count++] = entry;
    if (isGpu && g_gpu_count < 512) g_gpu[g_gpu_count++] = entry;
  }

  g_prepared = 1;
  return 1;
}

int smcb_cpu_count(void) { return g_cpu_count; }

int smcb_gpu_count(void) { return g_gpu_count; }

static double avg_entries(const SMCKeyEntry *entries, int count) {
  if (!g_conn || count <= 0) return 0.0;
  double sum = 0.0;
  int valid = 0;
  for (int i = 0; i < count; i++) {
    SMCKeyData_t in;
    SMCKeyData_t outData;
    memset(&in, 0, sizeof(in));
    memset(&outData, 0, sizeof(outData));
    char name[5];
    decode_key(entries[i].key, name);
    in.key = entries[i].key;
    in.data8 = SMC_CMD_READ_BYTES;
    in.keyInfo.dataSize = entries[i].size;
    in.keyInfo.dataType = entries[i].type;
    if (smc_call(&in, &outData) != KERN_SUCCESS) continue;

    double v = value_to_double(entries[i].type, outData.bytes);
    if (v > 0.0 && v < 150.0) {
      sum += v;
      valid++;
    }
  }
  return valid > 0 ? sum / (double)valid : 0.0;
}

double smcb_cpu_temp_avg(void) { return avg_entries(g_cpu, g_cpu_count); }

double smcb_gpu_temp_avg(void) { return avg_entries(g_gpu, g_gpu_count); }

double smcb_read(const char *key) {
  if (!smcb_connect()) return 0.0;
  SMCKeyData_keyInfo_t info;
  unsigned char bytes[32];
  if (!read_key_info(key, &info)) return 0.0;
  if (!read_key(key, info, bytes)) return 0.0;
  double v = value_to_double(info.dataType, bytes);
  return (v > 0.0 && v < 150.0) ? v : 0.0;
}
