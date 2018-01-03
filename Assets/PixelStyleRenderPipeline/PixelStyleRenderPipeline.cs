using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

[ExecuteInEditMode]
public class PixelStyleRenderPipeline : RenderPipelineAsset
{
    [SerializeField] Vector2Int _resolution = new Vector2Int(426, 240);
    [SerializeField] int _normalQuantity = 128;

#if UNITY_EDITOR
    [UnityEditor.MenuItem("Assets/Create/Render Pipeline/Pixel Style Render Pipeline")]
    static void CreateBasicRenderPipeline()
    {
        var instance = ScriptableObject.CreateInstance<PixelStyleRenderPipeline>();
        UnityEditor.AssetDatabase.CreateAsset(instance, "Assets/PixelStyleRenderPipeline/PixelStyleRenderPipeline.asset");
    }

    protected override IRenderPipeline InternalCreatePipeline()
    {
        return new PixelStyleRenderPipelineInstance(new PixelStyleRenderPipelineData()
        {
            normalQuantity = _normalQuantity,
            resolution = _resolution
        });
    }
#endif

}

public struct PixelStyleRenderPipelineData
{
    public int normalQuantity;
    public Vector2Int resolution;
}

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

    // Main entry point for our scriptable render loop
    public static void Render(ScriptableRenderContext context, Camera[] cameras, PixelStyleRenderPipelineData _data)
    {
        Camera camera;

        Shader.SetGlobalInt("_PixelStyle_NormalQuantity", _data.normalQuantity);

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

            // Set the intermediate RT
            int intermediateRT = Shader.PropertyToID("_IntermediateTarget");
            RenderTargetIdentifier intermediateRTID = new RenderTargetIdentifier(intermediateRT);

            CommandBuffer bindIntermediateRTCmd = new CommandBuffer() { name = "Bind intermediate RT" };
            bindIntermediateRTCmd.GetTemporaryRT(intermediateRT, _data.resolution.x, _data.resolution.y, 24, FilterMode.Point, RenderTextureFormat.Default, RenderTextureReadWrite.Default, 1, true);
            bindIntermediateRTCmd.SetRenderTarget(intermediateRTID);

            context.ExecuteCommandBuffer(bindIntermediateRTCmd);
            bindIntermediateRTCmd.Dispose();

            // setup render target and clear it
            var cmd = new CommandBuffer();
            cmd.ClearRenderTarget(true, true, Color.black);
            context.ExecuteCommandBuffer(cmd);
            cmd.Dispose();

            // Draw opaque objects using PixelStylePass shader pass
            //var drawSettings = new DrawRendererSettings(camera, new ShaderPassName("PixelStylePass")) { sorting = { flags = SortFlags.CommonOpaque } };
            //var filterSettings = new FilterRenderersSettings(true) { renderQueueRange = RenderQueueRange.opaque };
            //context.DrawRenderers(cull.visibleRenderers, ref drawSettings, filterSettings);

            // Draw opaque objects using PixelStylePass_Normal shader pass
            //Shader.SetGlobalInt("_PixelStyle_NormalValuesCount", 50);
            var drawSettings = new DrawRendererSettings(camera, new ShaderPassName("PixelStylePass_Normal")) { sorting = { flags = SortFlags.CommonOpaque } };
            var filterSettings = new FilterRenderersSettings(true) { renderQueueRange = RenderQueueRange.opaque };
            context.DrawRenderers(cull.visibleRenderers, ref drawSettings, filterSettings);

            // Draw skybox
            context.DrawSkybox(camera);

            // Blit back intermediate RT to Camera
            CommandBuffer blitIntermediateRTCmd = new CommandBuffer() { name = "Copy intermediate RT to default RT" };
            blitIntermediateRTCmd.Blit(intermediateRTID, BuiltinRenderTextureType.CameraTarget);

            context.ExecuteCommandBuffer(blitIntermediateRTCmd);
            blitIntermediateRTCmd.Dispose();

            context.Submit();
        }
    }
}
