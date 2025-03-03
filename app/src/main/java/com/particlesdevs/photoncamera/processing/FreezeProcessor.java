package com.particlesdevs.photoncamera.processing;

import android.graphics.Point;
import android.util.Log;

import com.particlesdevs.photoncamera.app.PhotonCamera;
import com.particlesdevs.photoncamera.processing.opengl.GLFormat;
import com.particlesdevs.photoncamera.processing.opengl.GLTexture;
import com.particlesdevs.photoncamera.processing.opengl.nodes.Node;
import com.particlesdevs.photoncamera.processing.parameters.IsoExpoSelector;

import java.nio.FloatBuffer;
import java.util.ArrayList;

public class FreezeProcessor extends Node {
    private static final String TAG = "FreezeProcessor";
    private static final int MIN_FRAMES = 3;
    private static final int MAX_FRAMES = 8;
    private static final float MOTION_THRESHOLD = 0.5f;
    private static final float TEMPORAL_WEIGHT = 0.7f;

    private ArrayList<ImageFrame> images;
    private Point rawSize;
    private GLTexture[] alignedFrames;
    private GLTexture[] motionMaps;
    private GLTexture mergedOutput;

    public FreezeProcessor() {
        super("", "FreezeProcessor");
    }

    @Override
    public void Compile() {}

    private void initializeFrames(ArrayList<ImageFrame> inputImages) {
        images = inputImages;
        rawSize = new Point(images.get(0).image.getWidth(), images.get(0).image.getHeight());
        alignedFrames = new GLTexture[images.size()];
        motionMaps = new GLTexture[images.size()];
    }

    private void detectMotion() {
        // Use gyroscope data to detect motion
        for (int i = 0; i < images.size(); i++) {
            ImageFrame frame = images.get(i);
            float[] gyroData = frame.frameGyro.integrated;
            
            // Create motion map based on gyroscope movement
            GLTexture motionMap = new GLTexture(rawSize, new GLFormat(GLFormat.DataType.FLOAT_16));
            glProg.useAssetProgram("motionmap");
            glProg.setVar("gyroX", gyroData[0]);
            glProg.setVar("gyroY", gyroData[1]);
            glProg.setVar("gyroZ", gyroData[2]);
            glProg.drawBlocks(motionMap);
            
            motionMaps[i] = motionMap;
        }
    }

    private void alignFrames() {
        // Initialize base frame
        alignedFrames[0] = new GLTexture(rawSize, new GLFormat(GLFormat.DataType.FLOAT_16));
        GLTexture baseFrame = alignedFrames[0];
        
        // Align subsequent frames to base frame
        for (int i = 1; i < images.size(); i++) {
            alignedFrames[i] = new GLTexture(rawSize, new GLFormat(GLFormat.DataType.FLOAT_16));
            
            glProg.useAssetProgram("alignframe");
            glProg.setTexture("BaseFrame", baseFrame);
            glProg.setTexture("InputFrame", new GLTexture(rawSize, new GLFormat(GLFormat.DataType.UNSIGNED_16), images.get(i).buffer));
            glProg.setTexture("MotionMap", motionMaps[i]);
            glProg.setVar("temporalWeight", TEMPORAL_WEIGHT);
            glProg.setVar("motionThreshold", MOTION_THRESHOLD);
            glProg.drawBlocks(alignedFrames[i]);
        }
    }

    private GLTexture mergeFrames() {
        mergedOutput = new GLTexture(rawSize, new GLFormat(GLFormat.DataType.FLOAT_16));
        
        glProg.useAssetProgram("freezemerge");
        for (int i = 0; i < alignedFrames.length; i++) {
            glProg.setTexture("Frame" + i, alignedFrames[i]);
            glProg.setTexture("MotionMap" + i, motionMaps[i]);
        }
        glProg.setVar("frameCount", alignedFrames.length);
        glProg.drawBlocks(mergedOutput);
        
        return mergedOutput;
    }

    @Override
    public void Run() {
        Log.d(TAG, "Starting Freeze Mode processing");
        
        // Initialize processing
        initializeFrames(((RawPipeline) basePipeline).images);
        
        // Process frames
        detectMotion();
        alignFrames();
        WorkingTexture = mergeFrames();
        
        // Cleanup
        for (GLTexture tex : alignedFrames) {
            if (tex != null) tex.close();
        }
        for (GLTexture tex : motionMaps) {
            if (tex != null) tex.close();
        }
        
        Log.d(TAG, "Freeze Mode processing completed");
    }
} 