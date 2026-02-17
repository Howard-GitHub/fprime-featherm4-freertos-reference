# F' v4.1.1 Migration Changes & Build Fixes For fprime-freertos on STM32H723ZG (Nucleo-144)

All changes required to build fprime-freertos with F' v4.1.1 on the STM32H723ZG (Nucleo-144) target.

Changes are organized by repository. Each section describes the problem, affected file, and exact fix.

---

## Repository: `fprime-freertos` (main project)

### 1. `config/FpConfig.h` — Remove constants migrated to FPP

**Problem:** F' v4.1.1 moved ~30 constants (buffer sizes, handle sizes, serialization values) from `FpConfig.h` (C `#define`) into FPP files (`FpConstants.fpp`, `PlatformCfg.fpp`). Having definitions in both causes redefinition conflicts.

**Changes:**
- **Removed** all constants now owned by FPP: `FW_CONTEXT_DONT_CARE`, `FW_SERIALIZE_TRUE_VALUE`, `FW_SERIALIZE_FALSE_VALUE`, all `FW_*_BUFFER_MAX_SIZE`, all `FW_*_STRING_MAX_SIZE`, all `FW_*_HANDLE_MAX_SIZE`, `FW_HANDLE_ALIGNMENT`, `FW_FILE_CHUNK_SIZE`, `FW_FIXED_LENGTH_STRING_SIZE`, `FW_QUEUE_NAME_BUFFER_SIZE`, `FW_TASK_NAME_BUFFER_SIZE`, `FW_OBJ_SIMPLE_REG_*`, `FW_QUEUE_SIMPLE_QUEUE_ENTRIES`, `FW_LOG_TEXT_BUFFER_SIZE`
- **Kept** only C-header configuration switches that are still expected in a C header: `FW_OBJECT_NAMES=0`, `FW_OBJECT_REGISTRATION=0`, `FW_QUEUE_REGISTRATION`, `FW_PORT_TRACING`, `FW_PORT_SERIALIZATION`, `FW_SERIALIZATION_TYPE_ID`, `FW_ASSERT_LEVEL`, `FW_OBJ_NAME_BUFFER_SIZE`, `FW_CMD_CHECK_RESIDUAL`, `FW_ENABLE_TEXT_LOGGING`, `FW_SERIALIZABLE_TO_STRING`, `FW_AMPCS_COMPATIBLE`, `FW_USE_PRINTF_FAMILY_FUNCTIONS_IN_STRING_FORMATTING`
- Changed include order to match v4.1.1 default: `BasicTypes.h` before `PlatformTypes.h`
- Wrapped macro values in parentheses to match v4.1.1 style (e.g. `0` → `(0)`)

### 2. `config/PlatformCfg.fpp` — NEW file: OS handle size overrides

**Problem:** OS handle sizes previously lived in `FpConfig.h` but v4.1.1 expects them in `PlatformCfg.fpp`. The FreeRTOS platform needs different sizes than the defaults (e.g. smaller task handle, smaller queue handle).

**Changes:** Created this file with platform-specific overrides:
- `FW_TASK_HANDLE_MAX_SIZE = 24` (fprime default: 40)
- `FW_QUEUE_HANDLE_MAX_SIZE = 352` (fprime default: 368)
- All other handle sizes set to match fprime defaults for completeness

### 3. `config/CMakeLists.txt` — Register the new FPP config override

**Change:** Added `PlatformCfg.fpp` to the `CONFIGURATION_OVERRIDES` list so fprime's config system picks it up:
```cmake
register_fprime_config(
    fprime-featherm4-freertos-reference-config
  CONFIGURATION_OVERRIDES
    "${CMAKE_CURRENT_LIST_DIR}/CommandDispatcherImplCfg.hpp"
    "${CMAKE_CURRENT_LIST_DIR}/FpConfig.h"
    "${CMAKE_CURRENT_LIST_DIR}/TlmChanImplCfg.hpp"
    "${CMAKE_CURRENT_LIST_DIR}/PlatformCfg.fpp"          # <-- ADDED
  INTERFACE
)
```

### 4. `ReferenceDeployment/Top/ReferenceDeploymentTopology.cpp` — Fix FPP constant naming

**Problem:** v4.1.1 generates FPP constants as plain anonymous enums instead of the old namespaced form `FppConstant_<Name>::<Name>`.

**Change:**
```cpp
// OLD:
U32 rateGroup1Context[FppConstant_PassiveRateGroupOutputPorts::PassiveRateGroupOutputPorts] = {};

// NEW:
U32 rateGroup1Context[PassiveRateGroupOutputPorts] = {};
```

### 5. `ReferenceDeployment/CMakeLists.txt` — Uncomment `finalize_arduino_executable()`

**Problem:** `finalize_arduino_executable()` was commented out, so the `fprime_arduino_patcher` library was never built, causing an undefined reference linker error.

**Change:**
```cmake
# OLD:
# finalize_arduino_executable("${FPRIME_CURRENT_MODULE}")

# NEW:
finalize_arduino_executable()
```
Note: The function signature changed in the current fprime-arduino; it no longer takes an argument.

### 6. `fix.sh` — NEW file: Pre-build sketch directory setup

**Problem:** The STM32 Arduino core expects a `variant.h` header, but the Nucleo H723ZG variant uses `variant_NUCLEO_H723ZG.h`. When arduino-cli compiles the sketch during `fprime-util generate`, it can't resolve `variant.h` to the correct board-specific header. Additionally, the sketch directory needs a `build.opt` file to inject custom include paths into the arduino-cli build.

**Purpose:** Run this script **before** `fprime-util generate` whenever the build directory is clean/deleted.

**What it does:**

1. **Creates the sketch directory structure:**
   ```bash
   mkdir -p build-fprime-automatic-FeatherM4_FreeRTOS/arduino-cli-sketch/sketch
   ```

2. **Creates `build.opt`** — a file recognized by the STM32 Arduino core that adds extra compiler flags. Here it adds the sketch directory itself to the include path so that our custom `variant.h` wrapper is found:
   ```bash
   echo "-I<project_path>/build-fprime-automatic-FeatherM4_FreeRTOS/arduino-cli-sketch/sketch" \
     > build-fprime-automatic-FeatherM4_FreeRTOS/arduino-cli-sketch/sketch/build.opt
   ```

3. **Creates a `variant.h` wrapper** that redirects to the real board-specific variant header. The STM32 Arduino core's generic code includes `variant.h`, but the Nucleo H723ZG board defines its pins/peripherals in `variant_NUCLEO_H723ZG.h`. This wrapper bridges the gap:
   ```c
   #ifndef _VARIANT_ARDUINO_STM32_
   #define _VARIANT_ARDUINO_STM32_

   #ifdef VARIANT_H
   #undef VARIANT_H
   #endif

   // Force include the real variant header
   #include "variant_NUCLEO_H723ZG.h"

   #endif /* _VARIANT_ARDUINO_STM32_ */
   ```
   It also undefines the `VARIANT_H` macro (set via `-DVARIANT_H=...` in the toolchain) to prevent recursive inclusion issues.

---

## Repository: `fprime-featherm4-freertos` (submodule at `lib/fprime-featherm4-freertos/`)

### 7. `cmake/toolchain/FeatherM4_FreeRTOS.cmake` — STM32H723ZG toolchain config

**Problem (a):** Board was configured for STM32H723ZG but missing the `-DVARIANT_H` compile option needed by the STM32 Arduino core to select the correct variant header.

**Problem (b):** The FreeRTOS library wasn't registered for arduino-cli to compile. The name `"STM32duino FreeRTOS"` (with a space) generated an invalid `#include <STM32duino FreeRTOS.h>`. The correct library name matching the header `STM32FreeRTOS.h` is `"STM32FreeRTOS"`.

**Problem (c):** The FreeRTOS `xQueueGetMutexHolder` function (used by the fprime-freertos Mutex implementation) is guarded by `INCLUDE_xSemaphoreGetMutexHolder` in `queue.c`. The STM32duino FreeRTOS default config only defines this macro when `configUSE_CMSIS_RTOS_V2 == 1`, which we don't use. Without it, the symbol is not compiled, causing an undefined reference at link time.

**Changes:**
```cmake
# OLD:
set(ARDUINO_BUILD_PROPERTIES)
# ...
add_compile_options(-D_BOARD_NUCLEO_H723ZG  -DUSE_BASIC_TIMER)
# (no target_use_arduino_libraries call)

# NEW:
set(ARDUINO_BUILD_PROPERTIES
    "compiler.c.extra_flags=-DINCLUDE_xSemaphoreGetMutexHolder=1"
    "compiler.cpp.extra_flags=-DINCLUDE_xSemaphoreGetMutexHolder=1"
)
# ...
add_compile_options(
    -D_BOARD_NUCLEO_H723ZG
    -DVARIANT_H=\"variant_NUCLEO_H723ZG.h\"
    -DUSE_BASIC_TIMER
)
# ...
target_use_arduino_libraries("STM32FreeRTOS")
```

### 8. `library.cmake` — Fix include paths and enable FreeRTOS library

**Problem:** Include paths didn't have the `/src` suffix needed by STM32duino library layout, and the `target_use_arduino_libraries` call was commented out.

**Changes:**
```cmake
# OLD:
    ${ARDUINO_LIB_PATH}/STM32duino_FreeRTOS
    ${ARDUINO_STM32_LIB_PATH}/Wire
    ${ARDUINO_STM32_LIB_PATH}/SPI
# ...
#target_use_arduino_libraries("STM32FreeRTOS")

# NEW:
    ${ARDUINO_LIB_PATH}/STM32duino_FreeRTOS/src
    ${ARDUINO_STM32_LIB_PATH}/libraries/Wire/src
    ${ARDUINO_STM32_LIB_PATH}/libraries/SPI/src
# ...
target_use_arduino_libraries("STM32FreeRTOS")
```

---

## Repository: `fprime-arduino` (sub-submodule at `lib/fprime-featherm4-freertos/fprime-arduino/`)

### 9. `Arduino/Os/RawTime.hpp` — Update RawTime interface for v4.1.1

**Problem:** F' v4.1.1 changed `RawTimeInterface` virtual method signatures: renamed the buffer type from `Fw::SerializeBufferBase` to `Fw::SerialBufferBase` and added an `Fw::Endianness` parameter.

**Changes:**
```cpp
// OLD:
Fw::SerializeStatus serializeTo(Fw::SerializeBufferBase& buffer) const override;
Fw::SerializeStatus deserializeFrom(Fw::SerializeBufferBase& buffer) override;

// NEW:
Fw::SerializeStatus serializeTo(Fw::SerialBufferBase& buffer,
                                Fw::Endianness mode = Fw::Endianness::BIG) const override;
Fw::SerializeStatus deserializeFrom(Fw::SerialBufferBase& buffer,
                                    Fw::Endianness mode = Fw::Endianness::BIG) override;
```

### 10. `Arduino/Os/RawTime.cpp` — Update RawTime implementation

**Problem:** Implementation used old buffer API methods (`serialize()`/`deserialize()`) and old error enum style.

**Changes:**
```cpp
// OLD:
Fw::SerializeStatus ArduinoRawTime::serializeTo(Fw::SerializeBufferBase& buffer) const {
    status = buffer.serialize(this->m_handle.m_seconds);
    if (status == Fw::FW_SERIALIZE_OK) {
        status = buffer.serialize(this->m_handle.m_micros);
    }
    // ...
}

// NEW:
Fw::SerializeStatus ArduinoRawTime::serializeTo(Fw::SerialBufferBase& buffer, Fw::Endianness mode) const {
    Fw::SerializeStatus status = buffer.serializeFrom(this->m_handle.m_seconds, mode);
    if (status != Fw::SerializeStatus::FW_SERIALIZE_OK) {
        return status;
    }
    return buffer.serializeFrom(this->m_handle.m_micros, mode);
}
```
Same pattern applied to `deserializeFrom` — uses `buffer.deserializeTo()` with local variables, then assigns to handle fields on success.

### 11. `Arduino/config/FprimeArduino.hpp` — Fix DEPRECATED macro

**Problem:** `FprimeArduino.hpp` redefined `DEPRECATED(X,Y)` to expand to nothing (to suppress Arduino's version). In v4.1.1, fprime uses `DEPRECATED()` on inline function definitions with bodies `{ ... }`. The empty expansion deleted the function signature, leaving orphaned `{}` blocks that caused parse errors in `Serializable.hpp` and `ConstStringBase.hpp`.

**Change:**
```cpp
// OLD:
#define DEPRECATED(X,Y)

// NEW:
#define DEPRECATED(func, message) func __attribute__((deprecated(message)))
```

### 12. `cmake/toolchain/support/arduino-support.cmake` — Fix linker flag quoting for parenthesized paths

**Problem:** The STM32H723ZG variant directory path contains parentheses: `STM32H7xx/H723Z(E-G)T_H730ZBT_H733ZGT`. When this path appears in linker flags (e.g. `--default-script=...`), the unquoted parentheses cause shell syntax errors during linking.

**Change:** Added a regex after the linker flags are assembled (after line 72 in `set_arduino_build_settings`) to quote any flag token containing parentheses:
```cmake
# Quote any linker flag paths containing parentheses to avoid shell syntax errors
string(REGEX REPLACE "([^ ]*[(][^ ]*)" "\"\\1\"" CMAKE_EXE_LINKER_FLAGS_INIT "${CMAKE_EXE_LINKER_FLAGS_INIT}")
```

---

## Repository: `arduino-cli-cmake-wrapper` (CubeSTEP fork)

### 13. Updated `arduino-cli-cmake-wrapper` to 0.2.0a1 with build argument fixes

**Problem:** The PyPI release of `arduino-cli-cmake-wrapper` (0.1.0) is outdated and does not match the GitHub source (0.2.0a1). The 0.1.0 version does not correctly pass build arguments through to `arduino-cli`, which prevents proper compilation for custom boards like the STM32H723ZG.

**Change:** Forked `SterlingPeet/arduino-cli-cmake-wrapper` to `CubeSTEP/arduino-cli-cmake-wrapper` and replaced the source with the 0.2.0a1 codebase that includes:
- Proper build argument passthrough to `arduino-cli compile`
- Updated module structure (`builder.py`, `miner.py`, `parser.py`, `types.py`, `util.py` replacing old `parse.py`, `sketch.py`)
- Correct handling of `ARDUINO_BUILD_PROPERTIES` for injecting compiler flags (e.g. `-DINCLUDE_xSemaphoreGetMutexHolder=1`)

**Installation:** The `requirements.txt` in `fprime-arduino` and the project setup docs now point to the CubeSTEP fork:
```sh
pip install git+https://github.com/CubeSTEP/arduino-cli-cmake-wrapper.git@main
```

---

## Summary of Build Errors Resolved

| # | Error | Root Cause | Fix |
|---|-------|-----------|-----|
| 1 | Redefinition of FPP constants | `FpConfig.h` still had constants migrated to FPP in v4.1.1 | Removed from header, created `PlatformCfg.fpp` |
| 2 | `serializeTo`/`deserializeFrom` signature mismatch | v4.1.1 changed `RawTimeInterface` API | Updated signatures and buffer method calls |
| 3 | Parse errors in `Serializable.hpp` / `ConstStringBase.hpp` | `DEPRECATED` macro expanded to nothing, orphaning function bodies | Redefined with proper `__attribute__` |
| 4 | `FppConstant_PassiveRateGroupOutputPorts` not found | v4.1.1 uses plain enum constants, not namespaced | Changed to `PassiveRateGroupOutputPorts` |
| 5 | Undefined reference to `fprime_arduino_patcher` | `finalize_arduino_executable()` was commented out | Uncommented it |
| 6 | Shell syntax error from parenthesized linker paths | Variant path `H723Z(E-G)T_...` unquoted in linker flags | Added regex quoting in `arduino-support.cmake` |
| 7 | `STM32duino FreeRTOS.h: No such file` | Library name had space, generating invalid `#include` | Changed to `"STM32FreeRTOS"` |
| 8 | Undefined reference to `xQueueGetMutexHolder` | `INCLUDE_xSemaphoreGetMutexHolder` only set under CMSIS-RTOS | Added via `ARDUINO_BUILD_PROPERTIES` compiler flags |
