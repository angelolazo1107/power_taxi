package com.howen.howentestdemo;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.TextView;

import java.util.LinkedList;
import android.util.Log;
import com.android.howen.HowenManager;
import android.os.Message;
import android.os.Handler;
import java.math.BigDecimal;
import android.content.SharedPreferences;
import android.app.AlertDialog;
import android.widget.EditText;
import android.content.DialogInterface;
import java.math.RoundingMode;
import android.widget.Toast;
import android.widget.LinearLayout;
import java.lang.reflect.Method;

public class OimlActivity extends Activity 
{
	private static final String PULSE_SHARED = "com.howen.howentest";
	private static final int MSG_OIML_PLUSE_CHANGED = 0;
	private static final int MSG_OIML_POWER_ADC_CHANGED = 1;
	private Button startButton, stopButton,editkeyButton,cleanCountButton;
	private HowenManager howenobject = null;
	private TextView mShowPluseSpeed,mShowCount;
	private Context mContext;
	protected int mKeyValue=0;
	private TextView mKey;
	private boolean mStartCount=false;
	protected long mStartTime=0L;
	protected long mStartDistancePulse=0L;
	protected long mLastTotalDistancePulse=0L;

	private static volatile Method get = null;
	private static final String POWER_PROTECT = "persist.sys.power.protect";
	private static final String ACD_POWER_OFF = "persist.sys.power.off";
	private static final String ACD_POWER_ON = "persist.sys.power.on";
	private static final String ACD_FOR_HIRE = "persist.sys.for.hire";
	private static final String ACD_CLOSE_APP = "persist.sys.close.app";
	private static final String ACD_SHUTDOWN = "persist.sys.shutdown";
	private static final int ACTION_POWER_OFF    = 1;
	private static final int ACTION_FOR_HIRE     = 2;
	private static final int ACTION_CLOSEAPP    = 3;
	private static final int ACTION_POWER_ON = 4;
	private EditText mMainPowerOff,mMainPowerOn,mForHire,mCloseApp,mShutDown;
	private TextView mPowerAdcValue;
	private LinearLayout mLinearLayoutPowerAdc;
	private Button saveButton;
	private TextView mPulseSpeed;
	private TextView mFinalSpeed;
	private long mOldTime;
	private boolean mIsFirst = true;
	private long mTestOldTotalPulse;
	private long mOneSecondPulse;
	private int mCount = 0;
	private BigDecimal mPulseSpeed1 = new BigDecimal(0);
	private LinkedList<Long> mPulseWidthList = new LinkedList<>();
	private long mPulseWidthTotal;
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.oiml);
		mContext=this;
		mShowPluseSpeed=(TextView)findViewById(R.id.show_pulse_speed);
		mShowCount=(TextView)findViewById(R.id.show_count);
		mKey=(TextView)findViewById(R.id.key);
		mPowerAdcValue=(TextView)findViewById(R.id.power_adc_value);
		mLinearLayoutPowerAdc=(LinearLayout)findViewById(R.id.linearlayout_power_adc);

		mMainPowerOff=(EditText)findViewById(R.id.main_power_off);
		mMainPowerOn=(EditText)findViewById(R.id.main_power_on);
		mForHire=(EditText)findViewById(R.id.for_hire);
		mCloseApp=(EditText)findViewById(R.id.close_app);
		mShutDown=(EditText)findViewById(R.id.shutdown);
		mPulseSpeed = (TextView) findViewById(R.id.pulse_speed);
		mFinalSpeed = (TextView) findViewById(R.id.final_speed);
		if("true".equals(getSystemProperties(POWER_PROTECT, "false")))
		{
			mMainPowerOff.setText(getPowerAdcValue(ACD_POWER_OFF,290));
			mMainPowerOn.setText(getPowerAdcValue(ACD_POWER_ON,310));
			mForHire.setText(getPowerAdcValue(ACD_FOR_HIRE,500));
			mCloseApp.setText(getPowerAdcValue(ACD_CLOSE_APP,390));
			mShutDown.setText(getPowerAdcValue(ACD_SHUTDOWN,365));
		}else
		{
			mLinearLayoutPowerAdc.setVisibility(View.GONE);
		}
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

		saveButton = (Button) findViewById(R.id.save_power_adc);
		saveButton.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) 
			{
				savePowerAdcSettings();
			}
		});

		howenobject = HowenManager.create(this);
		howenobject.setOimlCallback(mOimlCallback);

		IntentFilter Filter = new IntentFilter();
        Filter.addAction("android.intent.action.POWER_CHANGE");
        mContext.registerReceiver(new BroadcastReceiver()
		{
            @Override
            public void onReceive(Context context, Intent intent)
            {
            	int main_power = intent.getIntExtra("main_power", 0);
                int box_power = intent.getIntExtra("box_power", 0);
				int action = intent.getIntExtra("action", 0);
				switch (action)
				{
					case ACTION_POWER_OFF:
						Toast.makeText(mContext, "MainPower:"+main_power+" BoxPower:"+box_power+" action: main power off", Toast.LENGTH_SHORT).show();
						break;
					case ACTION_FOR_HIRE:
						Toast.makeText(mContext, "MainPower:"+main_power+" BoxPower:"+box_power+" action: box for hire", Toast.LENGTH_SHORT).show();
						break;
					case ACTION_CLOSEAPP:
						Toast.makeText(mContext, "MainPower:"+main_power+" BoxPower:"+box_power+" action: box close app", Toast.LENGTH_SHORT).show();
						break;
					case ACTION_POWER_ON:
						Toast.makeText(mContext, "MainPower:"+main_power+" BoxPower:"+box_power+" action: main power on", Toast.LENGTH_SHORT).show();
					break;
					default:
						break;
				}		
            }
        }, Filter);
	}
	
	public void onDestroy()
	{
		howenobject.release();
		super.onDestroy();
	}
	
	private HowenManager.OimlCallback mOimlCallback = new HowenManager.OimlCallback() 
    {
	    @Override
		public void onOimlPluseChanged(int distance_pulse,long total_distance_pulse,long distance_pulse_width) 
		{
			Bundle bundle=new Bundle();
			bundle.putInt("distance_pulse", distance_pulse);
			bundle.putLong("total_distance_pulse", total_distance_pulse);
			bundle.putLong("distance_pulse_width", distance_pulse_width);

			Message msg = Message.obtain();
            msg.what = MSG_OIML_PLUSE_CHANGED;
            msg.obj = bundle;
            mOimlHandler.sendMessage(msg);
	    }

		@Override
		public void onOimlPowerAdcChanged(int main_power,int box_power) 
		{
			Bundle PowerAdc=new Bundle();
			PowerAdc.putInt("main_power", main_power);
			PowerAdc.putInt("box_power", box_power);
			Message AdcMsg = Message.obtain();
            AdcMsg.what = MSG_OIML_POWER_ADC_CHANGED;
            AdcMsg.obj = PowerAdc;
            mOimlHandler.sendMessage(AdcMsg);
	    }
	};
	
	private Handler mOimlHandler = new Handler()
 	{
		@Override
		public void handleMessage(Message msg) 
		{
			if (msg.what == MSG_OIML_PLUSE_CHANGED) 
			{
				Bundle bundle = (Bundle) msg.obj;
                if (bundle == null) {
                    return;
                }
                int distance_pulse = bundle.getInt("distance_pulse",0);
                long total_distance_pulse = bundle.getLong("total_distance_pulse", 0);
                long distance_pulse_width = bundle.getLong("distance_pulse_width", 0);
				updatePulseSpeedView(distance_pulse, total_distance_pulse, distance_pulse_width);
				if(mStartCount)
				{
					long total_pulse=total_distance_pulse-mStartDistancePulse;
					long time=System.currentTimeMillis()-mStartTime;
					updateShowCountView(total_pulse,time);
				}
				mLastTotalDistancePulse=total_distance_pulse;
			}else if(msg.what == MSG_OIML_POWER_ADC_CHANGED)
			{
				Bundle PowerAdc = (Bundle) msg.obj;
                if (PowerAdc == null) {
                    return;
                }

				int main_power = PowerAdc.getInt("main_power",0);
				int box_power = PowerAdc.getInt("box_power",0);
				String power_adc="MainPower:"+main_power+"  BoxPower:"+box_power;
				mPowerAdcValue.setText(power_adc);
			}
		}
	};

	 private void StartCount()
	 {
	 	mStartCount=true;
		mStartTime=System.currentTimeMillis();
		mStartDistancePulse=mLastTotalDistancePulse;
		startButton.setEnabled(false);
	 }
	 
	 private void StopCount()
	 {
	 	mStartCount=false;
		startButton.setEnabled(true);
	 }

	 private void clean()
	 {
		mStartCount=false;
		mShowCount.setText("");
		startButton.setEnabled(true);
	 }
	
	private void savePowerAdcSettings()
	{	
		String power_off=mMainPowerOff.getText().toString();
		String power_on=mMainPowerOn.getText().toString();
		String for_hire=mForHire.getText().toString();
		String close_app=mCloseApp.getText().toString();
		String shutdown=mShutDown.getText().toString();
		if(Integer.parseInt(power_off)>0&&Integer.parseInt(power_on)>0&&Integer.parseInt(for_hire)>0
			&&Integer.parseInt(close_app)>0&&Integer.parseInt(shutdown)>0)
		{
			setSystemProperties(ACD_POWER_OFF,power_off);
			setSystemProperties(ACD_POWER_ON,power_on);
			setSystemProperties(ACD_FOR_HIRE,for_hire);
			setSystemProperties(ACD_CLOSE_APP,close_app);
			setSystemProperties(ACD_SHUTDOWN,shutdown);
			Intent intent=new Intent("android.intent.action.POWER_ADC_SETTINGS_CHANGE");
			mContext.sendBroadcast(intent);
		}else
		{
			Toast.makeText(mContext, "Power adc value error!", Toast.LENGTH_SHORT).show();
		}
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
	
	private void updatePulseSpeedView(long distance_pulse, long total_distance_pulse, long distance_pulse_width) {
		long tmpPulseWidth;
		mOneSecondPulse += distance_pulse;
		mPulseWidthTotal = 0;
		mPulseWidthList.addFirst(distance_pulse_width);
		if (mCount < 10) {
			mCount++;
		} else {
			mPulseWidthList.removeLast();
			mCount = 10;
		}
		for (long pulseWidth : mPulseWidthList) {
			mPulseWidthTotal += pulseWidth;
		}

		if (mPulseWidthList.size() > 0) {
			tmpPulseWidth = mPulseWidthTotal / mPulseWidthList.size(); // 计算出1S内的平均脉冲宽度
		} else {
			tmpPulseWidth = distance_pulse_width;
		}
		BigDecimal bKey = new BigDecimal(mKeyValue);
		BigDecimal bPulse = new BigDecimal(1);
		BigDecimal bValue = bPulse.divide(bKey, 8, BigDecimal.ROUND_HALF_UP);
		// 计算出1s中内产生一个脉冲的临界速度。
		BigDecimal tmpSpeed = bValue.multiply(new BigDecimal(3600)).setScale(2, BigDecimal.ROUND_HALF_UP);
		BigDecimal pulseWidthSpeed;
		long currTime = System.currentTimeMillis();
		// 用时间戳来决定1S钟刷新一次速度
		if (currTime - mOldTime >= 1000) {
			long pulse = mOneSecondPulse/2;
			mIsFirst = true;
			// 方法一：用脉冲宽度计算速度
			if (total_distance_pulse - mTestOldTotalPulse == 0) {
				mShowPluseSpeed.setText(getString(R.string.text_pluse)+" : "+pulse+"	  "+getString(R.string.pulse_width_speed)+" : "+0);
				pulseWidthSpeed = new BigDecimal(0);
			} else if (tmpPulseWidth > 0) {
				BigDecimal time = new BigDecimal(tmpPulseWidth).multiply(new BigDecimal(2)).divide(new BigDecimal(1000000));
				pulseWidthSpeed = bValue.multiply(new BigDecimal(3600)).divide(time, 8, BigDecimal.ROUND_HALF_UP).setScale(2, RoundingMode.UP);
				Log.d("stone", "pulseWidthSpeed = " + pulseWidthSpeed);
                // 速度低于1S内1个脉冲时的速度就认为时0
				if (pulseWidthSpeed.compareTo(tmpSpeed) >= 0) {
					mShowPluseSpeed.setText(getString(R.string.text_pluse)+" : " + pulse + "	  "+getString(R.string.pulse_width_speed)+ " : " + pulseWidthSpeed);
				} else {
					mShowPluseSpeed.setText(getString(R.string.text_pluse)+" : " + pulse + "	  "+getString(R.string.pulse_width_speed)+" : " + 0);
					pulseWidthSpeed = new BigDecimal(0);
				}
			} else {
				mShowPluseSpeed.setText(getString(R.string.text_pluse)+" : " + pulse + "	  "+getString(R.string.pulse_width_speed)+ " : " + 0);
				pulseWidthSpeed = new BigDecimal(0);
			}

			// 方法二：用当前时间内的脉冲数计算速度
			long totalPulse = total_distance_pulse - mTestOldTotalPulse;
			long time = currTime - mOldTime;
			BigDecimal pulseCount = new BigDecimal(totalPulse).divide(new BigDecimal(2));
			BigDecimal currMileage = pulseCount.divide(bKey, 8 , BigDecimal.ROUND_HALF_UP);
			BigDecimal tt = new BigDecimal(time).divide(new BigDecimal(3600000), 8 , BigDecimal.ROUND_HALF_UP);
			BigDecimal currSpeed = currMileage.divide(tt, 2, BigDecimal.ROUND_HALF_DOWN);
			Log.d("stone", "currSpeed = " + currSpeed + " , tmpSpeed = " + tmpSpeed + " , pulseWidthSpeed = " + pulseWidthSpeed);
			if (total_distance_pulse - mTestOldTotalPulse == 0 || currSpeed.compareTo(tmpSpeed) < 0) {
				mPulseSpeed.setText(getString(R.string.pulse_speed) + " : " + 0);
				currSpeed = new BigDecimal(0);
			} else {
				mPulseSpeed.setText(getString(R.string.pulse_speed) + " : " + currSpeed);
			}

			// 最终显示，速度大于20时，以脉冲个数速度显示，小于时以脉冲宽度速度显示
			if (pulseWidthSpeed.compareTo(new BigDecimal(20)) >= 0) {
                mFinalSpeed.setText(getString(R.string.final_speed) + " : " + currSpeed);
			} else {
				mFinalSpeed.setText(getString(R.string.final_speed) + " : " + pulseWidthSpeed);
			}
		}

		if (mIsFirst) {
			mOldTime = currTime;
			mIsFirst = false;
			mTestOldTotalPulse = total_distance_pulse;
			mOneSecondPulse = 0;
		}
	}
	
	private void updateShowCountView(long total_pulse, long time)
	{
		if(mStartCount)
		{
			long Pulse=(total_pulse>>1);

			BigDecimal BPulse = new BigDecimal(Pulse);
       		BigDecimal BKey = new BigDecimal(mKeyValue); 
            BigDecimal BValue = BPulse.divide(BKey, 8, BigDecimal.ROUND_HALF_UP);

			BigDecimal Btime=new BigDecimal(time).divide(new BigDecimal(1000)).setScale(3, RoundingMode.HALF_UP);
			
			String ShowCountinf=getString(R.string.total_pulse)+" : "+Pulse+"      "
								+getString(R.string.total_mileage)+" : "+formatBigDecimalValue(BValue)+"      "
								+getString(R.string.total_time)+" : "+GetTimeFormSecond((int) Btime.floatValue());
			mShowCount.setText(ShowCountinf);
		}
		
	}
	
	private String formatBigDecimalValue(BigDecimal BigDecimalValue) 
	{
        BigDecimal value = BigDecimalValue.setScale(2, RoundingMode.DOWN);
        return value.toPlainString();
    }
	
	private static String getSystemProperties(String key, String defaultValue) 
	{
        try {
            final Class<?> systemProperties = Class.forName("android.os.SystemProperties");
            final Method get = systemProperties.getMethod("get", String.class, String.class);
            return (String) get.invoke(null, key, defaultValue);
        } catch (Exception e) {
            return defaultValue;
        }
    }
	
	private static void setSystemProperties(String key, String value)
	{
		try
		{
			Class<?> clazz = Class.forName("android.os.SystemProperties");
			Method mthd = clazz.getMethod("set", new Class[] { String.class, String.class });
			mthd.setAccessible(true);
			mthd.invoke(clazz, new Object[] { key, value });
		}
		catch (Exception e)
		{
			e.printStackTrace();
		}
	}
	
	private String getPowerAdcValue(String key,int defvalue) 
	{
		return getSystemProperties(key, Integer.toString(defvalue));
	}
	
}
