package com.howen.howentestdemo;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;
import android.view.KeyEvent;
import android.widget.Button;
import android.view.View;
import android.view.View.OnClickListener;
import android.content.ComponentName;
import android.content.Intent;
public class OEMKeysActivity extends Activity 
{
	private TextView mOEMkeyEvent;
	private static final int KEYCODE_OEM_LEFT = 290;
    private static final int KEYCODE_OEM_MIDDLE = 291;
    private static final int KEYCODE_OEM_RIGHT = 292;
	private Button settings_button;
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.oemkeys);
		mOEMkeyEvent=(TextView)findViewById(R.id.oem_key_event);

		settings_button = (Button) findViewById(R.id.settings_button);
		settings_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) 
            {
                Intent settings_intent = new Intent();
                settings_intent.setComponent(new ComponentName("com.android.settings","com.android.settings.Settings"));
                startActivity(settings_intent);
            }
        });
	}

	@Override
	public boolean dispatchKeyEvent(KeyEvent event) 
	{
		if(event.getAction() == KeyEvent.ACTION_DOWN)
		{
			if(event.getKeyCode()==KEYCODE_OEM_LEFT)
			{
				mOEMkeyEvent.setText("oem left key down");
			}else if(event.getKeyCode()==KEYCODE_OEM_MIDDLE)
			{
				mOEMkeyEvent.setText("oem middle key down");
			}else if(event.getKeyCode()==KEYCODE_OEM_RIGHT)
			{
				mOEMkeyEvent.setText("oem right key down");
			}
		}else if(event.getAction() == KeyEvent.ACTION_UP)
		{
			if(event.getKeyCode()==KEYCODE_OEM_LEFT)
			{
				mOEMkeyEvent.setText("oem left key up");
			}else if(event.getKeyCode()==KEYCODE_OEM_MIDDLE)
			{
				mOEMkeyEvent.setText("oem middle key up");
			}else if(event.getKeyCode()==KEYCODE_OEM_RIGHT)
			{
				mOEMkeyEvent.setText("oem right key up");
			}
		}
		return super.dispatchKeyEvent(event);
	}
	
}