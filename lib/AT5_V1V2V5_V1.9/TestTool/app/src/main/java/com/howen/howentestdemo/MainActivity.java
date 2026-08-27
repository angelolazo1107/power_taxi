
package com.howen.howentestdemo;

import com.howen.howentestdemo.SocketActivity;

import android.net.Uri;
import android.os.Bundle;
import android.app.Activity;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.res.Configuration;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import java.io.File;
//import android.os.SystemProperties;
import com.howen.howentestdemo.rfid.RFIDActivity;
import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Build;
import com.howen.howentestdemo.can.CanFdActivity;
import com.howen.howentestdemo.can.CanActivity;
import java.lang.reflect.Method;

public class MainActivity extends Activity {
	private static volatile Method get = null;
    private Button settings_button, sim_button, camera_button, sd_button,
            record_button, gps_button, phone_button, net_button, music_button,
            video_button, gsm_button, battery_button, gpio_button, com_button, sockeT_button;
	private Button canfd_button,can_button;

	private boolean mPermissionCheckActive = false;
	private Button pluse_button;
	private Button oemkeys_button;
	private Button rfid_button;
	private Button oiml_button;
	private Button brightness;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        setConfiguration();

        init_view();

        settings_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent settings_intent = new Intent();
                settings_intent
                        .setComponent(new ComponentName("com.android.settings",
                                "com.android.settings.Settings"));
                startActivity(settings_intent);
            }
        });

        sim_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent sim_intent = new Intent(MainActivity.this,
                        TelephonyStatus.class);
                MainActivity.this.startActivity(sim_intent);
            }
        });

        camera_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
				int cameraCount = android.hardware.Camera.getNumberOfCameras();
				if(havevide(0)&&havevide(1))
				{
					Intent TwoUsbCamera = new Intent(MainActivity.this,TwoUsbCameraActivity.class);
					MainActivity.this.startActivity(TwoUsbCamera);
				}else
				{
					Intent OneUsbCamera = new Intent(MainActivity.this,OneUsbCameraActivity.class);
					MainActivity.this.startActivity(OneUsbCamera);
				}

            }
        });

        sd_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent sd_intent = new Intent(MainActivity.this,
                        SDCardStatus.class);
                MainActivity.this.startActivity(sd_intent);
            }
        });

        record_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent record_intent = new Intent(MainActivity.this,
                        RecordActivity.class);
                MainActivity.this.startActivity(record_intent);
            }
        });

        gps_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent gps_intent = new Intent(MainActivity.this,
                        LocationActivity.class);
                MainActivity.this.startActivity(gps_intent);
            }
        });

        phone_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent phone_intent = new Intent();
                phone_intent.setAction(Intent.ACTION_DIAL);
                MainActivity.this.startActivity(phone_intent);
            }
        });

        net_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent net_intent = new Intent();
                Uri uri = Uri.parse("https://www.howentech.com/");
                net_intent.setAction(Intent.ACTION_VIEW);
                net_intent.setData(uri);
                MainActivity.this.startActivity(net_intent);
            }
        });

        music_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent music_intent = new Intent(MainActivity.this,
                        MusicActivity.class);
                MainActivity.this.startActivity(music_intent);
            }
        });

        video_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                if ("AT5_V5".equals(Build.MODEL)){
                    Intent video_intent = new Intent(MainActivity.this,
                            VideoActivityV5.class);
                    MainActivity.this.startActivity(video_intent);
                } else {
                    Intent video_intent = new Intent(MainActivity.this,
                            VideoActivity.class);
                    MainActivity.this.startActivity(video_intent);
                }
            }
        });

        gsm_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent gsm_intent = new Intent(MainActivity.this,
                        GsmActivity.class);
                MainActivity.this.startActivity(gsm_intent);
            }
        });

        battery_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
              Intent gsensor_intent = new Intent(MainActivity.this, GsensorActivity.class);
              MainActivity.this.startActivity(gsensor_intent);
            }
        });

        gpio_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
				Intent gpio_intent = new Intent(MainActivity.this,GPIOMainActivity.class);
				MainActivity.this.startActivity(gpio_intent);
            }
        });
 

        com_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent com_intent = new Intent(MainActivity.this,
                        SerialPortMain.class);
                MainActivity.this.startActivity(com_intent);
            }
        });

        sockeT_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent socket_intent = new Intent(MainActivity.this,
                        SocketActivity.class);
                MainActivity.this.startActivity(socket_intent);
            }
        });

		pluse_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent pluse_intent = new Intent(MainActivity.this,
                        PluseActivity.class);
                MainActivity.this.startActivity(pluse_intent);
                
            }
        });

		oemkeys_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent oemkeys_intent = new Intent(MainActivity.this,
                        OEMKeysActivity.class);
                MainActivity.this.startActivity(oemkeys_intent);
                
            }
        });

		rfid_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
            	Intent rfid_intent = new Intent(MainActivity.this,
                        RFIDActivity.class);
                MainActivity.this.startActivity(rfid_intent);
            }
        });
		canfd_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
            	Intent canfd_intent = new Intent(MainActivity.this,
                        CanFdActivity.class);
                MainActivity.this.startActivity(canfd_intent);
            }
        });

		can_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
            	Intent can_intent = new Intent(MainActivity.this,
                        CanActivity.class);
                MainActivity.this.startActivity(can_intent);
            }
        });
		oiml_button.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
            	Intent oiml_intent = new Intent(MainActivity.this,
                        OimlActivity.class);
                MainActivity.this.startActivity(oiml_intent);
            }
        });

		brightness.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
            	Intent brightness = new Intent(MainActivity.this,
                        BrightnessActivity.class);
                MainActivity.this.startActivity(brightness);
            }
        });

        if ("AT5_V5".equals(Build.MODEL))
        {
            if (!checkPermissionsV5()) {
                return;
            }
        }else {
            if (!checkPermissions()) {
                return;
            }
        }
    }

	 private boolean checkPermissions() {
        if (mPermissionCheckActive) return false;

        if ((checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED)
                || (checkSelfPermission(Manifest.permission.CALL_PHONE)
                != PackageManager.PERMISSION_GRANTED)
                || (checkSelfPermission(Manifest.permission.CAMERA)
                != PackageManager.PERMISSION_GRANTED)
                || (checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
                != PackageManager.PERMISSION_GRANTED)
                || (checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                != PackageManager.PERMISSION_GRANTED)) {
            requestPermissions(new String[] {
                    Manifest.permission.RECORD_AUDIO,
                    Manifest.permission.CALL_PHONE,
                    Manifest.permission.CAMERA,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE}, 1
            );
            mPermissionCheckActive = true;
            return false;
        }

        return true;
    }

    private boolean checkPermissionsV5() {
        if (mPermissionCheckActive) return false;

        if ((checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED)
                || (checkSelfPermission(Manifest.permission.CALL_PHONE)
                != PackageManager.PERMISSION_GRANTED)
                || (checkSelfPermission(Manifest.permission.CAMERA)
                != PackageManager.PERMISSION_GRANTED)
                || (checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
                != PackageManager.PERMISSION_GRANTED)
                || (checkSelfPermission(Manifest.permission.READ_PHONE_STATE)
                != PackageManager.PERMISSION_GRANTED)
                || (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                != PackageManager.PERMISSION_GRANTED)
                || (checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                != PackageManager.PERMISSION_GRANTED)) {
            requestPermissions(new String[] {
                    Manifest.permission.RECORD_AUDIO,
                    Manifest.permission.CALL_PHONE,
                    Manifest.permission.CAMERA,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                    Manifest.permission.READ_PHONE_STATE,
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE}, 1
            );
            mPermissionCheckActive = true;
            return false;
        }

        return true;
    }

    private void setConfiguration() {
        Configuration configuration = getResources().getConfiguration();
        if (configuration.orientation == configuration.ORIENTATION_PORTRAIT) {
            MainActivity.this
                    .setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
        }
    }

    private void init_view() {
        settings_button = (Button) findViewById(R.id.settings_button);
        sim_button = (Button) findViewById(R.id.sim_button);
        camera_button = (Button) findViewById(R.id.camera_button);
        sd_button = (Button) findViewById(R.id.sd_button);
        record_button = (Button) findViewById(R.id.record_button);
        gps_button = (Button) findViewById(R.id.gps_button);
        phone_button = (Button) findViewById(R.id.phone_button);
        net_button = (Button) findViewById(R.id.net_button);
        music_button = (Button) findViewById(R.id.music_button);
        video_button = (Button) findViewById(R.id.video_button);
        gsm_button = (Button) findViewById(R.id.gsm_button);
        battery_button = (Button) findViewById(R.id.battery_button);
        gpio_button = (Button) findViewById(R.id.gpioButton);
        com_button = (Button) findViewById(R.id.comButton);
        sockeT_button = (Button) findViewById(R.id.socketButton);
		pluse_button = (Button) findViewById(R.id.pluse_button);
		oemkeys_button = (Button) findViewById(R.id.oemkeys_button);
		rfid_button = (Button) findViewById(R.id.rfid);
		canfd_button = (Button) findViewById(R.id.canfdButton);
		can_button = (Button) findViewById(R.id.canButton);
		oiml_button = (Button) findViewById(R.id.oiml_button);
		brightness = (Button) findViewById(R.id.brightness);
		if ("AT5_V2".equals(Build.MODEL)||"AT5_V5".equals(Build.MODEL))
		{
			pluse_button.setVisibility(View.VISIBLE);
			oemkeys_button.setVisibility(View.VISIBLE);
			rfid_button.setVisibility(View.VISIBLE);
			oiml_button.setVisibility(View.VISIBLE);
		}else
		{
			pluse_button.setVisibility(View.GONE);
			oemkeys_button.setVisibility(View.GONE);
			rfid_button.setVisibility(View.GONE);
			oiml_button.setVisibility(View.GONE);
		}
		String canfd=getSystemProperties("persist.sys.can.fd","false");
		if("false".equals(canfd))
		{
			canfd_button.setVisibility(View.GONE);
			can_button.setVisibility(View.GONE);
		}
    }

	public boolean havevide(int id) 
	{
		String filename="/dev/video"+id;
		File file = new File(filename);
		if(file.exists())
		{
			return true;
		}
		return false; 
	}
	private static String getSystemProperties(String prop, String defaultvalue)
	{
	        String value = defaultvalue;
	        try {
	            if (null == get) {
	                synchronized (MainActivity.class) {
	                    if (null == get) {
	                        Class<?> cls = Class.forName("android.os.SystemProperties");
	                        get = cls.getDeclaredMethod("get", new Class<?>[]{String.class, String.class});
	                    }
	                }
	            }
	            value = (String) (get.invoke(null, new Object[]{prop, defaultvalue}));
	        } catch (Throwable e) {
	            e.printStackTrace();
	        }
	        return value;
	 }
}
