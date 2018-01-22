#pragma multi_compile _NORMALQUANTIFICATION_NONE _NORMALQUANTIFICATION_FRIBONNACIBRUTE _NORMALQUANTIFICATION_FIBONNACIREVERSE _NORMALQUANTIFICATION_OCTAHEDRA

float _PixelStyle_NormalQuantity;

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

float3 FibonacciSphere(int _index)
{
	return FibonacciSphere(_index, _PixelStyle_NormalQuantity);
}

#if _NORMALQUANTIFICATION_FRIBONNACIBRUTE
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

float3 ClosestFibonacciSphere(float3 _v)
{
	return ClosestFibonacciSphere(_v, _PixelStyle_NormalQuantity);
}
#endif

#if _NORMALQUANTIFICATION_FIBONNACIREVERSE
// Reverse Spherical Fibonacci : http://lgdv.cs.fau.de/uploads/publications/spherical_fibonacci_mapping_opt.pdf
#define madfrac(A,B) mad((A),(B),-floor((A)*(B)))
// PHI = ( 1+sqrt(5) ) / 2
#define PHI 1.6180339887f

#define INFINITY 3.402823e+38

float2x2 Inverse(float2x2 _m)
{
	float2x2 o = float2x2(_m[1][1], -_m[0][1], -_m[1][0], _m[0][0]);
	return (1 / (_m[0][0] * _m[1][1] - _m[0][1] * _m[1][0])) * o;
}

float inverseSF(float3 p, float n)
{
	// axis swizle
	p.xyz = float3(-p.x, p.z, -p.y);

	/*
	float sc_r = sqrt(p.x*p.x + p.y*p.y + p.z*p.z);
	float sc_phi = acos(p.z / sc_r);
	float sc_theta = atan2(p.y, p.x);

	p.x = sc_r;
	p.y = sc_phi;
	p.z = sc_theta;
	*/

	// for some reason, I need to rotate the coordinates to have correct results.

	float theta = -42.6 * UNITY_PI / 180.0;

	float cs = cos(theta), sn = sin(theta);

	float rx = p.x * cs - p.y * sn;
	float ry = p.x * sn + p.y * cs;

	p.x = rx;
	p.y = ry;

	// do the calculation

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
	float2x2 invB = Inverse(B);
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

float inverseSF(float3 p)
{
	return inverseSF(p, _PixelStyle_NormalQuantity);
}
#endif

#if _NORMALQUANTIFICATION_OCTAHEDRA
// Octahedral normal : http://jcgt.org/published/0003/02/01/paper.pdf
// Returns ±1
fixed2 signNotZero(fixed2 v) {
	return fixed2((v.x >= 0.0) ? +1.0 : -1.0, (v.y >= 0.0) ? +1.0 : -1.0);
}

// Convert to oct, quantize, and convert back to vec3
float3 QuantifyOct(float3 _v, int _quantity)
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

float3 QuantifyOct(float3 _v)
{
	return QuantifyOct(_v, pow(_PixelStyle_NormalQuantity, 1.0/3.0));
}
#endif

void QuantifyNormal(inout float3 _v)
{
#if _NORMALQUANTIFICATION_FRIBONNACIBRUTE
	_v.xyz = ClosestFibonacciSphere(_v.xyz, _PixelStyle_NormalQuantity);
#endif
#if _NORMALQUANTIFICATION_FIBONNACIREVERSE
	_v.xyz = FibonacciSphere(inverseSF(_v.xyz, _PixelStyle_NormalQuantity), _PixelStyle_NormalQuantity);
#endif
#if _NORMALQUANTIFICATION_OCTAHEDRA
	_v.xyz = QuantifyOct(_v.xyz, floor(pow(_PixelStyle_NormalQuantity, 1 / 3.0)));
#endif
}