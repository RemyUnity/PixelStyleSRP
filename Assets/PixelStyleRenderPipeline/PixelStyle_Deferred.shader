Shader "Hidden/PixelStyle/Deferred"
{
	SubShader
	{
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 lightDir : TEXCOORD1;
			};

			sampler2D _AlbedoRT;
			sampler2D _NormalRT;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;

				o.lightDir = normalize(float3(cos(_Time.y), -1.0, sin(_Time.y)));

				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float4 c = fixed4(0,0,0,0);

				float4 albedoRT = tex2D(_AlbedoRT, i.uv);
				float4 normalRT = tex2D(_NormalRT, i.uv);

				float lDotN = - dot(i.lightDir, normalRT);

				lDotN = lDotN * 0.5 + 0.5;

				lDotN = lDotN * lDotN * lDotN;

				c.rgb = albedoRT.rgb * lDotN;

				return c;
			}
			ENDCG
		}
	}
}
