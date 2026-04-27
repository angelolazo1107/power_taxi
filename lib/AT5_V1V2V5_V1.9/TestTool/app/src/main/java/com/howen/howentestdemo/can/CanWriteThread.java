package com.howen.howentestdemo.can;

import java.util.concurrent.ArrayBlockingQueue;
import android.util.Log;

public class CanWriteThread extends Thread
{
	private static String TAG = "CanWrite";
	private static final int CAN_SEND_SIZE_MAX = 1024*1024;
	private static ArrayBlockingQueue<byte[]> mCanWriteQueue = new ArrayBlockingQueue<byte[]>(CAN_SEND_SIZE_MAX); 
	private boolean mThreadRun;
	private CanManager mCanManager;
	private int mSheepTime=10;
	private CanWriteCB mCanWriteCB = null;
	public CanWriteThread(CanManager CanManager,int sleep_time)
	{
		mCanManager=CanManager;
		mCanWriteQueue.clear();
		mSheepTime=sleep_time;
		Log.d(TAG,"mSheepTime=="+mSheepTime);
	}
	
	public void Write(byte[] msg) 
	{
		if (mCanWriteQueue.size() >= CAN_SEND_SIZE_MAX) 
		{
			mCanWriteQueue.poll();
		}
		mCanWriteQueue.add(msg);
		//Log.d("TAG","size=="+mCanWriteQueue.size());
	}
	
	public void Release() 
	{
		mCanWriteCB = null;
		mThreadRun = false;
	}

	public void setSheepTime(int time) 
	{
		mSheepTime = time;
	}
	
	@Override
	public void run() 
	{
		//Log.d("TAG","run==>CanWrite");
		mThreadRun = true;
		while(mThreadRun) 
		{
			try
			{
				while (mCanWriteQueue.size()>0&&mThreadRun)
				{
					byte[] CanBuf=mCanWriteQueue.poll();
					mCanManager.writebuf(CanBuf);
					if(mCanWriteCB!=null)
					{
						mCanWriteCB.CanWriteCallback(CanBuf);
					}
					Thread.sleep(mSheepTime);
				}
			} catch (InterruptedException e)
			{
				e.printStackTrace();
			}
		}
	}
	
	public interface CanWriteCB
	{
		void CanWriteCallback(byte [] buff);
	}
	
	public void setCanWriteCB(CanWriteCB cb) 
	{
		this.mCanWriteCB = cb;
	}
}
