float linstep(float edge0, float edge1, float x)
{
	return  saturate((x - edge0) / (edge1 - edge0));
}

half3 linstep(half3 edge0, half3 edge1, half3 x)
{
	return  saturate((x - edge0) / (edge1 - edge0));
}

float expImpulse(half x, half k)
{
	float h = k * x;
	return h * exp(1.0 - h);
}

half3 palette(fixed t, half3 a, half3 b, half3 c, half3 d)
{
	return a + b * cos(6.28318 * (c * t + d));
}

float invLerp(float from, float to, float value) {
	return (value - from) / (to - from);
}

//half3 squaredDistance(half3 a, half3 b)
//{
//	return a.x * b.x + a.y * b.y + a.z * b.z;
//}

half rand(half2 co) {
	return frac(sin(dot(co.xy, half2(12.9898, 78.233))) * 43758.5453);
}

half4x4 rotationMatrix(half3 axis, half angle)
{
	// axis should be normalized
	half s = sin(angle);
	half c = cos(angle);
	half oc = 1.0 - c;

	return half4x4(
		oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s, 0.0,
		oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z - axis.x * s, 0.0,
		oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c, 0.0,
		0.0, 0.0, 0.0, 1.0);
}

half cubicPulse(half c, half w, half x)
{
	// less instructions than gauss()
	x = abs(x - c);
	if (x>w) return 0.0f;
	x /= w;
	return 1.0f - x*x*(3.0f - 2.0f*x);
}

half gauss(half c, half w, half x)
{
	return smoothstep(c - w, c, x) - smoothstep(c, c + w, x);
}

float gain(float x, float k)
{
	const float a = 0.5 * pow(2.0 * ((x < 0.5) ? x : 1.0 - x), k);
	return (x < 0.5) ? a : 1.0 - a;
}

float gamma(float x, float gamma)
{
	return pow(x, 1.0 / gamma);
}

float posterize(float x, float steps)
{
	// round() == floor(x + .5)
	return floor(x * steps + 0.5) / steps;
}

// All components are in the range [0…1], including hue.
half3 hsv2rgb(half3 c)
{
	half4 K = half4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	half3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// All components are in the range [0…1], including hue.
half3 rgb2hsv(half3 c)
{
	half4 K = half4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	half4 p = lerp(half4(c.bg, K.wz), half4(c.gb, K.xy), step(c.b, c.g));
	half4 q = lerp(half4(p.xyw, c.r), half4(c.r, p.yzx), step(p.x, c.r));

	half d = q.x - min(q.w, q.y);
	half e = 1.0e-10;
	return half3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
