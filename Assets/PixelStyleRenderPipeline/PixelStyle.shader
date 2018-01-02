// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "PixelStyle/Standard"
{
	Properties
	{
		[int] _PixelStyle_NormalValuesCount ("Normal Values Count", int) = 20
		[KeywordEnum(FibonnaciAbsolute, ReverseFibonnaci, Octahedra)] _QuantizeMethod("Quantize Normal Method", Float) = 0
		_Test ("Test", float)=0
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

#pragma multi_compile _QUANTIZEMETHOD_FIBONNACIABSOLUTE _QUANTIZEMETHOD_REVERSEFIBONNACI _QUANTIZEMETHOD_OCTAHEDRA

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

		float _Test;

		v2f vert(appdata v)
		{
			v2f o;
			o.vertex = UnityObjectToClipPos(v.vertex);
			o.uv = TRANSFORM_TEX(v.uv, _MainTex);
			o.normal = mul( unity_ObjectToWorld, v.normal);
			return o;
		}

		float _PixelStyle_NormalValuesCount;

		float3 FibonacciSphere(int _index, int _samples)
		{
			float offset = 2.0 / _samples;
			float increment = 2.3999632297286533222315555066336; // pi * (3. - sqrt(5.));

			float3 p = float3(0, 0, 0);

			p.y = ((_index*offset) - 1.0) + (offset / 2.0);
			float r = sqrt(1.0 - pow(p.y, 2));

			float phi = ((_index + 1.0) % (_samples*1.0))*increment;

			p.x = cos(phi) * r;
			p.z = sin(phi) * r;

			return p;
		}

		// idea comes from here : https://stackoverflow.com/questions/9600801/evenly-distributing-n-points-on-a-sphere
		float3 ClosestFibonacciSphere(float3 _v, int _samples)
		{
			_v = normalize(_v);

			float dotP = 0;

			float3 p, o = float3(0, 0, 0);

			for (int i = 0; i < _samples; ++i)
			{
				/*p.y = ((i*offset) - 1.0) + (offset/2.0);
				float r = sqrt( 1.0 - pow(p.y,2) );

				float phi = ((i + 1.0) % (_samples*1.0))*increment;

				p.x = cos(phi) * r;
				p.z = sin(phi) * r;*/

				p = FibonacciSphere(i, _samples);

				float d = dot(_v, p);
				if (d > dotP)
				{
					dotP = d;
					o = p;
				}
			}

			return o;
		}

		// Reverse Spherical Fibonacci : http://lgdv.cs.fau.de/uploads/publications/spherical_fibonacci_mapping_opt.pdf
#define madfrac(A,B) mad((A),(B),-floor((A)*(B)))
		// PHI = ( 1+sqrt(5) ) / 2
#define PHI 1.6180339887f

#define INFINITY 3.402823e+38

		float2x2 Inverse(float2x2 _m)
		{
			float2x2 o = float2x2(_m[1][1], -_m[0][1], -_m[1][0], _m[0][0]);
			return (1 / ( _m[0][0]*_m[1][1] - _m[0][1] * _m[1][0] )) * o;
		}

		float inverseSF(float3 p, float n)
		{
			// axis swizle
			p.xyz = float3(-p.x, p.z, -p.y);


			float phi = min(atan2(p.y, p.x), UNITY_PI), cosTheta = p.z;
			float k = max(2, floor(
				log(n * UNITY_PI * sqrt(5) * (1 - cosTheta*cosTheta))
				/ log(PHI*PHI)));
			float Fk = pow(PHI, k) / sqrt(5);
			float F0 = round(Fk), F1 = round(Fk * PHI);
			float2x2 B = float2x2(
				2 * UNITY_PI*madfrac(F0 + 1, PHI - 1) - 2 * UNITY_PI*(PHI - 1),
				2 * UNITY_PI*madfrac(F1 + 1, PHI - 1) - 2 * UNITY_PI*(PHI - 1),
				-2 * F0 / n,
				-2 * F1 / n);
			float2x2 invB = Inverse( B );
			float2 c = floor(mul(invB, float2(phi, cosTheta - (1 - 1 / n))));
			float d = INFINITY, j = 0;
			for (uint s = 0; s < 4; ++s) {
				float cosTheta = dot(B[1], float2(s % 2, s / 2) + c) + (1 - 1 / n);
				cosTheta = clamp(cosTheta, -1, +1) * 2 - cosTheta;
				float i = floor(n*0.5 - cosTheta*n*0.5);
				float phi = 2 * UNITY_PI*madfrac(i, PHI - 1);
				cosTheta = 1 - (2 * i + 1)*rcp(n);
				float sinTheta = sqrt(1 - cosTheta*cosTheta);
				float3 q = float3(
					cos(phi)*sinTheta,
					sin(phi)*sinTheta,
					cosTheta);
				float squaredDistance = dot(q - p, q - p);
				if (squaredDistance < d) {
					d = squaredDistance;
					j = i;
				}
			}
			return j;
		}


		// Octahedral normal : http://jcgt.org/published/0003/02/01/paper.pdf
		// Returns ±1
		fixed2 signNotZero(fixed2 v) {
			return fixed2((v.x >= 0.0) ? +1.0 : -1.0, (v.y >= 0.0) ? +1.0 : -1.0);
		}

		// Convert to oct, quantize, and convert back to vec3
		float3 QuantizeOct(float3 _v, int _quantity)
		{
			// Project the sphere onto the octahedron, and then onto the xy plane
			fixed2 p = _v.xy * (1.0 / (abs(_v.x) + abs(_v.y) + abs(_v.z)));

			// Reflect the folds of the lower hemisphere over the diagonals
			p = (_v.z <= 0.0) ? ((1.0 - abs(p.yx)) * signNotZero(p)) : p;

			// Quantize
			p *= _quantity;
			p = floor(p);
			p /= _quantity;

			// Convert back to vec3
			float3 v = float3(p.xy, 1.0 - abs(p.x) - abs(p.y));
			if (v.z < 0) v.xy = (1.0 - abs(v.yx)) * signNotZero(v.xy);
			return normalize(v);
		}

		fixed4 frag(v2f i) : SV_Target
		{
			fixed4 n = fixed4(0,0,0,0);
			n.xyz = i.normal;

#if _QUANTIZEMETHOD_FIBONNACIABSOLUTE
			n.xyz = ClosestFibonacciSphere(n.xyz, _PixelStyle_NormalValuesCount);
#endif
#if _QUANTIZEMETHOD_REVERSEFIBONNACI
			n.xyz = FibonacciSphere(inverseSF(n.xyz, _PixelStyle_NormalValuesCount), _PixelStyle_NormalValuesCount);
			//n.xyz = inverseSF(n.xyz, _PixelStyle_NormalValuesCount) / _PixelStyle_NormalValuesCount;
#endif
#if _QUANTIZEMETHOD_OCTAHEDRA
			n.xyz = QuantizeOct(n.xyz, _PixelStyle_NormalValuesCount / 8);
#endif
			return n;
		}
		ENDCG
	}
	}
}
