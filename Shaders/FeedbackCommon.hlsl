﻿#ifndef VIRTUAL_TEXTURE_FEEDBACK_INCLUDED
#define VIRTUAL_TEXTURE_FEEDBACK_INCLUDED

#include "VirtualTextureCommon.hlsl"
#define UNITY_INSTANCING_ENABLED

UNITY_INSTANCING_BUFFER_START(Terrain)
    UNITY_DEFINE_INSTANCED_PROP(float4, _TerrainPatchInstanceData)  // float4(xBase, yBase, skipScale, ~)
UNITY_INSTANCING_BUFFER_END(Terrain)

#ifdef UNITY_INSTANCING_ENABLED
    TEXTURE2D(_TerrainHeightmapTexture);
    SAMPLER(sampler_TerrainNormalmapTexture);
    float4 _TerrainHeightmapRecipSize;   // float4(1.0f/width, 1.0f/height, 1.0f/(width-1), 1.0f/(height-1))
    float4 _TerrainHeightmapScale;       // float4(hmScale.x, hmScale.y / (float)(kMaxHeight), hmScale.z, 0.0f)
#endif

struct feed_v2f
{
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
};

struct feed_attr
{
    float4 vertex : POSITION;
    float2 texcoord : TEXCOORD0;
    
    
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

feed_v2f VTVertFeedback(feed_attr v)
{
    feed_v2f o;
    UNITY_SETUP_INSTANCE_ID(v);
    
#if defined(UNITY_INSTANCING_ENABLED)
    float2 patchVertex = v.vertex.xy;
    float4 instanceData = UNITY_ACCESS_INSTANCED_PROP(Terrain, _TerrainPatchInstanceData);

    float2 sampleCoords = (patchVertex.xy + instanceData.xy) * instanceData.z; // (xy + float2(xBase,yBase)) * skipScale
    float height = UnpackHeightmap(_TerrainHeightmapTexture.Load(int3(sampleCoords, 0)));

    v.vertex.xz = sampleCoords * _TerrainHeightmapScale.xz;
    v.vertex.y = height * _TerrainHeightmapScale.y;
    
    v.texcoord = sampleCoords * _TerrainHeightmapRecipSize.zw;
#endif
    
    VertexPositionInputs Attributes = GetVertexPositionInputs(v.vertex.xyz);
    
    o.pos = Attributes.positionCS;
    float2 posWS = Attributes.positionWS.xz;
    o.uv = (posWS - _VTVolumeParams.xy) * rcp(_VTVolumeParams.zw);
    
    return o;
}

float MipLevel(float2 UV)
{
    float2 DX = ddx(UV);
    float2 DY = ddy(UV);
    float MaxSqr = max(dot(DX, DX), dot(DY, DY));
    float MipLevel = 0.5 * log2(MaxSqr);
    return max(0, MipLevel);
}

float4 VTFragFeedback(feed_v2f i) : SV_Target
{
	float2 PageUV = floor(i.uv * _VTFeedbackParam.x);
    float ComputedLevel = MipLevel(i.uv * _VTFeedbackParam.y) + _VTFeedbackParam.w /*+ 1 * 0.5 - 0.25*/;
    //ComputedLevel = clamp(ComputedLevel, 0, 7);

	return float4(PageUV / 255.0, floor(ComputedLevel) / 255.0, 1);
}

#endif