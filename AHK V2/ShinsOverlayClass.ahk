;Direct2d overlay class by Spawnova (5/27/2022)
;https://github.com/Spawnova/ShinsOverlayClass
;
;I'm not a professional programmer, I do this for fun, if it doesn't work for you I can try and help
;but I can't promise I will be able to solve the issue
;
;Special thanks to teadrinker for helping me understand some 64bit param structures! -> https://www.autohotkey.com/boards/viewtopic.php?f=76&t=105420

#Requires AutoHotkey v2+

class ShinsOverlayClass {

	;x_orTitle					:		x pos of overlay OR title of window to attach to
	;y_orClient					:		y pos of overlay OR attach to client instead of window (default window)
	;width_orForeground			:		width of overlay OR overlay is only drawn when the attached window is in the foreground (default 1)
	;height						:		height of overlay
	;alwaysOnTop				:		If enabled, the window will always appear over other windows
	;vsync						:		If enabled vsync will cause the overlay to update no more than the monitors refresh rate, useful when looping without sleeps
	;clickThrough				:		If enabled, mouse clicks will pass through the window onto the window beneath
	;taskBarIcon				:		If enabled, the window will have a taskbar icon
	;guiID						:		name of the ahk gui id for the overlay window, if 0 defaults to "ShinsOverlayClass_TICKCOUNT"
	;
	;notes						:		if planning to attach to window these parameters can all be left blank
	
	__New(x_orTitle:=0,y_orClient:=1,width_orForeground:=1,height:=0,alwaysOnTop:=1,vsync:=0,clickThrough:=1,taskBarIcon:=0,guiID:=0) {
	
	
		;[input variables] you can change these to affect the way the script behaves
		
		this.interpolationMode := 0 ;0 = nearestNeighbor, 1 = linear ;affects DrawImage() scaling 
		this.data := Map()			;reserved name for general data storage
		this.HideOnStateChange := 1 ;hides or shows the overlay when attached windows state changes, change to 0 to turn this behaviour off
	
	
		;[output variables] you can read these to get extra info, DO NOT MODIFY THESE
		
		this.x := x_orTitle					;overlay x position OR title of window to attach to
		this.y := y_orClient				;overlay y position OR attach to client area
		this.width := width_orForeground	;overlay width OR attached overlay only drawn when window is in foreground
		this.height := height				;overlay height
		this.x2 := (IsNumber(x_orTitle) ? x_orTitle : 0) + width_orForeground
		this.y2 := y_orClient+height
		this.attachHWND := 0				;HWND of the attached window, 0 if not attached
		this.attachClient := 0				;1 if using client space, 0 otherwise
		this.attachForeground := 0			;1 if overlay is only drawn when the attached window is the active window; 0 otherwise
		
		;Generally with windows there are invisible borders that allow
		;the window to be resized, but it makes the window larger
		;these values should contain the window x, y offset and width, height for actual postion and size
		this.realX := 0
		this.realY := 0
		this.realWidth := 0
		this.realHeight := 0
		this.realX2 := 0
		this.realY2 := 0
	
	
	
	
	
	
		;#############################
		;	Setup internal stuff
		;#############################
		this.bits := (a_ptrsize == 8)
		this.imageCache := Map()
		this.fonts := Map()
		this.lastPos := 0
		this.offX := -(IsNumber(x_orTitle) ? x_orTitle : 0)
		this.offY := -y_orClient
		this.lastCol := 0
		this.drawing := 0
		this.guiID := (guiID = 0 ? "ShinsOverlayClass_" a_tickcount : guiID)
		this.owned := 0
		this.lastSize := 0
		this.notifyActive := 0
		this.alwaysontop := alwaysontop
		pOut := 0
		
		this._cacheImage := this.mcode("VVdWMfZTg+wMi0QkLA+vRCQoi1QkMMHgAoXAfmSLTCQki1wkIA+26gHIiUQkCGaQD7Z5A4PDBIPBBIn4D7bwD7ZB/g+vxpn3/YkEJA+2Qf0Pr8aZ9/2JRCQED7ZB/A+vxpn3/Q+2FCSIU/wPtlQkBIhT/YhD/on4iEP/OUwkCHWvg8QMifBbXl9dw5CQkJCQ|V1ZTRTHbRItUJEBFD6/BRo0MhQAAAABFhcl+YUGD6QFFD7bSSYnQQcHpAkqNdIoERQ+2WANBD7ZAAkmDwARIg8EEQQ+vw5lB9/qJx0EPtkD9QQ+vw5lB9/pBicFBD7ZA/ECIefxEiEn9QQ+vw0SIWf+ZQff6iEH+TDnGdbNEidhbXl/DkJCQkJCQkJCQkJCQ")
		
		this.LoadLib("d2d1","dwrite","dwmapi","gdiplus")
		gsi := buffer(24,0)
		NumPut("uint", 1, gsi, 0)
		token := 0
		DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", gsi, "Ptr*", 0)
		this.gdiplusToken := token
		
		this._guid("{06152247-6f50-465a-9245-118bfd3b6007}",&clsidFactory)
		this._guid("{b859ee5a-d838-4b5b-a2e8-1adc7d93db48}",&clsidwFactory)
		
		this.gui := Gui("-DPIScale -Caption +E0x80000" (clickthrough ? " +E0x20" : "") (alwaysontop ? " +Alwaysontop" : "") (!taskBarIcon ? " +toolwindow" : ""),this.guiID)
		
		this.hwnd := hwnd := this.gui.hwnd
		DllCall("ShowWindow","Uptr",this.hwnd,"uint",(clickThrough ? 8 : 1))

		this.OnEraseFunc := _SOC_ONERASE.bind(hwnd)
		OnMessage(0x14,this.OnEraseFunc)
		
		this.tBufferPtr := Buffer(4096,0)
		this.rect1Ptr :=  Buffer(64,0)
		this.rect2Ptr :=  Buffer(64,0)
		this.rtPtr :=  Buffer(64,0)
		this.hrtPtr :=  Buffer(64,0)
		this.matrixPtr :=  Buffer(64,0)
		this.colPtr :=  Buffer(64,0)
		this.clrPtr :=  Buffer(64,0)
		margins := Buffer(16,0)
		NumPut("int",-1,margins,0), NumPut("int",-1,margins,4), NumPut("int",-1,margins,8), NumPut("int",-1,margins,12)
		ext := DllCall("dwmapi\DwmExtendFrameIntoClientArea","Uptr",hwnd,"ptr",margins,"uint")
		if (ext != 0) {
			this.Err("Problem with DwmExtendFrameIntoClientArea","overlay will not function`n`nReloading the script usually fixes this`n`nError: " DllCall("GetLastError","uint") " / " ext)
			return
		}
		DllCall("SetLayeredWindowAttributes","Uptr",hwnd,"Uint",0,"char",255,"uint",2)
		if (DllCall("d2d1\D2D1CreateFactory","uint",1,"Ptr",clsidFactory,"uint*",0,"Ptr*",&pOut) != 0) {
			this.Err("Problem creating factory","overlay will not function`n`nError: " DllCall("GetLastError","uint"))
			return
		}
		this.factory := pOut
		NumPut("float",255,this.tBufferPtr,16)
		if (DllCall(this.vTable(this.factory,11),"ptr",this.factory,"ptr",this.tBufferPtr,"ptr",0,"uint",0,"ptr*",&pOut) != 0) {
			this.Err("Problem creating stroke","overlay will not function`n`nError: " DllCall("GetLastError","uint"))
			return
		}
		this.stroke := pOut
		NumPut("uint",2,this.tBufferPtr,0)
		NumPut("uint",2,this.tBufferPtr,4)
		NumPut("uint",2,this.tBufferPtr,12)
		NumPut("float",255,this.tBufferPtr,16)
		if (DllCall(this.vTable(this.factory,11),"ptr",this.factory,"ptr",this.tBufferPtr,"ptr",0,"uint",0,"ptr*",&pOut) != 0) {
			this.Err("Problem creating rounded stroke","overlay will not function`n`nError: " DllCall("GetLastError","uint"))
			return
		}
		this.strokeRounded := pOut
		NumPut("uint",1,this.rtPtr,8)
		NumPut("float",96,this.rtPtr,12)
		NumPut("float",96,this.rtPtr,16)
		NumPut("Uptr",hwnd,this.hrtPtr,0)
		NumPut("uint",width_orForeground,this.hrtPtr,a_ptrsize)
		NumPut("uint",height,this.hrtPtr,a_ptrsize+4)
		NumPut("uint",(vsync?0:2),this.hrtPtr,a_ptrsize+8)
		if (DllCall(this.vTable(this.factory,14),"Ptr",this.factory,"Ptr",this.rtPtr,"ptr",this.hrtPtr,"Ptr*",&pOut) != 0) {
			this.Err("Problem creating renderTarget","overlay will not function`n`nError: " DllCall("GetLastError","uint"))
			return
		}
		this.renderTarget := pOut
		NumPut("float",1,this.matrixPtr,0)
		this.SetIdentity(4)
		if (DllCall(this.vTable(this.renderTarget,8),"Ptr",this.renderTarget,"Ptr",this.colPtr,"Ptr",this.matrixPtr,"Ptr*",&pOut) != 0) {
			this.Err("Problem creating brush","overlay will not function`n`nError: " DllCall("GetLastError","uint"))
			return
		}
		this.brush := pOut
		DllCall(this.vTable(this.renderTarget,32),"Ptr",this.renderTarget,"Uint",1)
		if (DllCall("dwrite\DWriteCreateFactory","uint",0,"Ptr",clsidwFactory,"Ptr*",&pOut) != 0) {
			this.Err("Problem creating writeFactory","overlay will not function`n`nError: " DllCall("GetLastError","uint"))
			return
		}
		this.wFactory := pOut

		this.InitFuncs()
		
		if (x_orTitle != 0 and winexist(x_orTitle))
			this.AttachToWindow(x_orTitle,y_orClient,width_orForeground)
		 else
			this.SetPosition(x_orTitle,y_orClient)
		

		 this.Clear()
	}
	
	
	;####################################################################################################################################################################################################################################
	;AttachToWindow
	;
	;title				:				Title of the window (or other type of identifier such as 'ahk_exe notepad.exe' etc..
	;attachToClientArea	:				Whether or not to attach the overlay to the client area, window area is used otherwise
	;foreground			:				Whether or not to only draw the overlay if attached window is active in the foreground, otherwise always draws
	;setOwner			:				Sets the ownership of the overlay window to the target window
	;
	;return				;				Returns 1 if either attached window is active in the foreground or no window is attached; 0 otherwise
	;
	;Notes				;				Does not actually 'attach', but rather every BeginDraw() fuction will check to ensure it's 
	;									updated to the attached windows position/size
	;									Could use SetParent but it introduces other issues, I'll explore further later
	
	AttachToWindow(title,AttachToClientArea:=0,foreground:=1,setOwner:=0) {
		if (title = "") {
			this.Err("AttachToWindow: Error","Expected title string, but empty variable was supplied!")
			return 0
		}
		if (!this.attachHWND := winexist(title)) {
			this.Err("AttachToWindow: Error","Could not find window - " title)
			return 0
		}
		numput("Uptr",this.attachHwnd,this.tbufferptr,0)
		this.attachHWND := numget(this.tbufferptr,0,"Ptr")
		if (!DllCall("GetWindowRect","Uptr",this.attachHWND,"ptr",this.tBufferPtr)) {
			this.Err("AttachToWindow: Error","Problem getting window rect, is window minimized?`n`nError: " DllCall("GetLastError","uint"))
			return 0
		}
		x := NumGet(this.tBufferPtr,0,"int")
		y := NumGet(this.tBufferPtr,4,"int")
		w := NumGet(this.tBufferPtr,8,"int")-x
		h := NumGet(this.tBufferPtr,12,"int")-y
		this.attachClient := AttachToClientArea
		this.attachForeground := foreground
		this.AdjustWindow(&x,&y,&w,&h)
		
		newSize := Buffer(16,0)
		NumPut("uint",this.width := w,newSize,0)
		NumPut("uint",this.height := h,newSize,4)
		DllCall(this._NRSize,"Ptr",this.renderTarget,"ptr",newsize)
		this.SetPosition(x,y,this.width,this.height)
		if (setOwner) {
			this.alwaysontop := 0
			WinSetAlwaysOnTop(0, "ahk_id " this.hwnd)
			this.owned := 1
			dllcall("SetWindowLongPtr","Uptr",this.hwnd,"int",-8,"Uptr",this.attachHWND)
			this.SetPosition(this.x,this.y)
		} else {
			this.owned := 0
		}
	}
	
	
	;####################################################################################################################################################################################################################################
	;BeginDraw
	;
	;return				;				Returns 1 if either attached window is active in the foreground or no window is attached; 0 otherwise
	;
	;Notes				;				Must always call EndDraw to finish drawing and update the overlay
	
	BeginDraw() {
		local pOut := 0
		if (this.attachHWND) {
			if (!DllCall("GetWindowRect","Uptr",this.attachHWND,"ptr",this.tBufferPtr) or (this.attachForeground and DllCall("GetForegroundWindow","cdecl Ptr") != this.attachHWND)) {
				if (this.drawing) {
					this.Clear()
					this.drawing := 0
					if (this.HideOnStateChange)
						this.Display(0)
				}
				return 0
			} else if (!this.drawing) {
				if (this.HideOnStateChange)
					this.Display(1)
			}
			x := NumGet(this.tBufferPtr,0,"int")
			y := NumGet(this.tBufferPtr,4,"int")
			w := NumGet(this.tBufferPtr,8,"int")-x
			h := NumGet(this.tBufferPtr,12,"int")-y
			if ((w<<16)+h != this.lastSize) {
				this.AdjustWindow(&x,&y,&w,&h)
				newSize := Buffer(16,0)
				NumPut("uint",this.width := w,newSize,0)
				NumPut("uint",this.height := h,newSize,4)
				DllCall(this._NRSize,"Ptr",this.renderTarget,"ptr",newsize)
				this.SetPosition(x,y)
			} else if ((x<<16)+y != this.lastPos) {
				this.AdjustWindow(&x,&y,&w,&h)
				this.SetPosition(x,y)
			}
			if (!this.drawing and this.alwaysontop) {
				WinSetAlwaysOnTop(1,"ahk_id " this.hwnd)
			}
			
		} else {
			if (!DllCall("GetWindowRect","Uptr",this.hwnd,"ptr",this.tBufferPtr)) {
				if (this.drawing) {
					this.Clear()
					this.drawing := 0
				}
				return 0
			}
			x := NumGet(this.tBufferPtr,0,"int")
			y := NumGet(this.tBufferPtr,4,"int")
			w := NumGet(this.tBufferPtr,8,"int")-x
			h := NumGet(this.tBufferPtr,12,"int")-y
			if ((w<<16)+h != this.lastSize) {
				this.AdjustWindow(&x,&y,&w,&h)
				newSize := Buffer(16,0)
				NumPut("uint",this.width := w,newSize,0)
				NumPut("uint",this.height := h,newSize,4)
				DllCall(this._NRSize,"Ptr",this.renderTarget,"ptr",newsize)
				this.SetPosition(x,y)
			} else if ((x<<16)+y != this.lastPos) {
				this.AdjustWindow(&x,&y,&w,&h)
				this.SetPosition(x,y)
			}
		}

		DllCall(this._BeginDraw,"Ptr",this.renderTarget)
		DllCall(this._Clear,"Ptr",this.renderTarget,"Ptr",this.clrPtr)
		if (this.notifyActive) {
			;if (this.callbacks["active"])
				;this.callbacks["active"].call(this,1) ;not implemented yet
			this.notifyActive := 0
		}
		return this.drawing := 1
	}
	
	
	;####################################################################################################################################################################################################################################
	;EndDraw
	;
	;return				;				Void
	;
	;Notes				;				Must always call EndDraw to finish drawing and update the overlay
	
	EndDraw() {
		local pOut:=0
		if (this.drawing)
			DllCall(this._EndDraw,"Ptr",this.renderTarget,"Ptr*",&pOut,"Ptr*",&pOut)
	}
	
	
	;####################################################################################################################################################################################################################################
	;DrawImage
	;
	;dstX				:				X position to draw to
	;dstY				:				Y position to draw to
	;dstW				:				Width of image to draw to
	;dstH				:				Height of image to draw to
	;srcX				:				X position to draw from
	;srcY				:				Y position to draw from
	;srcW				:				Width of image to draw from
	;srcH				:				Height of image to draw from
	;alpha				:				Image transparency, float between 0 and 1
	;drawCentered		:				Draw the image centered on dstX/dstY, otherwise dstX/dstY will be the top left of the image
	;rotation			:				Image rotation in degrees (0-360)
	;rotationOffsetX	:				X offset to base rotations on (defaults to center x)
	;rotationOffsetY	:				Y offset to base rotations on (defaults to center y)
	;
	;return				;				Void
	
	DrawImage(image,dstX,dstY,dstW:=0,dstH:=0,srcX:=0,srcY:=0,srcW:=0,srcH:=0,alpha:=1,drawCentered:=0,rotation:=0,rotOffX:=0,rotOffY:=0) {
		i := (this.imageCache.Has(image) ? this.imageCache[image] : this.cacheImage(image))
		
		if (dstW <= 0)
			dstW := i["w"]
		if (dstH <= 0)
			dstH := i["h"]
		x := dstX-(drawCentered?dstW/2:0)
		y := dstY-(drawCentered?dstH/2:0)
		NumPut("float", x, this.rect1Ptr, 0)
		NumPut("float", y, this.rect1Ptr, 4)
		NumPut("float", x + dstW, this.rect1Ptr, 8)
		NumPut("float", y + dstH, this.rect1Ptr, 12)
		NumPut("float", srcX, this.rect2Ptr, 0)
		NumPut("float", srcY,this.rect2Ptr,4)
		NumPut("float", srcX + (srcW=0?i["w"]:srcW),this.rect2Ptr,8)
		NumPut("float", srcY + (srcH=0?i["h"]:srcH),this.rect2Ptr,12)
		
		if (rotation != 0) {
			if (this.bits) {
				bf := Buffer(64)
				if (rotOffX or rotOffY) {
					NumPut("float", dstX+rotOffX, bf, 0)
					NumPut("float", dstY+rotOffY,bf,4)
				} else {
					NumPut("float", dstX+(drawCentered?0:dstW/2), bf, 0)
					NumPut("float", dstY+(drawCentered?0:dstH/2), bf, 4)
				}
				DllCall("d2d1\D2D1MakeRotateMatrix","float",rotation,"double",NumGet(bf,0,"double"),"ptr",this.matrixPtr)
			} else {
				DllCall("d2d1\D2D1MakeRotateMatrix","float",rotation,"float",dstX+(drawCentered?0:dstW/2),"float",dstY+(drawCentered?0:dstH/2),"ptr",this.matrixPtr)
			}
			DllCall(this._RMatrix,"ptr",this.renderTarget,"ptr",this.matrixPtr)
			DllCall(this._DrawImage,"ptr",this.renderTarget,"ptr",i["p"],"ptr",this.rect1Ptr,"float",alpha,"uint",this.interpolationMode,"ptr",this.rect2Ptr)
			this.SetIdentity()
			DllCall(this._RMatrix,"ptr",this.renderTarget,"ptr",this.matrixPtr)
		} else {
			DllCall(this._DrawImage,"ptr",this.renderTarget,"ptr",i["p"],"ptr",this.rect1Ptr,"float",alpha,"uint",this.interpolationMode,"ptr",this.rect2Ptr)
		}
	}
	
	
	;####################################################################################################################################################################################################################################
	;DrawText
	;
	;text				:				The text to be drawn
	;x					:				X position
	;y					:				Y position
	;size				:				Size of font
	;color				:				Color of font
	;fontName			:				Font name (must be installed)
	;extraOptions		:				Additonal options which may contain any of the following seperated by spaces:
	;									Width .............	w[number]				: Example > w200			(Default: this.width)
	;									Height ............	h[number]				: Example > h200			(Default: this.height)
	;                 Weight ............ b[number]       : Example > b800      (Default: 400)
	;                 Style ............. s[Italic/Oblique]     : Example > sItalic     (Default: normal)
	;									Alignment ......... a[Left/Right/Center]	: Example > aCenter			(Default: Left)
	;                           ......... a[Near/Far/Mid]    : Example > aNear       (Default: Far)
	;                 WordWrapping ...... ww[number]        : Example > ww0           (Default: 0) (0 wrap, 1 nowrap, and more https://learn.microsoft.com/en-us/windows/win32/api/dwrite/ne-dwrite-dwrite_word_wrapping
	;									DropShadow ........	ds[hex color]			: Example > dsFF000000		(Default: DISABLED)
	;									DropShadowXOffset . dsx[number]				: Example > dsx2			(Default: 1)
	;									DropShadowYOffset . dsy[number]				: Example > dsy2			(Default: 1)
	;									Outline ........... ol[hex color]			: Example > olFF000000		(Default: DISABLED)
	;
	;return				;				Void
	
	DrawText(text,x,y,size:=18,color:=0xFFFFFFFF,fontName:="Arial",extraOptions:="") {
		local p,ds,dsx,dsy,ol
		p := this._CreateTextFormat(fontName, size, extraOptions)
		w := (RegExMatch(extraOptions,"w([\d\.]+)",&w) ? w[1] : this.width)
		h := (RegExMatch(extraOptions,"h([\d\.]+)",&h) ? h[1] : this.height)

		if (RegExMatch(extraOptions,"ds([a-fA-F\d]+)",&ds)) {
			dsx := (RegExMatch(extraOptions,"dsx([\d\.]+)",&dsx) ? dsx[1] : 1)
			dsy := (RegExMatch(extraOptions,"dsy([\d\.]+)",&dsy) ? dsy[1] : 1)
			this.DrawTextShadow(p,text,x+dsx,y+dsy,w,h,"0x" ds[1])
		} else if (RegExMatch(extraOptions,"ol([a-fA-F\d]+)",&ol)) {
			this.DrawTextOutline(p,text,x,y,w,h,"0x" ol[1])
		}

		this.SetBrushColor(color)
		bf := Buffer(64)
		NumPut("float", x, bf, 0)
		NumPut("float", y, bf, 4)
		NumPut("float", x+w, bf, 8)
		NumPut("float", y+h, bf, 12)
		
		DllCall(this._DrawText,"ptr",this.renderTarget,"wstr",text,"uint",strlen(text),"ptr",p,"ptr",bf,"ptr",this.brush,"uint",0,"uint",0)
	}
	
	; internal function
	_CreateTextFormat(fontName, size, options) {
		local p,s,cacheKey,b,ww
		b := (RegExMatch(options,"b([\d]+)",&b) ? b[1] : 400)
		s := (RegExMatch(options,"i)s(Italic|Oblique)\b", &s)) ? (s[1] = 'Italic' ? 2 : 1) : 0
		cacheKey := fontName size b s
		p := (this.fonts.Has(cacheKey) ? this.fonts[cacheKey] : this.CacheFont(fontName,size,b,s,cacheKey))
		
		DllCall(this.vTable(p,3),"ptr",p,"uint",(InStr(options,"aRight") ? 1 : InStr(options,"aCenter") ? 2 : 0))
		DllCall(this.vTable(p,4),"ptr",p,"uint",(InStr(options,"aFar") ? 1 : InStr(options,"aMid") ? 2 : 0))
		if RegExMatch(options,"ww([\d])",&ww)
		  DllCall(this.vTable(p,5),"ptr",p, 'uint', ww[1])  ; word wrapping
		return p
	}

  ;DrawTextLayout
	; https://learn.microsoft.com/en-us/windows/win32/api/d2d1/nf-d2d1-id2d1rendertarget-drawtextlayout
	;text          :  The text to be drawn
	;x             :  X position
	;y             :  Y position
	;w             :  Width
	;h             :  Height
	;size          :  Size of font
	;color         :  Color of font
	;fontName      :  Font name (must be installed)
	;extraOptions  :  Additonal options which may contain any of the following seperated by spaces:
	;                 Weight ............ b[number]       : Example > b800      (Default: 400)
	;                 Style ............. s[Italic/Oblique]     : Example > sItalic     (Default: normal)
	;                 Alignment H ....... a[Left/Right/Center]	: Example > aCenter			(Default: Left)
	;                           V ....... a[Near/Far/Center]    : Example > aNear       (Default: Far)
	;                 WordWrapping ...... ww[number]      : Example > ww0           (Default: 0) (0 wrap, 1 nowrap, and more https://learn.microsoft.com/en-us/windows/win32/api/dwrite/ne-dwrite-dwrite_word_wrapping
	;                 DropShadow ........	ds[hex color]	: Example > dsFF000000		(Default: DISABLED)
	;                 DropShadowXOffset . dsx[number]		: Example > dsx2			(Default: 1)
	;                 DropShadowYOffset . dsy[number]		: Example > dsy2			(Default: 1)
	;                 Outline ........... ol[hex color]	: Example > olFF000000		(Default: DISABLED)
	;
	;return   ;	      Void

	DrawTextLayout(text,x,y,w,h,size:=18,color:=0xFFFFFFFF,fontName:="Arial", layout:= unset) {
		extraOptions := IsSet(layout) ? layout.options : ''
		p := this._CreateTextFormat(fontName, size, extraOptions)
		this.SetBrushColor(color)

		local textLayout := 0

		; https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritefactory-createtextlayout
		if (DllCall(this.vTable(this.wFactory,18),"ptr",this.wFactory,"wstr",text,"uint",StrLen(text), "ptr", p,'float',w,'float', h,"Ptr*",&textLayout) != 0) {
			this.Err("Unable to create textlayout:" fontName)
			return 0
		}

		if IsSet(layout) { ; apply layout
		  ; https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nn-dwrite-idwritetextlayout
			local len := StrLen(text)
			for v in layout.format.weight {
				i := v[1]
				range := Buffer(16), NumPut('uint', v[2], range, 0), NumPut('uint', v[3] = -1 ? len : v[3], range, 4)
				DllCall(this.vTable(textLayout,27+5),'ptr',textLayout, 'uint', i, 'double',NumGet(range, 0, 'double'))
			}
			for v in layout.format.style {
				i := v[1]
				range := Buffer(16), NumPut('uint', v[2], range, 0), NumPut('uint', v[3] = -1 ? len : v[3], range, 4)
				DllCall(this.vTable(textLayout,27+6),'ptr',textLayout, 'uint', i , 'double',NumGet(range, 0, 'double'))
			}
			for v in layout.format.size {
				i := v[1]
				range := Buffer(16), NumPut('uint', v[2], range, 0), NumPut('uint', v[3] = -1 ? len : v[3], range, 4)   
				DllCall(this.vTable(textLayout,27+8),'ptr',textLayout, 'float', i, 'double',NumGet(range, 0, 'double'))
			}
			for v in layout.format.underline {
				i := v[1]
				range := Buffer(16), NumPut('uint', v[2], range, 0), NumPut('uint', v[3] = -1 ? len : v[3], range, 4)
				DllCall(this.vTable(textLayout,27+9),'ptr',textLayout, 'uint', i, 'double',NumGet(range, 0, 'double'))
			}
			for v in layout.format.strike {
				i := v[1]
				range := Buffer(16), NumPut('uint', v[2], range, 0), NumPut('uint', v[3] = -1 ? len : v[3], range, 4)
				DllCall(this.vTable(textLayout,27+10),'ptr',textLayout, 'uint', i, 'double',NumGet(range, 0, 'double'))
			}
		}

		; other getter functions
	  ; DllCall(this.vTable(textLayout,27+15), 'ptr', textLayout) ; get width
	  ; DllCall(this.vTable(textLayout,27+16), 'ptr', textLayout) ; get height
		; DllCall(this.vTable(textLayout,27+20), 'ptr', textLayout,'uint', 1, 'ptr*', &wei:=0, 'ptr*', 0) ; get weight
		; DllCall(this.vTable(textLayout,27+21), 'ptr', textLayout,'uint', 1, 'ptr*', &sty:=0, 'ptr*', 0) ; get style

		point := Buffer(8), NumPut('float', x, point, 0), NumPut('float', y, point, 4)
	  DllCall(this._DrawTextLayout,"ptr",this.renderTarget,'double', NumGet(point, 0, 'double'),"ptr", textLayout, 'ptr', this.brush)
	}
	
	
	;####################################################################################################################################################################################################################################
	;DrawEllipse
	;
	;x					:				X position
	;y					:				Y position
	;w					:				Width of ellipse
	;h					:				Height of ellipse
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;thickness			:				Thickness of the line
	;
	;return				;				Void
	
	DrawEllipse(x, y, w, h, color, thickness:=1) {
		this.SetBrushColor(color)
		bf := Buffer(64)
		NumPut("float", x, bf, 0)
		NumPut("float", y, bf, 4)
		NumPut("float", w, bf, 8)
		NumPut("float", h, bf, 12)
		DllCall(this._DrawEllipse,"Ptr",this.renderTarget,"Ptr",bf,"ptr",this.brush,"float",thickness,"ptr",this.stroke)
	}
	
	
	;####################################################################################################################################################################################################################################
	;FillEllipse
	;
	;x					:				X position
	;y					:				Y position
	;w					:				Width of ellipse
	;h					:				Height of ellipse
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;
	;return				;				Void
	
	FillEllipse(x, y, w, h, color) {
		this.SetBrushColor(color)
		bf := Buffer(64)
		NumPut("float", x, bf, 0)
		NumPut("float", y, bf, 4)
		NumPut("float", w, bf, 8)
		NumPut("float", h, bf, 12)
		DllCall(this._FillEllipse,"Ptr",this.renderTarget,"Ptr",bf,"ptr",this.brush)
	}
	
	
	;####################################################################################################################################################################################################################################
	;DrawCircle
	;
	;x					:				X position
	;y					:				Y position
	;radius				:				Radius of circle
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;thickness			:				Thickness of the line
	;
	;return				;				Void
	
	DrawCircle(x, y, radius, color, thickness:=1) {
		this.SetBrushColor(color)
		bf := Buffer(64)
		NumPut("float", x, bf, 0)
		NumPut("float", y, bf, 4)
		NumPut("float", radius, bf, 8)
		NumPut("float", radius, bf, 12)
		DllCall(this._DrawEllipse,"Ptr",this.renderTarget,"Ptr",bf,"ptr",this.brush,"float",thickness,"ptr",this.stroke)
	}
	
	
	;####################################################################################################################################################################################################################################
	;FillCircle
	;
	;x					:				X position
	;y					:				Y position
	;radius				:				Radius of circle
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;
	;return				;				Void
	
	FillCircle(x, y, radius, color) {
		this.SetBrushColor(color)
		bf := Buffer(64)
		NumPut("float", x, bf, 0)
		NumPut("float", y, bf, 4)
		NumPut("float", radius, bf, 8)
		NumPut("float", radius, bf, 12)
		DllCall(this._FillEllipse,"Ptr",this.renderTarget,"Ptr",bf,"ptr",this.brush)
	}
	
	
	;####################################################################################################################################################################################################################################
	;DrawRectangle
	;
	;x					:				X position
	;y					:				Y position
	;w					:				Width of rectangle
	;h					:				Height of rectangle
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;thickness			:				Thickness of the line
	;
	;return				;				Void
	
	DrawRectangle(x, y, w, h, color, thickness:=1) {
		this.SetBrushColor(color)
		bf := Buffer(64)
		NumPut("float", x, bf, 0)
		NumPut("float", y, bf, 4)
		NumPut("float", x+w, bf, 8)
		NumPut("float", y+h, bf, 12)
		DllCall(this._DrawRectangle,"Ptr",this.renderTarget,"Ptr",bf,"ptr",this.brush,"float",thickness,"ptr",this.stroke)
	}
	
	
	;####################################################################################################################################################################################################################################
	;FillRectangle
	;
	;x					:				X position
	;y					:				Y position
	;w					:				Width of rectangle
	;h					:				Height of rectangle
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;
	;return				;				Void
	
	FillRectangle(x, y, w, h, color) {
		this.SetBrushColor(color)
		bf := Buffer(64)
		NumPut("float", x, bf, 0)
		NumPut("float", y, bf, 4)
		NumPut("float", x+w, bf, 8)
		NumPut("float", y+h, bf, 12)
		DllCall(this._FillRectangle,"Ptr",this.renderTarget,"Ptr",bf,"ptr",this.brush)
	}
	
	
	;####################################################################################################################################################################################################################################
	;DrawRoundedRectangle
	;
	;x					:				X position
	;y					:				Y position
	;w					:				Width of rectangle
	;h					:				Height of rectangle
	;radiusX			:				The x-radius for the quarter ellipse that is drawn to replace every corner of the rectangle.
	;radiusY			:				The y-radius for the quarter ellipse that is drawn to replace every corner of the rectangle.
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;thickness			:				Thickness of the line
	;
	;return				;				Void
	
	DrawRoundedRectangle(x, y, w, h, radiusX, radiusY, color, thickness:=1) {
		this.SetBrushColor(color)
		bf := Buffer(64)
		NumPut("float", x, bf, 0)
		NumPut("float", y, bf, 4)
		NumPut("float", x+w, bf, 8)
		NumPut("float", y+h, bf, 12)
		NumPut("float", radiusX, bf, 16)
		NumPut("float", radiusY, bf, 20)
		DllCall(this._DrawRoundedRectangle,"Ptr",this.renderTarget,"Ptr",bf,"ptr",this.brush,"float",thickness,"ptr",this.stroke)
	}
	
	
	;####################################################################################################################################################################################################################################
	;FillRectangle
	;
	;x					:				X position
	;y					:				Y position
	;w					:				Width of rectangle
	;h					:				Height of rectangle
	;radiusX			:				The x-radius for the quarter ellipse that is drawn to replace every corner of the rectangle.
	;radiusY			:				The y-radius for the quarter ellipse that is drawn to replace every corner of the rectangle.
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;
	;return				;				Void
	
	FillRoundedRectangle(x, y, w, h, radiusX, radiusY, color) {
		this.SetBrushColor(color)
		bf := Buffer(64)
		NumPut("float", x, bf, 0)
		NumPut("float", y, bf, 4)
		NumPut("float", x+w, bf, 8)
		NumPut("float", y+h, bf, 12)
		NumPut("float", radiusX, bf, 16)
		NumPut("float", radiusY, bf, 20)
		DllCall(this._FillRoundedRectangle,"Ptr",this.renderTarget,"Ptr",bf,"ptr",this.brush)
	}
	
	
	;####################################################################################################################################################################################################################################
	;DrawLine
	;
	;x1					:				X position for line start
	;y1					:				Y position for line start
	;x2					:				X position for line end
	;y2					:				Y position for line end
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;thickness			:				Thickness of the line
	;
	;return				;				Void

	DrawLine(x1,y1,x2,y2,color:=0xFFFFFFFF,thickness:=1,rounded:=0) {
		this.SetBrushColor(color)
		if (this.bits) {
			bf := Buffer(64)
			NumPut("float", x1, bf, 0)  ;Special thanks to teadrinker for helping me
			NumPut("float", y1, bf, 4)  ;with these params!
			NumPut("float", x2, bf, 8)
			NumPut("float", y2, bf, 12)
			DllCall(this._DrawLine,"Ptr",this.renderTarget,"Double",NumGet(bf,0,"double"),"Double",NumGet(bf,8,"double"),"ptr",this.brush,"float",thickness,"ptr",(rounded?this.strokeRounded:this.stroke))
		} else {
			DllCall(this._DrawLine,"Ptr",this.renderTarget,"float",x1,"float",y1,"float",x2,"float",y2,"ptr",this.brush,"float",thickness,"ptr",(rounded?this.strokeRounded:this.stroke))
		}
		
	}
	
	
	;####################################################################################################################################################################################################################################
	;DrawLines
	;
	;lines				:				An array of 2d points, example: [[0,0],[5,0],[0,5]]
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;connect			:				If 1 then connect the start and end together
	;thickness			:				Thickness of the line
	;
	;return				;				1 on success; 0 otherwise

	DrawLines(points,color,connect:=0,thickness:=1,rounded:=0) {
		if (points.length < 2)
			return 0
		lx := sx := points[1][1]
		ly := sy := points[1][2]
		this.SetBrushColor(color)
		if (this.bits) {
			bf := Buffer(64)
			loop points.length-1 {
				NumPut("float", lx, bf, 0), NumPut("float", ly, bf, 4), NumPut("float", lx:=points[a_index+1][1], bf, 8), NumPut("float", ly:=points[a_index+1][2], bf, 12)
				DllCall(this._DrawLine,"Ptr",this.renderTarget,"Double",NumGet(bf,0,"double"),"Double",NumGet(bf,8,"double"),"ptr",this.brush,"float",thickness,"ptr",(rounded?this.strokeRounded:this.stroke))
			}
			if (connect) {
				NumPut("float", sx, bf, 0), NumPut("float", sy, bf, 4), NumPut("float", lx, bf, 8), NumPut("float", ly, bf, 12)
				DllCall(this._DrawLine,"Ptr",this.renderTarget,"Double",NumGet(bf,0,"double"),"Double",NumGet(bf,8,"double"),"ptr",this.brush,"float",thickness,"ptr",(rounded?this.strokeRounded:this.stroke))
			}
		} else {
			loop points.length-1 {
				x1 := lx
				y1 := ly
				x2 := lx := points[a_index+1][1]
				y2 := ly := points[a_index+1][2]
				DllCall(this._DrawLine,"Ptr",this.renderTarget,"float",x1,"float",y1,"float",x2,"float",y2,"ptr",this.brush,"float",thickness,"ptr",(rounded?this.strokeRounded:this.stroke))
			}
			if (connect)
				DllCall(this._DrawLine,"Ptr",this.renderTarget,"float",sx,"float",sy,"float",lx,"float",ly,"ptr",this.brush,"float",thickness,"ptr",(rounded?this.strokeRounded:this.stroke))
		}
		return 1
	}
	
	
	;####################################################################################################################################################################################################################################
	;DrawPolygon
	;
	;points				:				An array of 2d points, example: [[0,0],[5,0],[0,5]]
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;thickness			:				Thickness of the line
	;xOffset			:				X offset to draw the polygon array
	;yOffset			:				Y offset to draw the polygon array
	;
	;return				;				1 on success; 0 otherwise

	DrawPolygon(points,color,thickness:=1,rounded:=0,xOffset:=0,yOffset:=0) {
		if (points.length < 3)
			return 0
		pGeom := sink := 0
		if (DllCall(this.vTable(this.factory,10),"Ptr",this.factory,"Ptr*",&pGeom) = 0) {
			if (DllCall(this.vTable(pGeom,17),"Ptr",pGeom,"Ptr*",&sink) = 0) {
				this.SetBrushColor(color)
				if (this.bits) {
					bf := Buffer(64)
					NumPut("float", points[1][1]+xOffset, bf, 0)
					NumPut("float", points[1][2]+yOffset, bf, 4)
					DllCall(this.vTable(sink,5),"ptr",sink,"double",numget(bf,0,"double"),"uint",1)
					loop points.length-1
					{
						NumPut("float", points[a_index+1][1]+xOffset, bf, 0)
						NumPut("float", points[a_index+1][2]+yOffset, bf, 4)
						DllCall(this.vTable(sink,10),"ptr",sink,"double",numget(bf,0,"double"))
					}
					DllCall(this.vTable(sink,8),"ptr",sink,"uint",1)
					DllCall(this.vTable(sink,9),"ptr",sink)
				} else {
					DllCall(this.vTable(sink,5),"ptr",sink,"float",points[1][1]+xOffset,"float",points[1][2]+yOffset,"uint",1)
					loop points.length-1
						DllCall(this.vTable(sink,10),"ptr",sink,"float",points[a_index+1][1]+xOffset,"float",points[a_index+1][2]+yOffset)
					DllCall(this.vTable(sink,8),"ptr",sink,"uint",1)
					DllCall(this.vTable(sink,9),"ptr",sink)
				}
				
				if (DllCall(this.vTable(this.renderTarget,22),"Ptr",this.renderTarget,"Ptr",pGeom,"ptr",this.brush,"float",thickness,"ptr",(rounded?this.strokeRounded:this.stroke)) = 0) {
					DllCall(this.vTable(sink,2),"ptr",sink)
					DllCall(this.vTable(pGeom,2),"Ptr",pGeom)
					return 1
				}
				DllCall(this.vTable(sink,2),"ptr",sink)
				DllCall(this.vTable(pGeom,2),"Ptr",pGeom)
			}
		}
		
		
		return 0
	}
	
	
	;####################################################################################################################################################################################################################################
	;FillPolygon
	;
	;points				:				An array of 2d points, example: [[0,0],[5,0],[0,5]]
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;xOffset			:				X offset to draw the filled polygon array
	;yOffset			:				Y offset to draw the filled polygon array
	;
	;return				;				1 on success; 0 otherwise

	FillPolygon(points,color,xoffset:=0,yoffset:=0) {
		if (points.length < 3)
			return 0
		pGeom := sink := 0
		if (DllCall(this.vTable(this.factory,10),"Ptr",this.factory,"Ptr*",&pGeom) = 0) {
			if (DllCall(this.vTable(pGeom,17),"Ptr",pGeom,"Ptr*",&sink) = 0) {
				this.SetBrushColor(color)
				if (this.bits) {
					bf := Buffer(64)
					NumPut("float", points[1][1]+xoffset, bf, 0)
					NumPut("float", points[1][2]+yoffset, bf, 4)
					DllCall(this.vTable(sink,5),"ptr",sink,"double",numget(bf,0,"double"),"uint",0)
					loop points.length-1
					{
						NumPut("float", points[a_index+1][1]+xoffset, bf, 0)
						NumPut("float", points[a_index+1][2]+yoffset, bf, 4)
						DllCall(this.vTable(sink,10),"ptr",sink,"double",numget(bf,0,"double"))
					}
					DllCall(this.vTable(sink,8),"ptr",sink,"uint",1)
					DllCall(this.vTable(sink,9),"ptr",sink)
				} else {
					DllCall(this.vTable(sink,5),"ptr",sink,"float",points[1][1]+xoffset,"float",points[1][2]+yoffset,"uint",0)
					loop points.length-1
						DllCall(this.vTable(sink,10),"ptr",sink,"float",points[a_index+1][1]+xoffset,"float",points[a_index+1][2]+yoffset)
					DllCall(this.vTable(sink,8),"ptr",sink,"uint",1)
					DllCall(this.vTable(sink,9),"ptr",sink)
				}
				
				if (DllCall(this.vTable(this.renderTarget,23),"Ptr",this.renderTarget,"Ptr",pGeom,"ptr",this.brush,"ptr",0) = 0) {
					DllCall(this.vTable(sink,2),"ptr",sink)
					DllCall(this.vTable(pGeom,2),"Ptr",pGeom)
					return 1
				}
				DllCall(this.vTable(sink,2),"ptr",sink)
				DllCall(this.vTable(pGeom,2),"Ptr",pGeom)
				
			}
		}
		
		
		return 0
	}
	
	
	;####################################################################################################################################################################################################################################
	;SetPosition
	;
	;x					:				X position to move the window to (screen space)
	;y					:				Y position to move the window to (screen space)
	;w					:				New Width (only applies when not attached)
	;h					:				New Height (only applies when not attached)
	;
	;return				;				Void
	;
	;notes				:				Only used when not attached to a window
	
	SetPosition(x,y,w:=0,h:=0) {
		this.x := x
		this.y := y
		if (!this.attachHWND and w != 0 and h != 0) {
			newSize := Buffer(16,0)
			NumPut("uint",this.width := w,newSize,0)
			NumPut("uint",this.height := h,newSize,4)
			DllCall(this._NRSize,"Ptr",this.renderTarget,"ptr",newsize)
		}
		DllCall("MoveWindow","Uptr",this.hwnd,"int",x,"int",y,"int",this.width,"int",this.height,"char",1)
	}
	
	
	;####################################################################################################################################################################################################################################
	;GetImageDimensions
	;
	;image				:				Image file name
	;&w					:				Width of image
	;&h					:				Height of image
	;
	;return				;				Void
	
	GetImageDimensions(image, &w, &h) {
		local i
		i := (this.imageCache.Has(image) ? this.imageCache[image] : this.cacheImage(image))
		w := i["w"]
		h := i["h"]
	}
	
	
	;####################################################################################################################################################################################################################################
	;GetMousePos
	;
	;&x					:				X position of mouse to return
	;&y					:				Y position of mouse to return
	;realRegionOnly		:				Return 1 only if in the real region, which does not include the invisible borders, (client area does not have borders)
	;
	;return				;				Returns 1 if mouse within window/client region; 0 otherwise
	
	GetMousePos(&x, &y, realRegionOnly:=0) {
		DllCall("GetCursorPos","ptr",this.tBufferPtr)
		x := NumGet(this.tBufferPtr,0,"int")
		y := NumGet(this.tBufferPtr,4,"int")
		if (!realRegionOnly) {
			inside := (x >= this.x and y >= this.y and x <= this.x2 and y <= this.y2)
			x += this.offX
			y += this.offY
			return inside
		}
		x += this.offX
		y += this.offY
		return (x >= this.realX and y >= this.realY and x <= this.realX2 and y <= this.realY2)
		
	}
	
	
	;####################################################################################################################################################################################################################################
	;Clear
	;
	;notes						:			Clears the overlay, essentially the same as running BegindDraw followed by EndDraw
	
	Clear() {
		local pOut:=0
		DllCall(this._BeginDraw,"Ptr",this.renderTarget)
		DllCall(this._Clear,"Ptr",this.renderTarget,"Ptr",this.clrPtr)
		DllCall(this._EndDraw,"Ptr",this.renderTarget,"Ptr*",&pOut,"Ptr*",&pOut)
	}
	
	
	
	
	;0 = off
	;1 = on
	SetAntialias(state:=0) {
		DllCall(this.vTable(this.renderTarget,32),"Ptr",this.renderTarget,"Uint",!state)
	}
	
	
	
	DisableOnErase() {
		OnMessage(0x14,this.OnEraseFunc,0)
	}
	
	
	
	;########################################## 
	;  internal functions used by the class
	;########################################## 
	AdjustWindow(&x,&y,&w,&h) {
		this.lastPos := (x<<16)+y
		this.lastSize := (w<<16)+h
		DllCall("GetWindowInfo","Uptr",(this.attachHWND ? this.attachHWND : this.hwnd),"ptr",this.tBufferPtr)
		pp := (this.attachClient ? 20 : 4)
		x1 := NumGet(this.tBufferPtr,pp,"int")
		y1 := NumGet(this.tBufferPtr,pp+4,"int")
		x2 := NumGet(this.tBufferPtr,pp+8,"int")
		y2 := NumGet(this.tBufferPtr,pp+12,"int")
		this.width := w := x2-x1
		this.height := h := y2-y1
		this.x := x := x1
		this.y := y := y1
		this.x2 := x + w
		this.y2 := y + h
		hBorders := (this.attachClient ? 0 : NumGet(this.tBufferPtr,48,"int"))
		vBorders := (this.attachClient ? 0 : NumGet(this.tBufferPtr,52,"int"))
		this.realX := hBorders
		this.realY := 0
		this.realWidth := w - (hBorders*2)
		this.realHeight := h - vBorders
		this.realX2 := this.realX + this.realWidth
		this.realY2 := this.realY + this.realHeight
		this.offX := -x1 ;- hBorders
		this.offY := -y1
	}
	SetIdentity(o:=0) {
		NumPut("float", 1, this.matrixPtr, o+0)
		NumPut("float", 0, this.matrixPtr, o+4)
		NumPut("float", 0, this.matrixPtr, o+8)
		NumPut("float", 1, this.matrixPtr, o+12)
		NumPut("float", 0, this.matrixPtr, o+16)
		NumPut("float", 0, this.matrixPtr, o+20)
	}
	DrawTextShadow(p,text,x,y,w,h,color) {
		this.SetBrushColor(color)
		bf := Buffer(64)
		NumPut("float", x, bf, 0)
		NumPut("float", y, bf, 4)
		NumPut("float", x+w, bf, 8)
		NumPut("float", y+h, bf, 12)
		DllCall(this._DrawText,"ptr",this.renderTarget,"wstr",text,"uint",strlen(text),"ptr",p,"ptr",bf,"ptr",this.brush,"uint",0,"uint",0)
	}
	DrawTextOutline(p,text,x,y,w,h,color) {
		static o := [[1,0],[1,1],[0,1],[-1,1],[-1,0],[-1,-1],[0,-1],[1,-1]]
		this.SetBrushColor(color)
		bf := Buffer(64)
		for k,v in o
		{
			NumPut("float", x+v[1], bf, 0)
			NumPut("float", y+v[2], bf, 4)
			NumPut("float", x+w+v[1], bf, 8)
			NumPut("float", y+h+v[2], bf, 12)
			DllCall(this._DrawText,"ptr",this.renderTarget,"wstr",text,"uint",strlen(text),"ptr",p,"ptr",bf,"ptr",this.brush,"uint",0,"uint",0)
		}
	}
	Err(str*) {
		s := ""
		for k,v in str
			s .= (s = "" ? "" : "`n`n") v
		msgbox(s, "Problem!", 0x30 | 0x1000)
	}
	LoadLib(lib*) {
		for k,v in lib {
			if (!DllCall("GetModuleHandle", "str", v, "Ptr")) {
				DllCall("LoadLibrary", "Str", v) 
			}
		}
	}
	SetBrushColor(col) {
		if (col <= 0xFFFFFF)
			col += 0xFF000000
		if (col != this.lastCol) {
			NumPut("Float",((col & 0xFF0000)>>16)/255,this.colPtr,0)
			NumPut("Float",((col & 0xFF00)>>8)/255,this.colPtr,4)
			NumPut("Float",((col & 0xFF))/255,this.colPtr,8)
			NumPut("Float",(col > 0xFFFFFF ? ((col & 0xFF000000)>>24)/255 : 1),this.colPtr,12)
			DllCall(this._SetBrush,"Ptr",this.brush,"Ptr",this.colPtr)
			this.lastCol := col
			return 1
		}
		return 0
	}
	vTable(a,p) {
		v := NumGet(a+0,0,"ptr")
		return (v ? NumGet(v+0,p*a_ptrsize,"Ptr") : 0)
	}
	_guid(guidStr,&clsid) {
		clsid := buffer(16,0)
		DllCall("ole32\CLSIDFromString", "WStr", guidStr, "Ptr", clsid)
	}
	CacheImage(image) {
		if (this.imageCache.has(image))
			return 1
		if (image = "") {
			this.Err("Error, expected resource image path but empty variable was supplied!")
			return 0
		}
		if (!FileExist(image)) {
			this.Err("Error finding resource image","'" image "' does not exist!")
			return 0
		}
		w := h := bm := bitmap := 0
		DllCall("gdiplus\GdipCreateBitmapFromFile", "Str", image, "Ptr*", &bm)
		DllCall("gdiplus\GdipGetImageWidth", "Ptr", bm, "Uint*", &w)
		DllCall("gdiplus\GdipGetImageHeight", "Ptr", bm, "Uint*", &h)
		r := buffer(16,0)
		NumPut("uint", w, r, 8)
		NumPut("uint", h, r, 12)
		bmdata := buffer(32,0)
		ret := DllCall("Gdiplus\GdipBitmapLockBits", "Ptr", bm, "Ptr", r, "uint", 3, "int", 0x26200A, "Ptr", bmdata)
		scan := NumGet(bmdata, 16, "Ptr")
		p := DllCall("GlobalAlloc", "uint", 0x40, "ptr", 16+((w*h)*4), "ptr")
		DllCall(this._cacheImage,"Ptr",p,"Ptr",scan,"int",w,"int",h,"uchar",255,"int")
		DllCall("Gdiplus\GdipBitmapUnlockBits", "Ptr", bm, "Ptr", bmdata)
		DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
		props := buffer(64,0)
		NumPut("uint", 28, props, 0)
		NumPut("uint",1,props,4)
		if (this.bits) {
			bf := Buffer(64)
			NumPut("uint", w, bf, 0)
			NumPut("uint", h, bf, 4)
			if (v := DllCall(this.vTable(this.renderTarget,4),"ptr",this.renderTarget,"int64",NumGet(bf,0,"int64"),"ptr",p,"uint",4 * w,"ptr",props,"Ptr*",&bitmap) != 0) {
				this.Err("Problem creating D2D bitmap for image '" image "'")
				return 0
			}
		} else {
			if (v := DllCall(this.vTable(this.renderTarget,4),"ptr",this.renderTarget,"uint",w,"uint",h,"ptr",p,"uint",4 * w,"ptr",props,"Ptr*",&bitmap) != 0) {
				this.Err("Problem creating D2D bitmap for image '" image "'")
				return 0
			}
		}
		return this.imageCache[image] := Map("p",bitmap, "w",w, "h",h)
	}

	class TextLayout {

		__New(textFormatOptions) {
			this.options := textFormatOptions
			this.format := {
				underline: [],
				strike: [],
				weight: [],
				style: [],
				size: []
			}
		}

		SetUnderline(enable, x := 1, n := -1) => (this.format.underline.Push([enable, x - 1, n]), this)
		SetStrikethrough(enable, x := 1, n := -1) => (this.format.strike.Push([enable, x - 1, n]), this)
		; DWRITE_FONT_STYLE_NORMAL = 0
		; DWRITE_FONT_STYLE_OBLIQUE = 1
		; DWRITE_FONT_STYLE_ITALIC = 2
		SetStyle(style, x := 1, n := -1) => (this.format.style.Push([style, x - 1, n]), this)
		; DWRITE_FONT_WEIGHT_THIN = 100
		; DWRITE_FONT_WEIGHT_EXTRA_LIGHT = 200
		; DWRITE_FONT_WEIGHT_ULTRA_LIGHT = 200
		; DWRITE_FONT_WEIGHT_LIGHT = 300
		; DWRITE_FONT_WEIGHT_SEMI_LIGHT = 350
		; DWRITE_FONT_WEIGHT_NORMAL = 400
		; DWRITE_FONT_WEIGHT_REGULAR = 400
		; DWRITE_FONT_WEIGHT_MEDIUM = 500
		; DWRITE_FONT_WEIGHT_DEMI_BOLD = 600
		; DWRITE_FONT_WEIGHT_SEMI_BOLD = 600
		; DWRITE_FONT_WEIGHT_BOLD = 700
		; DWRITE_FONT_WEIGHT_EXTRA_BOLD = 800
		; DWRITE_FONT_WEIGHT_ULTRA_BOLD = 800
		; DWRITE_FONT_WEIGHT_BLACK = 900
		; DWRITE_FONT_WEIGHT_HEAVY = 900
		; DWRITE_FONT_WEIGHT_EXTRA_BLACK = 950
		; DWRITE_FONT_WEIGHT_ULTRA_BLACK = 950
		SetWeight(weight, x := 1, n := -1) => (this.format.weight.Push([weight, x - 1, n]), this)
		SetSize(size, x := 1, n := -1) => (this.format.size.Push([size, x - 1, n]), this)
	}
	
	CacheFont(name,size,weight,style,cacheKey) {
		local textFormat := 0
		; https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritefactory-createtextformat
		if (DllCall(this.vTable(this.wFactory,15),"ptr",this.wFactory,"wstr",name,"ptr",0,"uint",weight,"uint",style,"uint",5,"float",size,"wstr","en-us","Ptr*",&textFormat) != 0) {
			this.Err("Unable to create font: " name " (size: " size ")","Try a different font or check to see if " name " is a valid font!")
			return 0
		}
		return this.fonts[cacheKey] := textFormat
	}
	__Delete() {
		DllCall("gdiplus\GdiplusShutdown", "Ptr*", this.gdiplusToken)
		DllCall(this.vTable(this.factory,2),"ptr",this.factory)
		DllCall(this.vTable(this.stroke,2),"ptr",this.stroke)
		DllCall(this.vTable(this.strokeRounded,2),"ptr",this.strokeRounded)
		DllCall(this.vTable(this.renderTarget,2),"ptr",this.renderTarget)
		DllCall(this.vTable(this.brush,2),"ptr",this.brush)
		DllCall(this.vTable(this.wfactory,2),"ptr",this.wfactory)
		DllCall("GlobalFree", "ptr", this._cacheImage)
		for k,v in this.fonts {
			if (v and this.vTable(v,2)) {
				DllCall(this.vTable(v,2),"ptr",v)
			}
		}
		for k,v in this.imageCache {
			if (v["p"] and this.vTable(v["p"],2)) {
				DllCall(this.vTable(v["p"],2),"ptr",v["p"])
			}
		}
		this.gui.destroy()
		OnMessage(0x14,this.OnEraseFunc,0)
		this.OnEraseFunc := ""
	}
	InitFuncs() {
		this._DrawText := this.vTable(this.renderTarget,27)
		this._DrawTextLayout := this.vTable(this.renderTarget,28)
		this._BeginDraw := this.vTable(this.renderTarget,48)
		this._Clear := this.vTable(this.renderTarget,47)
		this._DrawImage := this.vTable(this.renderTarget,26)
		this._EndDraw := this.vTable(this.renderTarget,49)
		this._RMatrix := this.vTable(this.renderTarget,30)
		this._DrawEllipse := this.vTable(this.renderTarget,20)
		this._FillEllipse := this.vTable(this.renderTarget,21)
		this._DrawRectangle := this.vTable(this.renderTarget,16)
		this._FillRectangle := this.vTable(this.renderTarget,17)
		this._DrawRoundedRectangle := this.vTable(this.renderTarget,18)
		this._FillRoundedRectangle := this.vTable(this.renderTarget,19)
		this._DrawLine := this.vTable(this.renderTarget,15)
		this._NRSize := this.vTable(this.renderTarget,58)
		this._SetBrush := this.vTable(this.brush,8)
	}
	Mcode(str) {
		local pp := 0, op := 0
		s := strsplit(str,"|")
		if (s.length != 2)
			return
		if (!DllCall("crypt32\CryptStringToBinary", "str", s[this.bits+1], "uint", 0, "uint", 1, "ptr", 0, "uint*", &pp, "ptr", 0, "ptr", 0))
			return
		p := DllCall("GlobalAlloc", "uint", 0, "ptr", pp, "ptr")
		if (this.bits)
			DllCall("VirtualProtect", "ptr", p, "ptr", pp, "uint", 0x40, "uint*", &op)
		if (DllCall("crypt32\CryptStringToBinary", "str", s[this.bits+1], "uint", 0, "uint", 1, "ptr", p, "uint*", &pp, "ptr", 0, "ptr", 0))
			return p
		DllCall("GlobalFree", "ptr", p)
	}
	Display(state) {
		if (!state) {
			DllCall("User32.dll\ShowWindow","Ptr",this.hwnd,"Int",0)
		} else {
			DllCall("User32.dll\ShowWindow","Ptr",this.hwnd,"Int",4)
		}
		this.notifyActive := 1
	}
}
_SOC_ONERASE(oHwnd, wParam, lParam, msg, hwnd) {
	if (oHwnd = hwnd)
		return 0
}
