// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

//
// Copyright (C) Microsoft. All rights reserved.
//


Shader "Spatial Mapping/Spatial Mappping Tap"
{
	Properties
	{
		_Radius("Radius", Range(0, 10)) = 1
		_Center("Center", Vector) = (0, 0, 0, -1)
		_PulseColor("Pulse Color", Color) = (.145, .447, .922)
		_PulseWidth("Pulse Width", Range(0, 1)) = 1
		_WireframeColor("Wireframe Color", Color) = (.5, .5, .5)
		_WireframeThick("Wireframe Thick", Range(0, 1)) = .1

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

			fixed _Radius;
			half3 _Center;
			half3 _PulseColor;
			half  _PulseWidth;
			half3 _WireframeColor;
			half  _WireframeThick;

		    // http://www.iquilezles.org/www/articles/functions/functions.htm
			half cubicPulse(half c, half w, half x)
			{
				x = abs(x - c);
				if ( x > w )
					return 0;
				x /= w;
				return 1 - x * x * (3 - 2 * x);
			}

			struct v2g
			{
				half4 viewPos : SV_POSITION;
				fixed3 color : COLOR;
			};

			v2g vert(appdata_base v)
			{
				v2g o;

				o.viewPos = UnityObjectToClipPos(v.vertex);
				float4 worldPos = mul(unity_ObjectToWorld, v.vertex);

				half distToCenter = distance(_Center, worldPos.xyz);
				
				half pulse = cubicPulse(_Radius, _PulseWidth, distToCenter);

				o.viewPos = UnityObjectToClipPos(worldPos);

				o.color = pulse * _PulseColor;

				return o;
			}

			struct g2f
			{
				float4 viewPos : SV_POSITION;
				half3 color : TEXCOORD1;
				half3 bary : TEXCOORD2;
			};

			[maxvertexcount(3)]
			void geom(triangle v2g i[3], inout TriangleStream<g2f> triStream)
			{
				half3 barys[3] = {
					half3(1, 0, 0),
					half3(0, 1, 0),
					half3(0, 0, 1)
				};

				g2f o;

				[unroll]
				for (uint idx = 0; idx < 3; ++idx)
				{
					o.viewPos = i[idx].viewPos;
					o.bary = barys[idx];
					o.color = i[idx].color;
					triStream.Append(o);
				}
			}

			half4 frag(g2f i) : COLOR
			{
				half d = dot(i.bary, i.bary);
				half3 fw3 = fwidth(i.bary);
				half fw = max(max(fw3.x, fw3.y), fw3.z);
				half triBary = min( min(i.bary.x, i.bary.y), i.bary.z) * 3;
				half w = smoothstep(fw * 2, 0, triBary - _WireframeThick);
				half3 result = w * i.color;
				return half4(result, 1);
			}

			ENDCG
		}
	}
	
	FallBack "Diffuse"
}

