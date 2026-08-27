package com.howen.howentestdemo;

import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Bundle;
import android.widget.EditText;
import android.widget.TextView;
import android.app.Activity;

public class GsensorActivity extends Activity implements SensorEventListener {
    private TextView Xvalue;
    private TextView Yvalue;
    private TextView Zvalue;
    private SensorManager sensorManager;
    private Sensor mSensor;
    public EditText fileName;
    public float x;
    public float y;
    public float z;
    public int flag;

    @Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
        setContentView(R.layout.gsensor);
        
        Xvalue=(TextView)findViewById(R.id.X_value);
        Yvalue=(TextView)findViewById(R.id.Y_value);
        Zvalue=(TextView)findViewById(R.id.Z_value);
         
		sensorManager = (SensorManager) getSystemService(Context.SENSOR_SERVICE);
        mSensor=sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);

    }

	protected void onResume() {
		super.onResume();
		sensorManager.registerListener(this, mSensor, SensorManager.SENSOR_DELAY_NORMAL);
	}

	protected void onPause() {
		super.onPause();
		sensorManager.unregisterListener(this);
	}

	@Override
	public void onAccuracyChanged(Sensor sensor, int accuracy) {
		
	}

    @SuppressWarnings("deprecation")
	@Override
    public void onSensorChanged(SensorEvent event)
    {
         x =event.values[SensorManager.DATA_X];
         y =event.values[SensorManager.DATA_Y];
         z =event.values[SensorManager.DATA_Z];

         Xvalue.setText("x = "+x);
         Yvalue.setText("y = "+y);
         Zvalue.setText("z = "+z);
    }

}
