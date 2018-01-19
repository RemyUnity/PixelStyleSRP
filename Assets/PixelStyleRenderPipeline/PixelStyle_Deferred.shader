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

			float3 RGB2HSV(float3 _rgb)
			{
				float cMax = max(max(_rgb.r, _rgb.g), _rgb.b);
				float cMin = min(min(_rgb.r, _rgb.g), _rgb.b);

				float delta = cMax - cMin;

				float h = 0;

				if (cMax >= _rgb.r) h = (_rgb.g - _rgb.b) / delta;
				if (cMax >= _rgb.g) h = 2.0 + (_rgb.b - _rgb.r) / delta;
				if (cMax >= _rgb.b) h = 4.0 + (_rgb.r - _rgb.g) / delta;

				h /= 6.0;

				if (h < 0) h += 1;

				float s = (cMax == 0) ? 0 : delta / cMax;

				return float3(h, s, cMax);
			}

			float HSV2RGB(float3 _hsv)
			{
				float hh = _hsv.x * 6.0;
				float i = floor(hh);
				float ff = frac(hh);

				float p = _hsv.z * (1.0 - _hsv.y);
				float q = _hsv.z * (1.0 - (_hsv.y * ff));
				float t = _hsv.z * (1.0 - (_hsv.y * (1.0 - ff)));

				float3 o = float3(0,0,0);

				if		(i==0.0) o = float3(_hsv.z, t, p);
				else if (i==1.0) o = float3(q, _hsv.z, p);
				else if (i==2.0) o = float3(p, _hsv.z, t);
				else if (i==3.0) o = float3(p, q, _hsv.z);
				else if (i==4.0) o = float3(t, p, _hsv.z);
				else			 o = float3(_hsv.z, p, q);

				return o;
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
				//hsv = floor((hsv * channelQuantity) + 0.5) / channelQuantity;

				//c.rgb = hsv;
				//c.rgb = HSV2RGB(hsv);

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
