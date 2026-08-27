
package com.howen.rfid;
import android.util.Log;

public class RFID 
{
	public static byte[] PICC_ATQA = new byte[2];
	public static byte[] PICC_UID = new byte[15];
	public static byte[] PICC_SAK = new byte[3];
	public native static int open();	
	public native static int close();
	public native static byte [] CardActivate();
	public native static int CardAuth(int mode,int sector,byte [] mifare_key,byte [] card_uid);
	public native static int CardBlockwrite(int block,byte [] buff);
	public native static byte [] CardBlockread(int block);
	public native static int CardBlockset(int block,byte [] buff);
	public native static int CardBlockinc(int block,byte [] buff);
	public native static int CardBlockdec(int block,byte [] buff);
	public native static int CardTransfer(int block);
	public native static int CardRestore(int block);
	
	public static boolean getRfidInfo()
	{
		byte[] Cardbuffer= RFID.CardActivate();
		if(Cardbuffer!=null)
		{
			System.arraycopy(Cardbuffer, 0, RFID.PICC_ATQA, 0, 2);
			System.arraycopy(Cardbuffer, 2, RFID.PICC_UID, 0, 15);
			System.arraycopy(Cardbuffer, 17, RFID.PICC_SAK, 0, 3);
			return true;
		}
		return false;
	}
	
	static {
		try {
			System.loadLibrary("rfid_jni");
		} catch (UnsatisfiedLinkError ule) {
			System.err.println("WARNING: Could not load rfid_jni library!");
		}
	}
}
