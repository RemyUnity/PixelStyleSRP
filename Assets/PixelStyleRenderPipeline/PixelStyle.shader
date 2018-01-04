// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "PixelStyle/Standard"
{
	Properties
	{
		_Test ("Test", float)=0
		_MainTex ("Texture", 2D) = "white" {}
		[Normal, NOSCALEOFFSET] _NormalMap("Normal", 2D) = "bump" {}
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

#pragma multi_compile _NORMALQUANTIFICATION_NONE _NORMALQUANTIFICATION_FRIBONNACIBRUTE _NORMALQUANTIFICATION_FIBONNACIREVERSE _NORMALQUANTIFICATION_OCTAHEDRA

#include "UnityCG.cginc"
#include "PixelStyle.cginc"

		struct appdata
		{
			float4 vertex : POSITION;
			float2 uv : TEXCOORD0;
			float3 normal : NORMAL;
			float3 tangent : TANGENT;
		};

		struct v2f
		{
			float2 uv : TEXCOORD0;
			float4 vertex : SV_POSITION;
			float3 normal : NORMAL;
			float3 tangent : TANGENT;
		};

		sampler2D _MainTex;
		sampler2D _NormalMap;
		float4 _MainTex_ST;

		float _Test;

		v2f vert(appdata v)
		{
			v2f o;
			o.vertex = UnityObjectToClipPos(v.vertex);
			o.uv = TRANSFORM_TEX(v.uv, _MainTex);
			o.normal = normalize( mul( (float3x3) unity_ObjectToWorld, v.normal) );
			o.tangent = normalize ( mul( (float3x3) unity_ObjectToWorld, v.tangent) );
			return o;
		}

		fixed4 frag(v2f i) : SV_Target
		{
			fixed4 n = fixed4(0,0,0,0);
			
			fixed3 normalMap = UnpackNormal(tex2D(_NormalMap, i.uv));

			fixed3 bitangent = cross(i.normal, i.tangent.xyz);

			n.xyz = i.tangent * normalMap.x + bitangent * normalMap.y + i.normal * normalMap.z;

			QuantifyNormal(n.xyz);

			return n;
		}
		ENDCG
	}
	}
}
