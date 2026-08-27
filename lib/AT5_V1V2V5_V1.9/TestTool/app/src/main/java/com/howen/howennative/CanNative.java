package com.howen.howennative;
import android.util.Log;
public class CanNative 
{
	private CanReadCB mCanReadCB = null;

	static {
		System.loadLibrary("HowenCan_jni");
	}
	
	public CanNative() 
	{
		SetJniEnv();
		InitNative();
	}
	
	public void Release()
	{	
		JniRelease();
		mCanReadCB=null;
	}
	
	public int Open()
	{ 
		return CanOpen();
	}

	public int Close()
	{
		return CanClose();
	}

	public int Status()
	{
		return CanStatus();
	}
	
	public int WriteBuf(byte [] buff)
	{
		return CanWriteBuf(buff,buff.length);
	}
	
	public boolean Enabled()
	{
		return JniEnabled();
	}
	
	public interface CanReadCB
	{
		void CanReadCallback(byte [] buff);
	}
	
	public void setCanReadCB(CanReadCB cb) 
	{
		this.mCanReadCB = cb;
	}
	
	private native void SetJniEnv();
	private static native int InitNative();
	private static native boolean JniEnabled();
	private native void JniRelease();
	private static native int CanOpen();
	private static native int CanClose();
	private static native int CanWriteBuf(byte [] buff,int length);
	private static native int CanStatus();
	public void CanReadCallback(byte [] buff)
	{
		if(mCanReadCB!=null)
		{
			mCanReadCB.CanReadCallback(buff);
		}
	}
}
