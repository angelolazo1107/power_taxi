package com.howen.howennative;

import android.util.Log;

public class gpio_info {

	public gpio_info() {
	}

	static {
		try {
			System.loadLibrary("HowenGpio_jni");
			Log.d("HowenGpio", "Loaded HowenGpio_jni native library successfully");
		} catch (Throwable ule) {
			Log.w("HowenGpio", "Could not load HowenGpio_jni native library: " + ule.getMessage());
		}
	}

	public static native int open_gpio();

	public static native int close_gpio();

	public static native int get_gpio_data(String gpio_name);

	public static native int set_gpio_data(String gpio_name, int value);
}
