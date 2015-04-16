/*  $Id: $
/*
 * dbc_SQLite - SQLite database manager
 * Autocompletition routines
 *
 * Copyright 2014 Alexander S.Kresin <alex@kresin.ru>
 * www - http://www.kresin.ru
*/

#include "hbclass.ch"
#include "hwgui.ch"

Memvar _nAutoC

FUNCTION onEditKey( oEdit, nKey, nCtrl, nState, oDb )

   LOCAL nL, cTemp, oHili, oBrw

   IF nState == 0
      IF _nAutoC == 1 .AND. nKey == VK_TAB
         AutoDop( oEdit, oDb )
         RETURN 0
      ELSEIF _nAutoC == 2
         oHili := oEdit:oHili
         nL := oHili:nL
         cTemp := CleanDopText( oEdit )
         IF nKey == VK_TAB .OR. nKey == VK_RIGHT
            ListClose( oEdit )
            IF !Empty( cTemp )
               oEdit:InsText( { oHili:nStart,nL }, cTemp )
               RETURN 0
            ENDIF
         ELSEIF nKey == VK_DOWN
            IF Valtype( oEdit:cargo[2] ) == "O"
               oEdit:lSetFocus := .F.
               oEdit:cargo[1] := .T.
               oBrw := oEdit:cargo[2]:oBrw
               oBrw:bcolorSel := oBrw:htbColor := 0
               oBrw:tcolorSel := oBrw:httColor := 16777215
               oBrw:Refresh()
               hwg_SetFocus( oBrw:handle )
               RETURN 0
            ENDIF
         ELSEIF nCtrl <= 4 .AND. nKey >= 65 .AND. nKey <= 122
            ListClose( oEdit )
            oEdit:bChangePos := {|o| onEditChgPos( o, oDb ) }
         ENDIF
      ENDIF
   ENDIF

   RETURN -1

STATIC FUNCTION onEditChgPos( oEdit, oDb )

   oEdit:bChangePos := Nil
   AutoDop( oEdit, oDb )

   RETURN Nil

FUNCTION onEditLostF( oEdit )

   CleanDopText( oEdit )
   IF !oEdit:cargo[1]
      ListClose( oEdit )
   ENDIF
   oEdit:cargo[1] := .F.
   RETURN Nil

STATIC FUNCTION CleanDopText( oEdit )

   LOCAL i, cTemp, oHili := oEdit:oHili

   IF !Empty( oHili:nL )
      cTemp := Substr( oEdit:aText[oHili:nL], oHili:nStart, oHili:nLength )
      i := oEdit:nMaxUndo
      oEdit:nMaxUndo := 0
      oEdit:DelText( { oHili:nStart, oHili:nL }, ;
                     { oHili:nStart+oHili:nLength, oHili:nL }, .F. )
      oEdit:nMaxUndo := i
      oHili:nL := Nil
   ENDIF

   RETURN cTemp

STATIC FUNCTION AutoDop( oEdit, oDb )

   LOCAL nLine, nPos, cQ, cTemp, cCurr, i, arr, nLen, aRes := {}
   LOCAL aCmd := { "alter", "analyze", "attach", "begin transaction", ;
      "commit transaction", "create", "delete", "detach", "drop", ;
      "end transaction", "insert into", "pragma", "reindex", "replace into", ;
      "rollback transaction", "select", "update", "vacuum" }
   LOCAL aCreate := { "index", "table", "trigger", "view", "virtual table" }
   LOCAL aDrop := { "index", "table", "trigger", "view" }

   nLine := oEdit:aPointC[2]
   nPos  := oEdit:aPointC[1]

   cQ := oEdit:aText[nLine]
   FOR i := nLine-1 TO 1 STEP -1
      IF Right( cTemp := AllTrim( oEdit:aText[i] ) ) != ";"
         cQ := cTemp + cQ
         nPos += Len( cTemp )
      ENDIF
   NEXT

   IF !Empty( Substr(cQ,nPos,1) ) .OR. ( _nAutoC == 1 .AND. Empty( Substr(cQ,nPos-1,1) ) )
      RETURN 0
   ENDIF

   arr := hb_aTokens( Lower( Ltrim( Left( cQ, nPos-1 ) ) ), ' ', .T. )
   cCurr := ATail( arr )
   nLen := Len( cCurr )

   IF Len( arr ) == 1
      aRes := Auto_keyw( aCmd, cCurr )
   ELSEIF arr[1] == "select"
      IF arr[Len(arr)-1] == "from"
      ENDIF
   ELSEIF arr[1] == "insert"
      IF Len( arr ) == 3
         aRes := Auto_table( oDb,cCurr )
      ELSEIF Len( arr ) == 4
         IF cCurr = "v"
            Aadd( aRes, "values ( " )
         ENDIF
      ENDIF
   ELSEIF arr[1] == "delete"

   ELSEIF arr[1] == "create"
      IF Len( arr ) == 2
         aRes := Auto_keyw( aCreate, cCurr )
      ENDIF
   ELSEIF arr[1] == "drop"
      IF Len( arr ) == 2
         aRes := Auto_keyw( aDrop, cCurr )
      ELSEIF arr[2] == "table"
         IF Len( arr ) == 3
            aRes := Auto_table( oDb,cCurr )
            IF Empty( aRes ) .AND. "if" = cCurr
               Aadd( aRes, "if exists " )
            ENDIF
         ELSEIF Len( arr ) == 4
            IF arr[Len(arr)-1] == "if" .AND. "exists" = cCurr
               Aadd( aRes, "exists " )
            ENDIF
         ELSEIF ( Len( arr ) == 5 .AND. arr[3] == "if" )
            aRes := Auto_table( oDb,cCurr )
         ENDIF
      ENDIF
   ENDIF

   IF Empty( aRes )
      RETURN Iif( _nAutoC==1, 0, -1 )
   ELSEIF Len( aRes ) == 1
      nPos := oEdit:aPointC[1]
      IF _nAutoC == 1
         oEdit:InsText( { nPos-nLen,nLine }, Left( aRes[1], nLen ), .T. )
         oEdit:InsText( oEdit:aPointC, Substr( aRes[1], nLen+1 ) )
      ELSE
         oEdit:oHili:nL := oEdit:aPointC[2]
         oEdit:oHili:nStart := oEdit:aPointC[1]
         cTemp := Substr( aRes[1], nLen+1 )
         IF Right( cCurr,1 ) <= 'Z'
            cTemp := Upper( cTemp )
         ENDIF
         oEdit:oHili:nLength := Len( cTemp )
         i := oEdit:nMaxUndo
         oEdit:nMaxUndo := 0
         oEdit:InsText( oEdit:aPointC, cTemp,, .F. )
         oEdit:nMaxUndo := i
      ENDIF
   ELSE
      ListDop( oEdit, aRes )
   ENDIF
   
   RETURN 0

STATIC FUNCTION ListDop( oEdit, aRes )

   LOCAL oDlg, oBrw, nLeft, nTop, nWidth := 0, nHeight := 0, nStyle, nLen := 0
   LOCAL i, hDC, aSize
   LOCAL bEnter := {||

      ListClose( oEdit )
      hwg_Setfocus( oEdit:handle )
      Return Nil
   }
   LOCAL bKeyDown := {|o,key|
      IF key == VK_SPACE
         Eval( bEnter )
      ELSEIF key == VK_ESCAPE
         ListClose( oEdit )
         hwg_Setfocus( oEdit:handle )
      ELSEIF key == VK_UP
         IF o:nCurrent == 1
            o:bcolorSel := o:htbColor := o:bColor
            o:tcolorSel := o:httColor := 8421504
            o:Refresh()
            hwg_Setfocus( oEdit:handle )
            Return .F.
         ENDIF
      ENDIF
      Return .T.
   }

   hDC := hwg_Getdc( oEdit:handle )

   FOR i := 1 TO Len( aRes )
      nLen := Max( nLen, Len( aRes[i] ) )
      aSize := hwg_Gettextsize( hDC, aRes[i] )
      nWidth := Max( nWidth, aSize[1] )
      nHeight := Max( nHeight, aSize[2] )
   NEXT
   hwg_Releasedc( oEdit:handle, hDC )
   nHeight := ( nHeight + 4 ) * Len( aRes )
   nWidth += 20

   nLeft := oEdit:nLeft + hced_GetXCaretPos( oEdit:hEdit )
   nTop := oEdit:nTop + hced_GetYCaretPos( oEdit:hEdit ) + hced_GetCaretHeight( oEdit:hEdit ) + 4
   nStyle := WS_POPUP + WS_VISIBLE
   INIT DIALOG oDlg AT nLeft, nTop ;
      SIZE nWidth, nHeight STYLE nStyle

   @ 0, 0 BROWSE oBrw ARRAY SIZE nWidth, nHeight NO VSCROLL NOBORDER
   oBrw:aArray := aRes
   oBrw:AddColumn( HColumn():New( ,{ |value,o|o:aArray[o:nCurrent] },"C",nLen ) )
   oBrw:lDispHead := .F.
   oBrw:bEnter := bEnter
   oBrw:bKeyDown := bKeyDown
   oBrw:bcolorSel := oBrw:htbColor := oBrw:bColor := 12058623
   oBrw:tcolorSel := oBrw:httColor := 8421504
   oBrw:tcolor := 8421504

   ACTIVATE DIALOG oDlg NOMODAL

   oEdit:cargo[2] := oDlg
   hwg_Setfocus( oEdit:handle )

   RETURN 0

STATIC FUNCTION ListClose( oEdit )

   IF Valtype( oEdit:cargo[2] ) == "O"
      oEdit:cargo[2]:Close()
      oEdit:cargo[2] := Nil
   ENDIF

   RETURN Nil

STATIC FUNCTION Auto_keyw( arr, cCurr )

   LOCAL i := 1, aRes := {}

   DO WHILE ( i := Ascan( arr, cCurr, i ) ) != 0
      Aadd( aRes, arr[i]+' ' )
      i ++
   ENDDO

   RETURN aRes

STATIC FUNCTION Auto_table( oDb, cCurr )

   LOCAL i := 1, aRes := {}, s, cDbName

   IF Empty( oDb ) .OR. Empty( oDb:aTables )
      RETURN aRes
   ENDIF

   cDbName := Lower( CutPath(oDb:cDbName) ) 
   s := Iif( ( i := At( '.', cCurr ) ) != 0, Substr( cCurr, i+1 ), cCurr )

   DO WHILE ( i := Ascan( oDb:aTables, {|a|a[1]=s}, i ) ) != 0
      Aadd( aRes, cCurr + Substr( oDb:aTables[i,1],Len(s)+1 ) + ' ' )
      i ++
   ENDDO

   IF Empty( aRes ) .AND. !('.' $ cCurr) .AND. cDbName = Lower( s )
      Aadd( aRes, cDbName + '.' )
   ENDIF

   RETURN aRes

#define HILIGHT_AUTOC   5

CLASS HilightAC INHERIT Hilight

   DATA nL, nStart, nLength

   METHOD Set( oEdit )
   METHOD Do( nLine, lCheck )
ENDCLASS

METHOD Set( oEdit ) CLASS HilightAC
Local oHili := HilightAC():New()

   oHili:cCommands := ::cCommands
   oHili:cFuncs    := ::cFuncs
   oHili:cScomm    := ::cScomm
   oHili:cMcomm1   := ::cMcomm1
   oHili:cMcomm2   := ::cMcomm2
   oHili:oEdit     := oEdit

Return oHili

METHOD Do( oEdit, nLine, lCheck ) CLASS HilightAC
   Local cLine, cBack

   IF !Empty( ::nL ) .AND. ::nL == nLine
      cLine := oEdit:aText[nLine]
      cBack := Substr( cLine, ::nStart, ::nLength )
      oEdit:aText[nLine] := Left( cLine, ::nStart-1 ) + Space( ::nLength ) + Substr( cLine, ::nStart + ::nLength )
   ENDIF
   ::Super:Do( oEdit, nLine, lCheck )
   IF cBack != Nil
      ::AddItem( ::nStart, ::nStart+::nLength-1, HILIGHT_AUTOC )
      oEdit:aText[nLine] := Left( cLine, ::nStart-1 ) + cBack + Substr( cLine, ::nStart + ::nLength )
   ENDIF

   RETURN Nil
