Shader "Hidden/AcesGamutCompress/Compress"
{
    // ─────────────────────────────────────────────────────────────────────────
    // ACES 1.3 RGC + UE 色域预修正 Blit Shader
    // ACES 1.3 RGC + UE-style pre-tonemap gamut fix blit shader (URP RenderGraph).
    // ─────────────────────────────────────────────────────────────────────────

    HLSLINCLUDE
        #pragma exclude_renderers gles
    ENDHLSL

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        ZTest Always Cull Off ZWrite Off

        Pass
        {
            Name "AcesGamutCompress"

            HLSLPROGRAM
                #pragma vertex   Vert
                #pragma fragment AcesGamutCompressFrag
                #include "AcesGamutCompressPass.hlsl"
            ENDHLSL
        }
    }

    Fallback Off
}
