package com.howen.howentestdemo;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;
import android.view.Menu;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.ImageButton;
import android.widget.TextView;
import android.app.ActivityManager;
import android.app.ActivityManager.RunningServiceInfo;
import android.content.ComponentName;
import java.util.List;
import android.util.Log;

public class GPIOMainActivity extends Activity
{
	private Button mGetGPIO, mListenerGPIO;
	private Context mContext;
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.gpiomain);
		mGetGPIO = (Button) findViewById(R.id.gpio_get_Button);
		mListenerGPIO = (Button) findViewById(R.id.gpio_listener_Button);

		mGetGPIO.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) 
			{
				Intent GetIntent = new Intent(GPIOMainActivity.this,GPIOActivity.class);
				GPIOMainActivity.this.startActivity(GetIntent);
			}
		});

		mListenerGPIO.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) 
			{
				Intent ListenerIntent = new Intent(GPIOMainActivity.this,GPIOListenerActivity.class);
				GPIOMainActivity.this.startActivity(ListenerIntent);
			}
		});
	}

}