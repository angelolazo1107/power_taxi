package com.howen.howentestdemo;

import com.howen.howennative.gpio_info;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.TextView;
import android.os.BatteryManager;
import android.content.Intent;
import android.content.BroadcastReceiver;
import android.os.Build;

@SuppressLint("HandlerLeak")
public class GPIOActivity extends Activity {
	private static final String TAG="GPIOActivity";
	private TextView iN_1TV = null;
	private TextView iN_2TV = null;
	private TextView iN_3TV = null;
	private TextView iN_4TV = null;
	private TextView ACCTV = null;
	private TextView out_1TV = null;
	private TextView ledlighTextView = null;
	private TextView usb1_tv = null;
	private TextView usb2_tv = null;
	private TextView usb3_tv = null;
	private Button out1_bt = null;
	private Button led_light = null;
	private Button usb1_btn = null;
	private Button usb2_btn = null;
	private Button usb3_btn = null;
	
	private String[] gpioStrings_v1 = {"P3B6","P5C2","P3B3","P3B4","P4D3","P3B5"};
	
	private String[] gpioStrings_v2 = {"rk_pac_pin_12v_out_en",
									"rk_pac_pin_key_led_en",
									"rk_pac_pin_usb1_vbus_en",
									"rk_pac_pin_usb2_vbus_en",
									"rk_pac_pin_sensor_in1",
									"rk_pac_pin_sensor_in2",
									"rk_pac_pin_sensor_in3",
									"rk_pac_pin_sensor_in4",
									"rk_pac_pin_acc_in"};

	private String[] gpioStrings_v5 = {"rk_pac_pin_12v_out_en",
			"rk_pac_pin_key_led_en",
			"rk_pac_pin_usb1_vbus_en",
			"rk_pac_pin_camera1_vbus_en",
			"rk_pac_pin_camera2_vbus_en",
			"rk_pac_pin_acc_in"};

	private boolean ifdestroy = false;
	private int gpio_value;
	private int i = 0;
	private String gpioValueState = "";
	@Override
	protected void onCreate(Bundle savedInstanceState) 
	{
		super.onCreate(savedInstanceState);
		setContentView(R.layout.gpio);
		init();
		new gpioThread().start();
	}
	
	class gpioThread extends Thread {
		@Override
		public void run() 
		{
			if (gpio_info.open_gpio() < 0)
				Log.e(TAG, "open gpio fail");
			else {
				while (true) {
					if (ifdestroy) {
						break;
					}
					try {
						if ("AT5_V5".equals(Build.MODEL))
						{
							gpio_value = gpio_info.get_gpio_data(gpioStrings_v5[i]);
							if (gpio_value == 0) {
								if("rk_pac_pin_acc_in".equals(gpioStrings_v5[i]))
								{
									gpioValueState = "turn on";
								}else
								{
									gpioValueState = "low";
								}
							} else if (gpio_value == 1) {
								if("rk_pac_pin_acc_in".equals(gpioStrings_v5[i]))
								{
									gpioValueState = "turn off";
								}else
								{
									gpioValueState = "high";
								}
							} else{
								gpioValueState = "XX";
							}
							Message msg = handler.obtainMessage();
							msg.obj = gpioValueState;
							msg.what = i;
							handler.sendMessage(msg);

							i++;
							if (gpioStrings_v5.length == i)
								i = 0;
						}else if ("AT5_V2".equals(Build.MODEL))
							{
								gpio_value = gpio_info.get_gpio_data(gpioStrings_v2[i]);
								if (gpio_value == 0) {
									if("rk_pac_pin_acc_in".equals(gpioStrings_v2[i]))
									{
										gpioValueState = "turn on";
									}else
									{
										gpioValueState = "low";
									}
								} else if (gpio_value == 1) {
									if("rk_pac_pin_acc_in".equals(gpioStrings_v2[i]))
									{
										gpioValueState = "turn off";
									}else
									{
										gpioValueState = "high";
									}
								} else{
									gpioValueState = "XX";
								}
								Message msg = handler.obtainMessage();
								msg.obj = gpioValueState;
								msg.what = i;
								handler.sendMessage(msg);

								i++;
								if (gpioStrings_v2.length == i)
									i = 0;
							}else 
							{
								gpio_value = gpio_info.get_gpio_data(gpioStrings_v1[i]);
								if (gpio_value == 0) {
									if("P3B5".equals(gpioStrings_v1[i]))
									{
										gpioValueState = "turn on";
									}else
									{
										gpioValueState = "low";
									}
								} else if (gpio_value == 1) {
									if("P3B5".equals(gpioStrings_v1[i]))
									{
										gpioValueState = "turn off";
									}else
									{
										gpioValueState = "high";
									}
								} else{
									gpioValueState = "XX";
								}
								Message msg = handler.obtainMessage();
								msg.obj = gpioValueState;
								msg.what = i;
								handler.sendMessage(msg);

								i++;
								if (gpioStrings_v1.length == i)
									i = 0;
							}

							sleep(200);

					} catch (InterruptedException e) {
						e.printStackTrace();
					}
				}
			}
		}
	}

	Handler handler = new Handler() 
	{
		public void handleMessage(Message msg) 
		{
			if ("AT5_V5".equals(Build.MODEL))
			{
				switch (msg.what)
				{
					case 0:
						out_1TV.setText("OUT1 status is:" + msg.obj);
						break;
					case 1:
						ledlighTextView.setText("LED_EN status is:" + msg.obj);
						break;
					case 2:
						usb1_tv.setText("USB1 status is:" + msg.obj);
						break;
					case 3:
						usb2_tv.setText("CAM_1 status is:" + msg.obj);
						break;
					case 4:
						usb3_tv.setText("CAM_2 status is:" + msg.obj);
						break;
					case 5:
						ACCTV.setText("ACC status is:" + msg.obj);
						break;
					default:
						break;
				}
			}else if ("AT5_V2".equals(Build.MODEL))
			{
				switch (msg.what) 
				{
				case 0:
					out_1TV.setText("OUT1 status is:" + msg.obj);
					break;
				case 1:
					ledlighTextView.setText("LED_EN status is:" + msg.obj);
					break;
				case 2:
					usb1_tv.setText("USB1 status is:" + msg.obj);
					break;
				case 3:
					usb2_tv.setText("USB2 status is:" + msg.obj);
					break;
				case 4:
					iN_1TV.setText("IN_1 status is:" + msg.obj);
					break;
				case 5:
					iN_2TV.setText("IN_2 status is:" + msg.obj);
					break;
				case 6:
					iN_3TV.setText("IN_3 status is:" + msg.obj);
					break;
				case 7:
					iN_4TV.setText("IN_4 status is:" + msg.obj);
					break;
				case 8:
					ACCTV.setText("ACC status is:" + msg.obj);
					break;
				default:
					break;
				}
			}else
			{
				switch (msg.what) 
				{
				case 0:
					out_1TV.setText("OUT1 status is:" + msg.obj);
					break;
				case 1:
					ledlighTextView.setText("LED_EN status is:" + msg.obj);
					break;
				case 2:
					iN_1TV.setText("IN_1 status is:" + msg.obj);
					break;
				case 3:
					iN_2TV.setText("IN_2 status is:" + msg.obj);
					break;
				case 4:
					iN_3TV.setText("IN_3 status is:" + msg.obj);
					break;
				case 5:
					ACCTV.setText("ACC status is:" + msg.obj);
					break;
				default:
					break;
				}
			}
		};
	};

	private void init()
	{
		ACCTV = (TextView) findViewById(R.id.acc_tv);
		iN_1TV = (TextView) findViewById(R.id.in1);
		iN_2TV = (TextView) findViewById(R.id.in2);
		iN_3TV = (TextView) findViewById(R.id.in3);
		iN_4TV = (TextView) findViewById(R.id.in4);
		out_1TV = (TextView) findViewById(R.id.out1_tv);
		ledlighTextView = (TextView) findViewById(R.id.led_tv);
		usb1_tv = (TextView) findViewById(R.id.usb1_tv);
		usb2_tv = (TextView) findViewById(R.id.usb2_tv);
		usb3_tv = (TextView) findViewById(R.id.usb3_tv);
		out1_bt = (Button) findViewById(R.id.out1_btn);
		led_light = (Button) findViewById(R.id.led_btn);
		usb1_btn = (Button) findViewById(R.id.usb1_btn);
		usb2_btn = (Button) findViewById(R.id.usb2_btn);
		usb3_btn = (Button) findViewById(R.id.usb3_btn);
		buttonClick click = new buttonClick();
		out1_bt.setOnClickListener(click);
		led_light.setOnClickListener(click);
		usb1_btn.setOnClickListener(click);
		usb2_btn.setOnClickListener(click);
		usb3_btn.setOnClickListener(click);

		if ("AT5_V5".equals(Build.MODEL))
		{
			usb1_btn.setVisibility(View.VISIBLE);
			usb2_btn.setVisibility(View.VISIBLE);
			usb1_tv.setVisibility(View.VISIBLE);
			usb2_tv.setVisibility(View.VISIBLE);
			iN_1TV.setVisibility(View.GONE);
			iN_2TV.setVisibility(View.GONE);
			iN_3TV.setVisibility(View.GONE);
			iN_4TV.setVisibility(View.GONE);
		}else if ("AT5_V2".equals(Build.MODEL))
		{
			usb1_btn.setVisibility(View.VISIBLE);
			usb2_btn.setVisibility(View.VISIBLE);
			usb1_tv.setVisibility(View.VISIBLE);
			usb2_tv.setVisibility(View.VISIBLE);
			iN_4TV.setVisibility(View.VISIBLE);
			usb3_btn.setVisibility(View.GONE);
			usb3_tv.setVisibility(View.GONE);
		}else
		{
			usb1_btn.setVisibility(View.GONE);
			usb2_btn.setVisibility(View.GONE);
			usb1_tv.setVisibility(View.GONE);
			usb2_tv.setVisibility(View.GONE);
			iN_4TV.setVisibility(View.GONE);
			usb3_btn.setVisibility(View.GONE);
			usb3_tv.setVisibility(View.GONE);
		}
	}
	
	class buttonClick implements OnClickListener {
		@Override
		public void onClick(View v)
		{
			switch (v.getId()) {
			case R.id.out1_btn:

				if ("AT5_V2".equals(Build.MODEL)||"AT5_V5".equals(Build.MODEL))
				{
					if(gpio_info.get_gpio_data("rk_pac_pin_12v_out_en") == 1){
						gpio_info.set_gpio_data("rk_pac_pin_12v_out_en", 0);
					}else {
						gpio_info.set_gpio_data("rk_pac_pin_12v_out_en", 1);
					}
				}else 
				{
					if(gpio_info.get_gpio_data("P3B6") == 1){
					gpio_info.set_gpio_data("P3B6", 0);
					}else {
						gpio_info.set_gpio_data("P3B6", 1);
					}
				}
				break;
			case R.id.led_btn:
				if ("AT5_V2".equals(Build.MODEL)||"AT5_V5".equals(Build.MODEL))
				{
					if(gpio_info.get_gpio_data("rk_pac_pin_key_led_en") == 1){
						gpio_info.set_gpio_data("rk_pac_pin_key_led_en", 0);
					}else {
						gpio_info.set_gpio_data("rk_pac_pin_key_led_en", 1);
					}
				}else
				{
					if(gpio_info.get_gpio_data("P5C2") == 1){
					gpio_info.set_gpio_data("P5C2", 0);
					}else {
						gpio_info.set_gpio_data("P5C2", 1);
					}
				}
				break;
			case R.id.usb1_btn:
				if(gpio_info.get_gpio_data("rk_pac_pin_usb1_vbus_en") == 1){
					gpio_info.set_gpio_data("rk_pac_pin_usb1_vbus_en", 0);
				}else {
					gpio_info.set_gpio_data("rk_pac_pin_usb1_vbus_en", 1);
				}
				break;
			case R.id.usb2_btn:
				if ("AT5_V5".equals(Build.MODEL))
				{
					if (gpio_info.get_gpio_data("rk_pac_pin_camera1_vbus_en") == 1) {
						gpio_info.set_gpio_data("rk_pac_pin_camera1_vbus_en", 0);
					} else {
						gpio_info.set_gpio_data("rk_pac_pin_camera1_vbus_en", 1);
					}
				}else {
					if (gpio_info.get_gpio_data("rk_pac_pin_usb2_vbus_en") == 1) {
						gpio_info.set_gpio_data("rk_pac_pin_usb2_vbus_en", 0);
					} else {
						gpio_info.set_gpio_data("rk_pac_pin_usb2_vbus_en", 1);
					}
				}
				break;

			case R.id.usb3_btn:
				if ("AT5_V5".equals(Build.MODEL))
				{
					if (gpio_info.get_gpio_data("rk_pac_pin_camera2_vbus_en") == 1) {
						gpio_info.set_gpio_data("rk_pac_pin_camera2_vbus_en", 0);
					} else {
						gpio_info.set_gpio_data("rk_pac_pin_camera2_vbus_en", 1);
					}
				}else {
					if (gpio_info.get_gpio_data("rk_pac_pin_usb3_vbus_en") == 1) {
						gpio_info.set_gpio_data("rk_pac_pin_usb3_vbus_en", 0);
					} else {
						gpio_info.set_gpio_data("rk_pac_pin_usb3_vbus_en", 1);
					}
				}
				break;
				
			default:
				break;
			}
			
		}
	}

	@Override
	protected void onDestroy() {
		super.onDestroy();
		ifdestroy = true;
		gpio_info.close_gpio();
	}

}
