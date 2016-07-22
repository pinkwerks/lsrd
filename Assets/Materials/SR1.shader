// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

//
// Copyright (C) Microsoft. All rights reserved.
//

Shader "Surface Reconstruction/LSRD"
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
        /*
        _Offset("Offset", Vector) = (0, 0, 0, -1)
        _Amp("Amp", Vector) = (1, 1, 1, -1)
        _Freq("Freq", Vector) = (.25, .5, .25, -1)
        _Phase("Phase", Vector) = (-.25, -.25, -.25, -1)

        */
        _SpotColorA("SpotColorA", Color) = (1, 1, 1, 1)
        _SpotColorB("SpotColorB", Color) = (0, 0, 0, 1)

        _HazeA("HazeA", Color) = (.1, .1, 0, 1)
        _HazeB("HazeB", Color) = (.1, 0, .1, 1)

        // well slow me down
        // not good for hololens

        //_MainTex ("Texture", 2D) = "white" {} 


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

			fixed linstep(fixed a, fixed b, fixed x)
			{
				return saturate((x - a) / (b - a));
			}

			fixed3 linstep(fixed3 a, fixed3 b, fixed x)
			{
				return saturate((x - a) / (b - a));
			}

            fixed impulse(fixed k, fixed x)
            {
                fixed h = k * x;
                return saturate(h * exp(1.0f - h));
            }

            fixed3 palette(fixed t, fixed3 a, fixed3 b, fixed3 c, fixed3 d)
            {
                return a + b * cos(6.28318 * (c * t + d));
            }

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

                g2f o;

                const fixed cutoff = .15;

                const fixed rcp3 = 1.0 / 3.0;
                float3 triCenter = (i[0].worldPos.xyz + i[1].worldPos.xyz + i[2].worldPos.xyz) * rcp3;

                uint idx = 0;  // counter for loops

                float3 newPos = 0;  // displaced position

                // invent a normal (flat shaded)
                float3 normal = cross(
                    i[0].worldPos - i[1].worldPos,
                    i[0].worldPos - i[2].worldPos);

                float3 N = normalize(normal);

                fixed maxy = max(max(i[0].wave.y, i[1].wave.y), i[2].wave.y);

                if (maxy > cutoff)
                {
                    [unroll]
                    for (idx = 0; idx < 3; ++idx)
                    {
 
                        o.N = N;
                        o.wave = i[idx].wave;
                        o.worldPos = i[idx].worldPos;
                        o.viewPos = i[idx].viewPos;

                        // barycentric
                        o.bary.x = idx == 0;
                        o.bary.y = idx == 1;
                        o.bary.z = idx == 2;

                        //o.texcoord = i[idx].texcoord;
                        
                        o.id = 0;

                        triStream.Append(o);
                    }
                }

                //
                // Second layer
                //

                fixed maxw = max(max(i[0].wave.w, i[1].wave.w), i[2].wave.w);

                if (maxw > 0 && maxw < 1)
                {
                    fixed shrinkMask = maxw;
                    //fixed pushMask = maxw;

                    triStream.RestartStrip();

                    fixed3 centerDir = 0;

                    [unroll]
                    for (idx = 0; idx < 3; ++idx)
                    {
                        // shrink and 'up'
                        newPos = lerp(
                            i[idx].worldPos,
                            triCenter - N * _WaveOffset, shrinkMask);

                        //newPos = i[idx].worldPos;

                        // pushout
                        //newPos -= N * _WaveOffset * pushMask;

                        // update new vertex position
                        o.viewPos = mul(UNITY_MATRIX_MVP, mul(unity_WorldToObject, float4(newPos, 1)));

                        o.N = N;
                        o.wave = i[idx].wave;
                        o.worldPos = i[idx].worldPos;

                        // barycentric coordinates
                        o.bary.x = idx == 0;
                        o.bary.y = idx == 1;
                        o.bary.z = idx == 2;

						//o.texcoord = i[idx].texcoord;

                        o.id = 1;

                        triStream.Append(o);
                    }
                }
                
            }

            fixed4 frag(g2f i) : COLOR
            {
                //fixed mask = max(i.wave.x, i.wave.y);
                //fixed3 tex = tex2D(_MainTex, i.texcoord).rgb;

                fixed4 outColor = fixed4(0, 0, 0, 1);

                // make some circles
                fixed dist = dot(i.bary, i.bary);
				

                fixed3 fw3 = fwidth(i.bary);

                fixed fw = max(max(fw3.x, fw3.y), fw3.z) * 2;
				
				// wireframe
				const fixed thresh = .1;
				fixed minbary = min(min(i.bary.x, i.bary.y), i.bary.z) * 3;
				fixed triShape = linstep(thresh + fw, thresh - fw, minbary);
                
				fixed3 threshA = i.wave * _BaryThresh + fw;
				fixed3 threshB = i.wave * _BaryThresh - fw;

                fixed3 shape = linstep(threshA, threshB, dist);

                fixed3 baryColor = float3(shape.x, shape.y, shape.z);

                /*
                fixed3 pal = palette(b2,
                    _Offset,
                    _Amp,
                    _Freq,
                    _Phase);
                    */

                fixed shapeMax = max(max(shape.x, shape.y), shape.z);

                fixed3 c1 = lerp(
                    _HazeA,
                    baryColor * _SpotColorA,                    
                    shapeMax);

                c1 = lerp(c1, c1 + abs(i.N), _NormalMix);

                c1 *= i.wave.y;

                fixed3 c2 = lerp(
                    _HazeB, 
                    _SpotColorB,
                    shapeMax);

                c2 = lerp(c2, c2 + abs(i.N), _NormalMixB);

                c2 *= i.wave.w * 2; // 2 to compensate for wave brightness

                float3 jazz = lerp(c1, c2, i.id);


                //outColor.rgb = lerp(tex, jazz, shapeMax);

                //outColor.rgb = shapeMax;

                //outColor.rgb = i.wave.w;

                //outColor.rgb = abs(i.N);

                //outColor.rgb = i.wave.z;

				// hide the circles in the middle where we tapped
				fixed toCenterDist = distance(i.worldPos, _Center);
				
				fixed centerMask = linstep(1,.1,toCenterDist);
				
				//centerMask *= centerMask;
				
				outColor.rgb = jazz;

				//outColor.rgb *= 1 - centerMask;

				// add some fx to localize the tap
				// rings + wireframe

				fixed d = _Radius - toCenterDist;
//				fixed3 rings = impulse(50, (d - .05) % .75);// *abs(i.N);
				fixed3 rings = impulse(40, (d - .05));// *abs(i.N);

				// add some wireframe look
				rings += triShape * rings;
				rings *= centerMask;
				
				outColor.rgb += rings;

				//outColor.rgb = centerMask;

				//outColor.rgb = centerMask;

				//outColor.rgb += tex;

				//outColor.rgb = jazz;

                return outColor;
            }

            ENDCG
        }
    }
        FallBack "Diffuse"
}