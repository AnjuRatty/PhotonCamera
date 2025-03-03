package com.particlesdevs.photoncamera.processing.opengl.rawpipeline;

import android.media.Image;
import android.util.Log;

import com.particlesdevs.photoncamera.app.PhotonCamera;
import com.particlesdevs.photoncamera.processing.ImageFrame;
import com.particlesdevs.photoncamera.processing.opengl.GLBasePipeline;
import com.particlesdevs.photoncamera.processing.opengl.GLCoreBlockProcessing;
import com.particlesdevs.photoncamera.processing.opengl.GLFormat;
import com.particlesdevs.photoncamera.processing.opengl.GLInterface;
import com.particlesdevs.photoncamera.processing.render.Parameters;

import java.nio.ByteBuffer;
import java.util.ArrayList;

public class RawPipeline extends GLBasePipeline {
    public float sensitivity = 1.f;
    public ArrayList<ImageFrame> images;
    public ArrayList<ByteBuffer> alignments;
    public int alignAlgorithm;

    public ByteBuffer Run() {
        mParameters = PhotonCamera.getParameters();
        GLCoreBlockProcessing glproc = new GLCoreBlockProcessing(mParameters.rawSize, new GLFormat(GLFormat.DataType.UNSIGNED_16));
        glint = new GLInterface(glproc);
        glint.parameters = mParameters;

        if (PhotonCamera.getSettings().selectedMode == CameraMode.FREEZE) {
            add(new FreezeProcessor());
        } else if (alignAlgorithm == 1) {
            add(new AlignAndMerge());
        } else if (alignAlgorithm == 2) {
            Log.d("RawPipeline", "Entering hybrid alignment");
            add(new AlignAndMerge());
        }
        return runAllRaw();
    }
}
