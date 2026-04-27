package com.howen.howentestdemo;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.content.res.Configuration;
import android.net.Uri;
import android.os.Bundle;
import android.view.Window;
import android.view.WindowManager;
import android.widget.MediaController;
import android.widget.VideoView;
import android.media.MediaPlayer.OnCompletionListener; 
import android.media.MediaPlayer;

public class VideoActivityV5 extends Activity {
	private MediaController mediaController;
	private VideoView mVideoView;
	@Override
	protected void onCreate(Bundle savedInstanceState) 
	{
		super.onCreate(savedInstanceState);
		requestWindowFeature(Window.FEATURE_NO_TITLE);
		getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
				WindowManager.LayoutParams.FLAG_FULLSCREEN);
		setContentView(R.layout.video);

		Configuration configuration = getResources().getConfiguration();
		if (configuration.orientation == configuration.ORIENTATION_PORTRAIT) {
			VideoActivityV5.this
					.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
		}
		
		mediaController = new MediaController(this);
		
		mVideoView = (VideoView) findViewById(R.id.videoView);
		mVideoView.setVideoURI(Uri.parse("android.resource://" + getPackageName() + "/"+ R.raw.dzq));
		mVideoView.setMediaController(mediaController);
		mediaController.setMediaPlayer(mVideoView);
		
		mVideoView.setOnCompletionListener(new OnCompletionListener() 
		{
			public void onCompletion(MediaPlayer mp) 
			{
				mVideoView.setVideoURI(Uri.parse("android.resource://" + getPackageName() + "/"+ R.raw.dzq));
				mVideoView.start();
			}
		});
		 
		mVideoView.start();
	}

	
	@Override
	protected void onDestroy() 
	{
		super.onDestroy();
		mVideoView.stopPlayback();
		//mVideoView.release();
	}


	@Override
	protected void onResume() {
		mVideoView.start();
		super.onResume();
	}
		
	@Override
	protected void onPause() 
	{
		mVideoView.stopPlayback();
		super.onPause();
	}
	
}
