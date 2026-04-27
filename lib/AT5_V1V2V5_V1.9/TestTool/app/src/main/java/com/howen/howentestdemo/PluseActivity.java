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
import com.android.howen.HowenManager;
import android.os.Message;
import android.os.Handler;
import java.util.Timer;
import java.util.TimerTask;
import android.text.format.DateUtils;
import java.math.BigDecimal;
import android.content.SharedPreferences;
import android.app.AlertDialog;
import android.widget.EditText;
import android.content.DialogInterface;
import java.math.RoundingMode;
import android.widget.Toast;
public class PluseActivity extends Activity 
{
	private static final String PULSE_SHARED = "com.howen.howentest";
	private static final int MSG_PLUSE_CHANGED = 0;
	private Button startButton, stopButton,editkeyButton,cleanCountButton;
	private HowenManager howenobject = null;
	private TextView mShowPluseSpeed,mShowCount;
	private Context mContext;
	protected int mKeyValue=0;
	private TextView mKey;
	private boolean mStartCount=false;
	protected int mTotaltime=0;
	protected int mTotalPulse=0;
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.pluse);
		mContext=this;
		mShowPluseSpeed=(TextView)findViewById(R.id.show_pluse_speed);
		mShowCount=(TextView)findViewById(R.id.show_count);
		mKey=(TextView)findViewById(R.id.key);
		updatekeyView();
		startButton = (Button) findViewById(R.id.start_count_pluse);
		stopButton = (Button) findViewById(R.id.stop_count_pluse);
		editkeyButton = (Button) findViewById(R.id.edit_key);
		cleanCountButton = (Button) findViewById(R.id.clean_count_pluse);
		startButton.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) 
			{
				StartCount();
			}
		});
		stopButton.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) 
			{
				StopCount();
			}
		});

		editkeyButton.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) 
			{
				Editkey();
			}
		});

		cleanCountButton.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) 
			{
				clean();
			}
		});

		howenobject = HowenManager.create(this);
		howenobject.setPluseCallback(mPluseCallback);
	}
	
	public void onDestroy()
	{
		howenobject.release();
		super.onDestroy();
	}
	
	private HowenManager.PluseCallback mPluseCallback = new HowenManager.PluseCallback() 
    {
	    @Override
		public void onPluseChanged(int value) 
		{
			Message msg = Message.obtain();
            msg.what = MSG_PLUSE_CHANGED;
            msg.obj = value;
            mPlusehandler.sendMessage(msg);
	    }
	};
	
	private Handler mPlusehandler = new Handler()
 	{
		@Override
		public void handleMessage(Message msg) 
		{
			if (msg.what == MSG_PLUSE_CHANGED) 
			{
				Object obj = (Object) msg.obj;
				if(obj!=null)
				{
					int value=Integer.parseInt(String.valueOf(obj));
					updatePulseSpeedView(value);
					if(mStartCount)
					{
						mTotaltime++;
						mTotalPulse=mTotalPulse+value;
						updateShowCountView();
					}
				}
			}
		}
	};

	 private void StartCount()
	 {
	 	mStartCount=true;
		mTotaltime=0;
		mTotalPulse=0;
		startButton.setEnabled(false);
	 }
	 
	 private void StopCount()
	 {
	 	mStartCount=false;
		startButton.setEnabled(true);
	 }

	 private void clean()
	 {
	 	mTotaltime=0;
		mTotalPulse=0;
		mStartCount=false;
		mShowCount.setText("");
		startButton.setEnabled(true);
	 }
	 	
	 private void Editkey()
	 {
	        AlertDialog.Builder builder = new AlertDialog.Builder(mContext);
	        builder.setTitle(R.string.edit_key_value);
	        final View view = View.inflate(mContext, R.layout.edit_key_dialog, null);
	        EditText Editkey = (EditText)view.findViewById(R.id.key_value);
			int keyvalue=getkeyvalue();
			Editkey.setText(String.valueOf(keyvalue));
			Editkey.setSelection(Editkey.getText().toString().length());
			builder.setView(view);
	        builder.setPositiveButton(android.R.string.cancel, new DialogInterface.OnClickListener() {
	            @Override
	            public void onClick(DialogInterface dialog, int which) {
	                dialog.cancel();
	            }

	        });
	        builder.setNegativeButton(android.R.string.ok, new DialogInterface.OnClickListener() 
			{
	            @Override
	            public void onClick(DialogInterface dialog, int which) {
	            	String strvalue = Editkey.getText().toString();
					int value= Integer.parseInt(strvalue);
					if(value>0)
					{
						savekeyvalue(value);
					}else
					{
						Toast.makeText(mContext,getString(R.string.invalid) ,Toast.LENGTH_SHORT).show();
					}
					updatekeyView();
	                dialog.cancel();
	            }

	        });
	        builder.show();
    }

	private String GetTimeFormSecond(int time) 
	{
        int h = time/3600;
        int m = (time%3600)/60;
        int s = (time%3600)%60;
        return (h >= 10 ? String.valueOf(h) : ("0" + h)) + ":" +(m >= 10 ? m : ("0" + m)) + ":" + (s >= 10 ? s : ("0" + s));
    }

	private void savekeyvalue(int value)
	{
		SharedPreferences settings = mContext.getSharedPreferences(PULSE_SHARED,0);
		SharedPreferences.Editor editor = settings.edit();
		editor.putInt("key_value", value);
		editor.commit();
	}
	
	private int getkeyvalue()
	{
		SharedPreferences settings = mContext.getSharedPreferences(PULSE_SHARED,0);
		return settings.getInt("key_value", 500);
	}
	
	private void updatekeyView()
	{
		mKeyValue=getkeyvalue();
		String keystring=getString(R.string.key)+" : "+mKeyValue;
		mKey.setText(keystring);
	}
	
	private void updatePulseSpeedView(int Pulse)
	{
		BigDecimal BPulse = new BigDecimal(Pulse);
        BigDecimal BKey = new BigDecimal(mKeyValue); 
        BigDecimal BValue = BPulse.divide(BKey, 8, BigDecimal.ROUND_HALF_UP); 
    	BigDecimal BSpeed = BValue.multiply(new BigDecimal(3600));
		mShowPluseSpeed.setText(getString(R.string.text_pluse)+" : "+Pulse+"      "+getString(R.string.speed)+" : "+formatBigDecimalValue(BSpeed));
	}

	private void updateShowCountView()
	{
		if(mStartCount)
		{
			BigDecimal BPulse = new BigDecimal(mTotalPulse);
       		BigDecimal BKey = new BigDecimal(mKeyValue); 
            BigDecimal BValue = BPulse.divide(BKey, 8, BigDecimal.ROUND_HALF_UP);
			String ShowCountinf=getString(R.string.total_pulse)+" : "+mTotalPulse+"      "
								+getString(R.string.total_mileage)+" : "+formatBigDecimalValue(BValue)+"      "
								+getString(R.string.total_time)+" : "+GetTimeFormSecond(mTotaltime);
			mShowCount.setText(ShowCountinf);
		}
		
	}
	
	private String formatBigDecimalValue(BigDecimal BigDecimalValue) 
	{
        BigDecimal value = BigDecimalValue.setScale(2, RoundingMode.DOWN);
        return value.toPlainString();
    }
	
}