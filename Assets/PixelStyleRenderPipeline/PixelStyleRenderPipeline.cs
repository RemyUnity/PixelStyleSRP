using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

[ExecuteInEditMode]
public class PixelStyleRenderPipeline : RenderPipelineAsset
{
    public enum NormalQuantificationMethod { None, Fribonnaci_Brute, Fibonnaci_Reverse, Octahedra }

    [SerializeField] PixelStyleRenderPipelineData settings = new PixelStyleRenderPipelineData()
    {
        colorQuantity = 256,
        normalQuantity = 64,
        resolution = new Vector2Int(384, 216),
        normalQuantificationMethod = NormalQuantificationMethod.Fibonnaci_Reverse,
        
        debug = DebugStyle.None
    };

#if UNITY_EDITOR
    [UnityEditor.MenuItem("Assets/Create/Render Pipeline/Pixel Style Render Pipeline")]
    static void CreateBasicRenderPipeline()
    {
        var instance = ScriptableObject.CreateInstance<PixelStyleRenderPipeline>();
        UnityEditor.AssetDatabase.CreateAsset(instance, "Assets/PixelStyleRenderPipeline/PixelStyleRenderPipeline.asset");
    }

    protected override IRenderPipeline InternalCreatePipeline()
    {
        return new PixelStyleRenderPipelineInstance(settings);
    }
#endif

}

[System.Serializable]
public struct PixelStyleRenderPipelineData
{
    public int colorQuantity;
    public int normalQuantity;
    public Vector2Int resolution;
    public PixelStyleRenderPipeline.NormalQuantificationMethod normalQuantificationMethod;

    public DebugStyle debug;
}

public enum DebugStyle { None, Albedo, NormalsWS };

public class PixelStyleRenderPipelineInstance : RenderPipeline
{
    PixelStyleRenderPipelineData data;

    public PixelStyleRenderPipelineInstance(PixelStyleRenderPipelineData _data)
    {
        data = _data;
    }

    public override void Render(ScriptableRenderContext renderContext, Camera[] cameras)
    {
        base.Render(renderContext, cameras);
        PixelStyleRendering.Render(renderContext, cameras, data);
    }
}

public static class PixelStyleRendering
{
    static Material deferredMat;

    // Main entry point for our scriptable render loop
    public static void Render(ScriptableRenderContext context, Camera[] cameras, PixelStyleRenderPipelineData _data)
    {
        Camera camera;

        Shader.SetGlobalInt("_PixelStyle_ColorQuantity", _data.colorQuantity);
        Shader.SetGlobalInt("_PixelStyle_NormalQuantity", _data.normalQuantity);

        switch (_data.debug )
        {
            case DebugStyle.None:
                Shader.DisableKeyword("Debug_Albedo");
                Shader.DisableKeyword("Debug_NormalWS");
                break;
            case DebugStyle.Albedo:
                Shader.EnableKeyword("Debug_Albedo");
                Shader.DisableKeyword("Debug_NormalWS");
                break;
            case DebugStyle.NormalsWS:
                Shader.DisableKeyword("Debug_Albedo");
                Shader.EnableKeyword("Debug_NormalWS");
                break;
        }
        
        switch (_data.normalQuantificationMethod)
        {
            case PixelStyleRenderPipeline.NormalQuantificationMethod.None:
                Shader.DisableKeyword("_NORMALQUANTIFICATION_FRIBONNACIBRUTE");
                Shader.DisableKeyword("_NORMALQUANTIFICATION_FIBONNACIREVERSE");
                Shader.DisableKeyword("_NORMALQUANTIFICATION_OCTAHEDRA");
                break;
            case PixelStyleRenderPipeline.NormalQuantificationMethod.Fribonnaci_Brute:
                Shader.EnableKeyword("_NORMALQUANTIFICATION_FRIBONNACIBRUTE");
                Shader.DisableKeyword("_NORMALQUANTIFICATION_FIBONNACIREVERSE");
                Shader.DisableKeyword("_NORMALQUANTIFICATION_OCTAHEDRA");
                break;
            case PixelStyleRenderPipeline.NormalQuantificationMethod.Fibonnaci_Reverse:
                Shader.DisableKeyword("_NORMALQUANTIFICATION_FRIBONNACIBRUTE");
                Shader.EnableKeyword("_NORMALQUANTIFICATION_FIBONNACIREVERSE");
                Shader.DisableKeyword("_NORMALQUANTIFICATION_OCTAHEDRA");
                break;
            case PixelStyleRenderPipeline.NormalQuantificationMethod.Octahedra:
                Shader.DisableKeyword("_NORMALQUANTIFICATION_FRIBONNACIBRUTE");
                Shader.DisableKeyword("_NORMALQUANTIFICATION_FIBONNACIREVERSE");
                Shader.EnableKeyword("_NORMALQUANTIFICATION_OCTAHEDRA");
                break;
        }

        for (int ci = 0; ci < cameras.Length; ++ci)
        {
            camera = cameras[ci];

            // Culling
            ScriptableCullingParameters cullingParams;
            if (!CullResults.GetCullingParameters(camera, out cullingParams)) continue;
            CullResults cull = new CullResults();
            CullResults.Cull(ref cullingParams, context, ref cull);

            // Setup camera for rendering (sets render target, view/projection matrices and other
            // per-camera built-in shader variables).
            context.SetupCameraProperties(camera);

            // Set the albedo RT
            int albedoRT = Shader.PropertyToID("_AlbedoRT");
            RenderTargetIdentifier albedoRTID = new RenderTargetIdentifier(albedoRT);

            CommandBuffer bindAlbedoRTCmd = new CommandBuffer() { name = "Bind Albedo RT" };
            bindAlbedoRTCmd.GetTemporaryRT(albedoRT, _data.resolution.x, _data.resolution.y, 24, FilterMode.Point, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Default, 1, true);
            bindAlbedoRTCmd.SetRenderTarget(albedoRTID);

            context.ExecuteCommandBuffer(bindAlbedoRTCmd);
            bindAlbedoRTCmd.Dispose();

            // setup render target and clear it
            var cmd_Albedo = new CommandBuffer();
            cmd_Albedo.ClearRenderTarget(true, true, Color.black);
            context.ExecuteCommandBuffer(cmd_Albedo);
            cmd_Albedo.Dispose();

            // Draw opaque objects using PixelStylePass shader pass
            var albedo_DrawSettings = new DrawRendererSettings(camera, new ShaderPassName("PixelStylePass")) { sorting = { flags = SortFlags.CommonOpaque } };
            var albedo_FilterSettings = new FilterRenderersSettings(true) { renderQueueRange = RenderQueueRange.opaque };
            context.DrawRenderers(cull.visibleRenderers, ref albedo_DrawSettings, albedo_FilterSettings);


            // Set the normal RT
            int normalRT = Shader.PropertyToID("_NormalRT");
            RenderTargetIdentifier normalRTID = new RenderTargetIdentifier(normalRT);

            CommandBuffer bindNormalRTCmd = new CommandBuffer() { name = "Bind Normal RT" };
            bindNormalRTCmd.GetTemporaryRT(normalRT, _data.resolution.x, _data.resolution.y, 24, FilterMode.Point, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Default, 1, true);
            bindNormalRTCmd.SetRenderTarget(normalRTID);

            context.ExecuteCommandBuffer(bindNormalRTCmd);
            bindNormalRTCmd.Dispose();

            // setup render target and clear it
            var cmd_Normal = new CommandBuffer();
            cmd_Normal.ClearRenderTarget(true, true, Color.black);
            context.ExecuteCommandBuffer(cmd_Normal);
            cmd_Normal.Dispose();

            // Draw opaque objects using PixelStylePass_Normal shader pass
            //Shader.SetGlobalInt("_PixelStyle_NormalValuesCount", 50);
            var normal_DrawSettings = new DrawRendererSettings(camera, new ShaderPassName("PixelStylePass_Normal")) { sorting = { flags = SortFlags.CommonOpaque } };
            var normal_FilterSettings = new FilterRenderersSettings(true) { renderQueueRange = RenderQueueRange.opaque };
            context.DrawRenderers(cull.visibleRenderers, ref normal_DrawSettings, normal_FilterSettings);

            // Draw skybox
            context.DrawSkybox(camera);

            // Setup deferred compositor material
            if ( deferredMat == null )
            {
                deferredMat = new Material(Shader.Find("Hidden/PixelStyle/Deferred"));
            }

            // Blit back intermediate RT to Camera
            CommandBuffer blitIntermediateRTCmd = new CommandBuffer() { name = "Copy intermediate RT to default RT" };
            blitIntermediateRTCmd.Blit(normalRTID, BuiltinRenderTextureType.CameraTarget, deferredMat);

            context.ExecuteCommandBuffer(blitIntermediateRTCmd);
            blitIntermediateRTCmd.Dispose();

            context.Submit();
        }
    }
}
