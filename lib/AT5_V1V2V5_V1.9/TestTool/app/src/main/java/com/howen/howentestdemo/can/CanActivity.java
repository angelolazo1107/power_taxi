package com.howen.howentestdemo.can;
import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Spinner;
import android.os.Handler;
import android.os.Message;
import java.io.IOException;
import android.widget.TextView;
import android.widget.AdapterView;
import android.content.SharedPreferences;
import com.howen.howentestdemo.R;

public class CanActivity extends Activity
{
	private static String TAG = "CanActivity";
	private SharedPreferences mSharedPreferences;
	public static final String CAN_PRE = "CanActivity";
	public static final String BITRATE = "bitrate";
	public static final String SLEEP_TIME = "sleep_time";
	public static final String FRAME_ID_TYPE = "frame_id_type";
	public static final String FRAME_DATA_TYPE = "frame_data_type";
	public static final String FRAME_DATA_LENGTH = "frame_data_length";
	public static final String CAN_WRITE_VALUE = "can_write_value";
	public static final String CAN_ID = "can_id";
	private CanManager mCanManager;
	private boolean mCanEnabled=false;
	protected Button mOpenCan,mCloseCan,mWriteCan;
	protected Button mClean;
	private CanLog mCanLog;
	private EditText mLogMessge;
	private EditText mCanID;
	protected Spinner mFrameIdType,mFrameDataType,mCanWriteValue;
	protected Spinner mBitrate,mSleepTime;
	protected Spinner mFrameDataLength;
	private TextView mReadWriteValue;
	private static final int MSG_CAN_READ = 1;
	private static final int MSG_CAN_WRITE = 2;
	private  int mCanRead = 0;
	private  int mCanWrite = 0;
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.can);
		mSharedPreferences = this.getSharedPreferences(CAN_PRE, 0);
		initView();
		
		mCanManager=new CanManager();
		if (mCanManager.Enabled())
		{
			mCanManager.setCanManagerListener(mCanManagerListener);
			mCanEnabled=true;
		}else
		{
			mCanManager.Release();
			mCanEnabled=false;
		}
	}
	
	public int getValue(String key)
	{
		if(key.equals(BITRATE))
		{
			return mSharedPreferences.getInt(key,7);
		}else if(key.equals(SLEEP_TIME))
		{
			return mSharedPreferences.getInt(key,0);
		}else if(key.equals(CAN_ID))
		{
			return mSharedPreferences.getInt(key,1);
		}else if(key.equals(FRAME_DATA_LENGTH))
		{
			return mSharedPreferences.getInt(key,8);
		}else if(key.equals(FRAME_ID_TYPE))
		{
			return mSharedPreferences.getInt(key,1);
		}else if(key.equals(FRAME_DATA_TYPE))
		{
			return mSharedPreferences.getInt(key,1);
		}
		return mSharedPreferences.getInt(key,0);
	}
	
	public void putValue(String key,int value)
	{
		SharedPreferences.Editor edit = mSharedPreferences.edit();
		edit.putInt(key,value);
		edit.commit();
	}
	
	private void updateReadWriteValue() 
	{
		mReadWriteValue.setText(getString(R.string.can_read_write_value, mCanWrite,mCanRead));
	}
	
	private void initView() 
	{
		mLogMessge = (EditText)findViewById(R.id.show_log);
		mReadWriteValue = (TextView)findViewById(R.id.read_write_value);
		updateReadWriteValue();
        mCanLog=new CanLog(mLogMessge);
		
		mOpenCan=(Button)findViewById(R.id.open_can_device);
		mOpenCan.setOnClickListener(new ButtonClickEvent());

		mClean=(Button)findViewById(R.id.chean);
		mClean.setOnClickListener(new ButtonClickEvent());
		
		mCloseCan=(Button)findViewById(R.id.close_can_device);
		mCloseCan.setOnClickListener(new ButtonClickEvent());
		
		mWriteCan=(Button)findViewById(R.id.write_can_data);
		mWriteCan.setOnClickListener(new ButtonClickEvent());
		
		mFrameIdType = (Spinner) findViewById(R.id.frame_id_type);
		mCanWriteValue = (Spinner) findViewById(R.id.write_canmsg_value);
		mBitrate = (Spinner) findViewById(R.id.bitrate);
		mSleepTime = (Spinner) findViewById(R.id.writ_sleep_time);
		mFrameIdType.setOnItemSelectedListener(new ItemSelectedEvent());
		mCanWriteValue.setOnItemSelectedListener(new ItemSelectedEvent());
		mBitrate.setOnItemSelectedListener(new ItemSelectedEvent());
		mSleepTime.setOnItemSelectedListener(new ItemSelectedEvent());
		mFrameIdType.setSelection(getValue(FRAME_ID_TYPE));
		mCanWriteValue.setSelection(getValue(CAN_WRITE_VALUE));
		mBitrate.setSelection(getValue(BITRATE));
		mSleepTime.setSelection(getValue(SLEEP_TIME));

		mFrameDataLength = (Spinner) findViewById(R.id.frame_data_length);
		mFrameDataLength.setOnItemSelectedListener(new ItemSelectedEvent());
		mFrameDataLength.setSelection(getValue(FRAME_DATA_LENGTH));

		mFrameDataType = (Spinner) findViewById(R.id.frame_data_type);
		mFrameDataType.setOnItemSelectedListener(new ItemSelectedEvent());
		mFrameDataType.setSelection(getValue(FRAME_DATA_TYPE));
		
		mCanID=(EditText)findViewById(R.id.can_id);
		int id=getValue(CAN_ID);
		mCanID.setText(String.valueOf(id));
		
	}

	 class ItemSelectedEvent implements Spinner.OnItemSelectedListener
	 {
			public void onItemSelected(AdapterView<?> arg0, View arg1, int arg2, long arg3)
			{
				if(arg0 == mFrameIdType)
				{
					putValue(FRAME_ID_TYPE,arg2);
				}else if(arg0 == mCanWriteValue)
				{
					putValue(CAN_WRITE_VALUE,arg2);
				}if (arg0 == mBitrate)
				{
					putValue(BITRATE,arg2);
					
				}else if(arg0 == mSleepTime)
				{
					putValue(SLEEP_TIME,arg2);

					String SleepTime=mSleepTime.getSelectedItem().toString();
					int index=SleepTime.indexOf("(ms)");
					int sleep=10;
					if(index>0)
					{
						sleep=Integer.parseInt(SleepTime.substring(0,index));
					}
					mCanManager.setSheepTime(sleep);
				}else if(arg0 == mFrameDataLength)
				{
					putValue(FRAME_DATA_LENGTH,arg2);
				}else if(arg0 == mFrameDataType)
				{
					putValue(FRAME_DATA_TYPE,arg2);
				}
			}
			
			public void onNothingSelected(AdapterView<?> arg0)
			{}	
	 }
	
	
	@Override
    public void onDestroy() {
       if(mCanEnabled)
       {
       		mCanManager.StopWriteThread();
		  	mCanManager.close();
       		mCanManager.Release();
			mCanEnabled=false;
       }
       super.onDestroy();
    }
	
	class ButtonClickEvent implements View.OnClickListener 
	{
		public void onClick(View v)
		{
			
			switch (v.getId()) 
			{
				case R.id.open_can_device:
					OpenCan();
					break;
				case R.id.close_can_device:
					CloseCan();
					break;
				case R.id.write_can_data:
					WriteCan();
					break;
				case R.id.chean:
					Clean();
					break;
			}
			
		}
	}
	
	public void OpenCan() 
	{
		if(mCanEnabled)
		{
			String Bitrate=mBitrate.getSelectedItem().toString();
			if(mCanManager.openCan(Bitrate)>0)
			{
				String SleepTime=mSleepTime.getSelectedItem().toString();
				int index=SleepTime.indexOf("(ms)");
				int sleep=10;
				if(index>0)
				{
					sleep=Integer.parseInt(SleepTime.substring(0,index));
				}
				mCanManager.startWriteThread(sleep);
				mCanLog.Show("Open Can Success");
			}else
			{
				mCanLog.Show("Open Can Fail");
			}
		}else
		{
			mCanLog.Show("Open Can Fail");
		}
	 }
	 
	 public void CloseCan() 
	 {
	 	if(mCanEnabled)
	 	{
	      mCanManager.StopWriteThread();
		  if(mCanManager.close()>0)
		  {
		  	mCanLog.Show("Close Can Success");
		  }else
		  {
		  	mCanLog.Show("Close Can Fail");
		  }
	 	}else
	 	{
	 		mCanLog.Show("Close Can Fail");
	 	}
	 }
	 
	 public void WriteCan() 
	 {
	 	int frame_id_type=mFrameIdType.getSelectedItemPosition();
		int frame_data_type=mFrameDataType.getSelectedItemPosition();
		String length=mFrameDataLength.getSelectedItem().toString();
		int frame_data_length=Integer.parseInt(length);
		String id = mCanID.getText().toString();
		int frame_id=Integer.parseInt(id);
		byte[] frame_data=new byte[frame_data_length];
		for(int i=0;i<frame_data.length;i++)
		{
			frame_data[i]=(byte)i;
		}
		CanFrame frame=new CanFrame((byte)frame_id_type,(byte)frame_data_type,frame_id,frame_data,(byte)frame_data.length);
	 	if(mCanEnabled)
	 	{
	 		String Value=mCanWriteValue.getSelectedItem().toString();
			int writeValue=Integer.parseInt(Value);
	 		for(int i=0;i<writeValue;i++)
	 		{
				mCanManager.WriteQueue(frame.getCanFrameBuffer());
	 		}
	 	}
	 	
	}
	
	public void Clean() 
	{
		mCanWrite=0;
		mCanRead=0;
		mCanLog.clean();
		updateReadWriteValue();
	}
	
	private Handler mHandler = new Handler()
    {
        @Override
        public void handleMessage(Message msg)
        {
       		if(msg.what == MSG_CAN_WRITE)
            {
            	mCanWrite++;
            	byte [] writebuf =(byte []) msg.obj;
				mCanLog.Show("write",CanUtils.ByteArrToHex(writebuf));
				updateReadWriteValue();
            }else if(msg.what == MSG_CAN_READ)
            {
            	mCanRead++;
            	byte [] readbuf =(byte []) msg.obj;
				mCanLog.Show("read",CanUtils.ByteArrToHex(readbuf));
				updateReadWriteValue();
            }	
        }
	};
	
	private CanManager.CanManagerListener mCanManagerListener= new CanManager.CanManagerListener()
    {
		@Override
	    public void CanReadCallback(byte [] buf) 
	    {
			Message readmsg = Message.obtain();
	        readmsg.what = MSG_CAN_READ;
	        readmsg.obj = buf;
	        mHandler.sendMessage(readmsg);
		}
		
		@Override
	    public void CanWriteCallback(byte [] buf) 
	    {
	    	Message writemsg = Message.obtain();
	        writemsg.what = MSG_CAN_WRITE;
	        writemsg.obj = buf;
	        mHandler.sendMessage(writemsg);
		}
	};
	
}
