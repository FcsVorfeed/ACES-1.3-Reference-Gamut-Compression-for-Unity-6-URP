#ifndef ACES_GAMUT_COMPRESS_PASS_INCLUDED
#define ACES_GAMUT_COMPRESS_PASS_INCLUDED

// ─────────────────────────────────────────────────────────────────────────────
// ACES 1.3 Reference Gamut Compression + UE 色域预修正
// ACES 1.3 Reference Gamut Compression + UE-style pre-tonemap gamut fixes.
//
// Pipeline (执行顺序 / order of operations):
//   1. sRGB(linear) → AP1
//   2. ExpandGamut    (UE)       在 AP1 域把饱和高亮推到宽色域 (单向, UE 也是)
//                                Push saturated highlights to wider gamut (one-way, like UE).
//   3. BlueCorrect    (UE)       临时把蓝色挪开避开 ACES 蓝→紫陷阱
//                                Temporarily move blues out of the ACES blue→purple trap.
//   4. RGC            (ACES 1.3) 把 [-∞,1] 之外的色彩压回 [0,1]
//                                Compress out-of-gamut neon colors back into AP1.
//   5. BlueCorrectInv (UE)       把蓝色挪回来 (与第 3 步配对, 让 BlueCorrect 在本 pass 内闭环)
//                                Restore blues (paired with step 3 so BlueCorrect is self-contained).
//   6. AP1 → sRGB(linear)        交还给 URP UberPost 做 Bloom + ACES Tonemap
//                                Hand back to URP UberPost for Bloom + ACES Tonemap.
//
// 真值矩阵 / Source matrices:
//   * UE_Wide_2_XYZ / UE_BlueCorrect / UE_BlueCorrectInv 直接来自 UE5 ACES.ush
//     Sourced verbatim from UE5 Engine/Shaders/Private/ACES.ush.
//   * RGC 阈值 / 上限 来自 ACES 1.3 官方 reference implementation
//     RGC thresholds / limits from the ACES 1.3 reference implementation.
// ─────────────────────────────────────────────────────────────────────────────

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ACES.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

// ─── Volume 参数 / Volume parameters ────────────────────────────────────────
float _AGC_ExpandGamut;
float _AGC_BlueCorrection;
float _AGC_RgcStrength;
float _AGC_RgcPower;

// ─── UE 真值矩阵 / UE original matrices ──────────────────────────────────────
// sRGB → 介于 P3 与 AP1 之间的宽色域
// sRGB → wider gamut between P3 and AP1.
static const float3x3 AGC_Wide_2_XYZ_MAT = float3x3(
     0.5441691,  0.2395926,  0.1666943,
     0.2394656,  0.7021530,  0.0583814,
    -0.0023439,  0.0361834,  1.0552183
);

// BlueCorrect 在 AP0 域定义，使用时绕道 AP1
// BlueCorrect defined in AP0, wrapped to AP1 at use site.
static const float3x3 AGC_BlueCorrect = float3x3(
    0.9404372683, -0.0183068787, 0.0778696104,
    0.0083786969,  0.8286599939, 0.1629613092,
    0.0005471261, -0.0008833746, 1.0003362486
);

static const float3x3 AGC_BlueCorrectInv = float3x3(
     1.06318,      0.0233956,  -0.0865726,
    -0.0106337,    1.20632,    -0.19569,
    -0.000590887,  0.00105248,  0.999538
);

// ─── ACES 1.3 RGC 官方默认参数 / official defaults ───────────────────────────
// 详见 https://github.com/ampas/aces-dev RGC 参考实现
// See ampas/aces-dev RGC reference implementation.
static const float3 AGC_RGC_LIMIT = float3(1.147, 1.264, 1.312); // C / M / Y
static const float3 AGC_RGC_THRES = float3(0.815, 0.803, 0.880); // C / M / Y

//────────────────────────────────────────────────────────────────────────────────────────────────────
/// <summary>
/// 获取 sRGB → AP1 的 ExpandGamut 矩阵。
/// Build the sRGB → AP1 expand-gamut matrix (Wide → AP1 → from sRGB).
/// </summary>
float3x3 GetWideMat()
{
    // 从色彩空间逻辑看，这里很可疑。输入已经是 AP1，通常应该是类似 Wide_2_AP1 * AP1_2_sRGB 这种“AP1 → sRGB 数值 → 当作 Wide RGB → AP1”的路径，而不是 Wide_2_AP1 * sRGB_2_AP1。
    // 这不一定立刻报错，但会让效果偏离你以为的 UE ExpandGamut？
    float3x3 Wide_2_AP1 = mul(XYZ_2_AP1_MAT, AGC_Wide_2_XYZ_MAT);
    return                mul(Wide_2_AP1,    sRGB_2_AP1);
}

//────────────────────────────────────────────────────────────────────────────────────────────────────
/// <summary>
/// 把饱和高亮色彩外推到宽色域，避免 ACES 把饱和色压暗变灰。
/// Expand bright saturated colors outside sRGB to fake a wider rendering gamut.
/// </summary>
float3 ExpandBrightToFakeWideGamut(float3 ColorAP1)
{
    float  LumaAP1   = dot(ColorAP1, AP1_RGB2Y);
    float3 ChromaAP1 = ColorAP1 / max(LumaAP1, 1e-5);

    float ChromaDistSqr = dot(ChromaAP1 - 1.0, ChromaAP1 - 1.0);
    float ExpandAmount  = (1.0 - exp2(-4.0 * ChromaDistSqr))
                        * (1.0 - exp2(-4.0 * _AGC_ExpandGamut * LumaAP1 * LumaAP1));

    float3 ColorExpand = mul(GetWideMat(), ColorAP1);
    return lerp(ColorAP1, ColorExpand, ExpandAmount);
}

//────────────────────────────────────────────────────────────────────────────────────────────────────
/// <summary>
/// ACES 1.3 RGC 单通道压缩函数 (parameterized power)。
/// ACES 1.3 RGC per-channel compression (parameterized power formulation).
/// 对应 ampas/aces-dev: compress() in Reference_Gamut_Compress.blink。
/// Mirrors ampas/aces-dev: compress() in Reference_Gamut_Compress.blink.
/// </summary>
float CompressChannel(float dist, float lim, float thr, float pwr)
{
    // 阈值内不动 / Below threshold: passthrough
    if (dist < thr) return dist;

    // y = 1 处穿过 limit 的归一化尺度
    // Scale factor that lands the curve on y = 1 at distance = limit.
    float scl = (lim - thr) / pow(pow((1.0 - thr) / (lim - thr), -pwr) - 1.0, 1.0 / pwr);

    float nd = (dist - thr) / scl;
    return thr + scl * nd / pow(1.0 + pow(nd, pwr), 1.0 / pwr);
}

//────────────────────────────────────────────────────────────────────────────────────────────────────
/// <summary>
/// ACES 1.3 RGC 主流程：以最大通道为消色轴，三通道分别压缩"距离消色轴的归一距离"。
/// ACES 1.3 RGC main path: take max channel as achromatic axis, compress per-channel
/// normalized distance from that axis.
/// </summary>
float3 GamutCompressAP1(float3 ColorAP1)
{
    float ach = max(ColorAP1.r, max(ColorAP1.g, ColorAP1.b));
    if (ach == 0.0) return ColorAP1;

    float absAch = abs(ach);

    // 各通道距消色轴的归一距离 (achromatic 越大该值越小)
    // Per-channel normalized distance from the achromatic axis.
    float3 dist = (ach - ColorAP1) / absAch;

    float3 cdist;
    cdist.x = CompressChannel(dist.x, AGC_RGC_LIMIT.x, AGC_RGC_THRES.x, _AGC_RgcPower);
    cdist.y = CompressChannel(dist.y, AGC_RGC_LIMIT.y, AGC_RGC_THRES.y, _AGC_RgcPower);
    cdist.z = CompressChannel(dist.z, AGC_RGC_LIMIT.z, AGC_RGC_THRES.z, _AGC_RgcPower);

    float3 compressed = ach - cdist * absAch;

    // Strength 用于在原色和压缩色之间插值，方便美术调试
    // Strength lerps between original and compressed for art tuning.
    return lerp(ColorAP1, compressed, _AGC_RgcStrength);
}

//────────────────────────────────────────────────────────────────────────────────────────────────────
/// <summary>
/// 主 fragment：执行 ExpandGamut → RGC 两步色域预修正。
/// Main fragment: ExpandGamut → RGC pre-tonemap fix-ups.
/// </summary>
half4 AcesGamutCompressFrag(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    float4 src = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord);
    float3 ColorSrgbLinear = max(src.rgb, 0.0);

    // 1. sRGB(linear) → AP1
    float3 ColorAP1 = mul(sRGB_2_AP1, ColorSrgbLinear);

    // 2. ExpandGamut (UE)
    if (_AGC_ExpandGamut > 0.0)
        ColorAP1 = ExpandBrightToFakeWideGamut(ColorAP1);

    // 3. ACES 1.3 RGC
    if (_AGC_RgcStrength > 0.0)
        ColorAP1 = GamutCompressAP1(ColorAP1);

    // 4. AP1 → sRGB(linear)
    float3 ColorOut = mul(AP1_2_sRGB, ColorAP1);
    ColorOut = max(ColorOut, 0.0);

    return half4(ColorOut, src.a);
}

#endif // ACES_GAMUT_COMPRESS_PASS_INCLUDED
