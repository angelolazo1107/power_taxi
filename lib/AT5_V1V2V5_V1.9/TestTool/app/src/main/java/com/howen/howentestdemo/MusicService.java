package com.howen.howentestdemo;

import android.app.Service;
import android.content.Intent;
import android.media.MediaPlayer;
import android.os.IBinder;
import android.util.Log;
import android.media.AudioManager;
import android.content.Context;

public class MusicService extends Service {
	private final String Tag = "MusicService";
	MediaPlayer mp3player;
	private AudioManager mAudioManager = null;
	private int mCurrentVolume = -1;
	

	@Override
	public void onDestroy() {
		// TODO Auto-generated method stub
		super.onDestroy();
		mp3player.stop();
		Log.d(Tag,"onDestroy mCurrentVolume=="+mCurrentVolume);
		if(mCurrentVolume>0)
		{
			mAudioManager.setStreamVolume(AudioManager.STREAM_MUSIC, mCurrentVolume,0);
		}
		
	}

	@Override
	public int onStartCommand(Intent intent, int flags, int startId) {
		// TODO Auto-generated method stub
		if(mAudioManager==null)
		{
			mAudioManager = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
		}
		mp3player = MediaPlayer.create(this, R.raw.music);
		mCurrentVolume = mAudioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
		Log.d(Tag,"onStartCommand mCurrentVolume=="+mCurrentVolume);
        mAudioManager.setStreamVolume(AudioManager.STREAM_MUSIC,
                           mAudioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
                           0);
		Log.d(Tag,"onStartCommand mCurrentnewVolume=="+mAudioManager.getStreamVolume(AudioManager.STREAM_MUSIC));
		mp3player.start();
		return super.onStartCommand(intent, flags, startId);
	}

	@Override
	public IBinder onBind(Intent arg0) {
		// TODO Auto-generated method stub

		return null;
	}

}
