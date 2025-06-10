#Include ../ShinsOverlayClass.ahk

Esc:: ExitApp()

gw := 600, gh := 620

overlay := ShinsOverlayClass((A_ScreenWidth - gw) // 2, (A_ScreenHeight - gh) // 2, gw, gh, 1, 0, 0)

overlay.BeginDraw()
overlay.FillRectangle(0, 0, gw, gh, '0x232323')
overlay.DrawRectangle(1, 1, gw - 1, gh - 1, '0xff9b9b9b')

overlay.DrawText('Layout', 10, 10, 30, , , 'h40')
overlay.DrawText('ESC to exit', 0, 10, 30, , , 'h40 aRight w' gw - 10)
overlay.FillRectangle(10, y := 50, w := gw - 20, h := 150, '0x3f4f5c')
overlay.DrawText('Near', 10, y, , , , 'aNear aCenter w' w)
overlay.DrawText('Far', 10, y, , , , 'aFar aCenter w' w ' h' h)
overlay.DrawText('Left', 10, y, , , , 'aMid aLeft w' w ' h' h)
overlay.DrawText('Right', 10, y, , , , 'aMid aRight w' w ' h' h)
overlay.DrawText('Center/Mid', 10, y, , , , 'aMid aCenter w' w ' h' h)

overlay.DrawText('Style', 10, h + 50, 30, , , 'h40')
overlay.DrawText('normal:', 10, y := h + 100, 20, , ,), overlay.DrawText('abcdefghijklmnoqpr', 100, y, 20, , ,)
overlay.DrawText('bold:', 10, y += 30, 20, , ,), overlay.DrawText('abcdefghijklmnoqpr', 100, y, 20, , , 'b800'), overlay.DrawText('b800', 100, y, 20, , , 'aRight w' z := (gw - 10 - 100))
overlay.DrawText('outline:', 10, y += 30, 20, , ,), overlay.DrawText('abcdefghijklmnoqpr', 100, y, 20, , , 'olFF00AAEE'), overlay.DrawText('olFF00AAEE', 100, y, 20, , , 'aRight w' z := (gw - 10 - 100))
overlay.DrawText('shadow:', 10, y += 30, 20, , ,), overlay.DrawText('abcdefghijklmnoqpr', 100, y, 20, , , 'dsFF00AAEE dsx2 dsy2'), overlay.DrawText('dsFF00AAEE dsx2 dsy2', 100, y, 20, , , 'aRight w' z := (gw - 10 - 100))
overlay.DrawText('italic:', 10, y += 30, 20, , ,), overlay.DrawText('abcdefghijklmnoqpr', 100, y, 20, , , 'sItalic'), overlay.DrawText('sItalic', 100, y, 20, , , 'aRight w' z := (gw - 10 - 100))
overlay.DrawText('oblique:', 10, y += 30, 20, , ,), overlay.DrawText('abcdefghijklmnoqpr', 100, y, 20, , , 'sOblique'), overlay.DrawText('sOblique', 100, y, 20, , , 'aRight w' z := (gw - 10 - 100))

overlay.DrawLine(10, y += 30, gw - 10, y)
; textlayout
overlay.DrawText('Using DrawLayout below:', 10, y += 5, , '0xfff7c7c7', ,)
overlay.DrawText('underline:', 10, y += 30, 20, , ,)
  , overlay.DrawTextLayout('abcdefghijklmnoqpr', 100, y, 200, 20, 20, , , ShinsOverlayClass.TextLayout('').SetUnderline(1, 1))
overlay.DrawText('strike:', 10, y += 30, 20, , ,)
  , overlay.DrawTextLayout('abcdefghijklmnoqpr', 100, y, 200, 20, 20, , , ShinsOverlayClass.TextLayout('').SetStrikethrough(1, 1))
overlay.DrawText('mix1:', 10, y += 30, 20, , ,)
  , overlay.DrawTextLayout('abcdefghijklmnoqpr', 100, y, 200, 20, 20, , ,
    ShinsOverlayClass.TextLayout('')
    .SetSize(20, 1)
    .SetUnderline(1, 1)
    .SetStrikethrough(1, 1)
    .SetWeight(800, 1)
    .SetStyle(2, 1)
  )

overlay.DrawText('mix2:', 10, y += 30, 20, , ,)
  , overlay.DrawTextLayout('abcdefghijklmnoqpr', 100, y - 20, gw - 120, 10, 20, , ,
    ShinsOverlayClass.TextLayout('aRight')
    .SetSize(20, 1, 3)
    .SetUnderline(1, 4, 3)
    .SetStrikethrough(1, 7, 3)
    .SetWeight(800, 10, 3)
    .SetStyle(2, 13, 3)
    ; set all
    .SetSize(40, 16, 3)
    .SetUnderline(1, 16, 3)
    .SetStrikethrough(1, 16, 3)
    .SetWeight(800, 16, 3)
    .SetStyle(2, 16, 3)
  )
overlay.DrawText('Note: DrawLayout doesn`'t support shadow and outline', 10, y += 40, , '0xfff7c7c7')

overlay.EndDraw()