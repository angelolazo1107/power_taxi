
package com.howen.howentestdemo;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStream;
import java.io.InputStreamReader;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.content.res.Configuration;
import android.os.Bundle;
import android.os.Environment;
import android.os.StatFs;
import android.util.Log;
import android.widget.EditText;
import android.widget.ProgressBar;
import android.os.storage.StorageManager;
import android.content.Context;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Collections;
import java.lang.reflect.Field;
import java.lang.reflect.Method;

public class SDCardStatus extends Activity {
    private EditText out_sd_EditText, out_sd_all_EditText,
            out_sd_free_EditText, in_sd_EditText, in_sd_all_EditText,
            in_sd_free_EditText, out_tf_EditText, out_tf_all_EditText,
            out_tf_free_EditText;
    private ProgressBar out_usb_progressBar, out_tf_progressBar, in_sd_progressBar;
    private boolean out_existUSB, out_existTFCard, Internal_sd;
    private long allSize, freeSize;
    private int jindu;
    private String exttf_path, internal_sd_path;
	public static ArrayList<String> usb_dir_list = new ArrayList<String>();
	public static final int FLAG_SD = 1 << 2;
    public static final int FLAG_USB = 1 << 3;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // TODO Auto-generated method stub
        super.onCreate(savedInstanceState);
        setContentView(R.layout.sd_card);

        Configuration configuration = getResources().getConfiguration();
        if (configuration.orientation == configuration.ORIENTATION_PORTRAIT) {
            SDCardStatus.this
                    .setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
        }
		
		init_StoragePath(this);
        view_init();

		
        if (Internal_sd == true) {
            in_sd_EditText.setText(R.string.built_in_sd);
            allSize = getSDAllSize(internal_sd_path);
            in_sd_all_EditText.setText(allSize + "  MB");
            freeSize = getSDFreeSize(internal_sd_path);
            in_sd_free_EditText.setText(freeSize + "  MB");
            progress("in");
        } else {
            in_sd_EditText.setText(R.string.built_in_sd_error);
            allSize = 0;
            in_sd_all_EditText.setText(allSize + "  MB");
            freeSize = 0;
            in_sd_free_EditText.setText(freeSize + "  MB");
        }

		
        if (out_existUSB == true) 
		{
			long usballSize=0, usbfreeSize=0; 
			for(int i=0; i<usb_dir_list.size() && usb_dir_list.get(i) != null; i++)
			{
				String usb_path=usb_dir_list.get(i);
				usballSize = usballSize+getSDAllSize(usb_path);
				usbfreeSize =usbfreeSize+getSDFreeSize(usb_path);
			}
            out_sd_EditText.setText(R.string.external_usb_card);
            allSize = usballSize;
            out_sd_all_EditText.setText(allSize + "  MB");
            freeSize = usbfreeSize;
            out_sd_free_EditText.setText(freeSize + "  MB");
            progress("outusb");
        } else {
            out_sd_EditText.setText(R.string.external_usb_card_error);
            allSize = 0;
            out_sd_all_EditText.setText(allSize + "  MB");
            freeSize = 0;
            out_sd_free_EditText.setText(freeSize + "  MB");
        }
		
        
        if (out_existTFCard == true) {
            allSize = getSDAllSize(exttf_path);
            out_tf_all_EditText.setText(allSize + "  MB");

            if (allSize > 8)
                out_tf_EditText.setText(R.string.external_tf_card);
            else
                out_tf_EditText.setText(R.string.external_tf_card_error);
            
            freeSize = getSDFreeSize(exttf_path);
            out_tf_free_EditText.setText(freeSize + "  MB");
            progress("outtf");
        } else {
            out_tf_EditText.setText(R.string.external_tf_card_error);
            allSize = 0;
            out_tf_all_EditText.setText(allSize + "  MB");
            freeSize = 0;
            out_tf_free_EditText.setText(freeSize + "  MB");
        }
        

    }

	public boolean isSd(int flags) {
        return (flags & FLAG_SD) != 0;
    }

    public boolean isUsb(int flags) {
        return (flags & FLAG_USB) != 0;
    }
	
	public void init_StoragePath(Context context) 
	{
		out_existUSB=false;
		out_existTFCard=false;
		Internal_sd=false;

		internal_sd_path = Environment.getExternalStorageDirectory().getPath();
		Internal_sd=true;

		usb_dir_list.clear();
		
		StorageManager storageManager = (StorageManager) context.getSystemService(Context.STORAGE_SERVICE);
		try 
		{
			Class storeManagerClazz = Class.forName("android.os.storage.StorageManager");
            Method getVolumesMethod = storeManagerClazz.getMethod("getVolumes");
            List<?> volumeInfos  = (List<?>)getVolumesMethod.invoke(storageManager);
            Class volumeInfoClazz = Class.forName("android.os.storage.VolumeInfo");
			Field diskField = volumeInfoClazz.getDeclaredField("disk");
			Field pathField = volumeInfoClazz.getDeclaredField("path");
			Class DiskInfoClazz = Class.forName("android.os.storage.DiskInfo");
			Field flagsField = DiskInfoClazz.getDeclaredField("flags");
			if(volumeInfos != null)
			{
                for(Object volumeInfo:volumeInfos)
				{
					Object disk = (Object)diskField.get(volumeInfo);
					if(disk!=null)
					{
						Object Objectflag = (Object)flagsField.get(disk);
						if(Objectflag!=null)
						{
							int flags=Integer.parseInt(String.valueOf(Objectflag));
							if(isSd(flags))
							{
								exttf_path = (String)pathField.get(volumeInfo);
								out_existTFCard=true;
							}else if (isUsb(flags))
							{
								String usb = (String)pathField.get(volumeInfo);
								usb_dir_list.add(usb);
								out_existUSB=true;
							}
						}
					}
                }
             }
		} catch (Exception e) {
		    Log.d("jason", " e:" + e);
		}
	}
	
    private void view_init() {
        // TODO Auto-generated method stub
        out_sd_EditText = (EditText) findViewById(R.id.out_sd_editText);
        out_sd_all_EditText = (EditText) findViewById(R.id.out_sd_all_editText);
        out_sd_free_EditText = (EditText) findViewById(R.id.out_sd_free_editText);
        out_usb_progressBar = (ProgressBar) findViewById(R.id.out_usb_progressBar);

        in_sd_EditText = (EditText) findViewById(R.id.in_sd_editText);
        in_sd_all_EditText = (EditText) findViewById(R.id.in_sd_all_editText);
        in_sd_free_EditText = (EditText) findViewById(R.id.in_sd_free_editText);
        in_sd_progressBar = (ProgressBar) findViewById(R.id.in_sd_progressBar);

        out_tf_EditText = (EditText) findViewById(R.id.out_tf_editText);
        out_tf_all_EditText = (EditText) findViewById(R.id.out_tf_all_editText);
        out_tf_free_EditText = (EditText) findViewById(R.id.out_tf_free_editText);
        out_tf_progressBar = (ProgressBar) findViewById(R.id.out_tf_progressBar);

    }

    private void progress(String str) {
        if (allSize == 0) {
            jindu = 0;
        } else {
            jindu = (int) (1000 * (allSize - freeSize) / allSize);
        }
        if (str.equals("in")) {
            in_sd_progressBar.setProgress(jindu);
        } else if (str.equals("outusb")) {
            out_usb_progressBar.setProgress(jindu);
        } else {
            out_tf_progressBar.setProgress(jindu);
        }
    }

    public long getSDFreeSize(String path) 
	{
        StatFs sf = new StatFs(path);
        long blockSize = sf.getBlockSize();
        long freeBlocks = sf.getAvailableBlocks();
        return (freeBlocks * blockSize) / 1024 / 1024;
    }
	
    public long getSDAllSize(String path) 
	{
        StatFs sf = new StatFs(path);
        long blockSize = sf.getBlockSize();
        long allBlocks = sf.getBlockCount();
        return (allBlocks * blockSize) / 1024 / 1024;
    }

}
