package com.howen.howentestdemo.can;
import android.util.Log;

public class CanFrame {
	private byte mFrameIdType;
	private byte mFrameDataType;
	private int mFrameId;
	private byte mFrameDataLength;
	private byte[] mFrameData=null;
	
	public CanFrame(byte FIdType,byte FDataType,int mFId,byte[] FrameData,byte mFDataLength)
	{
		this.mFrameIdType=FIdType;
		this.mFrameDataType=FDataType;
		this.mFrameId=mFId;
		mFrameDataLength=mFDataLength;
		mFrameData=new byte[mFDataLength];
		System.arraycopy(FrameData, 0, mFrameData, 0, mFDataLength);
	}

	public CanFrame(byte[] Framebuf)
	{
		this.mFrameIdType=Framebuf[0];
		this.mFrameDataType=Framebuf[1];
		byte[] id=new byte[4];
		System.arraycopy(Framebuf, 2, id, 0, id.length);
		this.mFrameId=CanUtils.ByteArrayToIntHH(id);
		mFrameDataLength=Framebuf[6]; 
		mFrameData=new byte[mFrameDataLength];
		System.arraycopy(Framebuf, 7, mFrameData, 0, mFrameDataLength);
	}
	
	public byte[] getCanFrameBuffer()
	{
		int Length=(int)mFrameDataLength+7;
		byte[] FrameBuffer=new byte[Length];
		FrameBuffer[0]=mFrameIdType;
		FrameBuffer[1]=mFrameDataType;
		byte[]id=CanUtils.IntTobyteArrayHH(mFrameId);
		System.arraycopy(id, 0, FrameBuffer, 2, id.length);
		FrameBuffer[6]=mFrameDataLength;
		System.arraycopy(mFrameData, 0, FrameBuffer, 7, mFrameData.length);
		return FrameBuffer;
	}
	
}
