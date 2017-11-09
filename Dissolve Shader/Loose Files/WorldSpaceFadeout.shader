Shader "Custom/Worldspace Fadeout"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Albedo (RGB)", 2D) = "white" {}

		_Metallic("Metallic", 2D) = "black" {}
		_Glossiness("Metal Intensity", Range(0,1)) = 0.0

		_NormalMap("Normal", 2D) = "bump" {}

		_Occlusion("Occlusion", 2D) = "white" {}

		_Color1("Bottom Color", Color) = (0,0,0,1)
			_Color2("Top Color", Color) = (1,1,1,1)
		_DissolvePercentage("DissolveDistance", Range(0,10)) = 5.19
		_DissolvePercentage2("DissolveDistance2", Range(0,30)) = 11.9

		_Octaves("Octaves", Float) = 1
		_Frequency("Frequency", Float) = 2.0
		_Amplitude("Amplitude", Float) = 1.0
		_Lacunarity("Lacunarity", Float) = 1
		_Persistence("Persistence", Float) = 0.8
		_Offset("Offset", Vector) = (0.0, 0.0, 0.0, 0.0)
			_Size("Radius", Range(0,3)) = 2.04
			_Intensity("Intensity", Range(0,1)) = 1.0
	}

		CGINCLUDE
			//
			//	FAST32_hash
			//	A very fast hashing function.  Requires 32bit support.

			//	The hash formula takes the form....
			//	hash = mod( coord.x * coord.x * coord.y * coord.y, SOMELARGEFLOAT ) / SOMELARGEFLOAT
			//	We truncate and offset the domain to the most interesting part of the noise.
			//	SOMELARGEFLOAT should be in the range of 400.0->1000.0 and needs to be hand picked.  Only some give good results.
			//	3D Noise is achieved by offsetting the SOMELARGEFLOAT value by the Z coordinate
			//
			void FAST32_hash_3D(float3 gridcell,
				out float4 lowz_hash_0,
				out float4 lowz_hash_1,
				out float4 lowz_hash_2,
				out float4 highz_hash_0,
				out float4 highz_hash_1,
				out float4 highz_hash_2)		//	generates 3 random numbers for each of the 8 cell corners
		{
			//    gridcell is assumed to be an integer coordinate

			//	TODO: 	these constants need tweaked to find the best possible noise.
			//			probably requires some kind of brute force computational searching or something....
			const float2 OFFSET = float2(50.0, 161.0);
			const float DOMAIN = 69.0;
			const float3 SOMELARGEFLOATS = float3(635.298681, 682.357502, 668.926525);
			const float3 ZINC = float3(48.500388, 65.294118, 63.934599);

			//	truncate the domain
			gridcell.xyz = gridcell.xyz - floor(gridcell.xyz * (1.0 / DOMAIN)) * DOMAIN;
			float3 gridcell_inc1 = step(gridcell, float3(DOMAIN - 1.5, DOMAIN - 1.5, DOMAIN - 1.5)) * (gridcell + 1.0);

			//	calculate the noise
			float4 P = float4(gridcell.xy, gridcell_inc1.xy) + OFFSET.xyxy;
			P *= P;
			P = P.xzxz * P.yyww;
			float3 lowz_mod = float3(1.0 / (SOMELARGEFLOATS.xyz + gridcell.zzz * ZINC.xyz));
			float3 highz_mod = float3(1.0 / (SOMELARGEFLOATS.xyz + gridcell_inc1.zzz * ZINC.xyz));
			lowz_hash_0 = frac(P * lowz_mod.xxxx);
			highz_hash_0 = frac(P * highz_mod.xxxx);
			lowz_hash_1 = frac(P * lowz_mod.yyyy);
			highz_hash_1 = frac(P * highz_mod.yyyy);
			lowz_hash_2 = frac(P * lowz_mod.zzzz);
			highz_hash_2 = frac(P * highz_mod.zzzz);
		}
		//
		//	Interpolation functions
		//	( smoothly increase from 0.0 to 1.0 as x increases linearly from 0.0 to 1.0 )

		float3 Interpolation_C2(float3 x) { return x * x * x * (x * (x * 6.0 - 15.0) + 10.0); }
		//
		//	Perlin Noise 3D  ( gradient noise )
		//	Return value range of -1.0->1.0

		float Perlin3D(float3 P)
		{
			//	establish our grid cell and unit position
			float3 Pi = floor(P);
			float3 Pf = P - Pi;
			float3 Pf_min1 = Pf - 1.0;

			//
			//	classic noise.
			//	requires 3 random values per point.  with an efficent hash function will run faster than improved noise
			//

			//	calculate the hash.
			//	( various hashing methods listed in order of speed )
			float4 hashx0, hashy0, hashz0, hashx1, hashy1, hashz1;
			FAST32_hash_3D(Pi, hashx0, hashy0, hashz0, hashx1, hashy1, hashz1);

			//	calculate the gradients
			float4 grad_x0 = hashx0 - 0.49999;
			float4 grad_y0 = hashy0 - 0.49999;
			float4 grad_z0 = hashz0 - 0.49999;
			float4 grad_x1 = hashx1 - 0.49999;
			float4 grad_y1 = hashy1 - 0.49999;
			float4 grad_z1 = hashz1 - 0.49999;
			float4 grad_results_0 = rsqrt(grad_x0 * grad_x0 + grad_y0 * grad_y0 + grad_z0 * grad_z0) * (float2(Pf.x, Pf_min1.x).xyxy * grad_x0 + float2(Pf.y, Pf_min1.y).xxyy * grad_y0 + Pf.zzzz * grad_z0);
			float4 grad_results_1 = rsqrt(grad_x1 * grad_x1 + grad_y1 * grad_y1 + grad_z1 * grad_z1) * (float2(Pf.x, Pf_min1.x).xyxy * grad_x1 + float2(Pf.y, Pf_min1.y).xxyy * grad_y1 + Pf_min1.zzzz * grad_z1);

			//	Classic Perlin Interpolation
			float3 blend = Interpolation_C2(Pf);
			float4 res0 = lerp(grad_results_0, grad_results_1, blend.z);
			float2 res1 = lerp(res0.xy, res0.zw, blend.y);
			float final = lerp(res1.x, res1.y, blend.x);
			final *= 1.1547005383792515290182975610039;		//	(optionally) scale things to a strict -1.0->1.0 range    *= 1.0/sqrt(0.75)
			return final;
		}
		float PerlinNormal(float3 p, int octaves, float3 offset, float frequency, float amplitude, float lacunarity, float persistence)
		{
			float sum = 0;
			for (int i = 0; i < octaves; i++)
			{
				float h = 0;
				h = Perlin3D((p + offset) * frequency);
				sum += h*amplitude;
				frequency *= lacunarity;
				amplitude *= persistence;
			}
			return sum;
		}

		ENDCG


	SubShader
	{
		Tags{ "RenderType" = "Opaque" }
		LOD 200
		
		Cull Off
	
		
		//Blend SrcAlpha OneMinusSrcAlpha
		CGPROGRAM
		
		#pragma surface surf Standard fullforwardshadows 

		#pragma glsl
		#pragma target 3.0

		fixed _Octaves;
		float _Frequency;
		float _Amplitude;
		float3 _Offset;
		float _Lacunarity;
		float _Persistence;

		sampler2D _MainTex;
		sampler2D _Metallic;
		sampler2D _NormalMap;
		sampler2D _ScreenGradient;
		sampler2D _Occlusion;
		
		fixed4 _Color;
		float _Scale;
		float _DissolvePercentage;
		float _DissolvePercentage2;
		half _Glossiness;
		half _Size;
		half _Intensity;
		fixed4 _Color1;
		fixed4 _Color2;


		struct Input
		{
			float2 uv_MainTex;
			float2 uv_NormalMap;
			float3 pos;
			float3 worldPos;
			float3 worldNormal; INTERNAL_DATA
			float4 screenPos;
			float eyeDepth;
			float2 depth : TEXCOORD0;
		};

		

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			float dist = length(0 - IN.screenPos.z);
			half viewDist = length(dist);
			half falloff = saturate((viewDist - _DissolvePercentage2) / (_DissolvePercentage - _DissolvePercentage2));

			if (falloff <= 2)
			{
				_Size /= (falloff * 2);
			}

			const float pi = 3.14159;
			const float tau = pi * 2;
			float2 screenUV = IN.screenPos.xy / IN.screenPos.w;
			float sinX = clamp(0.0, 1.0, cos(clamp(0.0, pi, screenUV.x * pi - (0.5 * pi))));
			float sinY = clamp(0.0, 1.0, cos(clamp(0.0, pi, screenUV.y * pi - (0.5 * pi))));
			float2 moddedUV = float2(sinX, sinY) * _Intensity;
			//float2 moddedUV2 = float2(cos(moddedUV.x * (pi * 2) * screenUV.y) * 1, 1);
			// Albedo comes from a texture tinted by color
			fixed4 x = saturate(lerp(_Color1, _Color2, pow(moddedUV.x, _Size)) * lerp(_Color1, _Color2, pow(moddedUV.y, _Size)));


			
			float _Dissolve = x.r * (falloff);

			float gradient = PerlinNormal(IN.worldPos, _Octaves, _Offset, _Frequency, _Amplitude, _Lacunarity, _Persistence);

			float dissolve = (((_Dissolve) - 0) * (1 - 0)) * (1.5 - -1.5) + -1.5;

			clip(gradient - dissolve);

			fixed4 c = tex2D(_MainTex, IN.uv_MainTex);
			o.Albedo = c.rgb * _Color;
			fixed4 m = tex2D(_Metallic, IN.uv_MainTex);
			o.Metallic = m.rgb;

			fixed4 g = tex2D(_Metallic, IN.uv_MainTex);
			o.Smoothness = g.rgb * _Glossiness;

			o.Occlusion = tex2D(_Occlusion, IN.uv_MainTex);

			fixed3 n = UnpackNormal(tex2D(_NormalMap, IN.uv_MainTex));
			o.Normal = n;

			o.Alpha = 1;
		}
		ENDCG
		}

			FallBack "Diffuse"
}