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
//import android.os.UEventObserver;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import com.android.howen.HowenManager;
import com.android.howen.HowenGpioManager;
import android.os.Build;

@SuppressLint("HandlerLeak")
public class GPIOListenerActivity extends Activity 
{
		private String TAG = "gpio";
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
		
		private HowenManager howenobject = null;
		private static final int GPIO_IN_CHANGE = 0;  
		
		@Override
		protected void onCreate(Bundle savedInstanceState) 
		{
			super.onCreate(savedInstanceState);
			setContentView(R.layout.gpiolistener);
			howenobject = HowenManager.create(this);
			if (howenobject.howenOpenGpio() < 0)
				Log.e(TAG, "open gpio fail");
			init();
			howenobject.registerGpioListener(mListenerGPIO);
		}
		private void init() {
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

			if ("AT5_V2".equals(Build.MODEL)||"AT5_V5".equals(Build.MODEL))
			{
				if(howenobject.howenGetGpioData("rk_pac_pin_12v_out_en") == 1)
				{
					out_1TV.setText("OUT1 status is:high");
				}else {
					out_1TV.setText("OUT1 status is:low");
				}
		
				if(howenobject.howenGetGpioData("rk_pac_pin_key_led_en") == 1){
					ledlighTextView.setText("LED_EN status is::high");
					
				}else {
					ledlighTextView.setText("LED_EN status is:low");
				}
			}else
			{
				if(howenobject.howenGetGpioData("P3B6") == 1)
				{
					out_1TV.setText("OUT1 status is:high");
				}else {
					out_1TV.setText("OUT1 status is:low");
				}
		
				if(howenobject.howenGetGpioData("P5C2") == 1){
					ledlighTextView.setText("LED_EN status is::high");
					
				}else {
					ledlighTextView.setText("LED_EN status is:low");
				}
			}

			if ("AT5_V5".equals(Build.MODEL))
			{
				if(howenobject.howenGetGpioData("rk_pac_pin_usb1_vbus_en") == 1){
					usb1_tv.setText("USB1 status is:high");

				}else {
					usb1_tv.setText("USB1 status is:low");
				}

				if(howenobject.howenGetGpioData("rk_pac_pin_camera1_vbus_en") == 1){
					usb2_tv.setText("CAM_1 status is:high");

				}else {
					usb2_tv.setText("CAM_1 status is:low");
				}

				if(howenobject.howenGetGpioData("rk_pac_pin_camera2_vbus_en") == 1){
					usb3_tv.setText("CAM_2 status is:high");

				}else {
					usb3_tv.setText("CAM_2 status is:low");
				}
			}else {
				if (howenobject.howenGetGpioData("rk_pac_pin_usb1_vbus_en") == 1) {
					usb1_tv.setText("USB1 status is:high");

				} else {
					usb1_tv.setText("USB1 status is:low");
				}

				if (howenobject.howenGetGpioData("rk_pac_pin_usb2_vbus_en") == 1) {
					usb2_tv.setText("USB2 status is:high");

				} else {
					usb2_tv.setText("USB2 status is:low");
				}

				if (howenobject.howenGetGpioData("rk_pac_pin_usb3_vbus_en") == 1) {
					usb3_tv.setText("USB3 status is:high");

				} else {
					usb3_tv.setText("USB3 status is:low");
				}
			}
			out1_bt = (Button) findViewById(R.id.out1_btn);
			led_light = (Button) findViewById(R.id.led_btn);
	
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
			public void onClick(View v) {
				switch (v.getId()) 
				{
					case R.id.out1_btn:
						if ("AT5_V2".equals(Build.MODEL)||"AT5_V5".equals(Build.MODEL))
						{
							if(howenobject.howenGetGpioData("rk_pac_pin_12v_out_en") == 1){
								howenobject.howenSetGpioData("rk_pac_pin_12v_out_en", 0);
							}else {
								howenobject.howenSetGpioData("rk_pac_pin_12v_out_en", 1);
							}
						}else
						{
							if(howenobject.howenGetGpioData("P3B6") == 1){
								howenobject.howenSetGpioData("P3B6", 0);
							}else {
								howenobject.howenSetGpioData("P3B6", 1);
							}
						}
						break;
					case R.id.led_btn:
						if ("AT5_V2".equals(Build.MODEL)||"AT5_V5".equals(Build.MODEL))
						{
							if(howenobject.howenGetGpioData("rk_pac_pin_key_led_en") == 1){
								howenobject.howenSetGpioData("rk_pac_pin_key_led_en", 0);
							}else {
								howenobject.howenSetGpioData("rk_pac_pin_key_led_en", 1);
							}
						}else
						{
							if(howenobject.howenGetGpioData("P5C2") == 1){
								howenobject.howenSetGpioData("P5C2", 0);
							}else {
								howenobject.howenSetGpioData("P5C2", 1);
							}
						}
						break;
					case R.id.usb1_btn:
						if(howenobject.howenGetGpioData("rk_pac_pin_usb1_vbus_en") == 1){
							howenobject.howenSetGpioData("rk_pac_pin_usb1_vbus_en", 0);
						}else {
							howenobject.howenSetGpioData("rk_pac_pin_usb1_vbus_en", 1);
						}
						break;
					case R.id.usb2_btn:
						if ("AT5_V5".equals(Build.MODEL))
						{
							if (howenobject.howenGetGpioData("rk_pac_pin_camera1_vbus_en") == 1) {
								howenobject.howenSetGpioData("rk_pac_pin_camera1_vbus_en", 0);
							} else {
								howenobject.howenSetGpioData("rk_pac_pin_camera1_vbus_en", 1);
							}
						}else {
							if (howenobject.howenGetGpioData("rk_pac_pin_usb2_vbus_en") == 1) {
								howenobject.howenSetGpioData("rk_pac_pin_usb2_vbus_en", 0);
							} else {
								howenobject.howenSetGpioData("rk_pac_pin_usb2_vbus_en", 1);
							}
						}
						break;
					case R.id.usb3_btn:
						if ("AT5_V5".equals(Build.MODEL))
						{
							if (howenobject.howenGetGpioData("rk_pac_pin_camera2_vbus_en") == 1) {
								howenobject.howenSetGpioData("rk_pac_pin_camera2_vbus_en", 0);
							} else {
								howenobject.howenSetGpioData("rk_pac_pin_camera2_vbus_en", 1);
							}
						}else {
							if (howenobject.howenGetGpioData("rk_pac_pin_usb3_vbus_en") == 1) {
								howenobject.howenSetGpioData("rk_pac_pin_usb3_vbus_en", 0);
							} else {
								howenobject.howenSetGpioData("rk_pac_pin_usb3_vbus_en", 1);
							}
						}
						break;
					default:
						break;
				}
				
			}
		}
	
		
		private HowenGpioManager.ListenerGpio mListenerGPIO = new HowenGpioManager.ListenerGpio() 
		{
			@Override
			public void onGpioStateChanged(String gpioname,boolean state) 
			{
				Message msg = mHandler.obtainMessage(GPIO_IN_CHANGE);
				Bundle bundle = new Bundle();
				bundle.putString("gpioname", gpioname);
				bundle.putBoolean("state", state);
				msg.setData(bundle);
				mHandler.sendMessage(msg);
			}
		};
		
	
		private Handler mHandler = new Handler() 
		{  
		  @Override  
		  public void handleMessage(Message msg) 
		  {  
			 if (msg.what == GPIO_IN_CHANGE) 
			 {
				Bundle b = msg.getData();
				String gpioname= b.getString("gpioname");
				boolean state=b.getBoolean("state");
				 if ("AT5_V5".equals(Build.MODEL))
				 {
					 if(gpioname.equals("rk_pac_pin_12v_out_en"))
					 {
						 if(state)
						 {
							 out_1TV.setText("OUT1 status is:" + "high");
						 }else
						 {
							 out_1TV.setText("OUT1 status is:" + "low");
						 }
					 }else if(gpioname.equals("rk_pac_pin_key_led_en"))
					 {
						 if(state)
						 {
							 ledlighTextView.setText("LED_EN status is:" + "high");
						 }else
						 {
							 ledlighTextView.setText("LED_EN status is:" + "low");
						 }
					 }else if(gpioname.equals("rk_pac_pin_usb1_vbus_en"))
					 {
						 if(state)
						 {
							 usb1_tv.setText("USB1 status is:" + "high");
						 }else
						 {
							 usb1_tv.setText("USB1 status is:" + "low");
						 }
					 }else if(gpioname.equals("rk_pac_pin_camera1_vbus_en"))
					 {
						 if(state)
						 {
							 usb2_tv.setText("CAM_1 status is:" + "high");
						 }else
						 {
							 usb2_tv.setText("CAM_1 status is:" + "low");
						 }
					 }else if(gpioname.equals("rk_pac_pin_camera2_vbus_en"))
					 {
						 if(state)
						 {
							 usb3_tv.setText("CAM_2 status is:" + "high");
						 }else
						 {
							 usb3_tv.setText("CAM_2 status is:" + "low");
						 }
					 }else if(gpioname.equals("rk_pac_pin_acc_in"))
					 {
						 if(state)
						 {
							 ACCTV.setText("ACC status is:" + "turn off");
						 }else
						 {
							 ACCTV.setText("ACC status is:" + "turn on");
						 }
					 }
				 }else if ("AT5_V2".equals(Build.MODEL))
				{
					if(gpioname.equals("rk_pac_pin_12v_out_en"))
					{
						if(state)
						{
							out_1TV.setText("OUT1 status is:" + "high");
						}else 
						{
							out_1TV.setText("OUT1 status is:" + "low");
						}
					}else if(gpioname.equals("rk_pac_pin_key_led_en"))
					{
						if(state)
						{
							ledlighTextView.setText("LED_EN status is:" + "high");
						}else 
						{
							ledlighTextView.setText("LED_EN status is:" + "low");
						}
					}else if(gpioname.equals("rk_pac_pin_usb1_vbus_en"))
					{
						if(state)
						{
							usb1_tv.setText("USB1 status is:" + "high");
						}else 
						{
							usb1_tv.setText("USB1 status is:" + "low");
						}
					}else if(gpioname.equals("rk_pac_pin_usb2_vbus_en"))
					{
						if(state)
						{
							usb2_tv.setText("USB2 status is:" + "high");
						}else 
						{
							usb2_tv.setText("USB2 status is:" + "low");
						}
					}else if(gpioname.equals("rk_pac_pin_sensor_in1"))
					{
						if(state)
						{
							iN_1TV.setText("IN_1 status is:" + "high");
						}else 
						{
							iN_1TV.setText("IN_1 status is:" + "low");
						}
					}else if(gpioname.equals("rk_pac_pin_sensor_in2"))
					{
						if(state)
						{
							iN_2TV.setText("IN_2 status is:" + "high");
						}else 
						{
							iN_2TV.setText("IN_2 status is:" + "low");
						}
					}else if(gpioname.equals("rk_pac_pin_sensor_in3"))
					{
						if(state)
						{
							iN_3TV.setText("IN_3 status is:" + "high");
						}else 
						{
							iN_3TV.setText("IN_3 status is:" + "low");
						}
					}else if(gpioname.equals("rk_pac_pin_sensor_in4"))
					{
						if(state)
						{
							iN_4TV.setText("IN_4 status is:" + "high");
						}else 
						{
							iN_4TV.setText("IN_4 status is:" + "low");
						}
					}else if(gpioname.equals("rk_pac_pin_acc_in"))
					{
						if(state)
						{
							ACCTV.setText("ACC status is:" + "turn off");
						}else 
						{
							ACCTV.setText("ACC status is:" + "turn on");
						}
					}
				}else
				{
					if(gpioname.equals("P3B6"))
					{
						if(state)
						{
							out_1TV.setText("OUT1 status is:" + "high");
						}else 
						{
							out_1TV.setText("OUT1 status is:" + "low");
						}
					}else if(gpioname.equals("P5C2"))
					{
						if(state)
						{
							ledlighTextView.setText("LED_EN status is:" + "high");
						}else 
						{
							ledlighTextView.setText("LED_EN status is:" + "low");
						}
					}else if(gpioname.equals("P3B3"))
					{
						if(state)
						{
							iN_1TV.setText("IN_1 status is:" + "high");
						}else 
						{
							iN_1TV.setText("IN_1 status is:" + "low");
						}
					}else if(gpioname.equals("P3B4"))
					{
						if(state)
						{
							iN_2TV.setText("IN_2 status is:" + "high");
						}else 
						{
							iN_2TV.setText("IN_2 status is:" + "low");
						}
					}else if(gpioname.equals("P4D3"))
					{
						if(state)
						{
							iN_3TV.setText("IN_3 status is:" + "high");
						}else 
						{
							iN_3TV.setText("IN_3 status is:" + "low");
						}
					}else if(gpioname.equals("P3B5"))
					{
						if(state)
						{
							ACCTV.setText("ACC status is:" + "turn off");
						}else 
						{
							ACCTV.setText("ACC status is:" + "turn on");
						}
					}
				}
			 }
		  }
		};
	
		@Override
		protected void onDestroy() {
			super.onDestroy();
			howenobject.unregisterGpioListener(mListenerGPIO);
			howenobject.howenCloseGpio();
		}
	
}

