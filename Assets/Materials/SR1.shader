
Shader "Surface Reconstruction/SR1"
{
	Properties
	{
		_Center("Center", Vector) = (0, 0, 0, -1)
		_Radius("Radius", Range(0, 10)) = 1
		_WaveOffset("Wave Offset", Range(0, 1)) = .1

		_WaveTightnessA("Wave Tightness A", Range(0, 100)) = 6
		_WaveTightnessB("Wave Tightness B", Range(0, 100)) = 3
		_WaveTightnessC("Wave Tightness C", Range(0, 100)) = 2

		_WaveWidthFront("Wave Width Front", Range(-5, 5)) = 1

		_BaryThresh("Bary Threshold", Range(0, 1)) = 1

		_BottomSpotColorA("SpotColorA", Color) = (1, 1, 0, 1)
		_SpotColorB("SpotColorB", Color) = (0, 1, 1, 1)
		_SpotColorC("SpotColorC", Color) = (1, 0, 1, 1)

		_HazeA("HazeA", Color) = (1, 0, 1, 1)
		_HazeB("HazeB", Color) = (1, 0, 1, 1)

		_WaveColorTop("Wave Color Top", Color) = (.1, .0, .1, 1)
		_WaveColorBottom("Wave Color Bottom", Color) = (.1, .1, .0, 1)

		_NormalMix("Normal Mix", Range(0, 1)) = 0
		_NormalMixB("Normal MixB", Range(0, 1)) = 0

		_Laydown("Laydown", Range(0, 10)) = 1
	}

	SubShader
	{
		Tags { "RenderType" = "Opaque" }

		Pass
		{
			CGPROGRAM

			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag

			#pragma multi_compile_instancing

			#include "UnityCG.cginc"

			half3 _Center;
			half _Radius;
			half _WaveOffset;
			half _WaveTightnessA;
			half _WaveTightnessB;
			half _WaveTightnessC;
			half _WaveWidthFront;

			half3 _HazeA;
			half3 _HazeB;

			half _BaryThresh;
			half4 _BottomSpotColorA;
			half4 _SpotColorB;

			half4 _WaveColorTop;
			half4 _WaveColorBottom;

			half _NormalMix;
			half _NormalMixB;

			half _Laydown;

			#include "Util.cginc"

			struct v2g
			{
				float4 viewPos : SV_POSITION;
				float3 worldPos : POSITION1;
				half3 wave : TEXCOORD1;
				half laydown : TEXCOORD2;
				half waveMax : TEXCOORD3;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			struct g2f
			{
				float4 viewPos : SV_POSITION;
				float3 worldPos : POSITION1;
				half3 wave : TEXCOORD1;
				half3 N : NORMAL;
				half3 bary : TEXCOORD2;
				int id : TEXCOORD3;
				half3 color : TEXCOORD4;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2g vert(appdata_base i)
			{
				v2g o;

				UNITY_SETUP_INSTANCE_ID(i);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.viewPos = UnityObjectToClipPos(i.vertex);
				o.worldPos = mul(unity_ObjectToWorld, i.vertex).xyz;

				half distToCenter = distance(o.worldPos, _Center);

				half d = max(0, _Radius - distToCenter);

				o.laydown = smoothstep(0, _Laydown, d);

				o.wave.x = expImpulse(d, _WaveTightnessA);
				o.wave.y = expImpulse(d, _WaveTightnessB);
				o.wave.z = expImpulse(d, _WaveTightnessC);

				o.waveMax = max(max(o.wave.x, o.wave.y), o.wave.z);
				return o;
			}

			[maxvertexcount(6)]
			void geom(triangle v2g i[3], inout TriangleStream<g2f> triStream)
			{
				const half3 barys[3] = {
					half3(1, 0, 0),
					half3(0, 1, 0),
					half3(0, 0, 1)
				};

				g2f o;

				const float rcp3 = 1.0 / 3.0;
				float3 triCenter = (i[0].worldPos.xyz + i[1].worldPos.xyz + i[2].worldPos.xyz) * rcp3; // avg position

				// invent a normal (flat shaded)
				float3 normal = cross(
					i[0].worldPos - i[1].worldPos,
					i[0].worldPos - i[2].worldPos);

				float3 N = normalize(normal);

				half waveMax = max(max(i[0].waveMax, i[1].waveMax), i[2].waveMax);

				const half cutoff = .001;

				//
				// First layer
				//

				if (waveMax > cutoff)
				{
					[unroll]
					for (uint idx = 0; idx < 3; ++idx)
					{

						o.N = N;
						o.wave = i[idx].wave;
						o.worldPos = i[idx].worldPos;
						o.viewPos = i[idx].viewPos;

						// barycentric
						o.bary = barys[idx];

						o.color = i[idx].laydown; // XXX

						o.id = 0; // flag bottom layer
						UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(i[idx], o);
						triStream.Append(o);
					}
				}

				//
				// Second layer
				//

				float3 newPos = 0;  // displaced position

				if (waveMax > cutoff)
				{
					triStream.RestartStrip();

					[unroll]
					for (uint jdx = 0; jdx < 3; ++jdx)
					{
						newPos = lerp(
							triCenter + (N * _WaveOffset),
							i[jdx].worldPos,
							i[jdx].laydown);

						o.viewPos = UnityObjectToClipPos(mul(unity_WorldToObject, float4(newPos, 1)));

						o.N = N;
						o.wave = i[jdx].wave;
						o.worldPos = i[jdx].worldPos;

						o.color = i[jdx].laydown; // XXX

						// barycentric coordinates
						o.bary = barys[jdx];

						o.id = 1; // flag as top layer

						UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(i[jdx], o);
						triStream.Append(o);
					}
				}
			}

			half4 frag(g2f i) : COLOR
			{
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

				half4 outColor = half4(0, 0, 0, 1);

				// make some circles
				half dist = dot(i.bary, i.bary);

				half3 fw3 = fwidth(i.bary);

				half fw = max(max(fw3.x, fw3.y), fw3.z) * 2;

				// wireframe
				//const half thresh = .1;
				half minbary = min(min(i.bary.x, i.bary.y), i.bary.z) * 3;
				//half triShape = linstep(thresh + fw, thresh - fw, minbary);

				half3 threshA = i.wave * _BaryThresh + fw;
				half3 threshB = i.wave * _BaryThresh - fw;

				half3 baryC = smoothstep(threshA, threshB, dist);

				half3 baryColor = float3(baryC.x, baryC.y, baryC.z);

				half baryCMax = max(max(baryC.x, baryC.y), baryC.z);

				half3 bottomC = lerp(
					_HazeA,
					baryColor * _BottomSpotColorA,
					baryCMax);

				bottomC = lerp(bottomC, bottomC + abs(i.N), _NormalMix);

				bottomC *= i.wave.y;

				//half3 topC = lerp(
				//	_HazeB,
				//	_SpotColorB,
				//	baryCMax);

				//topC = lerp(topC, topC + abs(i.N), _NormalMixB);

				half3 topC = _NormalMixB * abs(i.N) * i.wave.z;

				//topC *= i.wave.z * 2; // 2 to compensate for wave brightness
				//topC *= i.wave.z;

				float3 jazz = lerp(bottomC, topC, i.id);

				// hide the circles in the middle where we tapped
				half toCenterDist = distance(i.worldPos, _Center);

				half centerMask = smoothstep(1, .1, toCenterDist);

				outColor.rgb = jazz;

				// add some fx to localize the tap
				// rings + wireframe

				half d = _Radius - toCenterDist;
				half3 rings = expImpulse(40, (d - .05));// *abs(i.N);

				// add some wireframe look
				//rings += triShape * rings;
				rings *= centerMask;

				outColor.rgb += rings;

				//outColor.rgb = rings; // XXX

				return outColor;
			}

			ENDCG
		}
	}
}
