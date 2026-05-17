![Samples](https://raw.githubusercontent.com/FcsVorfeed/ACES-1.3-Reference-Gamut-Compression-for-Unity-6-URP/refs/heads/main/Samples.png)
# ACES Gamut Compress for Unity URP

A small pre-tonemap gamut cleanup pass for Unity URP.

It combines a wide-gamut pre-expansion step with **ACES 1.3 Reference Gamut Compression** so Unity's built-in ACES tonemapper receives cleaner HDR color input.

This effect does **not** replace Unity's tonemapper. It runs before URP post-processing and is intended to be used together with `Tonemapping = ACES` in a URP Volume.

## Compatibility

| Item | Status |
| --- | --- |
| Render Pipeline | URP only |
| Tested Unity Version | Unity `6000.4.7f1` |
| Tested URP Version | URP `17.4.0` |
| RenderGraph | Required |
| Built-in Render Pipeline | Not supported |
| HDRP | Not supported |
| URP Compatibility Mode | Not supported / not tested |
| GLES | Not supported |
| WebGL | Not tested |

This package is currently aimed at Unity 6 / URP 17 projects using the RenderGraph renderer path.

## Installation

Copy or clone this folder into your Unity project, for example:

```text
Assets/Plugins/AcesGamutCompress
```

Then let Unity recompile the project.

## Setup

1. Open your URP Renderer Data asset.
2. Add `AcesGamutCompressRendererFeature` to the renderer feature list.
3. Enable post-processing on your Camera.
4. Add `ACES Gamut Compress` to a URP Volume.
5. In the same Volume, set Unity's built-in `Tonemapping` override to `ACES`.

Default values are intended to be usable out of the box. Tune the parameters only if your project needs a different artistic response.

## Parameters

| Parameter | Description |
| --- | --- |
| `Enabled` | Master toggle for the effect. |
| `Expand Gamut` | Controls the wide-gamut pre-expansion amount. `0` disables this part. |
| `Gamut Compress Strength` | Blends between the original color and the ACES 1.3 compressed result. `1` uses the reference-style result. |
| `Gamut Compress Power` | Controls the softness of the compression curve. The default is `1.2`. |

## What It Helps With

- Highly saturated HDR colors, such as red, blue, green, or purple neon lights, becoming gray, clipped, or unstable after ACES tonemapping.
- Saturated highlights losing channel balance before Unity's ACES tonemapper receives them.
- Negative or out-of-gamut AP1 values produced by extreme saturated HDR input.

## What It Does Not Fix

- ACES 1.x path-to-white behavior, where very bright highlights eventually become white.
- A complete Unreal-style tonemapper look.
- The ACES blue-to-purple highlight issue as a full tonemapper-level correction.
- Incorrect lighting, exposure, color grading, LUTs, texture import settings, or project color-space setup.
- Ordering issues caused by other custom renderer features or third-party post-processing assets.

## Technical Notes

The pass is injected at:

```text
BeforeRenderingPostProcessing
```

That means it runs before URP Bloom and before Unity's built-in post-processing stack performs ACES tonemapping.

The simplified pipeline is:

```text
HDR sRGB linear camera color
    -> AP1 / ACEScg working space
    -> wide-gamut pre-expansion
    -> ACES 1.3 Reference Gamut Compression
    -> sRGB linear camera color
    -> URP built-in post-processing and ACES tonemapping
```

URP does not expose a stable public hook inside `UberPost`, so this package intentionally stays as a pre-tonemap renderer feature instead of modifying URP internals.

## Known Limitations

- Requires an intermediate color texture and performs a fullscreen blit.
- Camera stacking has not been fully validated.
- Mobile, XR, WebGL, and non-PC platforms need project-specific testing.
- Compatibility with every third-party renderer feature cannot be guaranteed.
- Future URP versions may change RenderGraph APIs, so Unity major-version upgrades may require maintenance.

## Credits

- ACES 1.3 Reference Gamut Compression is based on the public ACES reference implementation and published ACES color science material.
- Unity URP/Core shader libraries are used for ACES color-space conversion helpers and RenderGraph blit infrastructure.

---

# 中文说明

ACES Gamut Compress 是一个给 Unity URP 使用的 pre-tonemap 色域修正 Pass。

它会在 Unity 内置 ACES Tonemapping 之前，对 HDR 高饱和颜色做一次宽色域预扩展和 **ACES 1.3 Reference Gamut Compression**，让 URP 自带 ACES Tonemapper 接收到更干净的颜色输入。

这个效果**不替代** Unity 的 Tonemapping。推荐和 URP Volume 里的 `Tonemapping = ACES` 一起使用。

## 兼容性

| 项目 | 状态 |
| --- | --- |
| 渲染管线 | 仅支持 URP |
| 已测试 Unity 版本 | Unity `6000.4.7f1` |
| 已测试 URP 版本 | URP `17.4.0` |
| RenderGraph | 必须启用 |
| Built-in Render Pipeline | 不支持 |
| HDRP | 不支持 |
| URP Compatibility Mode | 不支持 / 未测试 |
| GLES | 不支持 |
| WebGL | 未测试 |

当前版本主要面向 Unity 6 / URP 17 / RenderGraph 项目。

## 安装

把整个文件夹复制或克隆到 Unity 项目中，例如：

```text
Assets/Plugins/AcesGamutCompress
```

然后等待 Unity 重新编译。

## 使用

1. 打开 URP Renderer Data 资源。
2. 在 Renderer Feature 列表里添加 `AcesGamutCompressRendererFeature`。
3. 确认 Camera 开启了 Post Processing。
4. 在 URP Volume 中添加 `ACES Gamut Compress`。
5. 在同一个 Volume 中，把 Unity 内置 `Tonemapping` 设置为 `ACES`。

默认参数可以直接使用。只有当项目需要不同的美术响应时，再调整参数。

## 参数

| 参数 | 说明 |
| --- | --- |
| `Enabled` | 总开关。 |
| `Expand Gamut` | 控制宽色域预扩展强度，`0` 表示关闭这一部分。 |
| `Gamut Compress Strength` | 在原始颜色和 ACES 1.3 压缩结果之间插值，`1` 表示使用接近参考实现的结果。 |
| `Gamut Compress Power` | 控制压缩曲线的柔和程度，默认值为 `1.2`。 |

## 它适合解决的问题

- 高饱和 HDR 颜色经过 ACES 后变灰、裁剪或出现不稳定色块。
- 红、蓝、绿、紫等霓虹色或激光颜色在高亮区域失去通道比例。
- 极端 HDR 输入导致 AP1 工作空间中出现负值或色域外颜色。

## 它不解决的问题

- ACES 1.x 高亮最终走向白色的 path-to-white 特性。
- 完整的 Unreal 风格 Tonemapper 外观。
- Tonemapper 内部级别的 ACES 蓝色高亮变紫修正。
- 光照、曝光、Color Grading、LUT、贴图导入设置或项目色彩空间设置错误。
- 其他自定义 Renderer Feature 或第三方后处理导致的执行顺序问题。

## 技术说明

Pass 注入点为：

```text
BeforeRenderingPostProcessing
```

因此它会在 URP Bloom 和 Unity 内置 ACES Tonemapping 之前执行。

简化流程如下：

```text
HDR sRGB linear camera color
    -> AP1 / ACEScg working space
    -> wide-gamut pre-expansion
    -> ACES 1.3 Reference Gamut Compression
    -> sRGB linear camera color
    -> URP built-in post-processing and ACES tonemapping
```

URP 没有提供稳定的公开接口插入 `UberPost` 内部，所以这个插件刻意保持为 pre-tonemap Renderer Feature，不修改 URP 源码。

## 已知限制

- 需要中间颜色纹理，并会执行一次全屏 blit。
- Camera Stacking 尚未完整验证。
- 移动端、XR、WebGL 和非 PC 平台需要按项目单独测试。
- 不保证兼容所有第三方 Renderer Feature。
- 未来 URP 版本可能修改 RenderGraph API，大版本升级时可能需要维护。

## 致谢

- ACES 1.3 Reference Gamut Compression 基于公开的 ACES 参考实现和 ACES 色彩科学资料。
- 本插件使用 Unity URP/Core shader library 中的 ACES 色彩空间转换辅助函数和 RenderGraph blit 基础设施。
