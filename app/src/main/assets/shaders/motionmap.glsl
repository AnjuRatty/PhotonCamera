#version 320 es
precision highp float;
precision highp sampler2D;

layout(local_size_x = 16, local_size_y = 16) in;

// Gyroscope data
uniform float gyroX;
uniform float gyroY;
uniform float gyroZ;

// Output motion map
layout(rgba16f) uniform writeonly image2D outMotionMap;

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = vec2(pos) / vec2(imageSize(outMotionMap));
    
    // Calculate motion vector based on gyroscope rotation
    vec2 center = vec2(0.5);
    vec2 fromCenter = uv - center;
    
    // Convert gyroscope rotation to pixel movement
    float rotZ = gyroZ * 0.017453292519943295; // Convert to radians
    mat2 rotation = mat2(
        cos(rotZ), -sin(rotZ),
        sin(rotZ), cos(rotZ)
    );
    
    // Apply rotation and translation
    vec2 rotated = rotation * fromCenter;
    vec2 motion = rotated - fromCenter;
    
    // Add translation from X/Y gyro movement
    motion += vec2(gyroX, gyroY) * 0.1; // Scale factor for translation
    
    // Calculate motion magnitude
    float magnitude = length(motion);
    
    // Output motion information
    vec4 outColor = vec4(motion, magnitude, 1.0);
    imageStore(outMotionMap, pos, outColor);
} 