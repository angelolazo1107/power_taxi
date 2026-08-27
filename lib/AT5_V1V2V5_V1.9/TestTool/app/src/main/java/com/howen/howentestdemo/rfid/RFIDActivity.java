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
import com.howen.howentestdemo.R;

public class RFIDActivity extends Activity implements OnClickListener {
	private Button rfid_sdk, card_id, wallet;
	@Override
	protected void onCreate(Bundle savedInstanceState) 
	{
		super.onCreate(savedInstanceState);
		setContentView(R.layout.rfid);

		init_view();
		rfid_sdk.setOnClickListener(this);
		card_id.setOnClickListener(this);
		wallet.setOnClickListener(this);
	}
	private void init_view() 
	{
		rfid_sdk = (Button) findViewById(R.id.rfid_sdk);
		card_id = (Button) findViewById(R.id.card_id);
		wallet = (Button) findViewById(R.id.wallet);
	}
	
	@Override
	public void onClick(View v)
	{
		
		switch (v.getId()) 
		{
			case R.id.rfid_sdk:
				Intent RFIDSdk = new Intent(RFIDActivity.this,RFIDSdkActivity.class);
				startActivity(RFIDSdk);
				break;
			case R.id.card_id:
				Intent cardid = new Intent(RFIDActivity.this,RFIDCardID.class);
				startActivity(cardid);
				break;
			case R.id.wallet:
				Intent Wallet = new Intent(RFIDActivity.this,WalletActivity.class);
				startActivity(Wallet);
				break;
		}
	}
}
