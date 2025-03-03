#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float pointSize [[point_size]];
};

vertex VertexOut pointVertex(
    VertexIn in [[stage_in]],
    constant float &pointSize [[buffer(1)]],
    constant float4x4 &modelViewProjectionMatrix [[buffer(2)]]
) {
    VertexOut out;
    out.position = modelViewProjectionMatrix * float4(in.position, 1.0);
    out.color = in.color;
    out.pointSize = pointSize;
    return out;
}

fragment float4 pointFragment(
    VertexOut in [[stage_in]],
    float2 pointCoord [[point_coord]]
) {
    // Create circular points
    float dist = length(pointCoord - float2(0.5));
    if (dist > 0.5) {
        discard_fragment();
    }
    
    // Apply simple lighting
    float light = 1.0 - (dist * 2.0);
    return float4(in.color.rgb * light, in.color.a);
} 