
package com.howen.howentestdemo;

import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import java.text.DecimalFormat;
import java.text.SimpleDateFormat;

import com.howen.howentestdemo.R;

public class SocketActivity extends Activity implements OnClickListener {
    private EditText ipET, portET, sendET;
    private TextView recTV;
    private Button conBT, sendBT, recBT, disBT, gpsBT;

    private String ipStr, portStr, sendStr, recStr, autoStr;

    private StringBuilder sb;

    private boolean isWrite = false;
    private boolean isAuto = false;
    private boolean startConnect = true;

    private SharedPreferences preferencesValue;
    private SharedPreferences.Editor editorValue;

    TcpClient client = new TcpClient();

    LocationManager locManager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.socket);

        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_HIDDEN);

        init_view();

        preferencesValue = getSharedPreferences("feijie", MODE_PRIVATE);
        editorValue = preferencesValue.edit();

        ipET.setText(preferencesValue.getString("IP", null));
        portET.setText(preferencesValue.getString("PORT", null));
    }

    private void init_view() {
        portET = (EditText) findViewById(R.id.portEditText);
        ipET = (EditText) findViewById(R.id.ipEditText);
        sendET = (EditText) findViewById(R.id.sendEditText);

        recTV = (TextView) findViewById(R.id.recTextView);

        conBT = (Button) findViewById(R.id.conButton);
        conBT.setOnClickListener(this);
        sendBT = (Button) findViewById(R.id.sendButton);
        sendBT.setOnClickListener(this);
        sendBT.setClickable(false);
        recBT = (Button) findViewById(R.id.recButton);
        recBT.setOnClickListener(this);
        recBT.setClickable(false);
        gpsBT = (Button) findViewById(R.id.gpsButton);
        gpsBT.setOnClickListener(this);
        gpsBT.setClickable(false);

    }

    @Override
    public void onClick(View v) {
        switch (v.getId()) {
            case R.id.conButton:
                ipStr = ipET.getText().toString();
                portStr = portET.getText().toString();

                if ((ipStr.length() > 0) && (portStr.length() > 0) && (startConnect == true)) {
                
                    client.connect(ipStr, Integer.valueOf(portStr));

                    new MyNetThread().start();

                    startConnect = false;

                    editorValue.putString("IP", ipStr);
                    editorValue.putString("PORT", portStr);
                    editorValue.commit();
                }
                break;

            case R.id.sendButton:
                isWrite = true;
                break;

            case R.id.recButton:
                recTV.setText("");
                break;

            case R.id.gpsButton:
                location();
                break;

            default:
                break;
        }
    }

    public void location() {
        
        locManager = (LocationManager) getSystemService
                (Context.LOCATION_SERVICE);
        
        locManager.requestLocationUpdates(LocationManager.GPS_PROVIDER
                , 1000, 1, new LocationListener() 
                {
                    @Override
                    public void onLocationChanged(Location location)
                    {
                        updateView(location);
                    }

                    @Override
                    public void onProviderDisabled(String provider)
                    {
                        updateView(null);
                    }

                    @Override
                    public void onProviderEnabled(String provider)
                    {
                        updateView(locManager
                                .getLastKnownLocation(provider));
                    }

                    @Override
                    public void onStatusChanged(String provider, int status,
                            Bundle extras)
                    {

                    }
                });
    }

   
    public void updateView(Location newLocation)
    {
        sb = new StringBuilder();

        SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        DecimalFormat formatterValue = new DecimalFormat("#.00000");
        DecimalFormat formatterSpeed = new DecimalFormat("#0.0");

        if (newLocation != null)
        {
            sb.append("Time: ");
            sb.append(dateFormat.format(newLocation.getTime()));
            sb.append(" Longitude: ");
            sb.append(formatterValue.format(newLocation.getLongitude()));
            sb.append(" Latitude: ");
            sb.append(formatterValue.format(newLocation.getLatitude()));
            sb.append(" Speed: ");
            sb.append(formatterSpeed.format(newLocation.getSpeed()));

            isAuto = true;

            recTV.setText(sb.toString());
        }
        else
        {
            sb.append(" no location ");
        }
    }

    public class MyNetThread extends Thread {
        @Override
        public void run() {
            while (true) {
                try {
                    if (isWrite == true) {
                        sendStr = sendET.getText().toString();
                        byte[] data = sendStr.getBytes();
                        int length = data.length;
                        client.write(data, length);
                        isWrite = false;
                    }
                    sleep(1000);
                    if (client.readstr != null) {
                        Message msg0 = new Message();
                        msg0.what = 0;
                        msg0.obj = client.readstr;
                        handler.sendMessage(msg0);
                       
                        Log.i("socket", client.readstr);
                        client.readstr = null;
                    }
                    if (isAuto == true) {
                        autoStr = sb.toString();
                        byte[] data = autoStr.getBytes();
                        int length = data.length;
                        client.write(data, length);
                        isAuto = false;
                       
                    }
                    if (TcpClient.serverConnected == true) {
                        Message msg1 = new Message();
                        msg1.what = 1;
                        handler.sendMessage(msg1);
                    } else {
                        Message msg2 = new Message();
                        msg2.what = 2;
                        handler.sendMessage(msg2);
                    }

                } catch (InterruptedException e) {
                    
                    e.printStackTrace();
                }
            }
        }
    }

    Handler handler = new Handler() {
        @Override
        public void handleMessage(Message msg) {
            super.handleMessage(msg);
            switch (msg.what) {
                case 0:
                    recTV.setText(msg.obj.toString());
                    break;
                case 1:
                    sendBT.setClickable(true);
                    recBT.setClickable(true);
                    gpsBT.setClickable(true);
                    conBT.setText(R.string.connection_successful);
                    break;
                case 2:
                    sendBT.setClickable(false);
                    recBT.setClickable(false);
                    gpsBT.setClickable(false);
                    conBT.setText(R.string.reconnecting);
                    break;
            }
        }
    };

    @Override
    protected void onDestroy() {

        client.disconnect();

        super.onDestroy();
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
    
        ((InputMethodManager) getSystemService(INPUT_METHOD_SERVICE))
                .hideSoftInputFromWindow(SocketActivity.this.getCurrentFocus()
                        .getWindowToken(), InputMethodManager.HIDE_NOT_ALWAYS);

        return super.onTouchEvent(event);
    }

}
