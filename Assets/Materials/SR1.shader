// https://forum.unity.com/threads/is-it-possible-to-have-gpu-instancing-with-geometry-shader.898070/

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
			//Offset 50, 100

			CGPROGRAM

			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag

			#pragma multi_compile_instancing

			#include "UnityCG.cginc"

			//half4 _BaseColor;
			//half4 _WireColor;
			//half _WireThickness;
			//half _Radius;
			//half3 _Center;
			//half _WaveSizeA;
			//half _WaveSizeB;
			//half _WaveSizeC;
			//half _WaveOffset;
			//half _WaveWidth;
			//half _WaveWidthB;

			//half _BaryThresh;
			//half3 _Offset;
			//half3 _Amp;
			//half3 _Freq;
			//half3 _Phase;
			/*half4 _SpotColorA;
			half4 _SpotColorB;
			half4 _HazeA;
			half4 _HazeB;
			half _NormalMix;
			half _NormalMixB;*/

			UNITY_INSTANCING_BUFFER_START(Props)
				UNITY_DEFINE_INSTANCED_PROP(half3, _Center)
				UNITY_DEFINE_INSTANCED_PROP(half, _Radius)
				UNITY_DEFINE_INSTANCED_PROP(half, _WaveOffset)
				UNITY_DEFINE_INSTANCED_PROP(half, _WaveSizeA)
				UNITY_DEFINE_INSTANCED_PROP(half, _WaveSizeB)
				UNITY_DEFINE_INSTANCED_PROP(half, _WaveSizeC)
				UNITY_DEFINE_INSTANCED_PROP(half, _WaveWidth)
				UNITY_DEFINE_INSTANCED_PROP(half, _WaveWidthB)

				UNITY_DEFINE_INSTANCED_PROP(half, _BaryThresh)
				UNITY_DEFINE_INSTANCED_PROP(half, _SpotColorA)
				UNITY_DEFINE_INSTANCED_PROP(half, _SpotColorB)
				UNITY_DEFINE_INSTANCED_PROP(half, _HazeA)
				UNITY_DEFINE_INSTANCED_PROP(half, _HazeB)
				UNITY_DEFINE_INSTANCED_PROP(half, _NormalMix)
				UNITY_DEFINE_INSTANCED_PROP(half, _NormalMixB)

			UNITY_INSTANCING_BUFFER_END(Props)

			//sampler2D _MainTex;

			// utilities

			#include "Util.cginc"

			struct v2g
			{
				float4 viewPos : SV_POSITION;
				half4 wave : TEXCOORD1;
				float3 worldPos : POSITION1;
				//float2 texcoord : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct g2f
			{
				float4 viewPos : SV_POSITION;
				float3 worldPos : POSITION1;
				half4 wave : TEXCOORD2;
				half3 N : NORMAL;
				half3 bary : TEXCOORD3;
				//half fresnel : TEXCOORD4;
				int id : TEXCOORD5;
				//half2 texcoord : TEXCOORD6; // uv coords
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			v2g vert(appdata_base v)
			{
				v2g o;

				// https://docs.unity3d.com/Manual/SinglePassInstancing.html
				UNITY_INITIALIZE_OUTPUT(v2g, o);
				UNITY_SETUP_INSTANCE_ID(v);
				//UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				o.viewPos = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

				half center = UNITY_ACCESS_INSTANCED_PROP(Props, _Center);

				half dist = distance(o.worldPos, center);

				half radius = UNITY_ACCESS_INSTANCED_PROP(Props, _Radius);

				half d = radius - dist;

				half waveSizeA = UNITY_ACCESS_INSTANCED_PROP(Props, _WaveSizeA);
				half waveSizeB = UNITY_ACCESS_INSTANCED_PROP(Props, _WaveSizeB);
				half waveSizeC = UNITY_ACCESS_INSTANCED_PROP(Props, _WaveSizeC);
				half waveWidth = UNITY_ACCESS_INSTANCED_PROP(Props, _WaveWidth);
				half waveWidthB = UNITY_ACCESS_INSTANCED_PROP(Props, _WaveWidthB);

				o.wave.x = impulse(waveSizeA, d);
				o.wave.y = impulse(waveSizeB, d);
				o.wave.z = impulse(waveSizeC, d);
				o.wave.w = linstep(radius - waveWidth, radius + waveWidthB, dist);
				//o.texcoord = v.texcoord;

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

				UNITY_INITIALIZE_OUTPUT(g2f, o);
				UNITY_SETUP_INSTANCE_ID(i[0]);
				UNITY_TRANSFER_INSTANCE_ID(i[0], o);

				const half rcp3 = 1.0 / 3.0;
				float3 triCenter = (i[0].worldPos.xyz + i[1].worldPos.xyz + i[2].worldPos.xyz) * rcp3; // avg position

				// invent a normal (flat shaded)
				float3 normal = cross(
					i[0].worldPos - i[1].worldPos,
					i[0].worldPos - i[2].worldPos);

				float3 N = normalize(normal);

				half maxy = max(max(i[0].wave.y, i[1].wave.y), i[2].wave.y);

				half3 maxwaves = max(max(i[0].wave, i[1].wave), i[2].wave);

				half waveMax = max(max(maxwaves.x, maxwaves.y), maxwaves.z);

				const half cutoff = .01; // was .15

				//if (waveMax > cutoff)
				//{
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
				//}

				//
				// Second layer
				//

				float3 newPos = 0;  // displaced position

				half maxw = max(max(i[0].wave.w, i[1].wave.w), i[2].wave.w);

				float waveOffset = UNITY_ACCESS_INSTANCED_PROP(Props, _WaveOffset);

				//if (maxw > 0 && maxw < 1)
				//{
					half shrinkMask = maxw;
					//half pushMask = maxw;

					triStream.RestartStrip();

					half3 centerDir = 0;

					[unroll]
					for (uint jdx = 0; jdx < 3; ++jdx)
					{
						// shrink and 'up'
						newPos = lerp(
							i[jdx].worldPos,
							triCenter - N * waveOffset, shrinkMask);

						// update new vertex position
						o.viewPos = UnityObjectToClipPos(mul(unity_WorldToObject, float4(newPos, 1)));

						o.N = N;
						o.wave = i[jdx].wave;
						o.worldPos = i[jdx].worldPos;

						// barycentric coordinates
						o.bary = barys[jdx];

						o.id = 1; // flag as top layer

						triStream.Append(o);
					}
				//}
			}

			half4 frag(g2f i) : COLOR
			{
				UNITY_SETUP_INSTANCE_ID(i);

				half4 outColor = half4(0, 0, 0, 1);

				// make some circles
				half dist = dot(i.bary, i.bary);

				// anti alias
				half3 fw3 = fwidth(i.bary);
				half fw = max(max(fw3.x, fw3.y), fw3.z) * 2;

				// a triangle shape, thin enough looks like wireframe
				const half thresh = .1;
				half minbary = min(min(i.bary.x, i.bary.y), i.bary.z) * 3;

				half baryThresh = UNITY_ACCESS_INSTANCED_PROP(Props, _BaryThresh);

				half3 threshA = i.wave * baryThresh + fw;
				half3 threshB = i.wave * baryThresh - fw;

				half3 shape = linstep(threshA, threshB, dist);

				half shapeMax = max(max(shape.x, shape.y), shape.z);

				// color the first layer

				half hazeA = UNITY_ACCESS_INSTANCED_PROP(Props, _HazeA);
				half hazeB = UNITY_ACCESS_INSTANCED_PROP(Props, _HazeB);
				half spotColorA = UNITY_ACCESS_INSTANCED_PROP(Props, _SpotColorA);
				half spotColorB = UNITY_ACCESS_INSTANCED_PROP(Props, _SpotColorB);
				half normalMix = UNITY_ACCESS_INSTANCED_PROP(Props, _NormalMix);
				half normalMixB = UNITY_ACCESS_INSTANCED_PROP(Props, _NormalMixB);

				half3 bottomC = lerp(
					hazeA,
					shape * spotColorA,
					shapeMax);

				bottomC = lerp(bottomC, bottomC + abs(i.N), normalMix);

				//bottomC *= i.wave.y;

				half3 topC = lerp(
					hazeB,
					spotColorB,
					shapeMax);

				topC = lerp(topC, topC + abs(i.N), normalMixB);

				half3 jazz = lerp(bottomC, topC, i.id);

				jazz *= i.wave.w;

				// hide the circles in the middle where we tapped

				half center = UNITY_ACCESS_INSTANCED_PROP(Props, _Center);

				half toCenterDist = distance(i.worldPos, center);
				half centerMask = linstep(1, .5, toCenterDist);

				// Initialize the final color
				outColor.rgb = jazz;

				// add some FX to localize the tap
				half radius = UNITY_ACCESS_INSTANCED_PROP(Props, _Radius);

				half d = radius - toCenterDist;
				half3 rings = impulse(30, (d - .05));
				rings *= centerMask;
				outColor.rgb = max(outColor.rgb, half3(rings));

				// debug
				outColor.rgb = lerp(float3(.5,.5,0), float3(0,.5,.5), i.wave.x);

				return outColor;
			}

			ENDCG
		}
	}
		FallBack "Diffuse"
}
