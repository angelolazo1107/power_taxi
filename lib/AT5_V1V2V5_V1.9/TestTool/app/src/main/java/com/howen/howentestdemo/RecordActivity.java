package com.howen.howentestdemo;

import java.io.File;

import android.app.Activity;
import android.content.Intent;
import android.media.MediaRecorder;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.Toast;
import android.util.Log;
import android.os.Build;
import android.os.StrictMode;

public class RecordActivity extends Activity implements OnClickListener {
	private Button record_ImageButton, stop_ImageButton, play_ImageButton;
	private File soundFile;
	private MediaRecorder mRecorder;
	private boolean mRecordering=false;

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		// TODO Auto-generated method stub
		super.onCreate(savedInstanceState);
		setContentView(R.layout.record);

		init_view();

		record_ImageButton.setOnClickListener(this);
		stop_ImageButton.setOnClickListener(this);
		play_ImageButton.setOnClickListener(this);

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
			StrictMode.VmPolicy.Builder builder = new StrictMode.VmPolicy.Builder();
			StrictMode.setVmPolicy( builder.build() );
		}

	}

	private void init_view() {
		// TODO Auto-generated method stub
		record_ImageButton = (Button) findViewById(R.id.record_imageButton);
		stop_ImageButton = (Button) findViewById(R.id.stop_imageButton);
		play_ImageButton = (Button) findViewById(R.id.play_imageButton);
	}

	
	@Override
	public void onClick(View v) {
		// TODO Auto-generated method stub
		switch (v.getId()) {
		case R.id.record_imageButton:
			if (!Environment.getExternalStorageState().equals(
					android.os.Environment.MEDIA_MOUNTED)) {
				Toast.makeText(RecordActivity.this, R.string.not_find_sd_card,
						Toast.LENGTH_SHORT).show();
				return;
			}
			
			if(mRecordering)
			{
				Toast.makeText(RecordActivity.this, R.string.recording_message,Toast.LENGTH_SHORT).show();
				return;
			}
			try {
				if ("AT5_V5".equals(Build.MODEL))
				{
					soundFile = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).toString()+"/sound.amr");
				}else {
					soundFile = new File(Environment.getExternalStorageDirectory().getCanonicalFile() + "/sound.amr");
				}
				mRecorder = new MediaRecorder();
				mRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
				mRecorder.setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP);
				mRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB);
				mRecorder.setOutputFile(soundFile.getAbsolutePath());
				mRecorder.prepare();
				mRecorder.start();
				mRecordering=true;
			} catch (Exception e) {
				e.printStackTrace();
			}
			break;

		case R.id.stop_imageButton:
			if (mRecorder!=null&&soundFile != null && soundFile.exists()) 
			{
				try{
					mRecorder.stop();
					mRecorder.release();
					mRecordering=false;
					mRecorder = null;
					}catch(RuntimeException stopException )
   				{
   				}
				
			} else {
				Toast.makeText(RecordActivity.this, R.string.record_first,
						Toast.LENGTH_LONG).show();
			}
			break;

		case R.id.play_imageButton:
			if (soundFile != null && soundFile.exists()) {
				Intent intent = new Intent();
				intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
				intent.setAction(android.content.Intent.ACTION_VIEW);
				String type = getMIMEType(soundFile);
				intent.setDataAndType(Uri.fromFile(soundFile), type);
				startActivity(intent);
			} else {
				Toast.makeText(RecordActivity.this, R.string.record_first,
						Toast.LENGTH_LONG).show();
			}
			break;
		}
	}

	private String getMIMEType(File f) {
		String end = f
				.getName()
				.substring(f.getName().lastIndexOf(".") + 1,
						f.getName().length()).toLowerCase();
		String type = "";
		if (end.equals("mp3") || end.equals("aac") || end.equals("aac")
				|| end.equals("amr") || end.equals("mpeg") || end.equals("mp4")) {
			type = "audio";
		} else if (end.equals("jpg") || end.equals("gif") || end.equals("png")
				|| end.equals("jpeg")) {
			type = "image";
		} else {
			type = "*";
		}
		type += "/*";
		return type;
	}
}
