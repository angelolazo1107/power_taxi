package com.howen.howentestdemo.can;

import android.util.Log;
import com.howen.howennative.CanNative;
import java.io.*;
public class CanManager 
{
	private static final int CAN_STATE_CLOSE = 0;
	private static final int CAN_STATE_OPEN = 1;
	private CanManagerListener mCanManagerListener = null;
	private CanWriteThread mCanWriteThread;
	private CanNative mCanNative=null;
	public final String can_down_cmd = "/system/bin/ip link set can0 down";
	public CanManager() 
	{
		mCanNative=new CanNative();
		mCanNative.setCanReadCB(mCanReadCB);
	}
	
	public void Release()
	{	
		StopWriteThread();
		mCanNative.Release();
	}
	
	public void startWriteThread(int sleep_time)
	{
		if(mCanWriteThread == null)
		{
			mCanWriteThread = new CanWriteThread(this,sleep_time);
			mCanWriteThread.setCanWriteCB(mCanWriteCB);
			mCanWriteThread.start();
		}
	}
	
	public void StopWriteThread()
	{
		if(mCanWriteThread != null)
		{
			mCanWriteThread.Release();
			mCanWriteThread = null;
		}
	}

	public void setSheepTime(int time) 
	{
		if(mCanWriteThread != null)
		{
			mCanWriteThread.setSheepTime(time);
		}
	}

	public void WriteQueue(byte[] msg) 
	{
		if(mCanWriteThread != null)
		{
			mCanWriteThread.Write(msg);
		}
	}
	
	public interface CanManagerListener 
	{
		void CanReadCallback(byte [] buff);
		void CanWriteCallback(byte [] buff);
	}
	
	public void setCanManagerListener(CanManagerListener listener) 
	{
		this.mCanManagerListener = listener;
	}
	
	private CanWriteThread.CanWriteCB mCanWriteCB= new CanWriteThread.CanWriteCB()
    {
		@Override
	    public void CanWriteCallback(byte [] buf) 
	    {
			if (mCanManagerListener != null) 
			{
				mCanManagerListener.CanWriteCallback(buf);
			}
		}
	};
	
	private CanNative.CanReadCB mCanReadCB= new CanNative.CanReadCB()
    {
		@Override
	    public void CanReadCallback(byte [] buf) 
	    {
			if (mCanManagerListener != null) 
			{
				mCanManagerListener.CanReadCallback(buf);
			}
		}
	};
		
	public int openCanfd(String Bitrate,String Dbitrate)
	{ 
		int ret=0;
		if(mCanNative.Status()==CAN_STATE_CLOSE)
		{
			rootCommand(can_down_cmd);
			String CanSetting=getCanFdSetting(Bitrate,Dbitrate);
			rootCommand(CanSetting);
			ret=mCanNative.Open();
		}
		return ret;
	}

	public int openCan(String Bitrate)
	{ 
		int ret=0;
		if(mCanNative.Status()==CAN_STATE_CLOSE)
		{
			rootCommand(can_down_cmd);
			String CanSetting=getCanSetting(Bitrate);
			rootCommand(CanSetting);
			ret=mCanNative.Open();
		}
		return ret;
	}
	
	public int close()
	{
		int ret=0;
		if(mCanNative.Status()==CAN_STATE_OPEN)
		{
			ret=mCanNative.Close();
			rootCommand(can_down_cmd);
		}
		return ret;
	}
	
	public int writebuf(byte [] buff)
	{
		return mCanNative.WriteBuf(buff);
	}
	
	public boolean Enabled()
	{
		return mCanNative.Enabled();
	}
	
	public int Status()
	{
		return mCanNative.Status();
	}

	public boolean rootCommand(String command)
	{
	  Process process = null;
	  DataOutputStream dos = null;
	  try {
	   process = Runtime.getRuntime().exec("su");
	   dos = new DataOutputStream(process.getOutputStream());
	   dos.writeBytes(command+"\n");
	   dos.writeBytes("exit\n");
	   dos.flush();
	   process.waitFor();
	  } catch (Exception e) {
	   return false;
	  } finally {
	   try {
		if (dos != null) {
		 dos.close();
		}
		process.destroy();
	   } catch (Exception e) {
	   }
	  }
	  return true;

	}

	public String getCanFdSetting(String strBitrate,String strDbitrate) 
	{
		
		int Bitrate=Integer.parseInt(strBitrate.replaceAll("k", "000"));
		String setBitrate="0.75";
		if(Bitrate>800000)
		{
			setBitrate="0.75";
		}else if(Bitrate>500000&&Bitrate<=800000)
		{
			setBitrate="0.80";
		}else if(Bitrate<=500000)
		{
			setBitrate="0.875";
		}

		int Dbitrate=Integer.parseInt(strDbitrate.replaceAll("k", "000"));
		String setDbitrate="0.75";
		if(Dbitrate>800000)
		{
			setDbitrate="0.75";
		}else if(Dbitrate>500000&&Dbitrate<=800000)
		{
			setDbitrate="0.80";
		}else if(Dbitrate<=500000)
		{
			setDbitrate="0.875";
		}
		
		return "/system/bin/ip link set can0 up type can bitrate "+
			strBitrate.replaceAll("k", "000")+" sample-point "+setBitrate+" dbitrate "+
			strDbitrate.replaceAll("k", "000")+" dsample-point "+setDbitrate+" fd on";
	}
	
	public String getCanSetting(String strBitrate) 
	{
		return "/system/bin/ip link set can0 up type can bitrate "+strBitrate.replaceAll("k", "000");
	}
}
