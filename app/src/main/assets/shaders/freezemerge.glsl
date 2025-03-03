#version 320 es
precision highp float;
precision highp sampler2D;

layout(local_size_x = 16, local_size_y = 16) in;

// Input textures
uniform sampler2D Frame0;
uniform sampler2D Frame1;
uniform sampler2D Frame2;
uniform sampler2D Frame3;
uniform sampler2D Frame4;
uniform sampler2D Frame5;
uniform sampler2D Frame6;
uniform sampler2D Frame7;

uniform sampler2D MotionMap0;
uniform sampler2D MotionMap1;
uniform sampler2D MotionMap2;
uniform sampler2D MotionMap3;
uniform sampler2D MotionMap4;
uniform sampler2D MotionMap5;
uniform sampler2D MotionMap6;
uniform sampler2D MotionMap7;

uniform int frameCount;

// Output merged image
layout(rgba16f) uniform writeonly image2D outImage;

float calculateWeight(float motionMagnitude) {
    // Sigmoid function to smoothly transition weights based on motion
    return 1.0 / (1.0 + exp(10.0 * (motionMagnitude - 0.5)));
}

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = vec2(pos) / vec2(imageSize(outImage));
    
    vec4 accumColor = vec4(0.0);
    float totalWeight = 0.0;
    
    // Sample and weight each frame
    for (int i = 0; i < frameCount; i++) {
        vec4 frameColor;
        vec4 motionInfo;
        
        switch (i) {
            case 0: 
                frameColor = texture(Frame0, uv);
                motionInfo = texture(MotionMap0, uv);
                break;
            case 1:
                frameColor = texture(Frame1, uv);
                motionInfo = texture(MotionMap1, uv);
                break;
            case 2:
                frameColor = texture(Frame2, uv);
                motionInfo = texture(MotionMap2, uv);
                break;
            case 3:
                frameColor = texture(Frame3, uv);
                motionInfo = texture(MotionMap3, uv);
                break;
            case 4:
                frameColor = texture(Frame4, uv);
                motionInfo = texture(MotionMap4, uv);
                break;
            case 5:
                frameColor = texture(Frame5, uv);
                motionInfo = texture(MotionMap5, uv);
                break;
            case 6:
                frameColor = texture(Frame6, uv);
                motionInfo = texture(MotionMap6, uv);
                break;
            case 7:
                frameColor = texture(Frame7, uv);
                motionInfo = texture(MotionMap7, uv);
                break;
        }
        
        float weight = calculateWeight(motionInfo.z); // z contains motion magnitude
        accumColor += frameColor * weight;
        totalWeight += weight;
    }
    
    // Normalize and output
    vec4 finalColor = accumColor / max(totalWeight, 0.001);
    imageStore(outImage, pos, finalColor);
} 