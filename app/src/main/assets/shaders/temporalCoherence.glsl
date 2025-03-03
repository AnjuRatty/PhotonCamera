#version 310 es
precision highp float;
precision highp int;

layout(local_size_x = 16, local_size_y = 16) in;

// Input textures
layout(binding = 0) uniform sampler2D CurrentAlignment;
layout(binding = 1) uniform sampler2D PreviousAlignment;
layout(binding = 2) uniform sampler2D MotionConfidence;

// Output
layout(rgba32f, binding = 3) writeonly uniform image2D FilteredAlignment;

// Parameters
uniform float temporalWeight;
uniform float spatialWeight;
uniform float motionThreshold;

// Bilateral filter for spatial coherence
vec4 bilateralFilter(vec2 uv, float radius) {
    vec4 sum = vec4(0.0);
    float weightSum = 0.0;
    
    vec4 centerValue = texture(CurrentAlignment, uv);
    
    for(float y = -radius; y <= radius; y += 1.0) {
        for(float x = -radius; x <= radius; x += 1.0) {
            vec2 offset = vec2(x, y) / vec2(textureSize(CurrentAlignment, 0));
            vec2 samplePos = uv + offset;
            
            vec4 sampleValue = texture(CurrentAlignment, samplePos);
            
            // Spatial weight
            float spatialDist = length(vec2(x, y)) / radius;
            float spatialWeight = exp(-spatialDist * spatialDist);
            
            // Value weight
            float valueDist = length(sampleValue.xy - centerValue.xy) / motionThreshold;
            float valueWeight = exp(-valueDist * valueDist);
            
            float weight = spatialWeight * valueWeight;
            sum += sampleValue * weight;
            weightSum += weight;
        }
    }
    
    return sum / weightSum;
}

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = vec2(pos) / vec2(textureSize(CurrentAlignment, 0));
    
    // Get current and previous alignments
    vec4 current = texture(CurrentAlignment, uv);
    vec4 previous = texture(PreviousAlignment, uv);
    float confidence = texture(MotionConfidence, uv).x;
    
    // Apply bilateral filtering for spatial coherence
    vec4 spatiallyFiltered = bilateralFilter(uv, 2.0);
    
    // Temporal blend based on motion confidence
    float temporalBlend = mix(temporalWeight, 0.0, confidence);
    vec4 temporallyFiltered = mix(spatiallyFiltered, previous, temporalBlend);
    
    // Apply motion constraints
    float motionMagnitude = length(temporallyFiltered.xy);
    if(motionMagnitude > motionThreshold) {
        temporallyFiltered.xy *= motionThreshold / motionMagnitude;
    }
    
    // Store result
    imageStore(FilteredAlignment, pos, temporallyFiltered);
} 