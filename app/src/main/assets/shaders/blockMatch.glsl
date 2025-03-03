#version 310 es
#extension GL_OES_EGL_image_external : require
precision highp float;
precision highp int;

layout(local_size_x = TILESIZE, local_size_y = TILESIZE) in;

// Input textures
layout(binding = 0) uniform sampler2D ReferenceFrame;
layout(binding = 1) uniform sampler2D TargetFrame;
layout(binding = 2) uniform sampler2D PreviousAlignment;

// Output alignment vectors
layout(rgba32f, binding = 3) writeonly uniform image2D AlignmentOutput;

// Parameters
uniform float contrastWeight;
uniform float noiseWeight;
uniform float usePreviousAlignment;

// Constants
const float SEARCH_STEP = 2.0;
const int MAX_ITERATIONS = 16;

// Shared memory for block matching
shared float blockData[TILESIZE * TILESIZE];

// Harris corner response function
float harrisResponse(vec2 pos) {
    vec2 dx = vec2(1.0 / float(textureSize(ReferenceFrame, 0).x), 0.0);
    vec2 dy = vec2(0.0, 1.0 / float(textureSize(ReferenceFrame, 0).y));
    
    float Ixx = 0.0, Iyy = 0.0, Ixy = 0.0;
    
    for(int y = -1; y <= 1; y++) {
        for(int x = -1; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 samplePos = pos + offset;
            
            vec4 gradX = texture(ReferenceFrame, samplePos + dx) - texture(ReferenceFrame, samplePos - dx);
            vec4 gradY = texture(ReferenceFrame, samplePos + dy) - texture(ReferenceFrame, samplePos - dy);
            
            float weight = 1.0 - length(offset) * 0.3;
            
            Ixx += weight * gradX.x * gradX.x;
            Iyy += weight * gradY.x * gradY.x;
            Ixy += weight * gradX.x * gradY.x;
        }
    }
    
    float det = Ixx * Iyy - Ixy * Ixy;
    float trace = Ixx + Iyy;
    
    return det - 0.04 * trace * trace;
}

// Block matching with early termination
vec2 findMatch(vec2 refPos, vec2 initialGuess) {
    float bestError = 1e10;
    vec2 bestOffset = initialGuess;
    
    // Load reference block into shared memory
    for(int y = 0; y < TILESIZE; y++) {
        for(int x = 0; x < TILESIZE; x++) {
            vec2 samplePos = refPos + vec2(float(x), float(y));
            blockData[y * TILESIZE + x] = texture(ReferenceFrame, samplePos).x;
        }
    }
    
    // Coarse-to-fine search
    for(int scale = 4; scale >= 1; scale /= 2) {
        float searchRadius = float(SEARCH_RADIUS) / float(scale);
        
        for(float y = -searchRadius; y <= searchRadius; y += SEARCH_STEP) {
            for(float x = -searchRadius; x <= searchRadius; x += SEARCH_STEP) {
                vec2 offset = bestOffset + vec2(x, y);
                float error = 0.0;
                
                // Early termination threshold
                float earlyTermination = bestError * EARLY_TERMINATION;
                
                for(int by = 0; by < TILESIZE && error < earlyTermination; by++) {
                    for(int bx = 0; bx < TILESIZE && error < earlyTermination; bx++) {
                        vec2 samplePos = refPos + offset + vec2(float(bx), float(by));
                        float targetValue = texture(TargetFrame, samplePos).x;
                        float refValue = blockData[by * TILESIZE + bx];
                        
                        error += abs(targetValue - refValue);
                    }
                }
                
                if(error < bestError) {
                    bestError = error;
                    bestOffset = offset;
                }
            }
        }
    }
    
    return bestOffset;
}

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    vec2 texPos = vec2(pos) / vec2(textureSize(ReferenceFrame, 0));
    
    // Get initial guess from previous alignment if available
    vec2 initialGuess = vec2(0.0);
    if(usePreviousAlignment > 0.0) {
        initialGuess = texture(PreviousAlignment, texPos).xy;
    }
    
    // Calculate feature response
    float featureResponse = harrisResponse(texPos);
    
    // Find best match
    vec2 alignment = findMatch(texPos, initialGuess);
    
    // Weight alignment by feature response and contrast
    float contrast = length(texture(ReferenceFrame, texPos));
    float weight = (featureResponse * contrastWeight + contrast * noiseWeight) / (contrastWeight + noiseWeight);
    
    // Output alignment vector and confidence
    imageStore(AlignmentOutput, pos, vec4(alignment, weight, 1.0));
} 