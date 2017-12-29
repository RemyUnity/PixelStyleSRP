using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

[ExecuteInEditMode]
public class PixelStyleRenderPipeline : RenderPipelineAsset
{

#if UNITY_EDITOR
    [UnityEditor.MenuItem("Assets/Create/Render Pipeline/Pixel Style Render Pipeline")]
    static void CreateBasicRenderPipeline()
    {
        var instance = ScriptableObject.CreateInstance<PixelStyleRenderPipeline>();
        UnityEditor.AssetDatabase.CreateAsset(instance, "Assets/PixelStyleRenderPipeline/PixelStyleRenderPipeline.asset");
    }

    protected override IRenderPipeline InternalCreatePipeline()
    {
        return new PixelStyleRenderPipelineInstance();
    }
#endif

}

public class PixelStyleRenderPipelineInstance : RenderPipeline
{
    public PixelStyleRenderPipelineInstance() { }

    public override void Render(ScriptableRenderContext renderContext, Camera[] cameras)
    {
        base.Render(renderContext, cameras);
        PixelStyleRendering.Render(renderContext, cameras);
    }
}

public static class PixelStyleRendering
{

    // Main entry point for our scriptable render loop
    public static void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        Camera camera;

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

            // setup render target and clear it
            var cmd = new CommandBuffer();
            cmd.SetRenderTarget(BuiltinRenderTextureType.CameraTarget);
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

            context.Submit();
        }
    }
}
