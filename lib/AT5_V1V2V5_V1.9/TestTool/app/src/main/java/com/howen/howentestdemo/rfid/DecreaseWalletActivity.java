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

import android.widget.TextView;

import java.io.UnsupportedEncodingException;

public class DecreaseWalletActivity extends Activity 
{
	private static final String TAG = "DecreaseWalletActivity";
	private boolean mRFIDOpen=false;
	private static final int MSG_DECREASE_SUCCESS = 1;
	private static final int MSG_DECREASE_FAIL = 2;
	private static final int MSG_CLEAN = 3;
	private static final int DECREASE_INTERVAL_TIME = 10*1000;
	private boolean ifdestroy = false;
	private TextView decrease_value = null;
	private TextView decrease_result = null;
	private String lastcardid =null;
	private long lastDecreaseTime=0;
	
	@Override
	protected void onCreate(Bundle savedInstanceState) 
	{
		super.onCreate(savedInstanceState);
		setContentView(R.layout.wallet_decrease);

		decrease_value = (TextView) findViewById(R.id.decrease_value);
		decrease_result = (TextView) findViewById(R.id.decrease_result);
		new DecreaseWalletThread().start();
	}
	
	@Override
	protected void onDestroy() 
	{
		super.onDestroy();
		ifdestroy = true;
		RFID.close();
	}
	
	class DecreaseWalletThread extends Thread {
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
								int sector=Configs.WALLET_BLOCK/4;	
								if(RFID.CardAuth(Configs.WALLET_KEY_MODEM,sector,Configs.getwalletkey(),RFID.PICC_UID)==0)
								{
									byte[] buf = RFID.CardBlockread(Configs.WALLET_BLOCK);
									if(buf!=null)
									{
										byte[] temp = new byte[4] ;
										System.arraycopy(buf, 0, temp, 0, 4);
										int balance = Utils.byteArrayToInt(temp);
										if(balance>=Configs.WALLET_DECREASE_VALUE)
										{
											try 
											{
												String currentcardid=new String(RFID.PICC_UID, 0, RFID.PICC_UID.length, "ISO-8859-1");
												if((currentcardid.equals(lastcardid))&&(lastDecreaseTime>0))
												{
													if((System.currentTimeMillis()-lastDecreaseTime)<DECREASE_INTERVAL_TIME)
													{
														continue;
													}
												}	
												
												byte[] Decreasevaluebuf=Utils.intToByteArray(Configs.WALLET_DECREASE_VALUE);
												if(RFID.CardBlockdec(Configs.WALLET_BLOCK,Decreasevaluebuf) == 0)
												{
													lastcardid=currentcardid;
													lastDecreaseTime=System.currentTimeMillis();
													
													Message msg = Message.obtain(handler, MSG_DECREASE_SUCCESS, Configs.WALLET_DECREASE_VALUE);
													handler.sendMessage(msg);
												}
											} catch (UnsupportedEncodingException e) {
												e.printStackTrace();
											}
											
											
										}else
										{
											Message msg = Message.obtain(handler, MSG_DECREASE_FAIL,0);
											handler.sendMessage(msg);
										}
									}
									
									
								}
							}
							sleep(400);
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
				case MSG_DECREASE_SUCCESS:
					Object objsuccess = (Object) msg.obj;
					if(objsuccess!=null)
					{
						int success=Integer.parseInt(String.valueOf(objsuccess));
						String valuesuccess=getString(R.string.decrease_value)+success;
						decrease_value.setText(valuesuccess);
						decrease_result.setText(getString(R.string.successful_charge));
						Message msg1 = handler.obtainMessage(MSG_CLEAN);
						handler.sendMessageDelayed(msg1,2000);
					}
                    break;
				case MSG_DECREASE_FAIL:
					Object objfail = (Object) msg.obj;
					if(objfail!=null)
					{
						int fail=Integer.parseInt(String.valueOf(objfail));
						String valuefail=getString(R.string.decrease_value)+fail;
						decrease_value.setText(valuefail);
						decrease_result.setText(getString(R.string.credit_low));
						Message msg2 = handler.obtainMessage(MSG_CLEAN);
						handler.sendMessageDelayed(msg2,2000);
					}
                    break;
				case MSG_CLEAN:
					decrease_value.setText("");
					decrease_result.setText("");
                    break;
            }
		};
	};
}
