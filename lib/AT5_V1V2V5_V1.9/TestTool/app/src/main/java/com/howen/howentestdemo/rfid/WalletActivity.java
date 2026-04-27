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

public class WalletActivity extends Activity implements OnClickListener {
	private Button wallet_manager, decrease_wallet;
	@Override
	protected void onCreate(Bundle savedInstanceState) 
	{
		super.onCreate(savedInstanceState);
		setContentView(R.layout.wallet_main);

		init_view();
		wallet_manager.setOnClickListener(this);
		decrease_wallet.setOnClickListener(this);
	}
	private void init_view() 
	{
		wallet_manager = (Button) findViewById(R.id.wallet_manager);
		decrease_wallet = (Button) findViewById(R.id.decrease_wallet);
	}
	
	@Override
	public void onClick(View v)
	{
		switch (v.getId()) 
		{
			case R.id.wallet_manager:
				Intent RFIDSdk = new Intent(WalletActivity.this,WalletSettingsActivity.class);
				startActivity(RFIDSdk);
				break;
			case R.id.decrease_wallet:
				Intent Decrease = new Intent(WalletActivity.this,DecreaseWalletActivity.class);
				startActivity(Decrease);
				break;
		}
	}
}
