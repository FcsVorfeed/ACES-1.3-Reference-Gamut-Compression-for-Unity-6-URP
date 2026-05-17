using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

namespace AcesGamutCompress
{
    //────────────────────────────────────────────────────────────────────────────────────────────────────
    /// <summary>
    /// ACES 1.3 RGC + UE 色域预修正 RendererFeature（URP 17 / RenderGraph）。
    /// ACES 1.3 RGC + UE-style gamut fix renderer feature for URP 17 (RenderGraph).
    /// </summary>
    [DisallowMultipleRendererFeature("ACES Gamut Compress")]
    public class AcesGamutCompressRendererFeature : ScriptableRendererFeature
    {
        // ─── 可序列化字段 / serialized fields ────────────────────────────────────
        [SerializeField] Shader _Shader;

        // ─── 运行时字段 / runtime fields ─────────────────────────────────────────
        Material _Material;
        AcesGamutCompressPass _Pass;

        const string K_ShaderPath = "Hidden/AcesGamutCompress/Compress";

        //────────────────────────────────────────────────────────────────────────────────────────────────────
        /// <summary>
        /// 创建 Feature。/ Initialize the feature.
        /// </summary>
        public override void Create()
        {
            if (_Shader == null) _Shader = Shader.Find(K_ShaderPath);
            if (_Shader == null)
            {
                Debug.LogError($"[AcesGamutCompress] Shader '{K_ShaderPath}' not found.");
                return;
            }

            if (_Material == null) _Material = CoreUtils.CreateEngineMaterial(_Shader);

            _Pass = new AcesGamutCompressPass(_Material)
            {
                renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing,
            };
        }

        //────────────────────────────────────────────────────────────────────────────────────────────────────
        /// <summary>
        /// 加入渲染队列 / Enqueue the pass when applicable.
        /// </summary>
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            var camType = renderingData.cameraData.cameraType;
            if (camType == CameraType.Preview || camType == CameraType.Reflection) return;
            if (!renderingData.cameraData.postProcessEnabled) return;
            if (_Material == null || _Pass == null) return;

            var stack = VolumeManager.instance.stack;
            var vol = stack?.GetComponent<AcesGamutCompressVolume>();
            if (vol == null || !vol.IsActive()) return;

            _Pass.Setup(vol);
            renderer.EnqueuePass(_Pass);
        }

        //────────────────────────────────────────────────────────────────────────────────────────────────────
        /// <summary>
        /// 释放材质 / Dispose runtime material.
        /// </summary>
        protected override void Dispose(bool disposing)
        {
            CoreUtils.Destroy(_Material);
            _Material = null;
            _Pass = null;
        }
    }

    //────────────────────────────────────────────────────────────────────────────────────────────────────
    /// <summary>
    /// 实际执行色域压缩的 RenderPass。
    /// The actual render pass performing the gamut-compress blit.
    /// </summary>
    sealed class AcesGamutCompressPass : ScriptableRenderPass
    {
        readonly Material _Material;
        AcesGamutCompressVolume _Volume;

        // shader property ids（缓存避免每帧字符串哈希）
        // shader property ids (cached, avoid per-frame string hashing)
        static readonly int ID_ExpandGamut = Shader.PropertyToID("_AGC_ExpandGamut");
        static readonly int ID_RgcStrength = Shader.PropertyToID("_AGC_RgcStrength");
        static readonly int ID_RgcPower = Shader.PropertyToID("_AGC_RgcPower");

        public AcesGamutCompressPass(Material mat)
        {
            _Material = mat;
            requiresIntermediateTexture = true;
        }

        //────────────────────────────────────────────────────────────────────────────────────────────────────
        /// <summary>
        /// 把 Volume 参数写入 Material。
        /// Push volume parameters into the material.
        /// </summary>
        public void Setup(AcesGamutCompressVolume v)
        {
            _Volume = v;

            _Material.SetFloat(ID_ExpandGamut, v.ExpandGamut.value);
            _Material.SetFloat(ID_RgcStrength, v.GamutCompressStrength.value);
            _Material.SetFloat(ID_RgcPower, v.GamutCompressPower.value);
        }

        //────────────────────────────────────────────────────────────────────────────────────────────────────
        /// <summary>
        /// RenderGraph 主入口 / RenderGraph main entry.
        /// </summary>
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            if (_Material == null || _Volume == null) return;

            var resourceData = frameData.Get<UniversalResourceData>();
            if (resourceData.isActiveTargetBackBuffer) return;

            var src = resourceData.activeColorTexture;
            if (!src.IsValid()) return;

            var desc = renderGraph.GetTextureDesc(src);
            desc.name = "_AcesGamutCompressTarget";
            desc.clearBuffer = false;
            desc.depthBufferBits = 0;

            TextureHandle dst = renderGraph.CreateTexture(desc);

            var blitParams = new RenderGraphUtils.BlitMaterialParameters(src, dst, _Material, 0);
            renderGraph.AddBlitPass(blitParams, "ACES Gamut Compress");

            // 把摄像机色彩切到新的目标，让后续 pass 使用我们的输出
            // Swap camera color so subsequent passes consume our output.
            resourceData.cameraColor = dst;
        }
    }
}
