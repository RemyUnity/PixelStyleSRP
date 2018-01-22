Shader "Hidden/PixelStyle/Deferred"
{
	SubShader
	{
		Pass
		{
			CGPROGRAM
			#pragma multi_compile __ Debug_Albedo Debug_NormalWS

			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			#define EPSILON 1.0e-4

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

			float _PixelStyle_ColorQuantity;

			sampler2D _AlbedoRT;
			sampler2D _NormalRT;

			float3 RGB2HSV(float3 c)
			{
				float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
				float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
				float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
				float d = q.x - min(q.w, q.y);
				float e = EPSILON;
				return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
			}

			float3 HSV2RGB(float3 c)
			{
				float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
				float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
				return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
			}
			
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

				c.rgb = albedoRT.rgb;

				float3 hsv = RGB2HSV(c.rgb);

				// Quantize color;
				float channelQuantity = pow(_PixelStyle_ColorQuantity, 0.333333);
				hsv = floor((hsv * channelQuantity) + 0.5) / channelQuantity;

				c.rgb = floor((c.rgb * channelQuantity) + 0.5) / channelQuantity;

				//c.rgb = hsv.x;
				c.rgb = HSV2RGB(hsv);

#ifdef Debug_Albedo

#elif Debug_NormalWS
				c.rgb = ( normalRT * 0.5 + 0.5 ) * (1- normalRT.a);
#else
				// Lighting with wake moving directional
				float lDotN = - dot(i.lightDir, normalRT);

				lDotN = lDotN * 0.5 + 0.5;

				lDotN = lDotN * lDotN * lDotN;

				c.rgb *= lDotN;
#endif

				return c;
			}
			ENDCG
		}
	}
}
