package com.howen.howentestdemo.can;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import org.json.JSONArray;
public class CanUtils 
{
	public static int isOdd(int num)
	{
		return num & 0x1;
	}
    
	public static int HexToInt(String inHex)
    {
    	return Integer.parseInt(inHex, 16);
    }
    
    public static byte HexToByte(String inHex)
    {
    	return (byte)Integer.parseInt(inHex,16);
    }
    
    public static String Byte2Hex(Byte inByte)
    {
    	return String.format("%02x", inByte).toUpperCase();
    }
    
    public static String ByteArrToHex(byte[] inBytArr)
	{
		StringBuilder strBuilder=new StringBuilder();
		int j=inBytArr.length;
		for (int i = 0; i < j; i++)
		{
			strBuilder.append(Byte2Hex(inBytArr[i]));
			strBuilder.append(" ");
		}
		return strBuilder.toString(); 
	}

	public static String ByteArrToHex(byte[] inBytArr,int offset,int byteCount)
	{
    	StringBuilder strBuilder=new StringBuilder();
		int j=byteCount;
		for (int i = offset; i < j; i++)
		{
			strBuilder.append(Byte2Hex(inBytArr[i]));
		}
		return strBuilder.toString();
	}

    public static byte[] HexToByteArr(String inHex)
	{
		int hexlen = inHex.length();
		byte[] result;
		if (isOdd(hexlen)==1)
		{
			hexlen++;
			result = new byte[(hexlen/2)];
			inHex="0"+inHex;
		}else {
			result = new byte[(hexlen/2)];
		}
	    int j=0;
		for (int i = 0; i < hexlen; i+=2)
		{
			result[j]=HexToByte(inHex.substring(i,i+2));
			j++;
		}
	    return result; 
	}
    
    public static byte[] IntTobyteArrayLH(int n) 
    {  
    	  byte[] b = new byte[4];  
    	  b[0] = (byte) (n & 0xff);  
    	  b[1] = (byte) (n >> 8 & 0xff);  
    	  b[2] = (byte) (n >> 16 & 0xff);  
    	  b[3] = (byte) (n >> 24 & 0xff);  
    	  return b;  
    }
    
    public static int ByteArrayToIntLH(byte[] b)
	{
	    int res = 0;
	    for(int i=0;i<b.length;i++){
	        res += (b[i] & 0xff) << (i*8);
	    }
	    return res;
	}

	public static byte[] IntTobyteArrayHH(int n) 
	{  
	  byte[] b = new byte[4];  
	  b[3] = (byte) (n & 0xff);  
	  b[2] = (byte) (n >> 8 & 0xff);  
	  b[1] = (byte) (n >> 16 & 0xff);  
	  b[0] = (byte) (n >> 24 & 0xff);  
	  return b;  
	}
	
	
	
	public static int ByteArrayToIntHH(byte[] b)
	{
	    int res = 0;
	    for(int i=0;i<b.length;i++){
	        res += (b[i] & 0xff) << ((3-i)*8);
	    }
	    return res;
	}
	
	
	public static byte[] ShortTobyteArrayLH(short n) 
    {  
    	  byte[] b = new byte[2];  
    	  b[0] = (byte) (n & 0xff);  
    	  b[1] = (byte) (n >> 8 & 0xff);   
    	  return b;  
    }
    
    public static short ByteArrayToShortLH(byte[] b)
	{
    	short res = 0;
	    for(int i=0;i<b.length;i++){
	        res += (b[i] & 0xff) << (i*8);
	    }
	    return res;
	}

	public static byte[] ShortTobyteArrayHH(short n) 
	{  
	  byte[] b = new byte[2];  
	  b[1] = (byte) (n & 0xff);  
	  b[0] = (byte) (n >> 8 & 0xff);   
	  return b;  
	}
	
	public static short ByteArrayToShortHH(byte[] b)
	{
		short res = 0;
	    for(int i=0;i<b.length;i++){
	        res += (b[i] & 0xff) << ((1-i)*8);
	    }
	    return res;
	}
}