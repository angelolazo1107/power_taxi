package com.howen.howentestdemo.rfid;

import android.content.Context;
import android.content.SharedPreferences;
import java.io.UnsupportedEncodingException;
import android.util.Log;

public class RFIDSharedPreferences 
{
	public static final byte[] key_A = new byte[]{(byte)0x00,(byte)0x00,(byte)0x00,(byte)0x00,(byte)0x00,(byte)0x00};
	public static final byte[] Control = new byte[]{(byte)0xFF,(byte)0x07,(byte)0x80,(byte)0x69};
	public static final byte[] key_B = new byte[]{(byte)0xFF,(byte)0xFF,(byte)0xFF,(byte)0xFF,(byte)0xFF,(byte)0xFF};
	public static final byte[] defwrite = new byte[]
	{ 
		   	(byte)0x00,(byte)0x01,(byte)0x02,(byte)0x03,
			(byte)0x04,(byte)0x05,(byte)0x06,(byte)0x07,
			(byte)0x08,(byte)0x09,(byte)0x0A,(byte)0x0B,
			(byte)0x0C,(byte)0x0D,(byte)0x0E,(byte)0x0F
	};
	private SharedPreferences mSharedPreferences;
	public static final String KEY_FTM_PREFERENCES = "FtmPreferences";
	public static final String KEY_RFID_KEYS = "rfid_keys";

	public RFIDSharedPreferences(Context context)
	{
		mSharedPreferences = context.getSharedPreferences(KEY_FTM_PREFERENCES, 0);
	}
	
	public void putRfidKeys(String keys)
	{
		 SharedPreferences.Editor edit = mSharedPreferences.edit();
		 edit.putString(KEY_RFID_KEYS, keys);
		 edit.commit();
	}
	
	public byte[] getRfidKeys()
	{
		String keys=mSharedPreferences.getString(KEY_RFID_KEYS,null);
		if(keys!=null)
		{
			try {
				byte[] keysbuff = keys.getBytes("ISO-8859-1");
				return keysbuff;
			} catch (UnsupportedEncodingException e) {
				e.printStackTrace();
			}
		}else
		{
			byte[] keysbuff=new byte[key_A.length+key_B.length];
			System.arraycopy(key_A, 0, keysbuff, 0, key_A.length);
			System.arraycopy(key_B, 0, keysbuff, key_A.length, key_B.length);
			try {
				keys=new String(keysbuff, 0, keysbuff.length, "ISO-8859-1");
				putRfidKeys(keys);
			} catch (UnsupportedEncodingException e) {
				e.printStackTrace();
			}

			return keysbuff;
		}
		return null;
	}
}
