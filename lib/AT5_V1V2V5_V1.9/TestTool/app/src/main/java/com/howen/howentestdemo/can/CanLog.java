package com.howen.howentestdemo.can;

import android.widget.EditText;
import java.text.SimpleDateFormat;

public class CanLog {
    private SimpleDateFormat mSimpleDateFormat = new SimpleDateFormat("hh:mm:ss");
    protected int mLogLines=0;
    protected EditText mLogMessge;
    public CanLog(EditText editText)
    {
        this.mLogMessge=editText;
    }

    public  void Show(String message)
    {
        if(message.length()==0) return;
        StringBuilder StringMsg=new StringBuilder();
        String sRecTime = mSimpleDateFormat.format(new java.util.Date());
        StringMsg.append(sRecTime);
        StringMsg.append(" ");
        StringMsg.append("	{");
        StringMsg.append(message);
        StringMsg.append("}");
        StringMsg.append("\r\n");
        mLogMessge.post(new Runnable()
        {
            @Override
            public void run() {
                mLogMessge.append(StringMsg);
                mLogLines++;
                if (mLogLines > 500)
                {
                    mLogMessge.setText("");
                    mLogLines=0;
                }
            }
        });
    }

	 public  void Show(String message1,String message2)
    {
        if(message1.length()==0||message2.length()==0) return;
        StringBuilder StringMsg=new StringBuilder();
        String sRecTime = mSimpleDateFormat.format(new java.util.Date());
        StringMsg.append(sRecTime);
        StringMsg.append(" ");
		StringMsg.append(message1);
        StringMsg.append("	{");
        StringMsg.append(message2);
        StringMsg.append("}");
        StringMsg.append("\r\n");
        mLogMessge.post(new Runnable()
        {
            @Override
            public void run() {
                mLogMessge.append(StringMsg);
                mLogLines++;
                if (mLogLines > 500)
                {
                    mLogMessge.setText("");
                    mLogLines=0;
                }
            }
        });
    }

	
	public void clean()
	{
			mLogMessge.setText("");
      mLogLines=0;
	}
}
