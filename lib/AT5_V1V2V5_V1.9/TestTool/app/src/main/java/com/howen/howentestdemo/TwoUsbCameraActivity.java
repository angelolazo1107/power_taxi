package com.howen.howentestdemo;

import java.io.IOException;
import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.view.SurfaceHolder;
import android.view.WindowManager;
import android.view.SurfaceHolder.Callback;
import android.view.SurfaceView;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;

import android.hardware.Camera;
import java.io.File;
import android.os.Handler;

public class TwoUsbCameraActivity extends Activity {
	private static final String TAG = "TwoUsbCameraActivity";
	private SurfaceView mSurface1;
	private SurfaceView mSurface2;
	private PreviewCallbacks mCb1 = new PreviewCallbacks(0);
	private PreviewCallbacks mCb2 = new PreviewCallbacks(1);
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
		super.onCreate(savedInstanceState);
		setContentView(R.layout.twousbcamera);
		Log.d(TAG,"onCreate");
		mSurface1 = (SurfaceView)findViewById(R.id.surface1);
		mSurface2 = (SurfaceView)findViewById(R.id.surface2);
		mSurface1.getHolder().addCallback(mCb1.getPreviewCallback());
		mSurface2.getHolder().addCallback(mCb2.getPreviewCallback());		
	}

	@Override
	protected void onResume() {
		// TODO Auto-generated method stub
		super.onResume();
	}

	@Override
	protected void onPause() {
		// TODO Auto-generated method stub
		super.onPause();
	}

	private class PreviewCallbacks {
	    private SurfaceHolder mPreviewHolder;
		private Camera mCamera;
		private int mId = 0;
	    
	    private Callback mPreviewCallback = new Callback(){
	        @Override
		    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
	        		Log.d(TAG,"surfaceChanged");
				    mPreviewHolder=holder;
				    doSurfaceChanged();
		    }
	        
		    @Override
		    public void surfaceCreated(SurfaceHolder holder) {
		    	Log.d(TAG,"surfaceCreated");
		        mPreviewHolder=holder;
		        doSurfaceCreated();
		    }
		    
		    @Override
		    public void surfaceDestroyed(SurfaceHolder holder) {
		    	Log.d(TAG,"surfaceDestroyed");
		        mPreviewHolder=null;
		        doSurfaceDestroyed();
		    }
		};
				
		public Callback getPreviewCallback(){
			Log.d(TAG,"getPreviewCallback");
		    return mPreviewCallback;
		}
						
		public PreviewCallbacks(int uvc_id){
			Log.d(TAG,"PreviewCallbacks uvc_id=="+uvc_id);
			mId = uvc_id;
		}
		
		public void doSurfaceChanged() {
		
		}

		public void doSurfaceCreated() {
			Log.d(TAG,"doSurfaceCreated");
			if(mPreviewHolder==null){
			    return;
			}

			 int cameraCount = Camera.getNumberOfCameras();			
			 Log.e(TAG,"cameraCount=" + cameraCount + "   mId="+mId);            
			 if (mId >= cameraCount)			    
			 	return; 	
			
            if(!havevide(mId))
            {
            	mCameraErrorHandler.removeCallbacks(mCameraErrorRunnable);
				mCameraErrorHandler.postDelayed(mCameraErrorRunnable,mPostDelayTime);
				return; 
            }

			if(mCamera!=null){
			    mCamera.release();
			    mCamera=null;
			}
			
			try {
				mCamera = Camera.open(mId);
				if(mCamera==null){
					Log.e(TAG,"Can not open camera = "+mId);
					return;
				}								
				mCamera.setPreviewDisplay(mPreviewHolder);
				mCamera.startPreview();	
				mCamera.setErrorCallback(new Camera.ErrorCallback() {
				    @Override
				    public void onError(int error, Camera camera) 
				    {
				    	DoCameraError();
				    }
				  });
			} catch (IOException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}

		}
		
		private Handler mCameraErrorHandler = new Handler();
		private static final int mPostDelayTime = 2000;
		private final Runnable mCameraErrorRunnable = new Runnable() 
		{
	        @Override
	        public void run() 
	        {
	        	if(havevide(mId))
				{
	        		doSurfaceCreated();
				}else
				{
					mCameraErrorHandler.removeCallbacks(mCameraErrorRunnable);
					mCameraErrorHandler.postDelayed(mCameraErrorRunnable,mPostDelayTime);
				}
	        }
		};
		
		private void DoCameraError()
		{
		   mCamera.stopPreview();
		   mCamera.release();
		   mCamera=null;
		   mCameraErrorHandler.removeCallbacks(mCameraErrorRunnable);
		   mCameraErrorHandler.postDelayed(mCameraErrorRunnable,mPostDelayTime);
		}
		
		
		public boolean havevide(int id) 
		{
			String filename="/dev/video"+id;
			File file = new File(filename);
			if(file.exists())
			{
				return true;
			}
			return false; 
		}

		public void doSurfaceDestroyed() {
			Log.d(TAG,"doSurfaceDestroyed");
		    if(mPreviewHolder==null){
			    if(mCamera==null){
				    return ;
			    }
			    mCamera.stopPreview();
			    mCamera.release();
			    mCamera=null;
			    mPreviewHolder=null;
			}
		}
	}
	
	@Override
	protected void onStop() {
		super.onStop();
		Log.e(TAG, "onStop");

	}
	
	@Override
	protected void onDestroy() {
		super.onDestroy();
		Log.e(TAG, "onDestroy");

		//System.exit(0);
	}
	
}
