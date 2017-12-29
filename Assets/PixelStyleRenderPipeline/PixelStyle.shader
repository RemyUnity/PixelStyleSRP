// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "PixelStyle/Standard"
{
	Properties
	{
		[int] _PixelStyle_NormalValuesCount ("Normal Values Count", int) = 20
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
	{
		Tags{ "LightMode" = "PixelStylePass" }

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
	};

	sampler2D _MainTex;
	float4 _MainTex_ST;

	v2f vert(appdata v)
	{
		v2f o;
		o.vertex = UnityObjectToClipPos(v.vertex);
		o.uv = TRANSFORM_TEX(v.uv, _MainTex);
		return o;
	}

	fixed4 frag(v2f i) : SV_Target
	{
		// sample the texture
		fixed4 col = tex2D(_MainTex, i.uv);
	return col;
	}
		ENDCG
	}

		// Normals Pass
		Pass
	{
		Tags{ "LightMode" = "PixelStylePass_Normal" }

		CGPROGRAM
#pragma vertex vert
#pragma fragment frag

#include "UnityCG.cginc"

		struct appdata
		{
			float4 vertex : POSITION;
			float2 uv : TEXCOORD0;
			float3 normal : NORMAL;
		};

		struct v2f
		{
			float2 uv : TEXCOORD0;
			float4 vertex : SV_POSITION;
			float3 normal : NORMAL;
		};

		sampler2D _MainTex;
		float4 _MainTex_ST;

		v2f vert(appdata v)
		{
			v2f o;
			o.vertex = UnityObjectToClipPos(v.vertex);
			o.uv = TRANSFORM_TEX(v.uv, _MainTex);
			o.normal = mul( unity_ObjectToWorld, v.normal);
			return o;
		}

		float _PixelStyle_NormalValuesCount;

		// idea comes from here : https://stackoverflow.com/questions/9600801/evenly-distributing-n-points-on-a-sphere
		float3 ClosestFibonacciSphere(float3 _v, int _samples)
		{
			_v = normalize(_v);

			float dotP = 0;

			float offset = 2.0 / _samples;
			float increment = 2.3999632297286533222315555066336; // pi * (3. - sqrt(5.));

			float3 p, o = float3(0, 0, 0);

			for (int i = 0; i < _samples; ++i)
			{
				p.y = ((i*offset) - 1.0) + (offset/2.0);
				float r = sqrt( 1.0 - pow(p.y,2) );

				float phi = ((i + 1.0) % (_samples*1.0))*increment;

				p.x = cos(phi) * r;
				p.z = sin(phi) * r;

				float d = dot(_v, p);
				if (d > dotP)
				{
					dotP = d;
					o = p;
				}
			}

			return o;
		}

		fixed4 frag(v2f i) : SV_Target
		{
			fixed4 n = fixed4(0,0,0,0);
			n.xyz = i.normal;
			n.xyz = ClosestFibonacciSphere(n.xyz, _PixelStyle_NormalValuesCount);
			return n;
		}
		ENDCG
	}
	}
}
