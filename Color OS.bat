@echo off
::CODER BY CLStudio POWERD BY Visual Studio.

goto start
/***********************************************************
* Hook:http://blog.chinaunix.net/uid-660282-id-2414901.html
* Call:http://blog.csdn.net/yhz/article/details/1484073
* ���Ĵ���:https://github.com/YinTianliang/CAPIx
************************************************************
#include <windows.h>
#include <gdiplus.h>
#include <wchar.h>
#include <iostream>
#include <fstream>
#include <string>
#include <cstdio>
#include <map>
using namespace std;
using namespace Gdiplus;

#define KEYDOWN(vk_code) ((GetAsyncKeyState(vk_code) & 0x8000) ? 1 : 0) 
#define DLL_EXPORT __declspec(dllexport)
#define wtoi _wtoi
#define wcsicmp _wcsicmp
#define match(x,y) if (!wcsicmp(argv[x],y))
#define matchclsid(x) if (!wcsicmp(&argv[1][wcslen(argv[1]) - 3], x))
#pragma comment(lib,"msimg32.lib")
#pragma comment(lib,"GdiPlus.lib")

struct imageres { //��Դ�ṹ��
	HDC dc;
	HBITMAP oldbmp;
	int w, h;
	imageres() {};
	imageres(wchar_t *file) //��ʼ���ṹ�壬��������Դ
	{
		BITMAP bi;
		//Ϊ�˷�ֹ���hbmpͬʱ��һ��hdc������ͻ��������������е�hbmp������Ե�hdc
		dc = CreateCompatibleDC(nullptr);
		//HBITMAP bmp = (HBITMAP)LoadImageA(nullptr, file, IMAGE_BITMAP, 0, 0, LR_LOADFROMFILE | LR_CREATEDIBSECTION);
		HBITMAP bmp;
		Bitmap *bm = new Bitmap(file);
		bm->GetHBITMAP(0, &bmp);
		delete bm;
		oldbmp = (HBITMAP)SelectObject(dc, bmp);
		GetObject(bmp, sizeof(BITMAP), &bi);
		w = bi.bmWidth;
		h = bi.bmHeight;
	}
}*hTarget;
map<wstring, imageres> resmap; //��Դӳ���
HWND hCMD;//����̨���ھ��
double scale;//У�����ű�
wchar_t **argv;

void image(wchar_t *); //������
void Init_image(); //��ʼ��

bool WINAPI DllMain(HMODULE hModule, DWORD dwReason, LPVOID lpvReserved)
{
	switch (dwReason)
	{
	case DLL_PROCESS_ATTACH:
		//HookAPI(SetEnvironmentVariableW, SetCall_image);
		DisableThreadLibraryCalls(hModule);
		Init_image();
		break;
	case DLL_PROCESS_DETACH:
		break;
	}
	return true;
}
extern "C" DLL_EXPORT int WINAPI Init(void)//��������������,�������
{
	return 0;
}
extern "C" __declspec(dllexport) void call(wchar_t *varName, wchar_t *varValue)
{
	//�жϱ������Ƿ�Ϊimage, �������image
	if (!wcsicmp(varName, L"image")) image(varValue);
	return;
}

void Init_image() //��ʼ��
{
	GdiplusStartupInput gdiplusStartupInput;
	ULONG_PTR gdiplusToken;
	GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, nullptr);

	imageres hRes;
	//��ȡcmd��С�Լ���ͼ���
	hCMD = GetConsoleWindow();
	HDC hDC = GetDC(hCMD);
	DEVMODE dm;
	dm.dmSize = sizeof(DEVMODE);
	EnumDisplaySettings(nullptr, ENUM_CURRENT_SETTINGS, &dm);
	int ax = dm.dmPelsWidth;
	int bx = GetSystemMetrics(SM_CXSCREEN);
	scale = (double)ax / bx;//У�����ű�
	RECT rc;
	GetClientRect(hCMD, &rc);
	hRes.dc = hDC;
	hRes.w = int(scale*(rc.right - rc.left));
	hRes.h = int(scale*(rc.bottom - rc.top));
	resmap[L"cmd"] = hRes; //��cmd��Ϊ��Դ��ӵ����ñ���
	hTarget = &resmap[L"cmd"];//getres("cmd"); //��ͼĬ��ָ��cmd
	//��ȡdesktop��С�Լ���ͼ���
	hDC = GetDC(nullptr);
	hRes.dc = hDC;
	hRes.w = dm.dmPelsWidth;
	hRes.h = dm.dmPelsHeight;
	resmap[L"desktop"] = hRes; //��desktop��Ϊ��Դ��ӵ����ñ���

	TextOutA(hTarget->dc, 0, 0, 0, 0);//��һ��ʹ��TextOutA��Ч������Ǹ�bug
	return;
}
imageres * getres(wchar_t *tag) //����Դӳ����в�����Դ
{
	if (!resmap.count(tag)) //�������Դӳ������Ҳ�����Դ�����ȼ���ͼƬ����Դӳ���
	{
		imageres hRes(tag);
		resmap[tag] = hRes;
	}
	return &resmap[tag];
}
void delres(wchar_t *tag) //����ԭ������Դ����ֹ�ڴ�й©
{
	imageres * hRes = getres(tag);
	HBITMAP bmp = (HBITMAP)SelectObject(hRes->dc, hRes->oldbmp);
	DeleteObject(bmp);
	DeleteDC(hRes->dc);
	resmap.erase(tag);
	return;
}
//������SelectObject��ȡcmd��������Դ��hbitmap������Ҫ����һ�ݳ�����ע��ʹ��֮��ҪDeleteObject
HBITMAP copyhbitmap(imageres *hSrc)
{
	imageres hRes;
	hRes.dc = CreateCompatibleDC(hSrc->dc);
	HBITMAP hBitmap = CreateCompatibleBitmap(hSrc->dc, hSrc->w, hSrc->h);
	hRes.oldbmp = (HBITMAP)SelectObject(hRes.dc, hBitmap);
	BitBlt(hRes.dc, 0, 0, hSrc->w, hSrc->h, hSrc->dc, 0, 0, SRCCOPY);
	SelectObject(hRes.dc, hRes.oldbmp);
	DeleteDC(hRes.dc);
	return hBitmap;
}
void rotateres()
{
	imageres * hRes = getres(argv[1]);
	HBITMAP hSrc = copyhbitmap(hRes);
	Rect rect(0, 0, hRes->w, hRes->h);
	//���ڼ��ؾ�λͼ
	Bitmap bitmap(hSrc, nullptr);
	BitmapData bitmapData;
	bitmap.LockBits(&rect, ImageLockModeRead, PixelFormat24bppRGB, &bitmapData);
	byte* pixels = (byte*)bitmapData.Scan0;
	//���ڼ�����λͼ
	Bitmap bitmap2(hSrc, nullptr);
	BitmapData bitmapData2;
	bitmap2.LockBits(&rect, ImageLockModeWrite, PixelFormat24bppRGB, &bitmapData2);
	byte* pixels2 = (byte*)bitmapData2.Scan0;
	//��ת
	double pi = 3.1415926;
	double angle = -(double)wtoi(argv[2]) / 180 * pi;
	double sina = sin(angle), cosa = cos(angle);
	int cx = hRes->w / 2, cy = hRes->h / 2;
	for (int i = 0; i<hRes->w; i++)
		for (int j = 0; j<hRes->h; j++)
		{
			int x = (int)(cx + (i - cx)*cosa - (j - cy)*sina), y = (int)(cy + (i - cx)*sina + (j - cy)*cosa);//ԭ����
			if (x >= 0 && x < hRes->w&&y >= 0 && y < hRes->h)
			{
				for (int k = 0; k < 3; k++)
					pixels2[j*bitmapData2.Stride + 3 * i + k] = pixels[y*bitmapData.Stride + 3 * x + k];
			}
			else
			{
				for (int k = 0; k < 3; k++)
					pixels2[j*bitmapData2.Stride + 3 * i + k] = 0xFF;
			}
		}
	bitmap.UnlockBits(&bitmapData);
	bitmap2.UnlockBits(&bitmapData2);
	//������ʱ��Դ��Ŀ����Դ
	HDC hDCMem = CreateCompatibleDC(hRes->dc);
	HBITMAP hBitmap;
	bitmap2.GetHBITMAP(0, &hBitmap);
	HBITMAP oldbmp = (HBITMAP)SelectObject(hDCMem, hBitmap);
	BitBlt(hRes->dc, 0, 0, hRes->w, hRes->h, hDCMem, 0, 0, SRCCOPY);
	//������ʱ���Ƶ���Դ
	DeleteObject(hSrc);
	SelectObject(hDCMem, oldbmp);
	DeleteObject(hBitmap);
	DeleteDC(hDCMem);
}
void alphares()
{
	double alpha = (double)wtoi(argv[5])/100;
	//���ڼ���Դλͼ
	imageres * hRes = getres(argv[1]);
	HBITMAP hSrc = copyhbitmap(hRes);
	Rect rect(0, 0, hRes->w, hRes->h);
	Bitmap bitmap(hSrc, nullptr);
	BitmapData bitmapData;
	bitmap.LockBits(&rect, ImageLockModeRead, PixelFormat24bppRGB, &bitmapData);
	byte* pixels = (byte*)bitmapData.Scan0;
	//���ڼ���Ŀ��λͼ
	//����SelectObject��ȡcmd��������Դ��hbitmap������Ҫ����һ�ݳ�����ע��ʹ��֮��ҪDeleteObject
	HBITMAP hSrc2 = copyhbitmap(hTarget);
	Rect rect2(0, 0, hTarget->w, hTarget->h);
	Bitmap bitmap2(hSrc2, nullptr);
	BitmapData bitmapData2;
	bitmap2.LockBits(&rect2, ImageLockModeRead, PixelFormat24bppRGB, &bitmapData2);
	byte* pixels2 = (byte*)bitmapData2.Scan0;
	//���ڼ�����λͼ
	Rect rect3(0, 0, hTarget->w, hTarget->h);
	Bitmap bitmap3(hSrc2, nullptr);
	BitmapData bitmapData3;
	bitmap3.LockBits(&rect3, ImageLockModeWrite, PixelFormat24bppRGB, &bitmapData3);
	byte* pixels3 = (byte*)bitmapData3.Scan0;
	//alpha���
	int cx = wtoi(argv[2]), cy = wtoi(argv[3]);
	for (int i = 0; i<hTarget->w; i++)
		for (int j = 0; j<hTarget->h; j++)
		{
			int x = i - cx, y = j - cy;//Դ����
			if (x >= 0 && x < hRes->w&&y >= 0 && y < hRes->h)
			{
				for (int k = 0; k < 3; k++)
					pixels3[j*bitmapData3.Stride + 3 * i + k] =
					(byte)((1 - alpha) * pixels2[j*bitmapData2.Stride + 3 * i + k] +
						alpha * pixels[y*bitmapData.Stride + 3 * x + k]);
			}
			else
			{
				for (int k = 0; k < 3; k++)
					pixels3[j*bitmapData3.Stride + 3 * i + k] = pixels2[j*bitmapData2.Stride + 3 * i + k];
			}
		}
	bitmap.UnlockBits(&bitmapData);
	bitmap2.UnlockBits(&bitmapData2);
	bitmap3.UnlockBits(&bitmapData3);
	//������ʱ��Դ��Ŀ����Դ
	HDC hDCMem = CreateCompatibleDC(hTarget->dc);
	HBITMAP hBitmap;
	bitmap3.GetHBITMAP(0, &hBitmap);
	HBITMAP oldbmp = (HBITMAP)SelectObject(hDCMem, hBitmap);
	BitBlt(hTarget->dc, 0, 0, hTarget->w, hTarget->h, hDCMem, 0, 0, SRCCOPY);
	//������ʱ���Ƶ���Դ
	DeleteObject(hSrc);
	DeleteObject(hSrc2);
	SelectObject(hDCMem, oldbmp);
	DeleteObject(hBitmap);
	DeleteDC(hDCMem);
}

void image(wchar_t *CmdLine)
{
	int argc;
	argv = CommandLineToArgvW(CmdLine, &argc);
	match(0, L"help")
	{
		printf(
			"image\n"
			"����̨��ʾͼƬ Ver 3.0 by Byaidu\n"
			"\n"
			"help\t\t\t��ʾ����\n"
			"load file [tag]\t\t����һ�黭��tag��������ͼƬ������tag\n"
			"unload tag\t\tɾ������tag\n"
			"save file tag\t\t������tag�����ݴ洢��file��\n"
			"target tag\t\t�л���ǰ��ͼĿ��Ϊ����tag\n"
			"buffer tag\t\t����һ�黭��tag\n"
			"stretch tag w h\t\t������tag���ŵ�w*h�Ĵ�С\n"
			"cls\t\t\t��ջ���cmd������\n"
			"rotate tag degree\t������tag˳ʱ����תdegree��\n"
			"draw tag x y [trans|and]������tag���Ƶ���ǰ��ͼĿ���x,yλ����\n"
			"info tag\t\t������tag�Ŀ�͸ߴ洢������image\n"
			"export\t\t\t������cmd�ľ���洢������image\n"
			"import handle tag\tͨ���������һ������̨�Ļ���cmdӳ�䵽�˿���̨�Ļ���tag\n"
			"getpix tag x y\t\t������tag��x,yλ�õ�rgbֵ�洢������image\n"
			"setpix tag x y r g b\t���û���tag��x,yλ�õ�rgbֵ\n"
		);
	}
	match(0, L"load") //������Դ����Դӳ���
	{
		wchar_t *tag; //��Դ������
		tag = (argc == 3) ? argv[2] : argv[1];
		//����ԭ������Դ����ֹ�ڴ�й©
		if (resmap.count(tag)) delres(tag);
		imageres hRes(argv[1]);
		resmap[tag] = hRes;
	}
	match(0, L"unload") //ж����Դ
	{
		//����ԭ������Դ����ֹ�ڴ�й©
		delres(argv[1]);
	}
	match(0, L"save") //����ΪͼƬ
	{
		imageres * hRes = getres(argv[2]);
		HBITMAP hSrc = copyhbitmap(hRes);
		Rect rect(0, 0, hRes->w, hRes->h);
		Bitmap bitmap(hSrc, nullptr);
		//https://stackoverflow.com/questions/1584202/gdi-bitmap-save-problem
		CLSID Clsid;
		matchclsid(L"bmp") CLSIDFromString(L"{557cf400-1a04-11d3-9a73-0000f81ef32e}", &Clsid);
		matchclsid(L"jpg") CLSIDFromString(L"{557cf401-1a04-11d3-9a73-0000f81ef32e}", &Clsid);
		matchclsid(L"png") CLSIDFromString(L"{557cf406-1a04-11d3-9a73-0000f81ef32e}", &Clsid);
		bitmap.Save(argv[1], &Clsid, nullptr);
		DeleteObject(hSrc);
	}
	match(0, L"target") //���Ļ�ͼĿ��
	{
		hTarget = getres(argv[1]);
	}
	match(0, L"buffer") //�½�һ��buffer����
	{
		wchar_t *tag = argv[1];
		//����ԭ������Դ����ֹ�ڴ�й©
		if (resmap.count(tag)) delres(tag);
		imageres hRes;
		hRes.dc = CreateCompatibleDC(hTarget->dc);
		HBITMAP hBitmap = CreateCompatibleBitmap(hTarget->dc, hTarget->w, hTarget->h);
		hRes.oldbmp = (HBITMAP)SelectObject(hRes.dc, hBitmap);
		BitBlt(hRes.dc, 0, 0, hTarget->w, hTarget->h, nullptr, 0, 0, WHITENESS);
		hRes.w = hTarget->w;
		hRes.h = hTarget->h;
		//��buffer��ӵ���Դ���ñ���
		resmap[tag] = hRes;
	}
	match(0, L"resize") //����
	{
		imageres * hRes = getres(argv[1]);
		match(1,L"cmd")
		{
			RECT rc,rc2;
			SetScrollRange(hCMD, 0, 0, 0, 1);
			SetScrollRange(hCMD, 1, 0, 0, 1);
			GetClientRect(hCMD, &rc);
			GetWindowRect(hCMD, &rc2);
			int w = (rc2.right - rc2.left) - (rc.right - rc.left) + int((wtoi(argv[2])) / scale);
			int h = (rc2.bottom - rc2.top) - (rc.bottom - rc.top) + int((wtoi(argv[3])) / scale);
			//printf("scale:%f\n", scale);
			//printf("C:%dx%d\n", rc.right - rc.left, rc.bottom - rc.top);
			//printf("W:%dx%d\n", rc2.right - rc2.left, rc2.bottom - rc2.top);
			MoveWindow(hCMD, rc2.left, rc2.top, w, h, 0);
			Sleep(10);
			SetScrollRange(hCMD, 0, 0, 0, 1);
			SetScrollRange(hCMD, 1, 0, 0, 1);
			Sleep(10);
			hRes->w = (int)wtoi(argv[2]);
			hRes->h = (int)wtoi(argv[3]);
		}else{
			HDC hDCMem = CreateCompatibleDC(hRes->dc);
			HBITMAP hBitmap = CreateCompatibleBitmap(hRes->dc, wtoi(argv[2]), wtoi(argv[3]));
			HBITMAP oldbmp = (HBITMAP)SelectObject(hDCMem, hBitmap);
			StretchBlt(hDCMem, 0, 0, wtoi(argv[2]), wtoi(argv[3]), hRes->dc, 0, 0, hRes->w, hRes->h, SRCCOPY);
			//����ԭ������Դ����ֹ�ڴ�й©
			HBITMAP bmp = (HBITMAP)SelectObject(hRes->dc, hRes->oldbmp);
			DeleteObject(bmp);
			DeleteDC(hRes->dc);
			//�滻ԭ������Դ
			hRes->oldbmp = oldbmp;
			hRes->dc = hDCMem;
			hRes->w = wtoi(argv[2]);
			hRes->h = wtoi(argv[3]);
		}
	}
	match(0, L"cls") //����
	{
		InvalidateRect(hCMD, nullptr, true);
	}
	match(0, L"rotate")
	{
		rotateres();
	}
	match(0, L"draw")
	{
		//ֱ����Ŀ���ϻ�ͼ
		imageres * hRes = getres(argv[1]);
		if (argc == 4)
		{
				BitBlt(hTarget->dc, wtoi(argv[2]), wtoi(argv[3]), hRes->w, hRes->h, hRes->dc, 0, 0, SRCCOPY);
		}
		else
		{
			match(4, L"trans")
					TransparentBlt(hTarget->dc, wtoi(argv[2]), wtoi(argv[3]), hRes->w, hRes->h, hRes->dc, 0, 0, hRes->w, hRes->h, RGB(255, 255, 255));
			match(4, L"alpha")
				alphares();
		}
	}
	match(0, L"text")
	{
		//��ʾ���βŻ�ˢ�³���������Ǹ�bug
		for (int i = 0; i < 2;i++) TextOutW(hTarget->dc, wtoi(argv[2]), wtoi(argv[3]), argv[1], wcslen(argv[1]));
	}
	match(0, L"font")
	{
		SetBkMode(hTarget->dc, TRANSPARENT);
		SetTextColor(hTarget->dc, RGB(wtoi(argv[3]), wtoi(argv[4]), wtoi(argv[5])));
		HFONT hFont = CreateFontW(
			wtoi(argv[2]), wtoi(argv[1]), 0/*���ù�*/, 0/*���ù�*/, 400 /*һ�����ֵ��Ϊ400*/,
			FALSE/*����б��*/, FALSE/*�����»���*/, FALSE/*����ɾ����*/,
			DEFAULT_CHARSET, //��������ʹ��Ĭ���ַ��������������� _CHARSET ��β�ĳ�������
			OUT_CHARACTER_PRECIS, CLIP_CHARACTER_PRECIS, //���в������ù�
			DEFAULT_QUALITY, //Ĭ���������
			FF_DONTCARE, //��ָ��������*/
			L"������" //������
		);
		SelectObject(hTarget->dc,hFont);
	}
	match(0, L"sleep")
	{
		Sleep(wtoi(argv[1]));
	}
	match(0, L"info")
	{
		wchar_t info[100];
		imageres * hRes = getres(argv[1]);
		wsprintfW(info, L"%d %d", hRes->w, hRes->h);
		SetEnvironmentVariableW(L"image", info);
	}
	match(0, L"export")
	{
		wchar_t info[100];
		wsprintfW(info, L"%d", (int)hCMD);
		SetEnvironmentVariableW(L"image", info);
	}
	match(0, L"import")
	{
		wchar_t *tag = argv[2];
		//����ԭ������Դ����ֹ�ڴ�й©
		if (resmap.count(tag)) delres(tag);
		imageres hRes;
		//��ȡcmd��С�Լ���ͼ���
		HWND hCMD2 = (HWND)wtoi(argv[1]);
		HDC hDC = GetDC(hCMD2);
		DEVMODE dm;
		dm.dmSize = sizeof(DEVMODE);
		EnumDisplaySettings(nullptr, ENUM_CURRENT_SETTINGS, &dm);
		int ax = dm.dmPelsWidth;
		int bx = GetSystemMetrics(SM_CXSCREEN);
		double scale = (double)ax / bx;//У�����ű�
		RECT rc;
		GetClientRect(hCMD2, &rc);
		hRes.dc = hDC;
		hRes.w = (int)ceil(scale*(rc.right - rc.left));
		hRes.h = (int)ceil(scale*(rc.bottom - rc.top));
		resmap[tag] = hRes; //��cmd��Ϊ��Դ��ӵ����ñ���
	}
	match(0, L"getpix")
	{
		wchar_t info[100];
		COLORREF color=GetPixel(hTarget->dc, wtoi(argv[1]), wtoi(argv[2]));
		wsprintfW(info, L"%d %d %d", GetRValue(color), GetGValue(color), GetBValue(color));
		SetEnvironmentVariableW(L"image", info);
	}
	match(0, L"setpix")
	{
		SetPixel(hTarget->dc, wtoi(argv[1]), wtoi(argv[2]), RGB(wtoi(argv[3]), wtoi(argv[4]), wtoi(argv[5])));
	}
	match(0, L"list")
	{
		ifstream in(argv[1]);
		string str;
		wchar_t wstr[100];
		while (!in.eof())
		{
			getline(in, str);
			MultiByteToWideChar(CP_ACP, 0, str.c_str(), -1, wstr, sizeof(wstr));
			image(wstr);
		}
		in.close();
	}
	match(0, L"mouse")
	{
		imageres *hRes = getres((wchar_t*)L"cmd");
		wchar_t info[100];
		POINT mosPos;
		int x, y;
		// ��ȡ��׼��������豸���  
		HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
		HANDLE hIn = GetStdHandle(STD_INPUT_HANDLE);
		DWORD oldConMode;
		GetConsoleMode(hIn, &oldConMode); // ����
		SetConsoleMode(hIn, (oldConMode | ENABLE_WINDOW_INPUT | ENABLE_MOUSE_INPUT)&(~ENABLE_QUICK_EDIT_MODE) );
		INPUT_RECORD	mouseRec;
		DWORD			res;
		while (1)
		{
			ReadConsoleInput(hIn, &mouseRec, 1, &res);
			if (mouseRec.EventType == MOUSE_EVENT)
			{
				if (mouseRec.Event.MouseEvent.dwButtonState == FROM_LEFT_1ST_BUTTON_PRESSED)
				{
					GetCursorPos(&mosPos);
					ScreenToClient(hCMD, &mosPos);
					x = min(max((int)scale*mosPos.x, 0), hRes->w);
					y = min(max((int)scale*mosPos.y, 0), hRes->h);
					break;
				}
			}
		}
		wsprintfW(info, L"%d %d", x, y);
		SetEnvironmentVariableW(L"image", info);
		SetConsoleMode(hIn, oldConMode);
	}
	LocalFree(argv);
	return;
}


//CAPIx 2.0.1

/***********************************************************
* Hook:http://blog.chinaunix.net/uid-660282-id-2414901.html
* Call:http://blog.csdn.net/yhz/article/details/1484073
************************************************************/

//TODO:����if��˳��(Ҳ�����΢����ٶ�)
//TODO:int? uint?

#include <windows.h>
#include <process.h>
#include <tlhelp32.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <objbase.h>

#define DLL_EXPORT __declspec(dllexport)
#define wtoi _wtoi
#define itow _itow
#define wtof(x) wcstod(x, NULL); 
#define MAX_LENGTH_OF_ENVVARIABLE 8192
#define MAX_ARG_NUMBERS 32

#define TYPE_BYTE   '.'
#define TYPE_SHORT  ':'
#define TYPE_INT    ';'
#define TYPE_FLOAT  '~'
#define TYPE_DOUBLE '`'
#define TYPE_ASTR   '#'
#define TYPE_USTR   '$'
#define TYPE_PTR    '*'
#define TYPE_MOVEP  '@'

#define INT_FUNCTION 1
#define FLOAT_FUNCTION 2
#define DOUBLE_FUNCTION 4

#define CALL_FUNCTION 8
#define EXEC_FUNCTION 16

#define LIB_FROM_MEM (HMODULE)1
//11111

#define SetEnvW ((PFNSETENVIRONMENTVARIABLE)bakSetEnv)
#define GetEnvW ((PFNGETENVIRONMENTVARIABLE)bakGetEnv)


//���ù����干��һ���ڴ��������ʵ��ǿ������ת��
typedef union {
    double _double;
    int    _int[2];
    float  _float[2];
} CAPI_Ret;

#undef memcpy

#pragma comment(lib,"th32.lib")
#pragma comment(linker, "/OPT:nowin98")




// ����SetEnvironmentVariableW����ԭ��
typedef bool  (WINAPI *PFNSETENVIRONMENTVARIABLE)(wchar_t *, wchar_t *);
typedef DWORD (WINAPI *PFNGETENVIRONMENTVARIABLE)(wchar_t *, wchar_t *, DWORD);

bool WINAPI SetCall_CAPI(wchar_t *, wchar_t *);
bool CAPI(wchar_t *);
CAPI_Ret* APIStdCall(void *, int *, int, short);
CAPI_Ret* APICdecl(void *, int *, int, short);

wchar_t* GetVar(wchar_t *);
void SetVar(wchar_t *, int);
void HookAPI(void *, void *);//�̺߳���
void MemPut  (int, wchar_t **);
void MemPrint(int, wchar_t **);
void MemCopy (int, wchar_t **);

char* WcharToChar(wchar_t *);

bool *bakSetEnv  = (bool  *)SetEnvironmentVariableW;     //���溯������ڵ�ַ
DWORD *bakGetEnv = (DWORD *)GetEnvironmentVariableW;
//bool *NewAddr = (bool *)CallCAPI;


//-------------------------------------------------------��������ʼ

BOOL WINAPI DllMain(HMODULE hModule, DWORD dwReason, LPVOID lpvReserved)
{
    //OleInitialize(NULL); //��ʼ��COM���ù���
    
	if (dwReason == DLL_PROCESS_ATTACH)
	{
        HookAPI(SetEnvironmentVariableW, SetCall_CAPI);
		DisableThreadLibraryCalls(hModule);
		/*if(Load())
		{
			//LpkEditControl���������14����Ա�����뽫�临�ƹ���    
			//memcpy((LPVOID)(LpkEditControl+1), (LPVOID)((int*)GetAddress("LpkEditControl") + 1),52);   
			//_beginthread(Init,NULL,NULL);
		}
		else
			return FALSE;*/
	}
	else if (dwReason == DLL_PROCESS_DETACH)
	{
		//Free();
	}
	return TRUE;
}

//��������������,�������
extern "C" DLL_EXPORT int Init(void)
{
    return 0;
}
//�������̵ĺ���


void HookAPI(void *OldFunc, void *NewFunc)
{
    PIMAGE_DOS_HEADER pDosHeader;
    PIMAGE_NT_HEADERS pNTHeaders;
    PIMAGE_OPTIONAL_HEADER    pOptHeader;
    PIMAGE_IMPORT_DESCRIPTOR  pImportDescriptor;
    PIMAGE_THUNK_DATA         pThunkData;
    //PIMAGE_IMPORT_BY_NAME     pImportByName;
    HMODULE hMod;

    //------------hook api----------------
    hMod = GetModuleHandle(NULL);

    pDosHeader = (PIMAGE_DOS_HEADER)hMod;
    pNTHeaders = (PIMAGE_NT_HEADERS)((BYTE *)hMod + pDosHeader->e_lfanew);
    pOptHeader = (PIMAGE_OPTIONAL_HEADER)&(pNTHeaders->OptionalHeader);

    pImportDescriptor = (PIMAGE_IMPORT_DESCRIPTOR)((BYTE *)hMod + pOptHeader->DataDirectory[1].VirtualAddress);

    while(pImportDescriptor->FirstThunk)
    {
        //char * dllname = (char *)((BYTE *)hMod + pImportDescriptor->Name);

        pThunkData = (PIMAGE_THUNK_DATA)((BYTE *)hMod + pImportDescriptor->OriginalFirstThunk);

        int no = 1;
        while(pThunkData->u1.Function)
        {
            //char * funname = (char *)((BYTE *)hMod + (DWORD)pThunkData->u1.AddressOfData + 2);
            PDWORD lpAddr = (DWORD *)((BYTE *)hMod + (DWORD)pImportDescriptor->FirstThunk) +(no-1);

            //�޸��ڴ�Ĳ���
            if((*lpAddr) == (unsigned int)OldFunc)
            {
                //�޸��ڴ�ҳ������
                DWORD dwOLD;
                MEMORY_BASIC_INFORMATION mbi;
                VirtualQuery(lpAddr,&mbi,sizeof(mbi));
                VirtualProtect(lpAddr,sizeof(DWORD),PAGE_READWRITE,&dwOLD);

                WriteProcessMemory(GetCurrentProcess(),
                lpAddr, &NewFunc, sizeof(DWORD), NULL);
                //�ָ��ڴ�ҳ������
                VirtualProtect(lpAddr,sizeof(DWORD),dwOLD,0);
            }
            //---------
            no++;
            pThunkData++;
        }

        pImportDescriptor++;
    }
    //-------------------HOOK END-----------------
}

/* �жϱ������Ƿ�ΪCAPI, �������CAPI */
bool WINAPI SetCall_CAPI(wchar_t *varName, wchar_t *varValue)
{
    if (!wcsicmp(varName, L"CAPI")) {
        
        CAPI(varValue);
    } else {
        
        SetEnvW(varName, varValue);
    }
    return true;
}

DWORD WINAPI GetCall_CAPI(wchar_t *varName, wchar_t* varValue, DWORD size)
{
    if (!wcsnicmp(varName, L"CAPI", 4)) { //4 || 8 ??
        CAPI(varName + 5);
        wchar_t *ret = GetVar(L"CAPI_Ret");
        wcscpy(varValue, ret);
        free(ret);
        return lstrlenW(varValue);
    }
    return GetEnvW(varName, varValue, size);
}

/* �������ڴ���Ҫ�ֶ��ͷ�! */
inline char* WcharToChar(wchar_t *wstr)
{
    int len   = WideCharToMultiByte(CP_ACP, 0, wstr, -1, NULL, 0, NULL, NULL);
    char *str = (char *)malloc(len * sizeof(char));
    WideCharToMultiByte(CP_ACP, 0, wstr, -1, str, len, NULL, NULL);
    return str;
}

/* varValue��ռ�ڴ������ǵ��ͷ� */
wchar_t* GetVar(wchar_t *varName)
{
    wchar_t *varValue = (wchar_t *)malloc(8192 * sizeof(wchar_t));
    memset(varValue, 0, 8192 * sizeof(wchar_t));
    GetEnvironmentVariableW(varName, varValue, 8192);

    return varValue;
}

/* ���÷���ֵ */
inline void SetVar(wchar_t *varName, int _varValue)
{
    wchar_t *varValue = (wchar_t *)malloc(64 * sizeof(wchar_t));
    itow(_varValue, varValue, 10);
    SetEnvW(varName, varValue);
    free(varValue);

    return;
}

inline void SetVar(wchar_t *varName, double _varValue)
{
    wchar_t *varValue = (wchar_t *)malloc(64 * sizeof(wchar_t));
    swprintf(varValue, L"%f", _varValue);
    SetEnvW(varName, varValue);
    free(varValue);
}

inline void MemPut(int argc, wchar_t *argv[])
{
    void *dst = NULL;
    bool  fromVar = false; //���dst��һ�������ĵ�ַ,��ô�޸����ִ��SetEnvironmentVariable�滻ԭ���ı���ֵ

    if (argv[2][0] == TYPE_INT) {
        dst = (void *)wtoi((wchar_t *)&argv[2][1]);
    } else if (argv[2][0] == TYPE_PTR) {
        fromVar = true;
        dst = (void *)GetVar((wchar_t *)&argv[2][1]);
    } else {
        fprintf(stderr, "ERROR:δ֪��ʶ�� %c", argv[2][0]); //can't exit in case of memory overfloat
        return;
    }
    void *dstbak = dst;

    int i;
    int step = 0;

    int   i_data;
    void *p_data = NULL;
    bool can_free = false;
    for (i = 3; i < argc; ++i) {
        can_free = false;
        //printf("%d\n", (int)dst);
        switch (argv[i][0]) {
        case TYPE_BYTE:
            step = 1;
            i_data = (char)wtoi((wchar_t *)&argv[i][1]);
            p_data = &i_data;
            break;
        case TYPE_SHORT:
            step = 2;
            i_data = (short)wtoi((wchar_t *)&argv[i][1]);
            p_data = &i_data;
            break;
        case TYPE_INT:
            step = 4;
            i_data = wtoi((wchar_t *)&argv[i][1]);
            p_data = &i_data;
            break;
        case TYPE_FLOAT:
            {
                step = 4;
                float tmp = (float)wtof((wchar_t *)&argv[i][1]);
                i_data = *(int *)&tmp;
                p_data = &i_data;
            }
            break;
        case TYPE_DOUBLE:
            {
                step = 0; //double����ռ8���ֽ�,�޷���int����,��������
                double tmp = wtof((wchar_t *)&argv[i][1]);
                memcpy(dst, &tmp, 8);
                dst = (void *)((int)dst + 8);
            }
            break;
        case TYPE_ASTR:
            can_free = true;
            p_data = WcharToChar((wchar_t *)&argv[i][1]);
            step   = lstrlenA((char *)p_data);
            break;
        case TYPE_USTR:
            p_data = &argv[i][1];
            step   = 2 * lstrlenW((wchar_t *)&argv[i][1]);
            break;
        case TYPE_PTR:
            can_free = true;
            p_data = GetVar((wchar_t *)&argv[i][1]);
            step   = 2 * lstrlenW((wchar_t *)p_data);
            break;
        case TYPE_MOVEP:
            step  = 0;
            dst = (void *)((int)dst + wtoi((wchar_t *)&argv[i][1]));
            break;
        default:
            fprintf(stderr, "ERROR:δ֪��ʶ�� %c", argv[i][0]);
            // goto CLEAN_AND_EXIT;
            break;
        }

        if (step != 0) {
            memcpy(dst, p_data, step);
            if (can_free) {
                free(p_data);
            }
            dst = (void *)((int)dst + step);
        }

    }
    //CLEAN_AND_EXIT:
    if (fromVar) {
        SetEnvW((wchar_t *)&argv[2][1], (wchar_t *)dstbak);
        free(dstbak);
    }

    return;
}

void MemPrint(int argc, wchar_t *argv[])
{
    void *SrcMem = NULL;
    bool SrcFromVar = false;
    if (argv[2][0] == TYPE_INT) {
        SrcMem = (void *)wtoi((wchar_t *)&argv[2][1]);
    } else if (argv[2][0] == TYPE_PTR) {
        SrcFromVar = true;
        SrcMem = (void *)GetVar((wchar_t *)&argv[2][1]);
    } else {
        fprintf(stderr, "ERROR:δ֪��ʶ�� %c", argv[2][0]);
        return;
    }
    void *dstbak = SrcMem;

    int i, step = 0;
    char *varName = NULL;
    for (i = 3; i < argc; ++i) {
        step = 0;
        switch (argv[i][0]) {
        case TYPE_BYTE:
            SetVar((wchar_t *)&argv[i][1], *(char *)SrcMem);
            step = 1;
            break;
        case TYPE_SHORT:
            SetVar((wchar_t *)&argv[i][1], *(short *)SrcMem);
            step = 2;
            break;
        case TYPE_INT:
            SetVar((wchar_t *)&argv[i][1], *(int *)SrcMem);
            step = 4;
            break;
        case TYPE_FLOAT:
            SetVar((wchar_t *)&argv[i][1], *(float *)SrcMem);
            step = 4;
            break;
        case TYPE_DOUBLE:
            SetVar((wchar_t *)&argv[i][1], *(double *)SrcMem);
            step = 8;
            break;
        case TYPE_ASTR:
            varName = WcharToChar((wchar_t *)&argv[i][1]);
            SetEnvironmentVariableA(varName, (char *)SrcMem);
            step = lstrlenA((char *)SrcMem) + 1; //��Ҫ����'\0'
            free(varName);
            break;
        case TYPE_USTR:
            SetEnvW((wchar_t *)&argv[i][1], (wchar_t *)SrcMem);
            step = 2 * lstrlenW((wchar_t *)SrcMem) + 2; // ��Ҫ����'\0'  Unicodeһ���ַ�2�ֽ�,����*2
            break;
        case TYPE_MOVEP:
            step = wtoi((wchar_t *)&argv[i][1]);
            break;
        default:
            fprintf(stderr, "ERROR:δ֪��ʶ�� %c", argv[i][0]);
            //goto CLEAN_AND_EXIT;
            break;
        }
        SrcMem = (void *)((int)SrcMem + step);
    }
    //CLEAN_AND_EXIT:
    if (SrcFromVar) {
        free(dstbak);
    }
}

void MemCopy(int argc, wchar_t *argv[])
{
    void *dst = NULL;
    void *src = NULL;
    bool dst_fromVar = false;
    bool src_fromVar = false;

    if (argv[2][0] == TYPE_INT) {
        dst = (void *)wtoi((wchar_t *)&argv[2][1]);
    } else if (argv[2][0] == TYPE_PTR) {
        dst_fromVar = true;
        dst = (void *)GetVar((wchar_t *)&argv[2][1]);
        if (argv[2][1] == TYPE_ASTR) {
            /*free(dst);
            wchar_t *tmp = GetVar((wchar_t *)&argv[2][2]);
            dst = WcharToChar(tmp);
            free(tmp);*/  //��δ�����bug,��Ϊdst�Ĵ�С����û�дﵽ8192,�����
            free(dst);
            dst = GetVar((wchar_t *)&argv[2][2]);
            char *tmp = WcharToChar((wchar_t *)dst);
            memcpy(dst, tmp, (strlen(tmp) + 1) * sizeof(char));
            free(tmp);
        }
    } else {
        fprintf(stderr, "ERROR:δ֪��ʶ�� %c", argv[2][0]);
        return;
    }

    if (argv[3][0] == TYPE_INT) {
        src = (void *)wtoi((wchar_t *)&argv[3][1]);
    } else if (argv[3][0] == TYPE_PTR) {
        src_fromVar = true;
        src = (void *)GetVar((wchar_t *)&argv[3][1]);
        if (argv[3][1] == TYPE_ASTR) {
            /*free(src);
            wchar_t *tmp = GetVar((wchar_t *)&argv[3][2]);
            src = WcharToChar(tmp);
            free(tmp);*/  //��δ�����bug,��Ϊsrc�Ĵ�С����û�дﵽ8192,�����
            free(src);
            src = GetVar((wchar_t *)&argv[3][2]);
            char *tmp = WcharToChar((wchar_t *)src);
            memcpy(src, tmp, (strlen(tmp) + 1) * sizeof(char));
            free(tmp);
        }
    } else {
        fprintf(stderr, "ERROR:δ֪��ʶ�� %c", argv[3][0]);
        return;
    }
    if (argc == 5) {
        memcpy(dst, src, wtoi(argv[4]));
    } else {
        memcpy(dst, (void *)((int)src + wtoi(argv[4])), wtoi(argv[5]));
    }


    if (dst_fromVar) {
        if (argv[2][1] == TYPE_ASTR) {
            char *tmpname = WcharToChar((wchar_t *)&argv[2][2]);
            SetEnvironmentVariableA(tmpname, (char *)dst);
            free(tmpname);
        } else {
            SetEnvW((wchar_t *)&argv[2][1], (wchar_t *)dst);
        }
        free(dst);
    }
    if (src_fromVar)
    free(src);
}

void APICallAndExec(int argc, wchar_t *argv[])
{
    HMODULE hLib = GetModuleHandleW(argv[2]);
    if (!hLib) {
        hLib = LoadLibraryW(argv[2]);
        if (!wcscmp(argv[2], L"0")) { //dll��Ϊ0�Ļ����ڴ���غ���
            //printf("s");
            hLib = LIB_FROM_MEM;
        }
    }

    int *hProc;
    if (hLib) {
        char *ProcName;
        short function_type = INT_FUNCTION;
        switch (argv[3][0]) {
        case TYPE_FLOAT:
            ProcName = WcharToChar((wchar_t *)&argv[3][1]);
            function_type = FLOAT_FUNCTION;
            break;
        case TYPE_DOUBLE:
            ProcName = WcharToChar((wchar_t *)&argv[3][1]);
            function_type = DOUBLE_FUNCTION;
            break;
        default:
            ProcName = WcharToChar(argv[3]);
            break;
        }

        char *tmp;

        int       ArgList[MAX_ARG_NUMBERS]; //���32������,û�н���Խ����(Ӧ�ò���Խ���...)
        void     *ArgList_VarVal[MAX_ARG_NUMBERS]  = {NULL};
        wchar_t  *ArgList_VarName[MAX_ARG_NUMBERS] = {NULL};
        void     *ArgNeedFree[MAX_ARG_NUMBERS]	   = {NULL};

        int i, j;
        int tofree_i  = 0;
        int arglistvar_i = 0;

        //�ж��Ǹ��ݺ��������� ����ֱ�ӽ�����ת��Ϊ��ַ
        hProc    = (int)hLib == 1 ? (int *)wtoi(argv[3]) : (int *)GetProcAddress(hLib, ProcName);
        //printf("proc:%d\n", hProc);
        if (hProc != NULL) {

            for (i = 4, j = 0; i < argc; ++i, ++j) {

                switch (argv[i][0]) {
                case TYPE_INT:
                    ArgList[j] = wtoi((wchar_t *)&argv[i][1]);
                    break;
                case TYPE_FLOAT:
                    { //in this case can i use float_arg
                        float float_arg = (float)wtof((wchar_t *)&argv[i][1]);
                        ArgList[j] = *(int *)&float_arg;
                    }
                    break;
                case TYPE_DOUBLE:
                    union {
                        double db;
                        int i[2];
                    } double_int;
                    double_int.db = wtof((wchar_t *)&argv[i][1]);
                    //printf("f:%f\n", double_int.db);
                    //printf("f:%d-%d\n", double_int.i[0], double_int.i[1]);
                    ArgList[j] = double_int.i[0];
                    ArgList[j + 1] = double_int.i[1];
                    ++j;
                    break;
                case TYPE_USTR:
                    ArgList[j] = (int)&argv[i][1];
                    break;
                case TYPE_ASTR:
                    ArgList[j]      = (int)WcharToChar(&argv[i][1]);
                    ArgNeedFree[tofree_i++] = (void *)ArgList[j];
                    break;
                case TYPE_PTR:
                    ArgList_VarName[arglistvar_i] = &argv[i][1]; //������ʶ��
                    ArgList_VarVal[arglistvar_i]  = GetVar(&ArgList_VarName[arglistvar_i][1]); //ȡ������,������ʶ��

                    switch (argv[i][1]) {
                    case TYPE_INT: //����4�ֽڵ��ڴ汣����ArgList[j]
                        ArgList[j]  = (int)malloc(sizeof(int)); //
                        *(int *)ArgList[j] = wtoi((wchar_t *)ArgList_VarVal[arglistvar_i]);
                        ArgList_VarVal[arglistvar_i]  = (void *)ArgList[j];
                        //ArgNeedFree[tofree_i++]    = (void *)ArgList[j]; //ArgList_VarVal���ͷ�һ�Σ����ͷŻ������
                        break;                   
                        
                    case TYPE_ASTR:
                        tmp = WcharToChar((wchar_t *)ArgList_VarVal[arglistvar_i]);
                        memcpy(ArgList_VarVal[arglistvar_i], tmp, (strlen(tmp) + 1) * sizeof(char));
                        free(tmp);
                        ArgList[j] = (int)ArgList_VarVal[arglistvar_i];
                        break;
                        
                    case TYPE_USTR:
                        ArgList[j] = (int)ArgList_VarVal[arglistvar_i];
                        break;
                        
                    default:
                        argv[i][0] = TYPE_USTR;
                        free(ArgList_VarVal[arglistvar_i]);
                        ArgList_VarName[arglistvar_i] = &argv[i][0];
                        ArgList_VarVal[arglistvar_i]  = GetVar(&ArgList_VarName[arglistvar_i][1]);
                        ArgList[j] = (int)ArgList_VarVal[arglistvar_i];
                        //fprintf(stderr, "ERROR:δ֪��ʶ�� %c%c", argv[i][0], argv[i][1]);
                        //ArgList[l] = malloc(MAX_LENGTH_OF_ENVVARIABLE * sizeof(wchar_t));
                        break;
                    }
                    ++arglistvar_i;
                    break;
                default:
                    fprintf(stderr, "ERROR:δ֪��ʶ�� %c", argv[i][0]);
                    //goto CLEAN_AND_EXIT; //�������ñ�ǩò�Ƶ�����Ī����BUG?? free(ProcName) ���ǻᱻִ��
                    break;
                }
            }

            // ���ڲ����Ǵ�������ѹջ��,���Եڶ�������Ϊ�����β��ַ
            // ����������Ϊ���鳤��
            CAPI_Ret *capi_ret;
            
            if (argv[1][0] == 'C' || argv[1][0] == 'c') {
                capi_ret = APIStdCall(hProc, &ArgList[j - 1], j, function_type);
                //SetVar(L"CAPI_Ret", j == 0 ? hProc() : APIStdCall(hProc, &ArgList[j - 1], j));
            } else {
                capi_ret = APICdecl(hProc, &ArgList[j - 1], j, function_type);
                //SetVar(L"CAPI_Ret", j == 0 ? hProc() : APICdecl(hProc, &ArgList[j - 1], j));
            }
            
            //���÷���ֵ
            SetVar(L"CAPI_Err", (int)GetLastError());
            
            switch (function_type) {
            case INT_FUNCTION:
                SetVar(L"CAPI_Ret", capi_ret->_int[0]);
                break;
            case FLOAT_FUNCTION:
            case DOUBLE_FUNCTION:
                SetVar(L"CAPI_Ret", capi_ret->_double);
                break;
            }

            //CLEAN_AND_EXIT:
            free(capi_ret);
            
            for (i = 0; i < arglistvar_i; ++i) {
                switch (ArgList_VarName[i][0]) {
                case TYPE_INT:
                    SetVar(&ArgList_VarName[i][1], *((int *)ArgList_VarVal[i]));
                    break;
                case TYPE_USTR:
                    SetEnvW(&ArgList_VarName[i][1], (wchar_t *)ArgList_VarVal[i]);
                    break;
                case TYPE_ASTR:
                    tmp = WcharToChar(&ArgList_VarName[i][1]);
                    SetEnvironmentVariableA(tmp, (char *)ArgList_VarVal[i]);
                    free(tmp);
                    break;
                }

                //free(ArgList_VarName[i]);
                free(ArgList_VarVal[i]);
            }
            for (i = 0; i < tofree_i; ++i) { //�ͷ�������ڴ�
                free(ArgNeedFree[i]);
            }

        } else {
            fprintf(stderr, "[ERROR]cannot load API %S\n", argv[3]);
        }
        free(ProcName);
    } else {
        fprintf(stderr, "[ERROR]cannot load DLL %S\n", argv[2]);
    }
}


//�ĳɺ���ò��Ч���½���
bool CAPI(wchar_t *CmdLine)
{
    int argc;
    wchar_t **argv;

    argv = CommandLineToArgvW(CmdLine, &argc);
    if (argc <= 1) {
        return false;
    }


    if (!wcsicmp(argv[0], L"API") && (!wcsicmp(argv[1], L"Call") || !wcsicmp(argv[1], L"Exec"))) {
        APICallAndExec(argc, argv);
    } else if (!wcsicmp(argv[0], L"Mem")) { //Mem
        if (!wcsicmp(argv[1], L"Alloc")) {
            int sz = wtoi(argv[2]);
            int lp = (int)LocalAlloc(LPTR, sz);
            memset((void *)lp, 0, sz);
            SetVar(L"CAPI_Ret", lp);
        } else if (!wcsicmp(argv[1], L"Free")) { //Mem Free
            LocalFree((void *)wtoi(argv[2]));
        } else if (!wcsicmp(argv[1], L"Put")) {  //Mem Put
            MemPut(argc, argv);
        } else if (!wcsicmp(argv[1], L"Print")) { //Mem Print
            MemPrint(argc, argv);
        } else if (!wcsicmp(argv[1], L"Copy")) { //Mem Copy
            MemCopy(argc, argv);
        }
    } else if (!wcsicmp(argv[0], L"Com")) {
        //com(argc, argv);
    } else if (!wcsicmp(argv[0], L"Var")) {
        if (!wcsicmp(argv[1], L"SetCall")) {
            if (!wcsicmp(argv[2], L"Enable")) {
                HookAPI(SetEnvironmentVariableW, SetCall_CAPI);
            } else if (!wcsicmp(argv[2], L"Disable")) {
                HookAPI(SetEnvironmentVariableW, bakSetEnv);
            }
        } else if (!wcsicmp(argv[1], L"GetCall")) {
            if (!wcsicmp(argv[2], L"Enable")) {
                HookAPI(GetEnvironmentVariableW, GetCall_CAPI);
            } else if (!wcsicmp(argv[2], L"Disable")) {
                HookAPI(GetEnvironmentVariableW, bakGetEnv);
            }
        }
    } else if (!wcsicmp(argv[0], L"CAPIDll")) {
        if (!wcsicmp(argv[1], L"/?")) {
            printf(
            "\nCAPIx.dll (ver 2.0.1)\n"
            "License:LGPL v3+\n"
            "Compiled By VC++ 6.0\n"
            "Code By aiwozhonghuaba\n\n"
            );
        } else if (!wcsicmp(argv[1], L"Ver")) {
            SetEnvironmentVariableA("CAPI_Ret", "2.0");
        }
    }
    LocalFree(argv);
    return true;
}


CAPI_Ret* APIStdCall(void *hProc, int *arr, int len, short type)
{
    //int _high;
    int _low;
    double _double ;
    __asm
    {
        mov ebx, dword ptr [arr]  ;//��arrָ��ĵ�ַ�������б��β��ַ������ebx
        mov ecx, dword ptr [len]  ;//��len��ֵ����ecx����Ϊѭ�����Ʊ���
        dec ecx                   ;//�ݼ�ecx

LOOP1: 

        mov eax, dword ptr [ebx]  ;//���������arr��ebxָ������ݣ������ݼ��ص�eax
        sub ebx, 4                ;//��ebx�����ݵݼ�4��ebxָ���ǰ��һλ��
        push eax                  ;//��eaxѹջ
        dec ecx                   ;//�ݼ�ecx

        jns LOOP1                 ;//���ecx��Ϊ��ֵ������ת��LOOP1:

        call dword ptr [hProc]    ;//����API
        fstp _double;
        mov _low, eax              ;//����ֵ����result
        //mov _high, edx             ;

        mov ebx, dword ptr [len]  ;//��len��ֵ����ebx
        SHL ebx, 2                ;//������λ�����ǿɱ�����Ĵ�С
        //add esp, ebx              ;//�ָ���ջָ�� //API use __stdcall  needn't to add esp
        xor eax, eax              ;//���eax
    }
    
    CAPI_Ret *ret = (CAPI_Ret *)malloc(sizeof(CAPI_Ret));;
    if (type == INT_FUNCTION) {
        ret->_int[0] = _low;
    } else {
        ret->_double = _double;
    }
    return ret;
}

CAPI_Ret* APICdecl(void *hProc, int *arr, int len, short type)
{
    //int _high;
    int _low;
    double _double ;
    __asm
    {
        mov ebx, dword ptr [arr]  ;//��arrָ��ĵ�ַ�������б��β��ַ������ebx
        mov ecx, dword ptr [len]  ;//��len��ֵ����ecx����Ϊѭ�����Ʊ���
        dec ecx                   ;//�ݼ�ecx

LOOP1: 

        mov eax, dword ptr [ebx]  ;//���������arr��ebxָ������ݣ������ݼ��ص�eax
        sub ebx, 4                ;//��ebx�����ݵݼ�4��ebxָ���ǰ��һλ��
        push eax                  ;//��eaxѹջ
        dec ecx                   ;//�ݼ�ecx

        jns LOOP1                 ;//���ecx��Ϊ��ֵ������ת��LOOP1:

        call dword ptr [hProc]    ;//����API
        fstp _double;
        mov _low, eax              ;//����ֵ����result
        //mov _high, edx             ;

        mov ebx, dword ptr [len]  ;//��len��ֵ����ebx
        SHL ebx, 2                ;//������λ�����ǿɱ�����Ĵ�С
        add esp, ebx              ;//�ָ���ջָ�� //API use __stdcall  needn't to add esp
        xor eax, eax              ;//���eax
    }
    
    CAPI_Ret *ret = (CAPI_Ret *)malloc(sizeof(CAPI_Ret));;
    if (type == INT_FUNCTION) {
        ret->_int[0] = _low;
    } else {
        ret->_double = _double;
    }
    return ret;
}

:start

set tmpfile=data\temp.tmp
set sleepexe=Tools\TSleep.exe
set ctrlhta=%~dp0tool\ctrl.hta
set t=tools\"gBatch"

color f0
mode con:lines=42 cols=125
Tools\TCurS /crv 0
setlocal enabledelayedexpansion
for /f "tokens=1,2,3 delims=;" %%a in (Data\Sam.oby) do set "A=%%a" & set "P=%%b" & set "usertile=%%c"

REM ����ѡ��
Goto Desktop
REM ����ѡ��

:StartBoot
title Color OS!(V1.00)

Tools\Timage Image/log_desktop.bmp 0 0 
tools\timage image/test.bmp 220 360
Goto StartBoot_M

:StartBoot_M
Tools\pmos /K -1:10000
set /a y'=!errorlevel!,x'=y'/10000,y'=y'%%10000
if !x'! geq 220 if !x'! lss 790 if !y'! geq 360 if !y'! lss 410 Goto StartBoot_M_Account
if !x'! geq 220 if !x'! lss 790 if !y'! geq 490 if !y'! lss 540 Goto StartBoot_M_Password
if !x'! geq 610 if !x'! lss 695 if !y'! geq 590 if !y'! lss 630 Goto StartBoot_M_Login
if !x'! geq 310 if !x'! lss 395 if !y'! geq 590 if !y'! lss 630 Goto :EOF
Goto StartBoot_M

:StartBoot_M_Account
Tools\TCurS /crv 1
Tools\TCurS /pos 42 24
set /p Account=
Tools\TCurS /crv 0
goto StartBoot_M

:StartBoot_M_Password
Tools\TCurS /crv 1
Tools\TCurS /pos 42 32
tools\pwd -n -password>pwd.oby
set /p Password=<pwd.oby
Tools\TCurS /crv 0
goto StartBoot_M

:StartBoot_M_Login
if "!Account!"=="%A%" if "!Password!"=="%P%" mshta vbscript:msgbox("��¼�ɹ�",64,"Color OS")(window.close)&echo %date%��%time%,Login on %username% >>Data\.log&del /q pwd.oby>nul 2>nul&Goto DeskTop
mshta vbscript:msgbox("�˺Ż��������",64,"Color OS")(window.close)
del /q pwd.oby>nul 2>nul
cls
rem %t% /f me 20
Goto StartBoot_M

:Desktop
(
 echo Image\Desktop.bmp 0 0
 echo Image\ToolBar.bmp 0 610
 )>image.dat&Tools\Timage /l image.dat
for /f "tokens=1,2 delims=:" %%a in ("%time%") do call:Print %%a��%%b 870 625
for /f "delims= " %%a in ("%date:/=�u%") do call:Print %%a 850 640
set printx=20
set printy=20
set clickx=1
set clicky=1
for /f "tokens=1,2 delims=." %%a in ('dir /b Launcher') do (
  set unknown=yes
  if "%%b"=="" (Tools\timage Image\Type\folder.bmp !printx! !printy! /TRANSPARENTBLT& call:Print %%a !printx!-18 !printy!+60 & set cx!clickx!y!clicky!=%%a & set unknown=no) else (for /f "delims=" %%c in (Data\type.oby) do if "%%b"=="%%c" Tools\timage Image\Type\%%c.bmp !printx! !printy! /TRANSPARENTBLT& call:Print %%a.%%b !printx!-18 !printy!+50 & set cx!clickx!y!clicky!=%%a.%%b & set unknown=no)
  if "!unknown!"=="yes" Tools\timage Image\Type\unknown.bmp !printx! !printy! /TRANSPARENTBLT& call:Print %%a.%%b !printx!-18 !printy!+60 & set cx!clickx!y!clicky!=%%a.%%b
  set /a printy+=80 & set /a clicky+=1
  if "!printy!"=="500" set /a printx+=80 & set "printy=20" & set /a clickx+=1 & set clicky=1
)
Tools\cmos 0 -1 1
set /a X=%errorlevel:~0,-3%
set /a Y=%errorlevel%-1000*%X%
if %X% geq 2 if %X% leq 9 if %Y% geq 2 if %Y% leq 4 call:runout 1 1
if %X% geq 2 if %X% leq 9 if %Y% geq 7 if %Y% leq 9 call:runout 1 2
if %X% geq 2 if %X% leq 9 if %Y% geq 12 if %Y% leq 14 call:runout 1 3
if %X% geq 2 if %X% leq 9 if %Y% geq 17 if %Y% leq 19 call:runout 1 4
if %X% geq 2 if %X% leq 9 if %Y% geq 22 if %Y% leq 24 call:runout 1 5
if %X% geq 2 if %X% leq 9 if %Y% geq 27 if %Y% leq 28 call:runout 1 6

if %X% geq 12 if %X% leq 19 if %Y% geq 2 if %Y% leq 4 call:runout 2 1
if %X% geq 12 if %X% leq 19 if %Y% geq 7 if %Y% leq 9 call:runout 2 2
if %X% geq 12 if %X% leq 19 if %Y% geq 12 if %Y% leq 14 call:runout 2 3
if %X% geq 12 if %X% leq 19 if %Y% geq 17 if %Y% leq 19 call:runout 2 4
if %X% geq 12 if %X% leq 19 if %Y% geq 22 if %Y% leq 24 call:runout 2 5
if %X% geq 12 if %X% leq 19 if %Y% geq 27 if %Y% leq 28 call:runout 2 6

if %X% geq 22 if %X% leq 29 if %Y% geq 2 if %Y% leq 4 call:runout 3 1
if %X% geq 22 if %X% leq 29 if %Y% geq 7 if %Y% leq 9 call:runout 3 2
if %X% geq 22 if %X% leq 29 if %Y% geq 12 if %Y% leq 14 call:runout 3 3
if %X% geq 22 if %X% leq 29 if %Y% geq 17 if %Y% leq 19 call:runout 3 4
if %X% geq 22 if %X% leq 29 if %Y% geq 22 if %Y% leq 24 call:runout 3 5
if %X% geq 22 if %X% leq 29 if %Y% geq 27 if %Y% leq 28 call:runout 3 6

if %X% geq 32 if %X% leq 39 if %Y% geq 2 if %Y% leq 4 call:runout 4 1
if %X% geq 32 if %X% leq 39 if %Y% geq 7 if %Y% leq 9 call:runout 4 2
if %X% geq 32 if %X% leq 39 if %Y% geq 12 if %Y% leq 14 call:runout 4 3
if %X% geq 32 if %X% leq 39 if %Y% geq 17 if %Y% leq 19 call:runout 4 4
if %X% geq 32 if %X% leq 29 if %Y% geq 22 if %Y% leq 24 call:runout 4 5
if %X% geq 32 if %X% leq 39 if %Y% geq 27 if %Y% leq 28 call:runout 4 6

if %X% geq 42 if %X% leq 49 if %Y% geq 2 if %Y% leq 4 call:runout 5 1
if %X% geq 42 if %X% leq 49 if %Y% geq 7 if %Y% leq 9 call:runout 5 2
if %X% geq 42 if %X% leq 49 if %Y% geq 12 if %Y% leq 14 call:runout 5 3
if %X% geq 42 if %X% leq 49 if %Y% geq 17 if %Y% leq 19 call:runout 5 4
if %X% geq 42 if %X% leq 49 if %Y% geq 22 if %Y% leq 24 call:runout 5 5
if %X% geq 42 if %X% leq 49 if %Y% geq 27 if %Y% leq 28 call:runout 5 6

if %X% geq 52 if %X% leq 54 if %Y% geq 2 if %Y% leq 4 call:runout 6 1
if %X% geq 52 if %X% leq 54 if %Y% geq 7 if %Y% leq 9 call:runout 6 2
if %X% geq 52 if %X% leq 54 if %Y% geq 12 if %Y% leq 14 call:runout 6 3
if %X% geq 52 if %X% leq 54 if %Y% geq 17 if %Y% leq 19 call:runout 6 4
if %X% geq 52 if %X% leq 59 if %Y% geq 22 if %Y% leq 24 call:runout 6 5
if %X% geq 52 if %X% leq 59 if %Y% geq 27 if %Y% leq 28 call:runout 6 6

if %X% geq 62 if %X% leq 69 if %Y% geq 2 if %Y% leq 4 call:runout 7 1
if %X% geq 62 if %X% leq 69 if %Y% geq 7 if %Y% leq 9 call:runout 7 2
if %X% geq 62 if %X% leq 69 if %Y% geq 12 if %Y% leq 14 call:runout 7 3
if %X% geq 62 if %X% leq 69 if %Y% geq 17 if %Y% leq 19 call:runout 7 4
if %X% geq 62 if %X% leq 69 if %Y% geq 22 if %Y% leq 24 call:runout 7 5
if %X% geq 62 if %X% leq 69 if %Y% geq 27 if %Y% leq 28 call:runout 7 6

if %X% geq 72 if %X% leq 74 if %Y% geq 2 if %Y% leq 4 call:runout 8 1
if %X% geq 72 if %X% leq 74 if %Y% geq 7 if %Y% leq 9 call:runout 8 2
if %X% geq 72 if %X% leq 74 if %Y% geq 12 if %Y% leq 14 call:runout 8 3
if %X% geq 72 if %X% leq 74 if %Y% geq 17 if %Y% leq 19 call:runout 8 4
if %X% geq 72 if %X% leq 79 if %Y% geq 22 if %Y% leq 24 call:runout 8 5
if %X% geq 72 if %X% leq 79 if %Y% geq 27 if %Y% leq 28 call:runout 8 6

if %X% geq 82 if %X% leq 84 if %Y% geq 2 if %Y% leq 4 call:runout 9 1
if %X% geq 82 if %X% leq 84 if %Y% geq 7 if %Y% leq 9 call:runout 9 2
if %X% geq 82 if %X% leq 84 if %Y% geq 12 if %Y% leq 14 call:runout 9 3
if %X% geq 82 if %X% leq 84 if %Y% geq 17 if %Y% leq 19 call:runout 9 4
if %X% geq 82 if %X% leq 89 if %Y% geq 22 if %Y% leq 24 call:runout 9 5
if %X% geq 82 if %X% leq 89 if %Y% geq 27 if %Y% leq 28 call:runout 9 6

if %X% geq 92 if %X% leq 94 if %Y% geq 2 if %Y% leq 4 call:runout 10 1
if %X% geq 92 if %X% leq 94 if %Y% geq 7 if %Y% leq 9 call:runout 10 2
if %X% geq 92 if %X% leq 94 if %Y% geq 12 if %Y% leq 14 call:runout 10 3
if %X% geq 92 if %X% leq 94 if %Y% geq 17 if %Y% leq 19 call:runout 10 4
if %X% geq 92 if %X% leq 99 if %Y% geq 22 if %Y% leq 24 call:runout 10 5
if %X% geq 92 if %X% leq 99 if %Y% geq 27 if %Y% leq 28 call:runout 10 6

if %X% geq 102 if %X% leq 104 if %Y% geq 2 if %Y% leq 4 call:runout 11 1
if %X% geq 102 if %X% leq 104 if %Y% geq 7 if %Y% leq 9 call:runout 11 2
if %X% geq 102 if %X% leq 104 if %Y% geq 12 if %Y% leq 14 call:runout 11 3
if %X% geq 102 if %X% leq 104 if %Y% geq 17 if %Y% leq 19 call:runout 11 4
if %X% geq 112 if %X% leq 119 if %Y% geq 22 if %Y% leq 24 call:runout 12 5
if %X% geq 112 if %X% leq 119 if %Y% geq 27 if %Y% leq 28 call:runout 12 6

if %X% geq 112 if %X% leq 114 if %Y% geq 2 if %Y% leq 4 call:runout 12 1
if %X% geq 112 if %X% leq 114 if %Y% geq 7 if %Y% leq 9 call:runout 12 2
if %X% geq 112 if %X% leq 114 if %Y% geq 12 if %Y% leq 14 call:runout 12 3
if %X% geq 112 if %X% leq 114 if %Y% geq 17 if %Y% leq 19 call:runout 12 4
if %X% geq 112 if %X% leq 119 if %Y% geq 22 if %Y% leq 24 call:runout 12 5
if %X% geq 112 if %X% leq 119 if %Y% geq 27 if %Y% leq 28 call:runout 12 6

if %X% geq 122 if %X% leq 124 if %Y% geq 2 if %Y% leq 4 call:runout 13 1
if %X% geq 122 if %X% leq 124 if %Y% geq 7 if %Y% leq 9 call:runout 13 2
if %X% geq 122 if %X% leq 124 if %Y% geq 12 if %Y% leq 14 call:runout 13 3
if %X% geq 122 if %X% leq 124 if %Y% geq 17 if %Y% leq 19 call:runout 13 4
if %X% geq 122 if %X% leq 129 if %Y% geq 22 if %Y% leq 24 call:runout 13 5
if %X% geq 122 if %X% leq 129 if %Y% geq 27 if %Y% leq 28 call:runout 13 6

if %X% geq 2 if %X% leq 7 if %Y% geq 38 if %Y% leq 41 call:startmenu
if %X% geq 14 if %X% leq 19 if %Y% geq 38 if %Y% leq 41 echo %date%��%time%,Open File Explorer On Desktop>>Data\.log&start App\Explorer\Explorer.hta
if %X% geq 20 if %X% leq 27 if %Y% geq 38 if %Y% leq 41 echo %date%��%time%,Open File Browser On Desktop>>Data\.log&start App\Browser\Browser.exe
if %X% geq 28 if %X% leq 36 if %Y% geq 38 if %Y% leq 41 echo %date%��%time%,Open File OSExplorer On Desktop>>Data\.log&Goto OSExplorer
if %X% geq 37 if %X% leq 43 if %Y% geq 38 if %Y% leq 41 echo %date%��%time%,Open File Musicx On Desktop>>Data\.log&start App\mcool\mcool.exe
if %X% geq 44 if %X% leq 50 if %Y% geq 38 if %Y% leq 41 echo %date%��%time%,Open File Game_PushMe On Desktop>>Data\.log&start App\PushMe\PushMe.bat
if %X% geq 53 if %X% leq 58 if %Y% geq 38 if %Y% leq 41 echo %date%��%time%,Open File GUIDE On Desktop>>Data\.log&start App\GUIDE\GUIDE.bat
if %X% geq 60 if %X% leq 65 if %Y% geq 38 if %Y% leq 41 echo %date%��%time%,Open File iBAT On Desktop>>Data\.log&start App\iBAT\iBAT.exe

Goto Desktop

:OSExplorer
Tools\timage image\OSExplorer.bmp 0 0
set printx=20
set printy=20
set clickx=1
set clicky=1
for /f "tokens=1 delims=" %%a in ('dir /b OSExplorer') do (
  set unknown=yes
  if "%%b"=="" (Tools\timage Image\Type\folder.bmp !printx! !printy! & call:Print %%a !printx!-18 !printy!+60 & set ex!clickx!y!clicky!=%%a & set unknown=no) else (for /f "delims=" %%c in (Data\type.oby) do if "%%b"=="%%c" Tools\timage Image\Type\OSExplorer.bmp !printx! !printy! & call:Print %%a !printx!-18 !printy!+50 & set ex!clickx!y!clicky!=%%a & set unknown=no)
  if "!unknown!"=="yes" Tools\timage Image\Type\OSExplorer.bmp !printx! !printy! & call:Print %%a !printx!-18 !printy!+60 & set ex!clickx!y!clicky!=%%a
  set /a printy+=80 & set /a clicky+=1
  if "!printy!"=="500" set /a printx+=80 & set "printy=20" & set /a clickx+=1 & set clicky=1
)
Tools\pmos /K -1:10000
set /a y'=!errorlevel!,x'=y'/10000,y'=y'%%10000
if !x'! geq 465 if !x'! lss 685 if !y'! geq 605 if !y'! lss 655 echo %date%��%time%,new folder ON Explorer>>Data\.log&set r=!random!&echo NewTxt >NewFolder%r%&move NewFolder%r% OSExplorer >nul 2>nul&md NewFolder%r%&echo NewTXT >NewFolder%r%\NewTxt.txt&Goto OSExplorer 
if !x'! geq 745 if !x'! lss 965 if !y'! geq 605 if !y'! lss 655 echo %date%��%time%,Back To Desktop From Explorer>>Data\.log&Goto Desktop
Tools\cmos 0 -1 1
set /a X=%errorlevel:~0,-3%
set /a Y=%errorlevel%-1000*%X%
if %X% geq 2 if %X% leq 9 if %Y% geq 2 if %Y% leq 4 call:runoutOS 1 1
if %X% geq 2 if %X% leq 9 if %Y% geq 7 if %Y% leq 9 call:runoutOS 1 2
if %X% geq 2 if %X% leq 9 if %Y% geq 12 if %Y% leq 14 call:runoutOS 1 3
if %X% geq 2 if %X% leq 9 if %Y% geq 17 if %Y% leq 19 call:runoutOS 1 4
if %X% geq 2 if %X% leq 9 if %Y% geq 22 if %Y% leq 24 call:runoutOS 1 5
if %X% geq 2 if %X% leq 9 if %Y% geq 27 if %Y% leq 28 call:runoutOS 1 6

if %X% geq 12 if %X% leq 19 if %Y% geq 2 if %Y% leq 4 call:runoutOS 2 1
if %X% geq 12 if %X% leq 19 if %Y% geq 7 if %Y% leq 9 call:runoutOS 2 2
if %X% geq 12 if %X% leq 19 if %Y% geq 12 if %Y% leq 14 call:runoutOS 2 3
if %X% geq 12 if %X% leq 19 if %Y% geq 17 if %Y% leq 19 call:runoutOS 2 4
if %X% geq 12 if %X% leq 19 if %Y% geq 22 if %Y% leq 24 call:runoutOS 2 5
if %X% geq 12 if %X% leq 19 if %Y% geq 27 if %Y% leq 28 call:runoutOS 2 6

if %X% geq 22 if %X% leq 29 if %Y% geq 2 if %Y% leq 4 call:runoutOS 3 1
if %X% geq 22 if %X% leq 29 if %Y% geq 7 if %Y% leq 9 call:runoutOS 3 2
if %X% geq 22 if %X% leq 29 if %Y% geq 12 if %Y% leq 14 call:runoutOS 3 3
if %X% geq 22 if %X% leq 29 if %Y% geq 17 if %Y% leq 19 call:runoutOS 3 4
if %X% geq 22 if %X% leq 29 if %Y% geq 22 if %Y% leq 24 call:runoutOS 3 5
if %X% geq 22 if %X% leq 29 if %Y% geq 27 if %Y% leq 28 call:runoutOS 3 6

if %X% geq 32 if %X% leq 39 if %Y% geq 2 if %Y% leq 4 call:runoutOS 4 1
if %X% geq 32 if %X% leq 39 if %Y% geq 7 if %Y% leq 9 call:runoutOS 4 2
if %X% geq 32 if %X% leq 39 if %Y% geq 12 if %Y% leq 14 call:runoutOS 4 3
if %X% geq 32 if %X% leq 39 if %Y% geq 17 if %Y% leq 19 call:runoutOS 4 4
if %X% geq 32 if %X% leq 29 if %Y% geq 22 if %Y% leq 24 call:runoutOS 4 5
if %X% geq 32 if %X% leq 39 if %Y% geq 27 if %Y% leq 28 call:runoutOS 4 6

if %X% geq 42 if %X% leq 49 if %Y% geq 2 if %Y% leq 4 call:runoutOS 5 1
if %X% geq 42 if %X% leq 49 if %Y% geq 7 if %Y% leq 9 call:runoutOS 5 2
if %X% geq 42 if %X% leq 49 if %Y% geq 12 if %Y% leq 14 call:runoutOS 5 3
if %X% geq 42 if %X% leq 49 if %Y% geq 17 if %Y% leq 19 call:runoutOS 5 4
if %X% geq 42 if %X% leq 49 if %Y% geq 22 if %Y% leq 24 call:runoutOS 5 5
if %X% geq 42 if %X% leq 49 if %Y% geq 27 if %Y% leq 28 call:runoutOS 5 6

if %X% geq 52 if %X% leq 54 if %Y% geq 2 if %Y% leq 4 call:runoutOS 6 1
if %X% geq 52 if %X% leq 54 if %Y% geq 7 if %Y% leq 9 call:runoutOS 6 2
if %X% geq 52 if %X% leq 54 if %Y% geq 12 if %Y% leq 14 call:runoutOS 6 3
if %X% geq 52 if %X% leq 54 if %Y% geq 17 if %Y% leq 19 call:runoutOS 6 4
if %X% geq 52 if %X% leq 59 if %Y% geq 22 if %Y% leq 24 call:runoutOS 6 5
if %X% geq 52 if %X% leq 59 if %Y% geq 27 if %Y% leq 28 call:runoutOS 6 6

if %X% geq 62 if %X% leq 69 if %Y% geq 2 if %Y% leq 4 call:runoutOS 7 1
if %X% geq 62 if %X% leq 69 if %Y% geq 7 if %Y% leq 9 call:runoutOS 7 2
if %X% geq 62 if %X% leq 69 if %Y% geq 12 if %Y% leq 14 call:runoutOS 7 3
if %X% geq 62 if %X% leq 69 if %Y% geq 17 if %Y% leq 19 call:runoutOS 7 4
if %X% geq 62 if %X% leq 69 if %Y% geq 22 if %Y% leq 24 call:runoutOS 7 5
if %X% geq 62 if %X% leq 69 if %Y% geq 27 if %Y% leq 28 call:runoutOS 7 6

if %X% geq 72 if %X% leq 74 if %Y% geq 2 if %Y% leq 4 call:runoutOS 8 1
if %X% geq 72 if %X% leq 74 if %Y% geq 7 if %Y% leq 9 call:runoutOS 8 2
if %X% geq 72 if %X% leq 74 if %Y% geq 12 if %Y% leq 14 call:runoutOS 8 3
if %X% geq 72 if %X% leq 74 if %Y% geq 17 if %Y% leq 19 call:runoutOS 8 4
if %X% geq 72 if %X% leq 79 if %Y% geq 22 if %Y% leq 24 call:runoutOS 8 5
if %X% geq 72 if %X% leq 79 if %Y% geq 27 if %Y% leq 28 call:runoutOS 8 6

if %X% geq 82 if %X% leq 84 if %Y% geq 2 if %Y% leq 4 call:runoutOS 9 1
if %X% geq 82 if %X% leq 84 if %Y% geq 7 if %Y% leq 9 call:runoutOS 9 2
if %X% geq 82 if %X% leq 84 if %Y% geq 12 if %Y% leq 14 call:runoutOS 9 3
if %X% geq 82 if %X% leq 84 if %Y% geq 17 if %Y% leq 19 call:runoutOS 9 4
if %X% geq 82 if %X% leq 89 if %Y% geq 22 if %Y% leq 24 call:runoutOS 9 5
if %X% geq 82 if %X% leq 89 if %Y% geq 27 if %Y% leq 28 call:runoutOS 9 6

if %X% geq 92 if %X% leq 94 if %Y% geq 2 if %Y% leq 4 call:runoutOS 10 1
if %X% geq 92 if %X% leq 94 if %Y% geq 7 if %Y% leq 9 call:runoutOS 10 2
if %X% geq 92 if %X% leq 94 if %Y% geq 12 if %Y% leq 14 call:runoutOS 10 3
if %X% geq 92 if %X% leq 94 if %Y% geq 17 if %Y% leq 19 call:runoutOS 10 4
if %X% geq 92 if %X% leq 99 if %Y% geq 22 if %Y% leq 24 call:runoutOS 10 5
if %X% geq 92 if %X% leq 99 if %Y% geq 27 if %Y% leq 28 call:runoutOS 10 6

if %X% geq 102 if %X% leq 104 if %Y% geq 2 if %Y% leq 4 call:runoutOS 11 1
if %X% geq 102 if %X% leq 104 if %Y% geq 7 if %Y% leq 9 call:runoutOS 11 2
if %X% geq 102 if %X% leq 104 if %Y% geq 12 if %Y% leq 14 call:runoutOS 11 3
if %X% geq 102 if %X% leq 104 if %Y% geq 17 if %Y% leq 19 call:runoutOS 11 4
if %X% geq 112 if %X% leq 119 if %Y% geq 22 if %Y% leq 24 call:runoutOS 12 5
if %X% geq 112 if %X% leq 119 if %Y% geq 27 if %Y% leq 28 call:runoutOS 12 6

if %X% geq 112 if %X% leq 114 if %Y% geq 2 if %Y% leq 4 call:runoutOS 12 1
if %X% geq 112 if %X% leq 114 if %Y% geq 7 if %Y% leq 9 call:runoutOS 12 2
if %X% geq 112 if %X% leq 114 if %Y% geq 12 if %Y% leq 14 call:runoutOS 12 3
if %X% geq 112 if %X% leq 114 if %Y% geq 17 if %Y% leq 19 call:runoutOS 12 4
if %X% geq 112 if %X% leq 119 if %Y% geq 22 if %Y% leq 24 call:runoutOS 12 5
if %X% geq 112 if %X% leq 119 if %Y% geq 27 if %Y% leq 28 call:runoutOS 12 6

if %X% geq 122 if %X% leq 124 if %Y% geq 2 if %Y% leq 4 call:runoutOS 13 1
if %X% geq 122 if %X% leq 124 if %Y% geq 7 if %Y% leq 9 call:runoutOS 13 2
if %X% geq 122 if %X% leq 124 if %Y% geq 12 if %Y% leq 14 call:runoutOS 13 3
if %X% geq 122 if %X% leq 124 if %Y% geq 17 if %Y% leq 19 call:runoutOS 13 4
if %X% geq 122 if %X% leq 129 if %Y% geq 22 if %Y% leq 24 call:runoutOS 13 5
if %X% geq 122 if %X% leq 129 if %Y% geq 27 if %Y% leq 28 call:runoutOS 13 6
Goto OSExplorer


:startmenu
Tools\timage image\start.bmp 0 250
Tools\timage image\Sign\usertile%usertile%.bmp 150 270
call:Print %a% 140 320
Tools\pmos /K -1:10000
set /a y'=!errorlevel!,x'=y'/10000,y'=y'%%10000
if !x'! geq 138 if !x'! lss 210 if !y'! geq 562 if !y'! lss 586 echo %date%��%time%,Exit OS On %username%>>Data\.log&exit
if !x'! geq 8 if !x'! lss 120 if !y'! geq 276 if !y'! lss 300 echo %date%��%time%,Run CMD On Desktop>>Data\.log&start cmd.exe
if !x'! geq 8 if !x'! lss 120 if !y'! geq 305 if !y'! lss 330 echo %date%��%time%,New A Txt On Desktop>>Data\.log&set r=!random!&echo NewTxt >Txt%r%.txt&move Txt%r%.txt Launcher >nul 2>nul
if !x'! geq 8 if !x'! lss 120 if !y'! geq 335 if !y'! lss 360 echo %date%��%time%,goto set On Desktop>>Data\.log&goto desktop_set1
goto:eof

:startexplorer
tools\timage /d
tools\timage image\OSExplorer_G.bmp 0 0
set printx=20
set printy=20
set clickx=1
set clicky=1
set pat=%1
for /f "tokens=1,2 delims=." %%a in ('dir /b %1') do (
  set unknown=yes
  if "%%b"=="" (Tools\timage Image\Type\folder.bmp !printx! !printy! /TRANSPARENTBLT& call:Print %%a !printx!-18 !printy!+60 & set !pat!x!clickx!y!clicky!=%%a & set unknown=no) else (for /f "delims=" %%c in (Data\type.oby) do if "%%b"=="%%c" Tools\timage Image\Type\%%c.bmp !printx! !printy! /TRANSPARENTBLT& call:Print %%a.%%b !printx!-18 !printy!+50 & set !pat!x!clickx!y!clicky!=%%a.%%b & set unknown=no)
  if "!unknown!"=="yes" Tools\timage Image\Type\unknown.bmp !printx! !printy! /TRANSPARENTBLT& call:Print %%a.%%b !printx!-18 !printy!+60 & set !pat!x!clickx!y!clicky!=%%a.%%b
  set /a printy+=80 & set /a clicky+=1
  if "!printy!"=="500" set /a printx+=80 & set "printy=20" & set /a clickx+=1 & set clicky=1
)
Tools\cmos 0 -1 1
set /a X=%errorlevel:~0,-3%
set /a Y=%errorlevel%-1000*%X%
Tools\pmos /K -1:10000
set /a y'=!errorlevel!,x'=y'/10000,y'=y'%%10000
if !x'! geq 465 if !x'! lss 685 if !y'! geq 605 if !y'! lss 655 echo %date%��%time%,new file ON Explorer>>Data\.log&set r=!random!&set r=!random!&echo NewTxt >Txt%r%.txt&move Txt%r%.txt !pat! >nul 2>nul&call:startexplorer !pat!
if !x'! geq 745 if !x'! lss 965 if !y'! geq 605 if !y'! lss 655 echo %date%��%time%,Back To Desktop From Explorer>>Data\.log&Goto OSExplorer
if %X% geq 2 if %X% leq 9 if %Y% geq 2 if %Y% leq 4 call:runoutG 1 1 !pat!
if %X% geq 2 if %X% leq 9 if %Y% geq 7 if %Y% leq 9 call:runoutG 1 2 !pat!
if %X% geq 2 if %X% leq 9 if %Y% geq 12 if %Y% leq 14 call:runoutG 1 3 !pat!
if %X% geq 2 if %X% leq 9 if %Y% geq 17 if %Y% leq 19 call:runoutG 1 4 !pat!
if %X% geq 2 if %X% leq 9 if %Y% geq 22 if %Y% leq 24 call:runoutG 1 5 !pat!
if %X% geq 2 if %X% leq 9 if %Y% geq 27 if %Y% leq 28 call:runoutG 1 6 !pat!

if %X% geq 12 if %X% leq 19 if %Y% geq 2 if %Y% leq 4 call:runoutG 2 1 !pat!
if %X% geq 12 if %X% leq 19 if %Y% geq 7 if %Y% leq 9 call:runoutG 2 2 !pat!
if %X% geq 12 if %X% leq 19 if %Y% geq 12 if %Y% leq 14 call:runoutG 2 3 !pat!
if %X% geq 12 if %X% leq 19 if %Y% geq 17 if %Y% leq 19 call:runoutG 2 4 !pat!
if %X% geq 12 if %X% leq 19 if %Y% geq 22 if %Y% leq 24 call:runoutG 2 5 !pat!
if %X% geq 12 if %X% leq 19 if %Y% geq 27 if %Y% leq 28 call:runoutG 2 6 !pat!

if %X% geq 22 if %X% leq 29 if %Y% geq 2 if %Y% leq 4 call:runoutG 3 1 !pat!
if %X% geq 22 if %X% leq 29 if %Y% geq 7 if %Y% leq 9 call:runoutG 3 2 !pat!
if %X% geq 22 if %X% leq 29 if %Y% geq 12 if %Y% leq 14 call:runoutG 3 3 !pat!
if %X% geq 22 if %X% leq 29 if %Y% geq 17 if %Y% leq 19 call:runoutG 3 4 !pat!
if %X% geq 22 if %X% leq 29 if %Y% geq 22 if %Y% leq 24 call:runoutG 3 5 !pat!
if %X% geq 22 if %X% leq 29 if %Y% geq 27 if %Y% leq 28 call:runoutG 3 6 !pat!

if %X% geq 32 if %X% leq 39 if %Y% geq 2 if %Y% leq 4 call:runoutG 4 1 !pat!
if %X% geq 32 if %X% leq 39 if %Y% geq 7 if %Y% leq 9 call:runoutG 4 2 !pat!
if %X% geq 32 if %X% leq 39 if %Y% geq 12 if %Y% leq 14 call:runoutG 4 3 !pat!
if %X% geq 32 if %X% leq 39 if %Y% geq 17 if %Y% leq 19 call:runoutG 4 4 !pat!
if %X% geq 32 if %X% leq 29 if %Y% geq 22 if %Y% leq 24 call:runoutG 4 5 !pat!
if %X% geq 32 if %X% leq 39 if %Y% geq 27 if %Y% leq 28 call:runoutG 4 6 !pat!

if %X% geq 42 if %X% leq 49 if %Y% geq 2 if %Y% leq 4 call:runoutG 5 1 !pat!
if %X% geq 42 if %X% leq 49 if %Y% geq 7 if %Y% leq 9 call:runoutG 5 2 !pat!
if %X% geq 42 if %X% leq 49 if %Y% geq 12 if %Y% leq 14 call:runoutG 5 3 !pat!
if %X% geq 42 if %X% leq 49 if %Y% geq 17 if %Y% leq 19 call:runoutG 5 4 !pat!
if %X% geq 42 if %X% leq 49 if %Y% geq 22 if %Y% leq 24 call:runoutG 5 5 !pat!
if %X% geq 42 if %X% leq 49 if %Y% geq 27 if %Y% leq 28 call:runoutG 5 6 !pat!

if %X% geq 52 if %X% leq 54 if %Y% geq 2 if %Y% leq 4 call:runoutG 6 1 !pat!
if %X% geq 52 if %X% leq 54 if %Y% geq 7 if %Y% leq 9 call:runoutG 6 2 !pat!
if %X% geq 52 if %X% leq 54 if %Y% geq 12 if %Y% leq 14 call:runoutG 6 3 !pat!
if %X% geq 52 if %X% leq 54 if %Y% geq 17 if %Y% leq 19 call:runoutG 6 4 !pat!
if %X% geq 52 if %X% leq 59 if %Y% geq 22 if %Y% leq 24 call:runoutG 6 5 !pat!
if %X% geq 52 if %X% leq 59 if %Y% geq 27 if %Y% leq 28 call:runoutG 6 6 !pat!

if %X% geq 62 if %X% leq 69 if %Y% geq 2 if %Y% leq 4 call:runoutG 7 1 !pat!
if %X% geq 62 if %X% leq 69 if %Y% geq 7 if %Y% leq 9 call:runoutG 7 2 !pat!
if %X% geq 62 if %X% leq 69 if %Y% geq 12 if %Y% leq 14 call:runoutG 7 3 !pat!
if %X% geq 62 if %X% leq 69 if %Y% geq 17 if %Y% leq 19 call:runoutG 7 4 !pat!
if %X% geq 62 if %X% leq 69 if %Y% geq 22 if %Y% leq 24 call:runoutG 7 5 !pat!
if %X% geq 62 if %X% leq 69 if %Y% geq 27 if %Y% leq 28 call:runoutG 7 6 !pat!

if %X% geq 72 if %X% leq 74 if %Y% geq 2 if %Y% leq 4 call:runoutG 8 1 !pat!
if %X% geq 72 if %X% leq 74 if %Y% geq 7 if %Y% leq 9 call:runoutG 8 2 !pat!
if %X% geq 72 if %X% leq 74 if %Y% geq 12 if %Y% leq 14 call:runoutG 8 3 !pat!
if %X% geq 72 if %X% leq 74 if %Y% geq 17 if %Y% leq 19 call:runoutG 8 4 !pat!
if %X% geq 72 if %X% leq 79 if %Y% geq 22 if %Y% leq 24 call:runoutG 8 5 !pat!
if %X% geq 72 if %X% leq 79 if %Y% geq 27 if %Y% leq 28 call:runoutG 8 6 !pat!

if %X% geq 82 if %X% leq 84 if %Y% geq 2 if %Y% leq 4 call:runoutG 9 1 !pat!
if %X% geq 82 if %X% leq 84 if %Y% geq 7 if %Y% leq 9 call:runoutG 9 2 !pat!
if %X% geq 82 if %X% leq 84 if %Y% geq 12 if %Y% leq 14 call:runoutG 9 3 !pat!
if %X% geq 82 if %X% leq 84 if %Y% geq 17 if %Y% leq 19 call:runoutG 9 4 !pat!
if %X% geq 82 if %X% leq 89 if %Y% geq 22 if %Y% leq 24 call:runoutG 9 5 !pat!
if %X% geq 82 if %X% leq 89 if %Y% geq 27 if %Y% leq 28 call:runoutG 9 6 !pat!

if %X% geq 92 if %X% leq 94 if %Y% geq 2 if %Y% leq 4 call:runoutG 10 1 !pat!
if %X% geq 92 if %X% leq 94 if %Y% geq 7 if %Y% leq 9 call:runoutG 10 2 !pat!
if %X% geq 92 if %X% leq 94 if %Y% geq 12 if %Y% leq 14 call:runoutG 10 3 !pat!
if %X% geq 92 if %X% leq 94 if %Y% geq 17 if %Y% leq 19 call:runoutG 10 4 !pat!
if %X% geq 92 if %X% leq 99 if %Y% geq 22 if %Y% leq 24 call:runoutG 10 5 !pat!
if %X% geq 92 if %X% leq 99 if %Y% geq 27 if %Y% leq 28 call:runoutG 10 6 !pat!

if %X% geq 102 if %X% leq 104 if %Y% geq 2 if %Y% leq 4 call:runoutG 11 1 !pat!
if %X% geq 102 if %X% leq 104 if %Y% geq 7 if %Y% leq 9 call:runoutG 11 2 !pat!
if %X% geq 102 if %X% leq 104 if %Y% geq 12 if %Y% leq 14 call:runoutG 11 3 !pat!
if %X% geq 102 if %X% leq 104 if %Y% geq 17 if %Y% leq 19 call:runoutG 11 4 !pat!
if %X% geq 112 if %X% leq 119 if %Y% geq 22 if %Y% leq 24 call:runoutG 12 5 !pat!
if %X% geq 112 if %X% leq 119 if %Y% geq 27 if %Y% leq 28 call:runoutG 12 6 !pat!

if %X% geq 112 if %X% leq 114 if %Y% geq 2 if %Y% leq 4 call:runoutG 12 1 !pat!
if %X% geq 112 if %X% leq 114 if %Y% geq 7 if %Y% leq 9 call:runoutG 12 2 !pat!
if %X% geq 112 if %X% leq 114 if %Y% geq 12 if %Y% leq 14 call:runoutG 12 3 !pat!
if %X% geq 112 if %X% leq 114 if %Y% geq 17 if %Y% leq 19 call:runoutG 12 4 !pat!
if %X% geq 112 if %X% leq 119 if %Y% geq 22 if %Y% leq 24 call:runoutG 12 5 !pat!
if %X% geq 112 if %X% leq 119 if %Y% geq 27 if %Y% leq 28 call:runoutG 12 6 !pat!

if %X% geq 122 if %X% leq 124 if %Y% geq 2 if %Y% leq 4 call:runoutG 13 1 !pat!
if %X% geq 122 if %X% leq 124 if %Y% geq 7 if %Y% leq 9 call:runoutG 13 2 !pat!
if %X% geq 122 if %X% leq 124 if %Y% geq 12 if %Y% leq 14 call:runoutG 13 3 !pat!
if %X% geq 122 if %X% leq 124 if %Y% geq 17 if %Y% leq 19 call:runoutG 13 4 !pat!
if %X% geq 122 if %X% leq 129 if %Y% geq 22 if %Y% leq 24 call:runoutG 13 5 !pat!
if %X% geq 122 if %X% leq 129 if %Y% geq 27 if %Y% leq 28 call:runoutG 13 6 !pat!
Goto startexplorer

:runout
if "!cx%1y%2!"=="" goto :eof
Tools\timage Image\clickmenu.bmp 250 150
Tools\cmos 0 -1 1
set /a X=%errorlevel:~0,-3%
set /a Y=%errorlevel%-1000*%X%
if %X% geq 36 if %X% leq 43 (
if %Y%==11 echo %date%��%time%,Open File !cx%1y%2! On Desktop>>Data\.log&start Launcher\!cx%1y%2!&goto :eof
if %Y%==12 echo %date%��%time%,Delete File !cx%1y%2! On Desktop>>Data\.log&del Launcher\!cx%1y%2!>nul&goto :eof
if %Y%==14 echo %date%��%time%,RenName File !cx%1y%2! On Desktop>>Data\.log&start Tools\ren.bat !cx%1y%2!&goto :eof
if %Y%==15 goto :eof
)
goto runout

:runoutOS
if "!ex%1y%2!"=="" goto :eof
Tools\timage Image\clickmenu.bmp 250 150
Tools\cmos 0 -1 1
set /a X=%errorlevel:~0,-3%
set /a Y=%errorlevel%-1000*%X%
if %X% geq 36 if %X% leq 43 (
if %Y%==11 echo %date%��%time%,Open File !ex%1y%2! On Desktop>>Data\.log&call:startexplorer !ex%1y%2!&goto :eof
if %Y%==12 echo %date%��%time%,Delete File !ex%1y%2! On Desktop>>Data\.log&del OSExplorer\!ex%1y%2!>nul&rd !ex%1y%2!&goto :eof
if %Y%==14 echo %date%��%time%,RenName File !ex%1y%2! On Desktop>>Data\.log&start Tools\rena.bat !ex%1y%2!&goto :eof
if %Y%==15 goto :eof
)
goto runoutOS

:runoutG
if "!%3x%1y%2!"=="" goto :eof
set obua=%3
echo !obua!\!%3x%1y%2!
Tools\timage Image\clickmenu.bmp 250 150
Tools\cmos 0 -1 1
set /a X=%errorlevel:~0,-3%
set /a Y=%errorlevel%-1000*%X%
if %X% geq 36 if %X% leq 43 (
if %Y%==11 echo %date%��%time%,Open File !%3x%1y%2! On Desktop>>Data\.log&start !obua!\!%3x%1y%2!&goto :eof
if %Y%==12 echo %date%��%time%,Delete File !%3x%1y%2! On Desktop>>Data\.log&del !obua!\!%3x%1y%2!>nul&goto :eof
if %Y%==14 echo %date%��%time%,RenName File !%3x%1y%2! On Desktop>>Data\.log&start Tools\renb.bat !%3x%1y%2! !obua!&goto :eof
if %Y%==15 goto :eof
)
goto runoutG

:desktop_set1
tools\timage image\set1.bmp 0 0
Tools\timage image\Sign\usertile%usertile%.bmp 750 400
call:Print %a% 750 450
Tools\pmos /K -1:10000
set /a y'=!errorlevel!,x'=y'/10000,y'=y'%%10000
if !x'! geq 880 if !x'! lss 980 if !y'! geq 20 if !y'! lss 50 goto desktop
if !x'! geq 0 if !x'! lss 325 if !y'! geq 125 if !y'! lss 192 goto desktop_set2
if !x'! geq 0 if !x'! lss 325 if !y'! geq 192 if !y'! lss 259 goto desktop_set3
if !x'! geq 0 if !x'! lss 325 if !y'! geq 259 if !y'! lss 326 goto desktop_set4
goto desktop_set1

:desktop_set2
tools\timage image\set2.bmp 0 0
Tools\pmos /K -1:10000
set /a y'=!errorlevel!,x'=y'/10000,y'=y'%%10000
if !x'! geq 880 if !x'! lss 980 if !y'! geq 20 if !y'! lss 50 goto desktop
if !x'! geq 325 if !x'! lss 1000 if !y'! geq 58 if !y'! lss 672 echo %date%��%time%,Watches .log On Desktop>>Data\.log&start Data\.log&mshta vbscript:msgbox("�Ѵ���־�ļ���",64,"Color OS")(window.close)
if !x'! geq 0 if !x'! lss 325 if !y'! geq 58 if !y'! lss 125 goto desktop_set1
if !x'! geq 0 if !x'! lss 325 if !y'! geq 192 if !y'! lss 259 goto desktop_set3
if !x'! geq 0 if !x'! lss 325 if !y'! geq 259 if !y'! lss 326 goto desktop_set4
goto desktop_set2

:desktop_set3
tools\timage image\set3.bmp 0 0
Tools\pmos /K -1:10000
set /a y'=!errorlevel!,x'=y'/10000,y'=y'%%10000
if !x'! geq 880 if !x'! lss 980 if !y'! geq 20 if !y'! lss 50 goto desktop
if !x'! geq 0 if !x'! lss 325 if !y'! geq 58 if !y'! lss 125 goto desktop_set1
if !x'! geq 0 if !x'! lss 325 if !y'! geq 125 if !y'! lss 192 goto desktop_set2
if !x'! geq 0 if !x'! lss 325 if !y'! geq 259 if !y'! lss 326 goto desktop_set4
goto desktop_set3

:desktop_set4
tools\timage image\set4.bmp 0 0
Tools\pmos /K -1:10000
set /a y'=!errorlevel!,x'=y'/10000,y'=y'%%10000
if !x'! geq 880 if !x'! lss 980 if !y'! geq 20 if !y'! lss 50 goto desktop
if !x'! geq 325 if !x'! lss 1000 if !y'! geq 58 if !y'! lss 672 echo %date%��%time%,Delete .log On Desktop>>Data\.log&del Data\.log&mshta vbscript:msgbox("��ɾ����־�ļ���",64,"Color OS")(window.close)
if !x'! geq 0 if !x'! lss 325 if !y'! geq 58 if !y'! lss 125 goto desktop_set1
if !x'! geq 0 if !x'! lss 325 if !y'! geq 125 if !y'! lss 192 goto desktop_set2
if !x'! geq 0 if !x'! lss 325 if !y'! geq 192 if !y'! lss 259 goto desktop_set3
goto desktop_set4

:Print
set char=%1
set /a charx=%2
set /a chary=%3
:charfor
if not "!char!"=="" (
Tools\timage Image\Fonts\!char:~0,1!.bmp !charx! !chary! /SRCAND
set char=!char:~1!
set /a charx+=8
goto:charfor
)