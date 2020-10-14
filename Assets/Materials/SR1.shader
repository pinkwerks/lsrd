
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

		//_WaveWidthBack("Wave Width Back", Range(-5, 5)) = 1
		_WaveWidthFront("Wave Width Front", Range(-5, 5)) = 1

		_BaryThresh("Bary Threshold", Range(0, 1)) = 1

		_BottomSpotColorA("SpotColorA", Color) = (1, 1, 0, 1)
		_SpotColorB("SpotColorB", Color) = (0, 1, 1, 1)
		_SpotColorC("SpotColorC", Color) = (1, 0, 1, 1)

		_WaveColorTop("Wave Color Top", Color) = (.1, .0, .1, 1)
		_WaveColorBottom("Wave Color Bottom", Color) = (.1, .1, .0, 1)

		_NormalMix("Normal Mix", Range(0, 1)) = 0
		_NormalMixB("Normal MixB", Range(0, 1)) = 0

		_CenterMaskStart("Center Mask Start", Range(0, 1)) = 0
		_CenterMaskEnd("Center Mask End", Range(0, 1)) = .5

		_Laydown("Laydown", Range(0, 10)) = 1

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

#define DEBUG 0

			half4 _BaseColor;
			half4 _WireColor;
			half _WireThickness;

			half3 _Center;
			half _Radius;
			half _WaveOffset;
			half _WaveTightnessA;
			half _WaveTightnessB;
			half _WaveTightnessC;
			half _WaveWidthFront;
			//half _WaveWidthBack;

			half _BaryThresh;
			half4 _BottomSpotColorA;
			half4 _SpotColorB;

			half4 _WaveColorTop;
			half4 _WaveColorBottom;

			half _NormalMix;
			half _NormalMixB;

			half _CenterMaskStart;
			half _CenterMaskEnd;

			half _Laydown;

			//UNITY_INSTANCING_BUFFER_START(Props)
			//	UNITY_DEFINE_INSTANCED_PROP(half3, _Center)
			//	UNITY_DEFINE_INSTANCED_PROP(half, _Radius)
			//	UNITY_DEFINE_INSTANCED_PROP(half, _WaveOffset)
			//	UNITY_DEFINE_INSTANCED_PROP(half, _WaveTightnessA)
			//	UNITY_DEFINE_INSTANCED_PROP(half, _WaveTightnessB)
			//	UNITY_DEFINE_INSTANCED_PROP(half, _WaveTightnessC)
			//	UNITY_DEFINE_INSTANCED_PROP(half, _WaveWidth)
			//	UNITY_DEFINE_INSTANCED_PROP(half, _WaveWidthB)

			//	UNITY_DEFINE_INSTANCED_PROP(half, _BaryThresh)
			//	UNITY_DEFINE_INSTANCED_PROP(half4, _BottomSpotColorA)
			//	UNITY_DEFINE_INSTANCED_PROP(half4, _SpotColorB)
			//	UNITY_DEFINE_INSTANCED_PROP(half4, _WaveColorBottom)
			//	UNITY_DEFINE_INSTANCED_PROP(half4, _WaveBColor)
			//	UNITY_DEFINE_INSTANCED_PROP(half, _NormalMix)
			//	UNITY_DEFINE_INSTANCED_PROP(half, _NormalMixB)
			//UNITY_INSTANCING_BUFFER_END(Props)

			#include "Util.cginc"

			struct v2g
			{
				float4 viewPos : SV_POSITION;
				half3 wave : TEXCOORD1;
				float3 worldPos : POSITION1;
				//half3 color : TEXCOORD2;
				half laydown : TEXCOORD3;
				//UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			struct g2f
			{
				float4 viewPos : SV_POSITION;
				float3 worldPos : POSITION1;
				half3 wave : TEXCOORD2;
				half3 N : NORMAL;
				half3 bary : TEXCOORD3;
				//half3 color : TEXCOORD4;
				int id : TEXCOORD5;
				//UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2g vert(appdata_base i)
			{
				v2g o;

				// https://docs.unity3d.com/Manual/SinglePassInstancing.html
				UNITY_SETUP_INSTANCE_ID(i);
				//UNITY_INITIALIZE_OUTPUT(v2g, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				//UNITY_TRANSFER_INSTANCE_ID(i, o);

				o.viewPos = UnityObjectToClipPos(i.vertex);
				o.worldPos = mul(unity_ObjectToWorld, i.vertex).xyz;

				//half3 center = UNITY_ACCESS_INSTANCED_PROP(Props, _Center);
				half3 center = _Center;

				half dist = distance(o.worldPos, center);

				//half radius = UNITY_ACCESS_INSTANCED_PROP(Props, _Radius);
				//half radius = _Radius;

				half d = max(0, _Radius - dist);
				o.laydown = smoothstep(_Laydown, 0, d);

				//half waveSizeA = UNITY_ACCESS_INSTANCED_PROP(Props, _WaveTightnessA);
				//half waveSizeB = UNITY_ACCESS_INSTANCED_PROP(Props, _WaveTightnessB);
				//half waveSizeC = UNITY_ACCESS_INSTANCED_PROP(Props, _WaveTightnessC);
				//half waveWidth = UNITY_ACCESS_INSTANCED_PROP(Props, _WaveWidth);
				//half waveWidthB = UNITY_ACCESS_INSTANCED_PROP(Props, _WaveWidthB);

				//half waveSizeA = _WaveTightnessA;
				//half waveSizeB = _WaveTightnessB;
				//half waveSizeC = _WaveTightnessC;
				//half waveWidth = _WaveWidth;
				//half waveWidthB = _WaveWidthB;

				o.wave.x = expImpulse(d, _WaveTightnessA);
				o.wave.y = expImpulse(d, _WaveTightnessB);
				o.wave.z = expImpulse(d, _WaveTightnessC);
				//o.wave.w = linstep(radius - _WaveWidthFront, radius + _WaveTightnessB, dist);
				//o.texcoord = v.texcoord;
				//o.color = o.wave;
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
				//UNITY_INITIALIZE_OUTPUT(g2f, o);
				//UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				//UNITY_TRANSFER_INSTANCE_ID(i, o);

				//UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(i[0], o);

				const float rcp3 = 1.0 / 3.0;
				float3 triCenter = (i[0].worldPos.xyz + i[1].worldPos.xyz + i[2].worldPos.xyz) * rcp3; // avg position

				// invent a normal (flat shaded)
				float3 normal = cross(
					i[0].worldPos - i[1].worldPos,
					i[0].worldPos - i[2].worldPos);

				float3 N = normalize(normal);

				//half maxy = max(max(i[0].wave.y, i[1].wave.y), i[2].wave.y);

				half3 maxwaves = max(max(i[0].wave, i[1].wave), i[2].wave);

				half waveMax = max(max(maxwaves.x, maxwaves.y), maxwaves.z);

				const half cutoff = .1;

				//
				// First layer
				//

//#if !DEBUG
				if (waveMax > cutoff)
				{
//#endif
					[unroll]
					for (uint idx = 0; idx < 3; ++idx)
					{

						o.N = N;
						o.wave = i[idx].wave;
						o.worldPos = i[idx].worldPos;
						o.viewPos = i[idx].viewPos;

						// barycentric
						o.bary = barys[idx];
						//o.color = half3(waveMax, 0, 0);

						//o.texcoord = i[idx].texcoord;

						o.id = 0; // flag bottom layer
						UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(i[idx], o);
						triStream.Append(o);
					}
//#if !DEBUG
				}
//#endif

				//
				// Second layer
				//

				float3 newPos = 0;  // displaced position

				//half maxw = max(max(i[0].wave.w, i[1].wave.w), i[2].wave.w);

				//float waveOffset = UNITY_ACCESS_INSTANCED_PROP(Props, _WaveOffset);
				//float waveOffset = _WaveOffset;

				if (waveMax > cutoff)// && waveMax < 1)
				{
					//half shrinkMask = waveMax;

					triStream.RestartStrip();

					//half3 centerDir = 0;

					[unroll]
					for (uint jdx = 0; jdx < 3; ++jdx)
					{
						// shrink and 'up'
						//newPos = lerp(
						//	i[jdx].worldPos,
						//	triCenter + (N * _WaveOffset), waveMax);

						newPos = lerp(
							i[jdx].worldPos,
							triCenter + (N * _WaveOffset), i[jdx].laydown);

						//newPos = lerp(
						//	i[jdx].worldPos,
						//	triCenter, waveMax);

						//newPos += N * _WaveOffset * waveMax;

						//newPos = i[jdx].worldPos + (N * _WaveOffset) * i[jdx].laydown;
						// update new vertex position
						o.viewPos = UnityObjectToClipPos(mul(unity_WorldToObject, float4(newPos, 1)));

						o.N = N;
						o.wave = i[jdx].wave;
						o.worldPos = i[jdx].worldPos;
						//o.color = half3(shrinkMask, shrinkMask, shrinkMask);
						//o.color = ceil(i[jdx].color);
						//o.color.rb = 0;

						// barycentric coordinates
						o.bary = barys[jdx];

						o.id = 1; // flag as top layer

						UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(i[jdx], o);
//#if !DEBUG
						triStream.Append(o);
//#endif
					}
				}
			}

			half4 frag(g2f i) : COLOR
			{
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
				//UNITY_SETUP_INSTANCE_ID(i);

				half4 outColor = half4(0, 0, 0, 1);

				// make some circles
				const float onethird = 1.0 / 3.0;
				half baryDist = dot(i.bary, i.bary);
				baryDist = linstep(onethird, 1, baryDist);

				// anti alias
				half3 fw3 = fwidth(i.bary);
				half fw = max(max(fw3.x, fw3.y), fw3.z);

				// a triangle shape, thin enough looks like wireframe
				half minbary = min(min(i.bary.x, i.bary.y), i.bary.z);
				half wireframe = smoothstep(fw3, 0, minbary);

				//half baryThresh = UNITY_ACCESS_INSTANCED_PROP(Props, _BaryThresh);

				half thresh = i.wave.x * onethird;
				half3 baryEllipse = smoothstep(thresh, thresh - fw, baryDist);

				//half shapeMax = max(max(baryEllipse.x, baryEllipse.y), baryEllipse.z);

				// color the first layer

				//half4 waveAColor = UNITY_ACCESS_INSTANCED_PROP(Props, _WaveColorBottom);
				//half4 waveBColor = UNITY_ACCESS_INSTANCED_PROP(Props, _WaveBColor);
				//half4 spotColorA = UNITY_ACCESS_INSTANCED_PROP(Props, _BottomSpotColorA);
				//half4 spotColorB = UNITY_ACCESS_INSTANCED_PROP(Props, _SpotColorB);
				//half4 normalMix = UNITY_ACCESS_INSTANCED_PROP(Props, _NormalMix);
				//half4 normalMixB = UNITY_ACCESS_INSTANCED_PROP(Props, _NormalMixB);

				//half4 waveAColor = _WaveColorBottom;
				//half4 waveBColor = _WaveColorB;
				//half4 spotColorA = _BottomSpotColorA;
				//half4 spotColorB = _SpotColorB;
				//half normalMix = _NormalMix;
				//half normalMixB = _NormalMixB;

				half3 bottomC = lerp(
					_WaveColorBottom,
					_BottomSpotColorA * (1 - baryDist),
					baryEllipse);

				// OG
				half3 magic = i.wave.x * .2;
				half3 baryColor = linstep(magic + fw, magic - fw, baryDist);
				//bottomC = baryColor * baryEllipse;
				bottomC = lerp(_WaveColorBottom * i.wave.x, baryColor, baryEllipse);

				half3 topC = max(max(i.wave.x, i.wave.y), i.wave.z) * _WaveColorTop;
				topC *= 1 - wireframe;


				//topC = lerp(topC, topC + abs(i.N), _NormalMixB);

				half3 jazz = lerp(bottomC, topC, i.id);

				//jazz *= i.wave.z;

				// hide the circles in the middle where we tapped

				//half3 center = UNITY_ACCESS_INSTANCED_PROP(Props, _Center);
				//half3 center = ;

				half toCenterDist = distance(i.worldPos, _Center);
				half centerMask = smoothstep(_CenterMaskEnd, _CenterMaskStart, toCenterDist);

				// Initialize the final color
				outColor.rgb = jazz;

				// add some FX to localize the tap
				//half radius = UNITY_ACCESS_INSTANCED_PROP(Props, _Radius);
				//half radius = _Radius;

				half d = _Radius - toCenterDist;
				half3 rings = expImpulse((d - .05), 30);
				rings *= centerMask;

				outColor.rgb = max(outColor.rgb, half3(rings));

//#if DEBUG
				//outColor.rgb = topC;
//#endif

				return outColor;
			}

			ENDCG
		}
	}
		FallBack "Diffuse"
}
