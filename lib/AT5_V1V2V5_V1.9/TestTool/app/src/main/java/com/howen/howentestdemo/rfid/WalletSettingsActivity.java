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
import android.widget.EditText;
import com.howen.rfid.RFID;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import com.howen.howentestdemo.R;
public class WalletSettingsActivity extends Activity implements OnClickListener 
{
	private Button button_Initialize_wallet, button_increase_wallet,button_check_wallet,button_decrease_wallet;
	protected EditText mInitialize,mIncrease,mDecrease,mCheck;
	private boolean mRFIDOpen=false;
	@Override
	protected void onCreate(Bundle savedInstanceState) 
	{
		super.onCreate(savedInstanceState);
		setContentView(R.layout.wallet_setting);
		init_view();
		button_Initialize_wallet.setOnClickListener(this);
		button_increase_wallet.setOnClickListener(this);
		button_check_wallet.setOnClickListener(this);
		button_decrease_wallet.setOnClickListener(this);
		if(RFID.open()>0)
		{
			mRFIDOpen=true;
		}
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
	
	private void init_view() 
	{
		button_Initialize_wallet = (Button) findViewById(R.id.button_Initialize_wallet);
		button_increase_wallet = (Button) findViewById(R.id.button_increase_wallet);
		button_check_wallet = (Button) findViewById(R.id.button_check_wallet);
		button_decrease_wallet = (Button) findViewById(R.id.button_decrease_wallet);
		mInitialize=(EditText)findViewById(R.id.edit_Initialize_wallet);
		mIncrease=(EditText)findViewById(R.id.edit_increase_wallet);
		mDecrease=(EditText)findViewById(R.id.edit_decrease_wallet);
		mCheck=(EditText)findViewById(R.id.edit_check_wallet);
	}
	
	@Override
	public void onClick(View v)
	{
		switch (v.getId()) 
		{
			case R.id.button_Initialize_wallet:
				Initialize_wallet();
				break;
			case R.id.button_increase_wallet:
				increase_wallet();
				break;
			case R.id.button_decrease_wallet:
				decrease_wallet();
				break;
			case R.id.button_check_wallet:
				check_wallet();
				break;
		}
	}
	
	private void Initialize_wallet() 
	{
		if(!RFID.getRfidInfo())
		{
			ShowMessage("Initialize wallet fail");
			return ;
		}
		int sector=Configs.WALLET_BLOCK/4;	
		if(RFID.CardAuth(Configs.WALLET_KEY_MODEM,sector,Configs.getwalletkey(),RFID.PICC_UID)!=0)
		{
			ShowMessage("Initialize wallet fail");
			return ;
		}
		String initWallet=mInitialize.getText().toString();
		if(initWallet.length()==0)
		{
			ShowMessage("Initialize wallet fail");
			return ;
		}
		int Walletvalue= Integer.parseInt(initWallet);
		byte[] Walletvaluebuf=Utils.intToByteArray(Walletvalue);
		
		if(RFID.CardBlockset(Configs.WALLET_BLOCK,Walletvaluebuf) != 0)
		{
			ShowMessage("Initialize wallet fail");
		}else
		{
			ShowMessage("Initialize wallet success");
		}
	}
	
	private void increase_wallet() 
	{
		if(!RFID.getRfidInfo())
		{
			ShowMessage("increase wallet fail");
			return ;
		}
		int sector=Configs.WALLET_BLOCK/4;	
		if(RFID.CardAuth(Configs.WALLET_KEY_MODEM,sector,Configs.getwalletkey(),RFID.PICC_UID)!=0)
		{
			ShowMessage("increase wallet fail");
			return ;
		}
		String Increase=mIncrease.getText().toString();
		if(Increase.length()==0)
		{
			ShowMessage("increase wallet fail");
			return ;
		}
		
		int Increasevalue= Integer.parseInt(Increase);
		byte[] Increasevaluebuf=Utils.intToByteArray(Increasevalue);
		if(RFID.CardBlockinc(Configs.WALLET_BLOCK,Increasevaluebuf) != 0)
		{
			ShowMessage("increase wallet fail");
		}else
		{
			ShowMessage("increase wallet success");
		}
	}

	private void decrease_wallet() 
	{
		if(!RFID.getRfidInfo())
		{
			ShowMessage("decrease wallet fail");
			return ;
		}
		int sector=Configs.WALLET_BLOCK/4;	
		if(RFID.CardAuth(Configs.WALLET_KEY_MODEM,sector,Configs.getwalletkey(),RFID.PICC_UID)!=0)
		{
			ShowMessage("decrease wallet fail");
			return ;
		}
		String Decrease=mDecrease.getText().toString();
		if(Decrease.length()==0)
		{
			ShowMessage("decrease wallet fail");
			return ;
		}
		
		int Decreasevalue= Integer.parseInt(Decrease);
		byte[] Decreasevaluebuf=Utils.intToByteArray(Decreasevalue);
		if(RFID.CardBlockdec(Configs.WALLET_BLOCK,Decreasevaluebuf) != 0)
		{
			ShowMessage("decrease wallet fail");
		}else
		{
			ShowMessage("decrease wallet success");
		}
	}
	
	private void check_wallet() 
	{
		if(!RFID.getRfidInfo())
		{
			return ;
		}

		int sector=Configs.WALLET_BLOCK/4;	
		if(RFID.CardAuth(Configs.WALLET_KEY_MODEM,sector,Configs.getwalletkey(),RFID.PICC_UID)!=0)
		{
			return ;
		}
		
		byte[] buf = RFID.CardBlockread(Configs.WALLET_BLOCK);
		if(buf==null)
		{
			return ;
		}
		byte[] temp = new byte[4] ;
		System.arraycopy(buf, 0, temp, 0, 4);
		int wallet_num = Utils.byteArrayToInt(temp);
		mCheck.setText(""+wallet_num);
	}
	
	 private void ShowMessage(String sMsg)
	 {
	  		Toast.makeText(this,sMsg, Toast.LENGTH_LONG).show();
	 }
	 
}
