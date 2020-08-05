// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Surface Reconstruction/SR1"
{
	Properties
	{
		_Radius("Radius", Range(0, 10)) = 1
		_Center("Center", Vector) = (0, 0, 0, -1)
		_WaveSizeA("Wave Size A", Range(0, 10)) = 6
		_WaveSizeB("Wave Size B", Range(0, 10)) = 3
		_WaveSizeC("Wave Size C", Range(0, 10)) = 2
		_WaveWidth("Wave Width Back", Range(-5, 5)) = 1
		_WaveWidthB("Wave Width Front", Range(-5, 5)) = 1
		_WaveOffset("Wave Offset", Range(-1, 1)) = .1
		_NormalMix("Normal Mix", Range(0,1)) = 0
		_NormalMixB("Normal MixB", Range(0,1)) = 0
		_BaryThresh("Bary Threshold", Range(0, 1)) = 1
		_SpotColorA("SpotColorA", Color) = (1, 1, 1, 1)
		_SpotColorB("SpotColorB", Color) = (0, 0, 0, 1)
		_HazeA("HazeA", Color) = (.1, .1, 0, 1)
		_HazeB("HazeB", Color) = (.1, 0, .1, 1)
	}
		SubShader
	{
		Tags { "RenderType" = "Opaque" }

		Pass
		{
			Offset 50, 100

			CGPROGRAM

			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag
			#include "UnityCG.cginc"

			fixed4 _BaseColor;
			fixed4 _WireColor;
			fixed _WireThickness;
			fixed _Radius;
			fixed3 _Center;
			fixed _WaveSizeA;
			fixed _WaveSizeB;
			fixed _WaveSizeC;
			fixed _WaveOffset;
			fixed _WaveWidth;
			fixed _WaveWidthB;
			fixed _BaryThresh;
			fixed3 _Offset;
			fixed3 _Amp;
			fixed3 _Freq;
			fixed3 _Phase;
			fixed4 _SpotColorA;
			fixed4 _SpotColorB;
			fixed4 _HazeA;
			fixed4 _HazeB;
			fixed _NormalMix;
			fixed _NormalMixB;

			//sampler2D _MainTex;

			// utilities

			#include "Util.cginc"

			struct v2g
			{
				float4 viewPos : SV_POSITION;
				fixed4 wave : TEXCOORD1;
				float3 worldPos : POSITION1;
				//float2 texcoord : TEXCOORD0;
			};

			v2g vert(appdata_base v)
			{
				v2g o;

				o.viewPos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				fixed dist = distance(o.worldPos, _Center);
				fixed d = _Radius - dist;
				o.wave.x = impulse(_WaveSizeA, d);
				o.wave.y = impulse(_WaveSizeB, d);
				o.wave.z = impulse(_WaveSizeC, d);
				o.wave.w = linstep(_Radius - _WaveWidth, _Radius + _WaveWidthB, dist);
				//o.texcoord = v.texcoord;

				return o;
			}

			// inverseW is to counter-act the effect of perspective-correct interpolation so that the lines look the same thickness
			// regardless of their depth in the scene.
			struct g2f
			{
				float4 viewPos : SV_POSITION;
				fixed3 worldPos : POSITION1;
				fixed4 wave : TEXCOORD2;
				float3 N : NORMAL;
				fixed3 bary : TEXCOORD3;
				//fixed fresnel : TEXCOORD4;
				int id : TEXCOORD5;
				//fixed2 texcoord : TEXCOORD6; // uv coords
			};


			[maxvertexcount(6)]
			void geom(triangle v2g i[3], inout TriangleStream<g2f> triStream)
			{

				fixed3 barys[3] = {
					fixed3(1, 0, 0),
					fixed3(0, 1, 0),
					fixed3(0, 0, 1)
				};

				g2f o;


				const fixed rcp3 = 1.0 / 3.0;
				float3 triCenter = (i[0].worldPos.xyz + i[1].worldPos.xyz + i[2].worldPos.xyz) * rcp3; // avg position

				// invent a normal (flat shaded)
				float3 normal = cross(
					i[0].worldPos - i[1].worldPos,
					i[0].worldPos - i[2].worldPos);

				float3 N = normalize(normal);

				fixed maxy = max(max(i[0].wave.y, i[1].wave.y), i[2].wave.y);

				fixed3 maxwaves = max(max(i[0].wave, i[1].wave), i[2].wave);

				fixed waveMax = max(max(maxwaves.x, maxwaves.y), maxwaves.z);

				const fixed cutoff = .15;

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

						//o.texcoord = i[idx].texcoord;

						o.id = 0;

						triStream.Append(o);
					}
				}

				//
				// Second layer
				//

				float3 newPos = 0;  // displaced position

				fixed maxw = max(max(i[0].wave.w, i[1].wave.w), i[2].wave.w);

				if (maxw > 0 && maxw < 1)
				{
					fixed shrinkMask = maxw;
					//fixed pushMask = maxw;

					triStream.RestartStrip();

					fixed3 centerDir = 0;

					[unroll]
					for (uint idx = 0; idx < 3; ++idx)
					{
						// shrink and 'up'
						newPos = lerp(
							i[idx].worldPos,
							triCenter - N * _WaveOffset, shrinkMask);

						// update new vertex position
						o.viewPos = mul(UNITY_MATRIX_MVP, mul(unity_WorldToObject, float4(newPos, 1)));

						o.N = N;
						o.wave = i[idx].wave;
						o.worldPos = i[idx].worldPos;

						// barycentric coordinates
						o.bary = barys[idx];

						o.id = 1; // flag as top layer

						triStream.Append(o);
					}
				}

			}

			fixed4 frag(g2f i) : COLOR
			{
				fixed4 outColor = fixed4(0, 0, 0, 1);

				// make some circles
				fixed dist = dot(i.bary, i.bary);

				// anti alias
				fixed3 fw3 = fwidth(i.bary);
				fixed fw = max(max(fw3.x, fw3.y), fw3.z) * 2;

				// a triangle shape, thin enough looks like wireframe
				const fixed thresh = .1;
				fixed minbary = min(min(i.bary.x, i.bary.y), i.bary.z) * 3;

				fixed3 threshA = i.wave * _BaryThresh + fw;
				fixed3 threshB = i.wave * _BaryThresh - fw;

				fixed3 shape = linstep(threshA, threshB, dist);

				fixed shapeMax = max(max(shape.x, shape.y), shape.z);

				// color the first layer

				fixed3 bottomC = lerp(
					_HazeA,
					shape * _SpotColorA,
					shapeMax);

				bottomC = lerp(bottomC, bottomC + abs(i.N), _NormalMix);

				//bottomC *= i.wave.y;

				fixed3 topC = lerp(
					_HazeB,
					_SpotColorB,
					shapeMax);

				topC = lerp(topC, topC + abs(i.N), _NormalMixB);

				fixed3 jazz = lerp(bottomC, topC, i.id);

				jazz *= i.wave.w;

				// hide the circles in the middle where we tapped
				fixed toCenterDist = distance(i.worldPos, _Center);
				fixed centerMask = linstep(1, .5, toCenterDist);

				// Initialize the final color
				outColor.rgb = jazz;

				// add some FX to localize the tap
				fixed d = _Radius - toCenterDist;
				fixed3 rings = impulse(30, (d - .05));
				rings *= centerMask;
				outColor.rgb = max(outColor.rgb, fixed3(rings));

				// debug
				//outColor.rgb = centerMask;

				return outColor;
			}

			ENDCG
		}
	}
		FallBack "Diffuse"
}
