package com.howen.howentestdemo;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import android.app.Activity;
import android.content.Context;
import android.os.Bundle;
import android.telephony.TelephonyManager;
import android.widget.ListView;
import android.widget.SimpleAdapter;
import android.content.BroadcastReceiver;
import android.content.Intent;
import android.content.IntentFilter;
import java.lang.reflect.Method;
import android.os.Build;
import android.os.Bundle;

public class TelephonyStatus extends Activity {
	public static final String ACTION_SIM_STATE_CHANGED = "android.intent.action.SIM_STATE_CHANGED";
	public static final String INTENT_KEY_ICC_STATE = "ss";
	ListView showView;
	String[] statusNames;
	ArrayList<String> statusValues = new ArrayList<String>();
	private SimpleAdapter adapter;
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.sim_main);
		LoadStatusData(false,"");
		
		this.registerReceiver(
                new BroadcastReceiver() {
                    @Override
                    public void onReceive(Context context, Intent intent) {
                        String state = intent.getStringExtra(INTENT_KEY_ICC_STATE);
                        LoadStatusData(true,state);
                    }
                },
                new IntentFilter(ACTION_SIM_STATE_CHANGED));
	}

	private void LoadStatusData(boolean mReceiveIccState,String  SimState) 
	{
		statusValues.clear();
		TelephonyManager tManager = (TelephonyManager) getSystemService(Context.TELEPHONY_SERVICE);
		statusNames = getResources().getStringArray(R.array.statusNames);
		String[] simState = getResources().getStringArray(R.array.simState);
		String[] phoneType = getResources().getStringArray(R.array.phoneType);
		String Unknown = getResources().getString(R.string.text_Unknown);
		statusValues.add(tManager.getDeviceId());
		if ("AT5_V5".equals(Build.MODEL))
		{
			statusValues.add(getProperty("gsm.version.baseband",Unknown));
		}else {
			statusValues.add(tManager.getDeviceSoftwareVersion() != null ? tManager
					.getDeviceSoftwareVersion() : Unknown);
		}
		statusValues.add(tManager.getNetworkOperator());
		statusValues.add(tManager.getNetworkOperatorName());
		statusValues.add(phoneType[tManager.getPhoneType()]);
		statusValues.add(tManager.getCellLocation() != null ? tManager
				.getCellLocation().toString() : Unknown);
		statusValues.add(tManager.getSimCountryIso());
		statusValues.add(tManager.getSimSerialNumber());
		if(mReceiveIccState)
		{
			statusValues.add(SimState);
		}else
		{
			statusValues.add(simState[tManager.getSimState()]);
		}
		showView = (ListView) findViewById(R.id.show_sim);
		ArrayList<Map<String, String>> status = new ArrayList<Map<String, String>>();
		for (int i = 0; i < statusValues.size(); i++) 
		{
			HashMap<String, String> map = new HashMap<String, String>();
			map.put("name", statusNames[i]);
			map.put("value", statusValues.get(i));
			status.add(map);
		}
		
		adapter = new SimpleAdapter(this, status, R.layout.sim_line,
				new String[] { "name", "value" }, new int[] { R.id.name_sim,
						R.id.value_sim });
		showView.setAdapter(adapter);
		adapter.notifyDataSetChanged();
	}

	private static final String CLASS_NAME = "android.os.SystemProperties";
	public static String getProperty(String key, String defaultValue) {
		String value = defaultValue;

		try {
			Class<?> c = Class.forName(CLASS_NAME);
			Method get = c.getMethod("get", String.class, String.class);
			value = (String)(get.invoke(c, key, defaultValue));
		} catch (Exception e) {
			e.printStackTrace();
		} finally {
			return value;
		}
	}
}