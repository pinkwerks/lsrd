// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Studio"
{
	Properties
	{
		// we have removed support for texture tiling/offset,
		// so make them not be displayed in material inspector
		//[NoScaleOffset] _MainTex("Texture", 2D) = "white" {}

		_Intensity("Sky Intensity", Float) = 1
		_FresnelMin("Reflection Minimum", Range(0,1)) = 0.1
		_FresnelMax("Reflection Edge", Range(0,1)) = 1


			_GroundRefl("Grounding", Float) = 0.5

		//_Far("Far", Float) = 10

		_Base("Albedo", Color) = (0.2, 0.4, 0.2, 1)

		_Ground("Ground", Color) = (0, 0, 0, 1)
		_Sky("Sky", Color) = (1, 1, 1, 1)
		_ReflColor("Reflection", Color) = (1, 1, 1, 1)


		//	_PlaneOrigin("Plane Origin", Vector) = (0, 0, 0)
			_PlaneNormal("Sky Dir (normalized)", Vector) = (0, 1, 0)
	}

	SubShader
	{
		Pass
		{


		CGPROGRAM
		// use "vert" function as the vertex shader
#pragma vertex vert
		// use "frag" function as the pixel (fragment) shader
#pragma fragment frag

		float _Intensity;
		float _FresnelMin;
		float _FresnelMax;

		float _GroundRefl;
		//float _Far;
		float3 _PlaneNormal;
		//	float3 _PlaneOrigin;
			float4 _Ground;
			float4 _ReflColor;
			float4 _Sky;
			float4 _Base;


			// vertex shader inputs
			struct appdata
			{
			float4 vertex : POSITION; // vertex position
			float2 uv : TEXCOORD0; // texture coordinate
			float3 normal : NORMAL;
			};

			// vertex shader outputs ("vertex to fragment")
			struct v2f
			{
				float2 uv : TEXCOORD0; // texture coordinate
				float4 vertex : SV_POSITION; // clip space position
				float4 vertexWS : VERTEXWS;
				float3 normalWS : NORMALWS;
				float4 color : COLOR;
				float fresnel : TEXCOORD1;
			};

			// vertex shader
			v2f vert(appdata v)
			{
				v2f o;
				// transform position to clip space
				// (multiply with model*view*projection matrix)
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.vertexWS = mul(unity_ObjectToWorld, v.vertex);
				// just pass the texture coordinate
				o.uv = v.uv;
				o.normalWS = mul(unity_ObjectToWorld, v.normal);

				float3 I = normalize(o.vertexWS - _WorldSpaceCameraPos);

				float d = dot(-I, o.normalWS);

				//o.fresnel = pow(1 + -d, 5);			
				// XXX try this apporximation!
				o.fresnel = exp2((-5.55473 * d - 6.98316) * d); 

				o.fresnel = lerp(_FresnelMin, _FresnelMax, o.fresnel);

				float osky = (1 + 2 * dot(o.normalWS, _PlaneNormal)) / 3; // cie overcast sky model
				osky = lerp(max(0, osky), abs(osky), _GroundRefl);

				float3 oskyc = lerp(_Ground, _Sky, osky) * _Intensity * _Base;
				//oskyc = saturate(oskyc);

				o.color = float4(oskyc, 1);

				return o;
			}

			// texture we will sample
			//sampler2D _MainTex;


			// leland 
			//206-295-8029

			// pixel shader; returns low precision ("fixed4" type)
			// color ("SV_Target" semantic)
			fixed4 frag(v2f i) : SV_Target
			{
				// sample texture and return it
				fixed4 col = 0;// tex2D(_MainTex, i.uv);

				float3 I = i.vertexWS - _WorldSpaceCameraPos;

				float3 rayDir = reflect(I, i.normalWS);
				float3 rayDirN = normalize(rayDir);

				float oskyrefl = ((1 + 2 * dot(rayDirN, _PlaneNormal)) / 3) * _Intensity;
				oskyrefl = lerp(max(0, oskyrefl), abs(oskyrefl), _GroundRefl);

				float3 a = i.color;
				float3 b = lerp(_Ground, _Sky, oskyrefl) * _ReflColor;

				float3 x = lerp(a, b, i.fresnel);

				col.rgb = x;

				return col;
			}
				ENDCG
			}
	}
}