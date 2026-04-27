package com.howen.howentestdemo.rfid;

import java.io.File;

import android.app.Activity;
import android.content.Intent;
import android.media.MediaRecorder;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.Toast;
import android.util.Log;
import java.text.SimpleDateFormat;
import android.widget.EditText;
import com.howen.rfid.RFID;
import android.os.Message;
import android.os.Handler;
import com.howen.howentestdemo.R;
import com.howen.howentestdemo.rfid.Utils;

public class RFIDCardID extends Activity 
{
	private static final String TAG = "RFIDCardID";
	protected EditText mLogText;
	protected int mShowLogLines=0;
	private SimpleDateFormat mSimpleDateFormat = new SimpleDateFormat("hh:mm:ss");
	private boolean mRFIDOpen=false;
	private static final int MSG_GET_CARDID = 1;
	private boolean ifdestroy = false;
	private static final int RFID_LENGTH = 5;
	private Button button_clean;
	@Override
	protected void onCreate(Bundle savedInstanceState) 
	{
		super.onCreate(savedInstanceState);
		setContentView(R.layout.rfidcardid);
		mLogText=(EditText)findViewById(R.id.logtext);
		mLogText.setText("");
		mShowLogLines=0;

		button_clean = (Button) findViewById(R.id.button_clean);
		button_clean.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) 
            {
            	mLogText.setText("");
				mShowLogLines=0;
            }
        }); 
		new CardActivateThread().start();
	}
	
	@Override
	protected void onDestroy() 
	{
		super.onDestroy();
		ifdestroy = true;
		RFID.close();
	}
	
	private void ShowLog(String id)
	{	
		StringBuilder StringMsg=new StringBuilder();
		String sRecTime = mSimpleDateFormat.format(new java.util.Date()); 
		StringMsg.append(sRecTime);
		StringMsg.append(" ");
		StringMsg.append("	{");
		StringMsg.append(id);
		StringMsg.append("}");
		StringMsg.append("\r\n");
		mLogText.append(StringMsg);
		mShowLogLines++;
		if (mShowLogLines > 500)
		{
			mLogText.setText("");
			mShowLogLines=0;
		}
	 }

	class CardActivateThread extends Thread {
		@Override
		public void run() 
		{
			if (RFID.open() < 0)
			{
				Log.e(TAG, "RFID open fail");
			}else 
			{
				while (true) 
				{
					if (ifdestroy) 
					{
						break;
					}
					try {	
							if(RFID.getRfidInfo())
							{
								 Message msg = Message.obtain(handler, MSG_GET_CARDID, RFID.PICC_UID);
								 handler.sendMessage(msg);
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
			switch (msg.what) 
			{
				case MSG_GET_CARDID:
					final byte[] rfid = (byte[]) msg.obj;
					byte[] id=new byte[RFID_LENGTH];
					System.arraycopy(rfid, 0, id, 0, RFID_LENGTH);
					ShowLog(Utils.ByteArrToHex(id));
                    break;
            }
		};
	};
}
