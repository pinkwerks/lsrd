// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

//
// Copyright (C) Microsoft. All rights reserved.
//

Shader "Surface Reconstruction/Matrix Dot"
{
	Properties
	{
		//[Toggle]_WaxOn("Wax On", Float) = 1

		_Radius("Radius", Range(0, 20)) = 1
		_Center("Center", Vector) = (0, 0, 0, -1)

		_WaveColor("Wave Color", Color) = (1, 1, 1, 1)
		_WireColor("Wire Color", Color) = (1, 1, 1, 1)
		_WireWidth("Wire Width", Range(0, 1)) = .1

		_EdgeColor("Edge Color", Color) = (1, 1, 1, 1)
		_EdgeWidth("Edge Width", Range(0, 1)) = .1

		_Width("Width", Range(0, 2)) = .1
		_Freq("Dot Frequency", Range(0, 100)) = 10

		_Displace("Displace", Range(0,10)) = 1

        _MainTex ("Texture", 2D) = "grey" {}
		//_AlphaCutoff("Alpha cutoff", Range(0,1)) = 0.5

		_KnobOffset ("Knob Offset", Color) = (.5, .5, .5, 1)
			_KnobAmp("Knob Amp", Color) = (.5, .5, .5, 1)
			_KnobFreq("Knob Freq", Color) = (1, 1, 1, 1)
			_KnobPhase("Knob Phase", Color) = (.33, .67, 1, 1)

    }
    
	SubShader
    {
        Tags { 
			"Queue" = "AlphaTest"
			"IgnoreProjector" = "True"
			"RenderType" = "TransparentCutout" 
		}

        Pass
        {
            Offset 50, 100

            CGPROGRAM

            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
			
            #include "UnityCG.cginc"

			fixed _Radius;
			fixed3 _Center;
			fixed _AlphaCutoff;
			fixed _Width;
			fixed4 _WaveColor;
			fixed _Freq;
			fixed _Displace;
			fixed4 _WireColor;
			fixed4 _EdgeColor;
			fixed _EdgeWidth;
			fixed _WireWidth;
			fixed4 _KnobOffset;
			fixed4 _KnobAmp;
			fixed4 _KnobFreq;
			fixed4 _KnobPhase;


            sampler2D _MainTex;

			#include "Util.cginc"

            struct v2g
            {
                float4 viewPos : SV_POSITION;
				float3 worldPos : POSITION1;
                float2 texcoord : TEXCOORD0;
				half3 rand : TEXCOORD1;
            };

            v2g vert(appdata_base v)
            {
                v2g o;
                o.viewPos = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.texcoord = v.texcoord;

				o.rand.r = rand(half2(o.worldPos.x, o.worldPos.y));
				o.rand.g = rand(half2(o.worldPos.y, o.worldPos.z));
				o.rand.b = rand(half2(o.worldPos.z, o.worldPos.x));
				o.rand = o.rand * 2 - 1;

                return o;
            }

            struct g2f
            {
                float4 viewPos : SV_POSITION;
				float3 worldPos : POSITION1;
				float2 texcoord : TEXCOORD0;
				half3 bary : TEXCOORD2;
				half3 rand : TEXCOORD3;

            };

			[maxvertexcount(3)]
			void geom(triangle v2g i[3], inout TriangleStream<g2f> triStream)
			{
				g2f o;

				float3 newPos = 0;
				half3 N_toCenter = 0;

				// invent a normal (flat shaded)
				half3 normal = cross(
					i[0].worldPos - i[1].worldPos,
					i[0].worldPos - i[2].worldPos);


				[unroll]
				for (uint idx = 0; idx < 3; ++idx)
				{

					fixed distToCenter = distance(i[idx].worldPos, _Center);
					fixed radialWipeA = linstep(_Radius, _Radius - _Width, distToCenter);

					N_toCenter = normalize(_Center - i[idx].worldPos);

					half3 jiggle = i[idx].rand;

					// recalc view pos

					newPos = i[idx].worldPos - normal * jiggle * _Displace * radialWipeA;

					o.worldPos = newPos.xyz;

					o.viewPos = UnityObjectToClipPos(mul(unity_WorldToObject, float4(newPos, 1)));

					o.texcoord = i[idx].texcoord;

					o.bary.x = idx == 0;
					o.bary.y = idx == 1;
					o.bary.z = idx == 2;

					o.rand = i[idx].rand;

					triStream.Append(o);
				}
			}

            fixed4 frag(g2f i) : COLOR
            {
                //fixed3 tex = tex2D(_MainTex, i.texcoord).rgb;
				fixed3 tex = 0;

				fixed4 outColor = float4(tex.rgb, 1);

				fixed distToCenter = distance(i.worldPos, _Center);

				fixed radialWipeA = smoothstep(_Radius, _Radius - _Width, distToCenter);
				
				fixed radialWipeB = linstep(1-_EdgeWidth, 1, radialWipeA);

				fixed radialWipeC = linstep(1 - _EdgeWidth, 1, radialWipeA);

				radialWipeB *= radialWipeB;

				fixed radialWipeInv = 1 - radialWipeA;
				radialWipeInv = 1;

				fixed3 off = float3(0, .5 * radialWipeInv, 0);
				const fixed cntr = fixed3(.5, .5, .5);

				// sphere grid
				fixed d1 = distance(frac(i.worldPos * _Freq * radialWipeInv), cntr);

				d1 = 1-smoothstep(0, .6	, d1);
				fixed d2 = distance(frac(i.worldPos * _Freq * radialWipeInv + off), cntr);
				fixed d3 = distance(frac(i.worldPos * _Freq * radialWipeInv + off * 2), cntr);

				// wireframe
				fixed3 fw3 = fwidth(i.bary);
				fixed fw = max(max(fw3.x, fw3.y), fw3.z) * 2;

				fixed minbary = min(min(i.bary.x, i.bary.y), i.bary.z) * 3;

				fixed triShape = linstep(_WireWidth + fw, _WireWidth - fw, minbary);

				//triShape *= radialWipeA;

				// color aberation
				fixed3 aberation = 0;
				aberation.x = linstep(.5, .4, d1);
				aberation.y = linstep(.45, .35, d2);
				aberation.z = linstep(.4, .3, d3);

				// Add wave
				outColor.rgb += radialWipeA * _WaveColor.rgb * aberation;

				// Add edge burn
				//outColor.rgb += radialWipeB * _EdgeColor;

				// Add wireframe
				outColor.rgb += triShape * _WireColor * radialWipeA;

				clip(radialWipeA >= 1 ? -1:1);
				
				float pattern = lerp(minbary, d1, radialWipeA) * (1 - radialWipeB);

				float3 ca = float3(_KnobOffset.x, _KnobOffset.y, _KnobOffset.z);
				float3 cb = float3(_KnobAmp.x, _KnobAmp.y, _KnobAmp.z);
				// these 2 get the most action
				float3 cc = float3(_KnobFreq.x, _KnobFreq.y, _KnobFreq.z);
				// phase gets the most action
				float3 cd = float3(_KnobPhase.x, _KnobPhase.y, _KnobPhase.z);

				//float3 pal = palette(pattern, abs(ca), abs(cb), abs(cc), abs(cd));
				float3 pal = palette(pattern, ca, cb, cc, cd);

				//outColor.rgb = float3(pattern, pattern, pattern);
				
				outColor.rgb = pal;

				//outColor.rgb = radialWipeA;

				float trailMask = smoothstep(.85, 1, radialWipeA);
				float leadMask = smoothstep(.07, 0, radialWipeA);

				outColor.rgb *= 1 - (leadMask + trailMask);

				//outColor.r += radialWipeA;
				/*outColor.r = minbary;
				outColor.b = triShape;
				outColor.g = d1;*/

				//outColor.rgb = fwidth(i.worldPos * 1e2) * radialWipeA;

                return outColor;
            }

            ENDCG
        }
    }

    FallBack "Diffuse"

}