package com.howen.howentestdemo.rfid;

public final class Configs
{
	public static final int KEYA_MODE = 0;
	public static final int KEYB_MODE = 1;
	public static final byte[] KEY_A = new byte[]{(byte)0x00,(byte)0x00,(byte)0x00,(byte)0x00,(byte)0x00,(byte)0x00};
	public static final byte[] KEY_B = new byte[]{(byte)0xFF,(byte)0xFF,(byte)0xFF,(byte)0xFF,(byte)0xFF,(byte)0xFF};
	
	/******************wallet Configs******************/
	public static final int  WALLET_BLOCK= 62;
	public static final int  WALLET_KEY_MODEM= 0;
	public static final int  WALLET_DECREASE_VALUE= 10;
	public static byte[] getwalletkey()
	{
		if(WALLET_KEY_MODEM==Configs.KEYB_MODE)
		{
			return KEY_B;
		}
		return KEY_A;
	}
	
}
