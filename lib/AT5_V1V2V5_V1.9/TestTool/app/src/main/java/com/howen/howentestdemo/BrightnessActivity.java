package com.howen.howentestdemo;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TimePicker;
import android.widget.Spinner;
import java.util.ArrayList;
import java.util.List;
import android.widget.ArrayAdapter;
import android.view.View;
import android.util.Log;
import android.widget.Button;
import android.content.SharedPreferences;
import android.content.BroadcastReceiver;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.provider.Settings;
import android.net.Uri;
import android.text.format.Time;


public class BrightnessActivity extends Activity {
	private SharedPreferences mSharedPreferences;
	private Context mContext;
	public static final String BRIGHTNESS_PRE = "Brightness";
	public static final String FROM_HOUR = "from_hour";
	public static final String FROM_MINUTE = "from_minute";
	public static final String TO_HOUR = "to_hour";
	public static final String TO_MINUTE = "to_minute";
	public static final String DAY_LEVEL = "day_level";
	public static final String NIGHT_LEVEL = "night_level";
	public static final String SCREEN_BRIGHTNESS = "screen_brightness";
	private TimePicker DayTimeFrom;
	private TimePicker DayTimeTo;
	private Spinner Daylevel;
	private Spinner Nightlevel;
	private Button save;
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.brightness);
		mContext=this;
		mSharedPreferences = this.getSharedPreferences(BRIGHTNESS_PRE, 0);
		int screenBrightness=getScreenBrightness(mContext);
		putValue(SCREEN_BRIGHTNESS,screenBrightness);
		initView();
		registerTimeTickReceiver();
		CheckPermission();
		UpdateScreenBrightness();
	}

	private void initView() 
	{
		DayTimeFrom = (TimePicker) findViewById(R.id.day_time_from);
		DayTimeTo = (TimePicker) findViewById(R.id.day_time_to);
		DayTimeFrom.setIs24HourView(true);
		DayTimeTo.setIs24HourView(true);
		DayTimeFrom.setHour(getValue(FROM_HOUR));
		DayTimeFrom.setMinute(getValue(FROM_MINUTE));
		DayTimeTo.setHour(getValue(TO_HOUR));
		DayTimeTo.setMinute(getValue(TO_MINUTE));
		save=(Button)findViewById(R.id.save);
		save.setOnClickListener(new ButtonClickEvent());
		
		List<String> leave = new ArrayList<String>();
		for (int i = 1; i <= 100; i++) {
			leave.add(i+"%");
		}
		Daylevel = (Spinner) findViewById(R.id.day_level);
		ArrayAdapter<String> DayAdapter = new ArrayAdapter<String>(this,
				android.R.layout.simple_spinner_item, leave);
		DayAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
		Daylevel.setAdapter(DayAdapter);
		int daylevel=getValue(DAY_LEVEL);
		Daylevel.setSelection(daylevel-1);

		Nightlevel = (Spinner) findViewById(R.id.night_level);
		ArrayAdapter<String> NightAdapter = new ArrayAdapter<String>(this,
				android.R.layout.simple_spinner_item, leave);
		NightAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
		Nightlevel.setAdapter(NightAdapter);
		int nightlevel=getValue(NIGHT_LEVEL);
		Nightlevel.setSelection(nightlevel-1);
	}

	public int getValue(String key)
	{
		if(key.equals(FROM_HOUR))
		{
			return mSharedPreferences.getInt(key,6);
		}else if(key.equals(TO_HOUR))
		{
			return mSharedPreferences.getInt(key,18);
		}else if(key.equals(DAY_LEVEL))
		{
			return mSharedPreferences.getInt(key,90);
		}else if(key.equals(NIGHT_LEVEL))
		{
			return mSharedPreferences.getInt(key,70);
		}
		return mSharedPreferences.getInt(key,0);
	}

	public void putValue(String key,int value)
	{
		SharedPreferences.Editor edit = mSharedPreferences.edit();
		edit.putInt(key,value);
		edit.commit();
	}


	class ButtonClickEvent implements View.OnClickListener 
	{
		public void onClick(View v)
		{
			switch (v.getId()) 
			{
				case R.id.save:
					save();
					break;
				default:
					break;
			}
			
		}
	}
	
	public void save() 
	{	
		putValue(FROM_HOUR,DayTimeFrom.getHour());
		putValue(FROM_MINUTE,DayTimeFrom.getMinute());
		putValue(TO_HOUR,DayTimeTo.getHour());
		putValue(TO_MINUTE,DayTimeTo.getMinute());
		String strdaylevel = Daylevel.getSelectedItem().toString();
		int daylevel=getlevel(strdaylevel);
		String strnightlevel = Nightlevel.getSelectedItem().toString();
		int nightlevel=getlevel(strnightlevel);
		putValue(DAY_LEVEL,daylevel);
		putValue(NIGHT_LEVEL,nightlevel);
	}

	public int getlevel(String strlevel) 
	{
		int index=strlevel.indexOf("%");
		return Integer.parseInt(strlevel.substring(0,index));
	}

	@Override
    public void onDestroy() 
    {
		if (Settings.System.canWrite(BrightnessActivity.this))
		{
			int screenBrightness = getValue(SCREEN_BRIGHTNESS);
			setScreenBrightness(mContext, screenBrightness);
		}
	   mContext.unregisterReceiver(mIntentReceiver);
       super.onDestroy();
    }

	protected void registerTimeTickReceiver() 
	{
       IntentFilter filter = new IntentFilter();
       filter.addAction(Intent.ACTION_TIME_TICK);
       mContext.registerReceiver(mIntentReceiver, filter, null, null);
    }
	
	private BroadcastReceiver mIntentReceiver = new BroadcastReceiver() 
    {
        @Override
        public void onReceive(Context context, Intent intent) {
            final String action = intent.getAction();
            if (Intent.ACTION_TIME_TICK.equals(action))
            {
				UpdateScreenBrightness();
            }
        }
    };
	 private void CheckPermission() 
	 {
        if (!Settings.System.canWrite(BrightnessActivity.this))
		{
            Uri selfPackageUri = Uri.parse("package:"
                    + getPackageName());
            Intent intent = new Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS,
                    selfPackageUri);
            startActivity(intent);
        }
    }
	private int getScreenBrightness(Context context) 
    {
        return Settings.System.getInt(context.getContentResolver(),Settings.System.SCREEN_BRIGHTNESS, 125);
    }

	public void setScreenManualMode(Context context)
	{
        ContentResolver contentResolver = context.getContentResolver();
        try {
            int mode = Settings.System.getInt(contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS_MODE);
            if (mode == Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC) {
                Settings.System.putInt(contentResolver,
                        Settings.System.SCREEN_BRIGHTNESS_MODE,
                        Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL);
            }
        } catch (Settings.SettingNotFoundException e) {
            e.printStackTrace();
        }
    }
	
	private void setScreenBrightness(Context context,int birghtessValue)
	{
        setScreenManualMode(context);
        Settings.System.putInt(context.getContentResolver(),Settings.System.SCREEN_BRIGHTNESS, birghtessValue);
    }
	
	public void UpdateScreenBrightness()
	{
		if (!Settings.System.canWrite(BrightnessActivity.this))
			return;
		int ScreenBrightness=getScreenBrightness(mContext);
		int from_hour=getValue(FROM_HOUR);
		int from_minute=getValue(FROM_MINUTE);
		int to_hour=getValue(TO_HOUR);
		int to_minute=getValue(TO_MINUTE);
		if(lsDayTime(from_hour,from_minute,to_hour,to_minute))
		{
			int day_level=(int)(getValue(DAY_LEVEL)*2.55);
			if(day_level!=ScreenBrightness)
			{
				setScreenBrightness(mContext,day_level);
			}
		}else
		{
			int night_level=(int)(getValue(NIGHT_LEVEL)*2.55);
			if(night_level!=ScreenBrightness)
			{
				setScreenBrightness(mContext,night_level);
			}
		}
	}

	public static boolean lsDayTime(int beginHour, int beginMin, int endHour, int endMin)
    {
        boolean result = false;
        final long aDayInMillis = 1000 * 60 * 60 * 24;
        final long currentTimeMillis = System.currentTimeMillis();
        Time now = new Time();
        now.set(currentTimeMillis);
        Time startTime = new Time();
        startTime.set(currentTimeMillis);
        startTime.hour = beginHour;
        startTime.minute = beginMin;
        Time endTime = new Time();
        endTime.set(currentTimeMillis);
        endTime.hour = endHour;
        endTime.minute = endMin;
        if (!startTime.before(endTime)) 
        {
            startTime.set(startTime.toMillis(true) - aDayInMillis);
            result = !now.before(startTime) && !now.after(endTime); 
            Time startTimeInThisDay = new Time();
            startTimeInThisDay.set(startTime.toMillis(true) + aDayInMillis);
            if (!now.before(startTimeInThisDay)) {
                result = true;
            }
        } else {
            result = !now.before(startTime) && !now.after(endTime);
        }
        return result;
    }
}
