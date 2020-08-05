half linstep(half a, half b, half x)
{
	return saturate((x - a) / (b - a));
}

half3 linstep(half3 a, half3 b, fixed x)
{
	return saturate((x - a) / (b - a));
}

half impulse(half k, half x)
{
	fixed h = k * x;
	return saturate(h * exp(1.0f - h));
}

half3 palette(fixed t, half3 a, half3 b, half3 c, half3 d)
{
	return a + b * cos(6.28318 * (c * t + d));
}

half3 squaredDistance(half3 a, half3 b)
{
	return a.x * b.x + a.y * b.y + a.z * b.z;
}

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
