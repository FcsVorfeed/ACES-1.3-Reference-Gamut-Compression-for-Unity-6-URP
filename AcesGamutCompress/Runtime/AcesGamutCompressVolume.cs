using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace AcesGamutCompress
{
    //────────────────────────────────────────────────────────────────────────────────────────────────────
    /// <summary>
    /// ACES 1.3 Reference Gamut Compression + UE 色域预修正 Volume 参数。
    /// ACES 1.3 Reference Gamut Compression + UE-style pre-tonemap gamut fixes.
    ///
    /// 工作原理 / Pipeline:
    ///   HDR sRGB(linear)
    ///     → sRGB → AP1
    ///     → ExpandGamut (UE)               把饱和高亮推到宽色域，防止过早裁剪
    ///                                       Push saturated highlights to wider gamut.
    ///     → BlueCorrect (UE)               修正 ACES 蓝变紫
    ///                                       Fix the ACES blue→purple shift.
    ///     → ACES 1.3 RGC                   把溢出色域的霓虹色压回 AP1 内
    ///                                       Compress out-of-gamut neon colors back into AP1.
    ///     → AP1 → sRGB(linear)
    ///   交还给 URP UberPost 做 Bloom + ACES Tonemap。
    ///   Hand back to URP UberPost for Bloom + ACES Tonemap.
    ///
    /// 使用须知 / Usage:
    ///   1. 把 AcesGamutCompressRendererFeature 添加到 URP Renderer。
    ///      Add AcesGamutCompressRendererFeature to your URP Renderer.
    ///   2. URP Volume 中 Tonemapping 模式建议设为 ACES（本插件不替代 tonemap）。
    ///      Set Tonemapping mode to ACES in your URP Volume; this plugin does NOT replace tonemap.
    ///   3. 注入点为 BeforeRenderingPostProcessing，因此本修正在 Bloom 之前。
    ///      Injection point is BeforeRenderingPostProcessing, so it runs before Bloom.
    /// </summary>
    [Serializable, VolumeComponentMenu("Post-processing/ACES Gamut Compress")]
    [SupportedOnRenderPipeline(typeof(UnityEngine.Rendering.Universal.UniversalRenderPipelineAsset))]
    public class AcesGamutCompressVolume : VolumeComponent, IPostProcessComponent
    {
        // ─── 总开关 / master toggle (默认开启 / default ON) ──────────────────────
        public BoolParameter Enabled = new BoolParameter(true);

        // ─── UE 色域扩展 / UE expand gamut (UE 默认 1.0) ─────────────────────────
        public ClampedFloatParameter ExpandGamut = new ClampedFloatParameter(1f, 0f, 1f);

        // ─── ACES 1.3 RGC 强度 / RGC strength (0=关, 1=官方默认) ─────────────────
        public ClampedFloatParameter GamutCompressStrength = new ClampedFloatParameter(1f, 0f, 1f);

        // ─── ACES 1.3 RGC Power (官方默认 1.2，越大越软) ─────────────────────────
        public ClampedFloatParameter GamutCompressPower = new ClampedFloatParameter(1.2f, 1f, 3f);

        //────────────────────────────────────────────────────────────────────────────────────────────────────
        /// <summary>
        /// 是否启用本后处理（被 URP Volume 系统调用）。
        /// Whether this effect is active (queried by URP volume system).
        /// </summary>
        public bool IsActive() => Enabled.value;

        //────────────────────────────────────────────────────────────────────────────────────────────────────
        /// <summary>
        /// 旧 IPostProcessComponent 兼容。
        /// Legacy IPostProcessComponent compatibility.
        /// </summary>
        public bool IsTileCompatible() => true;
    }
}
