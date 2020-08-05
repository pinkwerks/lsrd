// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

//
// Copyright (C) Microsoft. All rights reserved.
//


Shader "Surface Reconstruction/Curl"
{
	Properties
	{
		_Radius("Radius", Range(0, 10)) = 1
		_Center("Center", Vector) = (0, 0, 0, -1)
		_Offset("Offset", Range(-1, 1)) = .1
		_Axis("Axis", Vector) = (0,1,0)
		_Angle("Angle", Float) = 3

		_RampOff("Ramp Offset", Vector) = (.5, .5, .5)
		_RampAmp("Ramp Amplitude", Vector) = (.5, .5, .5)
		_RampFreq("Ramp Frequency", Vector) = (1, 1, 1)
		_RampPhase("Ramp Phase", Vector) = (0, .333, .666)

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
			#include "Util.cginc"

			fixed _Radius;
			half3 _Center;
			half3 _Offset;
			half3 _Axis;
			half _Angle;

			half3 _RampOff;
			half3 _RampAmp;
			half3 _RampFreq;
			half3 _RampPhase;

			float4x4 _Rotation;

			half3 colorWave(float x)
			{
				return palette(x, _RampOff, _RampAmp, _RampFreq, _RampPhase);
			}

			struct v2g
			{
				half4 viewPos : SV_POSITION;
				float3 worldPos : POSITION1;
				//float3 rotPos : POSITION2;
				half3 N : NORMAL;
				fixed4 color : COLOR;
			};

			v2g vert(appdata_base v)
			{
				v2g o;

				float4 worldPos = mul(unity_ObjectToWorld, v.vertex);

				half3 axis = normalize(_Center - _WorldSpaceCameraPos);

				half distToCenter = distance(_Center, worldPos.xyz);
				
				half d = _Radius - distToCenter;

				half wave = cubicPulse(_Radius, 1, distToCenter);

				// lift
				float raiseAmt = _Offset * distToCenter;
				float4 raisedPos = v.vertex - float4(0, raiseAmt, 0, 0);

				// spin
				half angle = rsqrt(distToCenter);
				half4x4 R = rotationMatrix(axis, _Angle);				
				float4 rotatedPos = mul(R, raisedPos);

				float mask = smoothstep(_Radius, 0, distToCenter);

				float4 newPos = lerp(worldPos, rotatedPos, wave);

				// Populate the vertex values
				o.viewPos = UnityObjectToClipPos(newPos);
				o.worldPos = newPos.xyz;
				o.N = v.normal;
				o.color = half4(colorWave(wave), 1) * wave;
				o.color = wave;

				return o;
			}

			struct g2f
			{
				half4 viewPos : SV_POSITION;
				float3 worldPos : POSITION1;
				half3 N : NORMAL;
				int id : TEXCOORD1;
				fixed4 color : COLOR;
			};

			[maxvertexcount(6)]
			void geom(triangle v2g i[3], inout TriangleStream<g2f> triStream)
			{

				g2f o;

				// invent a normal (flat shaded)
				//fixed3 normal = cross(
					//i[0].worldPos - i[1].worldPos,
					//i[0].worldPos - i[2].worldPos);

				//fixed3 N = normalize(normal);

				const fixed cutoff = .15;

				//	if (waveMax > cutoff)
					{
						[unroll]
						for (uint idx = 0; idx < 3; ++idx)
						{
							o.N = i[idx].N;
							o.worldPos = i[idx].worldPos;
							o.viewPos = i[idx].viewPos;
							o.id = 0;
							o.color = i[idx].color;
							triStream.Append(o);
						}
					}

					//
					// Second layer
					//

					float3 newPos = 0;  // displaced position

					//fixed maxw = max(max(i[0].wave.w, i[1].wave.w), i[2].wave.w);
					fixed maxw = 1;

					if (maxw > 0 && maxw < 1 && true == false)
					{
						fixed shrinkMask = maxw;
						//fixed pushMask = maxw;

						triStream.RestartStrip();

						fixed3 centerDir = 0;

						const fixed rcp3 = 1.0 / 3.0;
						float3 triCenter = (i[0].worldPos.xyz + i[1].worldPos.xyz + i[2].worldPos.xyz) * rcp3; // avg position

						[unroll]
						for (uint idx = 0; idx < 3; ++idx)
						{
							// shrink and 'up'
							newPos = lerp(
								i[idx].worldPos,
								triCenter - i[idx].N * _Offset, shrinkMask);

							// update new vertex position
							o.viewPos = UnityObjectToClipPos(mul(unity_WorldToObject, float4(newPos, 1)));

							o.N = i[idx].N;
							o.worldPos = i[idx].worldPos;
							o.id = 1; // flag as top layer
							o.color = i[idx].color;

							triStream.Append(o);
						}
					}
				}

				fixed4 frag(g2f i) : COLOR
				{
					fixed4 outColor = fixed4(i.N, 1);

					// hide the circles in the middle where we tapped
					fixed toCenterDist = distance(i.worldPos, _Center);

					// add some FX to localize the tap
					fixed d = _Radius - toCenterDist;
					fixed3 rings = impulse(5, (d - .05));
					outColor.rgb += rings;

					outColor.rgb = i.color.rgb;
					return outColor;
				}

				ENDCG
			}
	}
		FallBack "Diffuse"
}

