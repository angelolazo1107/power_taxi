package com.howen.howentestdemo.rfid;

import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Bundle;
import android.widget.EditText;
import android.widget.TextView;
import android.app.Activity;
import android.util.Log;
import java.nio.ByteOrder;
import java.nio.ByteBuffer;
import java.text.SimpleDateFormat;
import android.widget.Button;
import android.view.View;
import com.howen.rfid.RFID;
import android.widget.Spinner;
import com.howen.howentestdemo.rfid.RFIDSharedPreferences;
import java.io.UnsupportedEncodingException;
import android.content.Intent;
import com.howen.howentestdemo.R;
import com.howen.howentestdemo.rfid.Utils;

public class RFIDSdkActivity extends Activity 
{
	   private static final String TAG = "RFIDSdkActivity";
	   private SimpleDateFormat mSimpleDateFormat = new SimpleDateFormat("hh:mm:ss");
	   private static final int RFID_LENGTH = 5;
	   protected EditText mLogText;
	   protected int mShowLogLines=0;
	   protected Button mReadRfid;
	   protected Button mClean;
	   protected Button mRead,mWrite;
	   protected Button mInitializeWallet,mDecreaseWallet,mIncreaseWallet,mCheckWallet;
	   protected TextView mRfidtype,mRfid;
	   protected Spinner mReadblock,mWriteblock,mWalletblock;
	   protected Spinner mReadkey,mWritekey;
	   protected Spinner mInitWalletkey,mDecreaseWalletkey,mIncreaseWalletkey,mCheckWalletkey;
	   private boolean mRFIDOpen=false;
	   protected EditText mInitialize,mDecrease,mIncrease,mCheck;
	   protected EditText mWriteValue;
	   private RFIDSharedPreferences mRFIDSharedPreferences = null;
	   private byte[] mKyeA=null;
	   private byte[] mKyeB=null;
	   protected EditText mEditKeya,mEditKeyb;
	   protected Button mSaveKeys;
	   protected Button mSecret;
	   protected EditText mSecretkeya,mSecretControl,mSecretkeyb;
	   protected Spinner  mSecretkey,mSpinnerSecret;
	   @Override
	   public void onCreate(Bundle savedInstanceState)
		{
			super.onCreate(savedInstanceState);
			setContentView(R.layout.rfidsdk);
			initViews();
			mRFIDSharedPreferences = new RFIDSharedPreferences(this);
			if(RFID.open()>0)
			{
				mRFIDOpen=true;
			}
			if(initKeys())
			{
				updateKeysViews();
			}
		}
	   	
		protected boolean initKeys()
		{
			byte[] Keys=mRFIDSharedPreferences.getRfidKeys();
			if(Keys==null)
				return false;
			if(Keys.length==12)
			{
				mKyeA=new byte[6];
				System.arraycopy(Keys, 0, mKyeA, 0, 6);
				mKyeB=new byte[6];
				System.arraycopy(Keys, 6, mKyeB, 0, 6);
				return true;
			}
			return false;
		}
		
		protected byte[] getkeybymode(int mode)
		{
			if(mode==Configs.KEYA_MODE)
			{
				String keya=mEditKeya.getText().toString();
				byte[] keyabuf =Utils.HexToByteArr(keya);
				if(keyabuf.length ==6)
				{
					return keyabuf;
				}
			}else if(mode==Configs.KEYB_MODE)
			{
				String keyb=mEditKeyb.getText().toString();
				byte[] keybbuf =Utils.HexToByteArr(keyb);
				if(keybbuf.length ==6)
				{
					return keybbuf;
				}
			}
			return null;
		}
		
		protected void updateKeysViews()
		{
			mEditKeya.setText(Utils.ByteArrToHex(mKyeA));
			mEditKeyb.setText(Utils.ByteArrToHex(mKyeB));
		}
		
		protected void initViews()
		{
			mLogText=(EditText)findViewById(R.id.logtext);
			mLogText.setText("");
			mShowLogLines=0;
			mWriteValue=(EditText)findViewById(R.id.write_value);
			mWriteValue.setText(Utils.ByteArrToHex(RFIDSharedPreferences.defwrite));
			mInitialize=(EditText)findViewById(R.id.edit_Initialize_wallet);
			mDecrease=(EditText)findViewById(R.id.edit_decrease_wallet);
			mIncrease=(EditText)findViewById(R.id.edit_increase_wallet);
			mCheck=(EditText)findViewById(R.id.edit_check_wallet);
			mRfidtype=(TextView)findViewById(R.id.rfid_type);
			mRfid=(TextView)findViewById(R.id.rfid_id);
			mReadRfid=(Button)findViewById(R.id.button_read_rfid);
			mReadRfid.setOnClickListener(new ButtonClickEvent());
			mClean=(Button)findViewById(R.id.button_clean);
			mClean.setOnClickListener(new ButtonClickEvent());
			mRead=(Button)findViewById(R.id.button_read_value);
			mRead.setOnClickListener(new ButtonClickEvent());
			mWrite=(Button)findViewById(R.id.button_write_value);
			mWrite.setOnClickListener(new ButtonClickEvent());
			mInitializeWallet=(Button)findViewById(R.id.button_Initialize_wallet);
			mInitializeWallet.setOnClickListener(new ButtonClickEvent());
			mDecreaseWallet=(Button)findViewById(R.id.button_decrease_wallet);
			mDecreaseWallet.setOnClickListener(new ButtonClickEvent());
			mIncreaseWallet=(Button)findViewById(R.id.button_increase_wallet);
			mIncreaseWallet.setOnClickListener(new ButtonClickEvent());
			mCheckWallet=(Button)findViewById(R.id.button_check_wallet);
			mCheckWallet.setOnClickListener(new ButtonClickEvent());
			mReadblock=(Spinner)findViewById(R.id.spinner_read_block);
			mWriteblock=(Spinner)findViewById(R.id.spinner_write_block);
			mWalletblock=(Spinner)findViewById(R.id.spinner_wallet_block);
			mReadkey=(Spinner)findViewById(R.id.spinner_read_key);
			mWritekey=(Spinner)findViewById(R.id.spinner_write_key);
			mInitWalletkey=(Spinner)findViewById(R.id.spinner_Initialize_wallet);
			mDecreaseWalletkey=(Spinner)findViewById(R.id.spinner_decrease_wallet);
			mIncreaseWalletkey=(Spinner)findViewById(R.id.spinner_increase_wallet);
			mCheckWalletkey=(Spinner)findViewById(R.id.spinner_check__wallet);
			mEditKeya=(EditText)findViewById(R.id.edit_key_a);
			mEditKeyb=(EditText)findViewById(R.id.edit_key_b);
			mSaveKeys=(Button)findViewById(R.id.button_save);
			mSaveKeys.setOnClickListener(new ButtonClickEvent());
			mSecret=(Button)findViewById(R.id.button_secret);
			mSecret.setOnClickListener(new ButtonClickEvent());
			mSecretkeya=(EditText)findViewById(R.id.secret_key_a);
			mSecretControl=(EditText)findViewById(R.id.secret_control);
			mSecretkeyb=(EditText)findViewById(R.id.secret_key_b);
			mSecretkeya.setText(Utils.ByteArrToHex(RFIDSharedPreferences.key_A));
			mSecretControl.setText(Utils.ByteArrToHex(RFIDSharedPreferences.Control));
			mSecretkeyb.setText(Utils.ByteArrToHex(RFIDSharedPreferences.key_B));
			mSecretkey=(Spinner)findViewById(R.id.spinner_secret_key);
			mSpinnerSecret=(Spinner)findViewById(R.id.spinner_secret);
		}
		
		@Override
		protected void onDestroy() 
		{
			super.onDestroy();
			if(mRFIDOpen)
			{
				RFID.close();
				mRFIDOpen=false;
			}
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
		 
		 class ButtonClickEvent implements View.OnClickListener 
		 {
			public void onClick(View v)
			{
				if(v==mSecret)
				{
					if(!RFID.getRfidInfo())
					{
						ShowLog("getRfidInfo fail");
						return ;
					}
					
					int keymode=mSecretkey.getSelectedItemPosition();
					int Secretblock=Integer.parseInt(mSpinnerSecret.getSelectedItem().toString());
					if(!checkBlock(keymode,Secretblock,RFID.PICC_UID))
					{
						ShowLog("checkBlock fail");
						return ;
					}
					
					String keya=mSecretkeya.getText().toString();
					byte[] keyabuf =Utils.HexToByteArr(keya);
					if(keyabuf.length !=6)
					{
						ShowLog("Secret key A Error length=="+keyabuf.length);
						return ;
					}

					String Control=mSecretControl.getText().toString();
					byte[] Controlbuf =Utils.HexToByteArr(Control);
					if(Controlbuf.length !=4)
					{
						ShowLog("Secret Control Error length=="+keyabuf.length);
						return ;
					}

					String keyb=mSecretkeyb.getText().toString();
					byte[] keybbuf =Utils.HexToByteArr(keyb);
					if(keybbuf.length !=6)
					{
						ShowLog("Secret key B Error length=="+keyabuf.length);
						return ;
					}

					byte[] keys=new byte[16];
					System.arraycopy(keyabuf, 0, keys, 0, 6);
					System.arraycopy(Controlbuf, 0, keys, 6, 4);
					System.arraycopy(keybbuf, 0, keys, 10, 6);
					
					int ret= RFID.CardBlockwrite(Secretblock,keys);
					if(ret != 0)
					{
						ShowLog("Secret Block fail");
					}else
					{
						ShowLog("Secret Block success");
					}
				}
				else if(v==mSaveKeys)
				{
					String keya=mEditKeya.getText().toString();
					byte[] keyabuf =Utils.HexToByteArr(keya);
					if(keyabuf.length !=6)
					{
						ShowLog("Key A Error length=="+keyabuf.length);
						return ;
					}
					String keyb=mEditKeyb.getText().toString();
					byte[] keybbuf =Utils.HexToByteArr(keyb);
					if(keybbuf.length !=6)
					{
						ShowLog("Key B Error length=="+keybbuf.length);
						return ;
					}
					
					byte[] keys=new byte[12];
					System.arraycopy(keyabuf, 0, keys, 0, 6);
					System.arraycopy(keybbuf, 0, keys, 6, 6);
					
					try {
						mRFIDSharedPreferences.putRfidKeys(new String(keys, 0, keys.length, "ISO-8859-1"));
					} catch (UnsupportedEncodingException e) {
						e.printStackTrace();
					}
					
					if(initKeys())
					{
						updateKeysViews();
						ShowLog("Save keys success");
					}else
					{
						mEditKeya.setText("");
						mEditKeyb.setText("");
						ShowLog("Save keys fail");
					}
				}
				else if(v==mClean)
				{
					mLogText.setText("");
					mShowLogLines=0;
				}
				else if(v==mReadRfid)
				{
					if(!RFID.getRfidInfo())
					{
						ShowLog("getRfidInfo fail");
						mRfidtype.setText("");
						mRfid.setText("");
						return ;
					}else 
					{
						ShowLog("getRfidInfo success");
					}
					mRfidtype.setText(Utils.ByteArrToHex(RFID.PICC_ATQA));
					byte[] rfid=new byte[RFID_LENGTH];
					System.arraycopy(RFID.PICC_UID, 0, rfid, 0, RFID_LENGTH);
					mRfid.setText(Utils.ByteArrToHex(rfid));
				}
				else if(v== mRead)
				{	
					if(!RFID.getRfidInfo())
					{
						ShowLog("getRfidInfo fail");
						return ;
					}
					int keymode=mReadkey.getSelectedItemPosition();
					int readblock=Integer.parseInt(mReadblock.getSelectedItem().toString());
					if(!checkBlock(keymode,readblock,RFID.PICC_UID))
					{
						ShowLog("checkBlock fail");
						return ;
					}			
					byte[] buf = RFID.CardBlockread(readblock);
					if(buf==null)
					{
						ShowLog("CardBlockread fail");
						return ;
					}
					
					ShowLog("CardBlockread success !  "+Utils.ByteArrToHex(buf));
				}else if(v== mWrite)
				{
					if(!RFID.getRfidInfo())
					{
						ShowLog("getRfidInfo fail");
						return ;
					}
					
					int keymode=mWritekey.getSelectedItemPosition();
					int writeblock=Integer.parseInt(mWriteblock.getSelectedItem().toString());
					if(!checkBlock(keymode,writeblock,RFID.PICC_UID))
					{
						ShowLog("checkBlock fail");
						return ;
					}
					String Write=mWriteValue.getText().toString();
					byte[] Writebuf =Utils.HexToByteArr(Write);
					if(Writebuf.length !=16)
					{
						ShowLog("WriteValue Error length=="+Writebuf.length);
						return ;
					}
					
					int ret= RFID.CardBlockwrite(writeblock,Writebuf);
					if(ret != 0)
					{
						ShowLog("CardBlockwrite fail");
					}else
					{
						ShowLog("CardBlockwrite success");
					}
				}else if(v== mInitializeWallet)
				{
					if(!RFID.getRfidInfo())
					{
						ShowLog("getRfidInfo fail");
						return ;
					}
					int keymode=mInitWalletkey.getSelectedItemPosition();
					int walletblock=Integer.parseInt(mWalletblock.getSelectedItem().toString());
					if(!checkBlock(keymode,walletblock,RFID.PICC_UID))
					{
						ShowLog("checkBlock fail");
						return ;
					}

					String initWallet=mInitialize.getText().toString();
					if(initWallet.length()==0)
					{
						ShowLog("Error please input initialize Value");
						return ;
					}
					int Walletvalue= Integer.parseInt(initWallet);
					byte[] Walletvaluebuf=Utils.intToByteArray(Walletvalue);

					int ret=RFID.CardBlockset(walletblock,Walletvaluebuf);
					if(ret != 0)
					{
						ShowLog("CardBlockwrite fail");
					}else
					{
						ShowLog("CardBlockwrite success");
					}
				}else if(v== mDecreaseWallet)
				{
					if(!RFID.getRfidInfo())
					{
						ShowLog("getRfidInfo fail");
						return ;
					}
					int keymode=mDecreaseWalletkey.getSelectedItemPosition();
					int walletblock=Integer.parseInt(mWalletblock.getSelectedItem().toString());
					if(!checkBlock(keymode,walletblock,RFID.PICC_UID))
					{
						ShowLog("checkBlock fail");
						return ;
					}
					String DecreaseWallet=mDecrease.getText().toString();
					if(DecreaseWallet.length()==0)
					{
						ShowLog("Error please input Decrease Value");
						return ;
					}
					int Decreasevalue= Integer.parseInt(DecreaseWallet);
					byte[] Decreasevaluebuf=Utils.intToByteArray(Decreasevalue);
					int ret=RFID.CardBlockdec(walletblock,Decreasevaluebuf);
					if(ret != 0)
					{
						ShowLog("CardBlockdec fail");
					}else
					{
						ShowLog("CardBlockdec success");
					}
				}else if(v== mIncreaseWallet)
				{
					if(!RFID.getRfidInfo())
					{
						ShowLog("getRfidInfo fail");
						return ;
					}
					int keymode=mIncreaseWalletkey.getSelectedItemPosition();
					int walletblock=Integer.parseInt(mWalletblock.getSelectedItem().toString());
					if(!checkBlock(keymode,walletblock,RFID.PICC_UID))
					{
						ShowLog("checkBlock fail");
						return ;
					}
					String IncreaseWallet=mIncrease.getText().toString();
					if(IncreaseWallet.length()==0)
					{
						ShowLog("Error please input Increase Value");
						return ;
					}
					int Increasevalue= Integer.parseInt(IncreaseWallet);
					byte[] Increasevaluebuf=Utils.intToByteArray(Increasevalue);
					int ret=RFID.CardBlockinc(walletblock,Increasevaluebuf);
					if(ret != 0)
					{
						ShowLog("CardBlockdec fail");
					}else
					{
						ShowLog("CardBlockdec success");
					}
				}else if(v== mCheckWallet)
				{
					if(!RFID.getRfidInfo())
					{
						ShowLog("getRfidInfo fail");
						return ;
					}
					int keymode=mCheckWalletkey.getSelectedItemPosition();
					int walletblock=Integer.parseInt(mWalletblock.getSelectedItem().toString());
					if(!checkBlock(keymode,walletblock,RFID.PICC_UID))
					{
						ShowLog("checkBlock fail");
						return ;
					}
					byte[] buf = RFID.CardBlockread(walletblock);
					if(buf==null)
					{
						ShowLog("CardBlockread fail");
						return ;
					}
					byte[] temp = new byte[4] ;
					System.arraycopy(buf, 0, temp, 0, 4);
					int wallet_num = Utils.byteArrayToInt(temp);
					mCheck.setText(""+wallet_num);
				}
			}
		}
		
		private boolean checkBlock(int keymode,int block,byte [] uid)
		{
			int sector=block/4;	
			byte[] key=getkeybymode(keymode);
			if(key==null)
			{
				return false;
			}
			if(RFID.CardAuth(keymode,sector,key,uid)==0)
			{
				return true;
			}
			return false;
		}
}

