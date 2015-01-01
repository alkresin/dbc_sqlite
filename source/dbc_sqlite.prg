/*  $Id: $
 *
 * dbc_SQLite - SQLite database manager
 * Copyright 2014 Alexander Kresin <alex@kresin.ru>
 * www - http://www.kresin.ru
 */

#include "hbclass.ch"
#include "hbsqlit3.ch"
#include "hwgui.ch"
#include "hxml.ch"

#define APP_VERSION  "0.8"

#define HILIGHT_KEYW    1
#define HILIGHT_FUNC    2
#define HILIGHT_QUOTE   3
#define HILIGHT_COMM    4

#define  CLR_WHITE   16777215
#define  CLR_DGREEN   3236352
#define  CLR_MGREEN   8421440
#define  CLR_GREEN      32768
#define  CLR_LGREEN   7335072
#define  CLR_DBLUE    8404992
#define  CLR_VDBLUE  10485760
#define  CLR_LBLUE   16759929
#define  CLR_LIGHT1  15132390
#define  CLR_LIGHT2  12632256
#define  CLR_LIGHTG  12507070

#define MITEM_PRAGMA     1901
#define MITEM_TABLE      1902
#define MITEM_SQL        1903
#define MITEM_ATTA       1904
#define MITEM_PACK       1905
#define MITEM_DUMP       1906
#define MITEM_SCHEMA     1907

#define QUE_TEXT_MAX      256
#define MAX_RECENT_FILES    6
#define MAX_RECENT_QUERIES 12

#ifdef __PLATFORM__UNIX
#define DEF_SEP      '/'
#else
#define DEF_SEP      '\'
#endif

REQUEST HB_CODEPAGE_UTF8

STATIC cAppName := "dbc_SQLite", cExePath, cNull := "(NULL)"
STATIC cCurrPath := "", oEditQ, oPanel, oSayNum, oBtnEd, oBrw1, oBrw2, oDb, oBq
Memvar _lOptChg, _oFont, _lExcl, _lRd, _aRecent, _lHisChg, _aHistory, nLimitText

FUNCTION Main( cFile )

   LOCAL oMainWindow, oBrwMenu
#ifdef __PLATFORM__UNIX
   LOCAL oFont := HFont():Add( "Sans", 0, 12 )
#else
   LOCAL oFont := HFont():Add( "MS Sans Serif", 0, - 17 )
#endif
   LOCAL oSplitV, oSplitH, oBtn, i
   PUBLIC _lOptChg := .F., _oFont, _lExcl := .T., _lRd := .T., _aRecent := {}, _lHisChg := .F., _aHistory := {}
   PUBLIC nLimitText

   cExePath := FilePath( hb_ArgV( 0 ) )

   IF hwg__isUnicode()
      hb_cdpSelect( "UTF8" )
   ENDIF

   ReadIni( cExePath )

   hwg_SetResContainer(  cExePath + Lower(cAppName) + ".bin" )

   INIT WINDOW oMainWindow MAIN TITLE "SQLite database manager" ;
      AT 200, 0 SIZE 800, 450  SYSCOLOR COLOR_3DLIGHT + 1 FONT oFont

   IF Empty( _oFont )
      _oFont := oFont
   ENDIF

   MENU OF oMainWindow
      MENU TITLE "&DataBase"
         MENUITEM "&New" ACTION dbNew()
         MENUITEM "&Open"+Chr(9)+"Ctrl+O" ACTION dbOpen() ACCELERATOR FCONTROL,Asc("O")
         MENU TITLE "&Recent files"
         FOR i := 1 TO Len( _aRecent )
            Hwg_DefineMenuItem( _aRecent[i], 1020 + i, ;
               &( "{||dbOpen('" + _aRecent[i] + "')}" ) )
         NEXT
         ENDMENU
         MENUITEM "&Attach" ID MITEM_ATTA ACTION dbAttach()
         MENUITEM "&Pack" ID MITEM_PACK ACTION dbPack()
         SEPARATOR
         MENUITEM "&Pragmas" ID MITEM_PRAGMA ACTION dbPragmas()
         MENUITEM "&Schema" ID MITEM_SCHEMA ACTION dbSchema()
         MENUITEM "&Dump" ID MITEM_DUMP ACTION dbDump( oDb )
         SEPARATOR
         MENUITEM "&Font" ACTION SetOpt()
         SEPARATOR
         MENUITEM "&Exit" ACTION hwg_EndWindow()
      ENDMENU
      MENU TITLE "&Table" ID MITEM_TABLE
         MENUITEM "&New" ACTION tblNew()
         MENUITEM "&View structure"+Chr(9)+"Ctrl+S" ACTION tblUpd( oBrw1:nCurrent ) ACCELERATOR FCONTROL,Asc("S")
         MENUITEM "&Delete" ACTION tblDrop( oBrw1:nCurrent )
         SEPARATOR
         MENUITEM "&Table info" ACTION tblInfo( oBrw1:nCurrent )
         MENUITEM "&Browse" ACTION ShowTable( oBrw1:nCurrent )
         SEPARATOR
         MENUITEM "&Import table" ACTION tblImport( oDb, oBrw1:nCurrent )
         MENUITEM "&Export table" ACTION tblExport( oDb, oBrw1:nCurrent )
      ENDMENU
      MENU TITLE "&SQL query" ID MITEM_SQL
         MENUITEM "&Execute"+Chr(9)+"Ctrl+E" ACTION QueExecute( oEditQ ) ACCELERATOR FCONTROL,Asc("E")
         MENUITEM "&History"+Chr(9)+"Ctrl+H" ACTION QueHistory( oEditQ ) ACCELERATOR FCONTROL,Asc("H")
         SEPARATOR
         MENUITEM "&Load" ACTION QueLoad( oEditQ )
         MENUITEM "&Save" ACTION QueSave( oEditQ )
      ENDMENU
      MENU TITLE "&Help"
         MENUITEM "&About" ACTION About()
      ENDMENU
   ENDMENU

   CONTEXT MENU oBrwMenu
      MENUITEM "&Browse" ACTION ShowTable( oBrw1:nCurrent )
      MENUITEM "&Table info" ACTION tblInfo( oBrw1:nCurrent )
      SEPARATOR
      MENUITEM "&View structure" ACTION tblUpd( oBrw1:nCurrent )
      MENUITEM "&Delete" ACTION tblDrop( oBrw1:nCurrent )
      SEPARATOR
      MENUITEM "&Import table" ACTION tblImport( oDb, oBrw1:nCurrent )
      MENUITEM "&Export table" ACTION tblExport( oDb, oBrw1:nCurrent )
   ENDMENU

   @ 10, 10 BROWSE oBrw1 ARRAY SIZE 200, 345 ;
      ON SIZE { |o, x, y|o:Move( , , , y - 20 ) } FONT _oFont

   oBrw1:aArray := {}
   oBrw1:tcolor := 0
   oBrw1:bcolor := CLR_LIGHT1
   oBrw1:bcolorSel := oBrw1:htbcolor := CLR_DBLUE
   oBrw1:AddColumn( HColumn():New( "Tables",{ |value,o|o:aArray[o:nCurrent,1] },"C",30 ) )
   oBrw1:bEnter := { |o|ShowTable( o:nCurrent ) }
   oBrw1:bRClick := {|o,n|brw1Menu(o,n,oBrwMenu)}

   oEditQ := HCEdit():New( ,,, 214, 10, 106, 50, _oFont,, { |o, x, y|o:Move( ,,x - oSplitV:nLeft - oSplitV:nWidth - 50 ) } )
   SetHili( oEditQ )
   oEditQ:bKeyDown := {|o,nKey,nCtrl|AutoDop(o,nKey,nCtrl,oDb)}

   @ 214, 65 PANEL oPanel SIZE 206, 378 ;
      ON SIZE { |o, x, y|o:Move( , , x - oSplitV:nLeft - oSplitV:nWidth - 10, y - 72 ) }

   @ 406, 10 BUTTON oBtn CAPTION ">" COLOR CLR_GREEN ;
      SIZE 36, 50 TOOLTIP "Execute SQL query" ;
      ON CLICK { || QueExecute( oEditQ ) } ;
      ON SIZE { |o, x, y| o:Move( oPanel:nLeft + oPanel:nWidth - 38 ) } ;

      @ 214, 60 SPLITTER oSplitH SIZE 206, 4 ;
      DIVIDE { oEditQ, oBtn } FROM { oPanel } ;
      ON SIZE { |o, x, y|o:Move( , , x - oSplitV:nLeft - oSplitV:nWidth - 10, ) }

   @ 210, 10 SPLITTER oSplitV SIZE 4, 290 ;
      DIVIDE { oBrw1 } FROM { oPanel, oSplitH, oEditQ } ;
      ON SIZE { |o, x, y|o:Move( , , , y - 20 ) } LIMITS ,400

   @ 6, 6 SAY oSayNum CAPTION "" OF oPanel SIZE 152, 24 FONT oFont:SetFontStyle( .T. ) COLOR CLR_DBLUE TRANSPARENT
   @ 156, 4 BUTTON "<<" OF oPanel COLOR CLR_DBLUE SIZE 28, 28 TOOLTIP "First record" ON CLICK { ||iif( Empty( oBrw2 ), .T. , oBrw2:Top() ) }
   @ 184, 4 BUTTON "<"  OF oPanel COLOR CLR_DBLUE SIZE 28, 28 TOOLTIP "Page Up"  ON CLICK { ||iif( Empty( oBrw2 ), .T. , oBrw2:PageUp() ) }
   @ 212, 4 BUTTON ">"  OF oPanel COLOR CLR_DBLUE SIZE 28, 28 TOOLTIP "Page Down"  ON CLICK { ||iif( Empty( oBrw2 ), .T. , oBrw2:PageDown() ) }
   @ 240, 4 BUTTON ">>" OF oPanel COLOR CLR_DBLUE SIZE 28, 28 TOOLTIP "Last record"  ON CLICK { ||iif( Empty( oBrw2 ), .T. , oBrw2:Bottom() ) }
   @ 276, 2 LINE LENGTH 28 OF oPanel VERTICAL
   @ 284, 4 BUTTON oBtnEd CAPTION "Edit" OF oPanel COLOR CLR_DBLUE SIZE 64, 28 TOOLTIP "Edit row"  ON CLICK { ||iif( Empty( oBrw2 ), .T. , EditRow( .F. ) ) }
   @ 352, 4 BUTTON "New" OF oPanel COLOR CLR_DBLUE SIZE 64, 28 TOOLTIP "Add row"  ON CLICK { ||iif( Empty( oBrw2 ), .T. , EditRow( .T. ) ) }

   BtnEnable( .F. )
   MenuEnable( { MITEM_PRAGMA,MITEM_TABLE,MITEM_SQL,MITEM_ATTA,MITEM_PACK,MITEM_DUMP,MITEM_SCHEMA }, .F. )

   ACTIVATE WINDOW oMainWindow ON ACTIVATE {|| Iif( !Empty(cFile), dbOpen(cFile), .T. )}

   IF _lOptChg
      WriteIni( cExePath )
   ENDIF
   IF _lHisChg
      WriteHistory( cExePath )
   ENDIF

   RETURN Nil

STATIC FUNCTION ReadIni( cPath )

   LOCAL oIni := HXMLDoc():Read( cPath + Lower(cAppName) + ".ini" )
   LOCAL oNode, i, j

   IF !Empty( oIni:aItems )
      FOR i := 1 TO Len( oIni:aItems[1]:aItems )
         oNode := oIni:aItems[1]:aItems[i]
         IF oNode:title == "font"
            _oFont := FontFromXML( oNode )
         ELSEIF oNode:title == "db_open_mode"
            _lExcl := oNode:GetAttribute( "exclusive", "L", .T. )
            _lRd := oNode:GetAttribute( "readonly", "L", .T. )
         ELSEIF oNode:title == "recent"
            FOR j := 1 TO Min( Len( oNode:aItems ), MAX_RECENT_FILES )
               Aadd( _aRecent, Trim( oNode:aItems[j]:GetAttribute("name") ) )
            NEXT
         ENDIF
      NEXT
   ENDIF

   RETURN Nil

STATIC FUNCTION WriteIni( cPath )

   LOCAL oIni := HXMLDoc():New()
   LOCAL oNode, oNodeR, i

   oIni:Add( oNode := HXMLNode():New( "init" ) )

   oNode:Add( FontToXML( _oFont ) )
   oNode:Add( HXMLNode():New( "db_open_mode", HBXML_TYPE_SINGLE, ;
      { { "exclusive",Iif(_lExcl,"on","off") }, { "readonly",Iif(_lRd,"on","off") } } ) )

   oNodeR := oNode:Add( HXMLNode():New( "recent" ) )
   FOR i := 1 TO Len( _aRecent )
      oNodeR:Add( HXMLNode():New( "db", HBXML_TYPE_SINGLE, { { "name", _aRecent[i] } } ) )
   NEXT

   oIni:Save( cPath + Lower(cAppName) + ".ini" )

   RETURN Nil

STATIC FUNCTION ReadHistory( cPath )

   LOCAL oIni := HXMLDoc():Read( cPath + Lower(cAppName) + ".his" )
   LOCAL oNode, i, j, n, arr

   IF !Empty( oIni:aItems )
      FOR i := 1 TO Min( Len( oIni:aItems[1]:aItems ), MAX_RECENT_FILES )
         oNode := oIni:aItems[1]:aItems[i]
         IF oNode:title == "db"
            Aadd( _aHistory, { oNode:GetAttribute( "name", "C" ), arr := {} } )
            FOR j := 1 TO Min( Len( oNode:aItems ), MAX_RECENT_QUERIES )
               Aadd( arr, oNode:aItems[j]:aItems[1] )
            NEXT
         ENDIF
      NEXT
   ENDIF

   RETURN Nil

STATIC FUNCTION WriteHistory( cPath )

   LOCAL oIni := HXMLDoc():New()
   LOCAL oNode, oNodeR, i, j

   oIni:Add( oNode := HXMLNode():New( "history" ) )

   FOR i := 1 TO Len( _aHistory )
      oNodeR := oNode:Add( HXMLNode():New( "db",,{ { "name", _aHistory[i,1] } } ) )
      FOR j := 1 TO Len( _aHistory[i,2] )
         oNodeR:Add( HXMLNode():New( "db", HBXML_TYPE_CDATA,, _aHistory[i,2,j] ) )
      NEXT
   NEXT
   oIni:Save( cPath + Lower(cAppName) + ".his" )

   RETURN Nil

STATIC FUNCTION brw1Menu( oBrw, nLine, oMenu )

   LOCAL i, nlCurr := oBrw:rowPos

   IF nlCurr > nLine
      FOR i := nLine+1 TO nlCurr
         oBrw:LineUp()
      NEXT
   ELSEIF nlCurr < nLine
      FOR i := nLine-1 TO nlCurr STEP -1
         oBrw:LineDown()
      NEXT
   ENDIF

   oBrw:Refresh()
   oMenu:Show( HWindow():GetMain() )

   RETURN Nil

STATIC FUNCTION dbNew()
   LOCAL cFile

#ifdef __PLATFORM__UNIX
   cFile := hwg_Selectfile( "( *.* )", "*.*", CurDir() )
#else
   cFile := hwg_Savefile( "*.*", "( *.* )", "*.*", CurDir() )
#endif

   IF !Empty( cFile ) .AND. !Empty( oDb := HSQLT():New( cFile ) )

      oBrw1:aArray := {}
      oBrw1:Refresh()
      MenuEnable( { MITEM_PRAGMA,MITEM_TABLE,MITEM_SQL,MITEM_ATTA,MITEM_PACK,MITEM_DUMP,MITEM_SCHEMA }, .T. )
      Add2Recent( cFile )
   ENDIF

   RETURN Nil

FUNCTION dbOpen( cFile )

   LOCAL oDlg, oGet
   LOCAL lExcl := _lExcl , lRd := _lRd
   LOCAL bFileBtn := { ||
   IF Empty( cFile := hwg_Selectfile( "( *.* )", "*.*", cCurrPath ) )
      cFile := ""
   ENDIF
   oGet:Refresh()

   RETURN .T.
   }

   IF Empty( cFile ); cFile := ""; ENDIF

   INIT DIALOG oDlg TITLE "Open file" AT 0, 0 SIZE 400, 190 ;
      FONT HWindow():GetMain():oFont

   @ 10, 34 SAY "File name: " SIZE 80, 24 STYLE SS_RIGHT

   @ 90, 34 GET oGet VAR cFile SIZE 220, 24 PICTURE "@S128" STYLE ES_AUTOHSCROLL
   Atail( oDlg:aControls ):Anchor := ANCHOR_TOPABS + ANCHOR_LEFTABS + ANCHOR_RIGHTABS
   @ 310, 30 BUTTON "Browse" SIZE 80, 32 ON CLICK bFileBtn ON SIZE ANCHOR_RIGHTABS

   @ 10, 72 GET CHECKBOX lExcl CAPTION "Exclusive" SIZE 140, 24
   @ 10, 96 GET CHECKBOX lRd CAPTION "Readonly" SIZE 140, 24

   @  30, 140 BUTTON "Ok" SIZE 100, 32 ON CLICK { ||oDlg:lResult := .T. , hwg_EndDialog() }
   @ 270, 140 BUTTON "Cancel" SIZE 100, 32 ON CLICK { ||hwg_EndDialog() }

   oDlg:Activate()

   IF oDlg:lResult 
      IF lExcl != _lExcl .OR. lRd != _lRd
         _lExcl := lExcl; _lRd := lRd
         _lOptChg := .T.
      ENDIF
      IF !Empty( cFile ) .AND. !Empty( oDb := HSQLT():Open( cFile, lExcl, lRd ) )
         oBrw1:aArray := oDb:GetTables()
         oBrw1:Refresh()
         oBrw1:Top()
         MenuEnable( { MITEM_PRAGMA,MITEM_TABLE,MITEM_SQL,MITEM_ATTA,MITEM_PACK,MITEM_DUMP,MITEM_SCHEMA }, .T. )
         Add2Recent( cFile )
      ENDIF
   ENDIF

   RETURN Nil

STATIC FUNCTION dbAttach()

   LOCAL oDlg

   INIT DIALOG oDlg TITLE "Attach database"  ;
      AT 0, 0 SIZE 600, 280 FONT HWindow():GetMain():oFont

   @ 200, 60 SAY "Not implemented yet." SIZE 200,24 STYLE SS_CENTER

   ACTIVATE DIALOG oDlg

   RETURN Nil

STATIC FUNCTION dbPack()

   LOCAL nRes

   sqlite3_exec( oDb:dbHandle, "VACUUM" )
   IF ( nRes := sqlite3_errcode( oDb:dbHandle ) ) == SQLITE_OK .OR. nRes == SQLITE_DONE
      hwg_MsgInfo( "Done!" )
   ELSE
      hwg_MsgStop( sqlite3_errmsg(oDb:dbHandle), "Error " + Ltrim(Str(nRes)) )
   ENDIF

   RETURN Nil

STATIC FUNCTION ShowTable( nTable )

   LOCAL aFlds, i

   IF Empty( nTable ) .OR. ( !Empty( oBrw2 ) .AND. oBrw2:cargo == nTable )
      RETURN Nil
   ENDIF

   IF !Empty( oBrw2 ) .AND. oBrw2:cargo == 0
      oPanel:DelControl( oBrw2 )
      oBrw2 := Nil
   ENDIF
   IF Empty( oBrw2 )
      @ 0, 36 BROWSE oBrw2 ARRAY OF oPanel SIZE oPanel:nWidth, oPanel:nHeight - 40 NO VSCROLL ;
         ON SIZE { |o, x, y|o:Move( , , x, y - 40 ) } FONT _oFont

      oBrw2:tcolor := 0
      oBrw2:bcolor := CLR_LIGHT1
      oBrw2:bcolorSel := oBrw2:htbcolor := CLR_DBLUE
      oBrw2:bEnter := {|| EditRow(.F.) }

      IF oDb:lRdOnly
         BtnEnable( .T., {1,2,3,4,5} )
         oBtnEd:SetText( "View" )
      ELSE
         BtnEnable( .T. )
         oBtnEd:SetText( "Edit" )
      ENDIF
   ENDIF
   oBrw2:aArray := {}
   oBrw2:cargo := nTable

   oBq := HBrwTable():New( oDb:dbHandle, oDb:aTables[nTable,1], oBrw2 )
   aFlds := oBq:aFlds

   oBrw2:aColumns := {}
   FOR i := 1 TO Len( aFlds )
      IF oBq:lRowId
         oBrw2:AddColumn( HColumn():New( aFlds[i,1],{ |v,o,n|o:aArray[o:nCurrent,n+1] },"C",Max(aFlds[i,2],Len(aFlds[i,1])) + 4,0 ) )
      ELSE
         oBrw2:AddColumn( HColumn():New( aFlds[i,1],{ |v,o,n|o:aArray[o:nCurrent,n] },"C",Max(aFlds[i,2],Len(aFlds[i,1])) + 4,0 ) )
      ENDIF
   NEXT

   oBq:ReadFirst()
   oBrw2:Refresh()
   hwg_Setfocus( oBrw2:handle )

   RETURN Nil

STATIC FUNCTION QueExecute( oEdit )

   LOCAL stmt, aFlds, arr := {}, nArr := 0, i, nCCount, cQuery := "", nRes 

   IF Empty( cQuery := oEdit:GetText() )
      RETURN Nil
   ENDIF

   hb_MemoWrit( cExePath+"_sql.tmp", cQuery )
   IF Lower( Left( cQuery, 7 ) ) == "select "
      IF !Empty( oBrw2 ) .AND. oBrw2:cargo != 0
         oPanel:DelControl( oBrw2 )
         oBrw2 := Nil
         BtnEnable( .F. )
      ENDIF
      IF Empty( oBrw2 )
         @ 0, 36 BROWSE oBrw2 ARRAY OF oPanel SIZE oPanel:nWidth, oPanel:nHeight - 40 ;
            ON SIZE { |o, x, y|o:Move( , , x, y - 40 ) } FONT _oFont

         oBrw2:tcolor := 0
         oBrw2:bcolor := CLR_LIGHT1
         oBrw2:bcolorSel := oBrw2:htbcolor := CLR_DBLUE

         BtnEnable( .T., {1,2,3,4,5} )
         oBtnEd:SetText( "View" )
      ENDIF
      oBrw2:aArray := {}
      oBrw2:cargo := 0

      IF !Empty( stmt := sqlite3_prepare( oDb:dbHandle, cQuery ) )
         nLimitText := Nil
         DO WHILE sqlite3_step( stmt ) == SQLITE_ROW
            nArr ++
            nCCount := sqlite3_column_count( stmt )
            IF nArr == 1
               aFlds := Array( nCCount, 2 )
               FOR i := 1 TO nCCount
                  aFlds[i,1] := sqlite3_column_name( stmt, i )
                  aFlds[i,2] := 1
               NEXT
            ENDIF
            AAdd( arr, Array( nCCount ) )
            FOR i := 1 TO nCCount
               arr[nArr,i] := sqlGetField( stmt, i )
               aFlds[i,2] := Max( aFlds[i,2], Len( arr[nArr,i] ) )
            NEXT
            IF nArr == 1024
               IF !hwg_msgYesNo( "There are more than 1024 rows," + Chr(13)+Chr(10) + "Continue anyway ?", "Warning" )
                  EXIT
               ENDIF
            ENDIF
         ENDDO
         sqlite3_finalize( stmt )
         Add2His( oDb:cdbName, cQuery )
         IF !Empty( arr )
            oBrw2:aArray := arr
            oBrw2:aColumns := {}
            FOR i := 1 TO Len( aFlds )
               oBrw2:AddColumn( HColumn():New( aFlds[i,1],{ |v,o,n|o:aArray[o:nCurrent,n] },"C",Max(aFlds[i,2],Len(aFlds[i,1])) + 4,0 ) )
            NEXT
            oBrw2:Refresh()
         ENDIF
         FSayNum( "Rows: " + LTrim( Str(Len(arr ) ) ) )
      ELSE
         hwg_MsgStop( hwg_MsgStop( sqlite3_errmsg(oDb:dbHandle), "Error " + Ltrim(Str(sqlite3_errcode(oDb:dbHandle))) ) )
      ENDIF
   ELSE
      sqlite3_exec( oDb:dbHandle, cQuery )
      IF ( nRes := sqlite3_errcode( oDb:dbHandle ) ) == SQLITE_OK .OR. nRes == SQLITE_DONE
         Add2His( oDb:cdbName, cQuery )
         hwg_MsgInfo( hb_ntos( sqlite3_changes( oDb:dbHandle ) ), "The number of rows changed" )
      ELSE
         hwg_MsgStop( sqlite3_errmsg(oDb:dbHandle), "Error " + Ltrim(Str(nRes)) )
      ENDIF
   ENDIF
   FErase( cExePath+"_sql.tmp" )

   RETURN Nil

STATIC FUNCTION QueHistory( oEdit )

   LOCAL oDlg, oBtn1, oBtn2, oLine, oBtnSele
   LOCAL aCtrl, nControls, nSel := 0, nFirst := 1, cQ
   LOCAL i, aData
   LOCAL bFocus := {|o,id|
      LOCAL oEdit := o:FindControl(id), n, s
      IF nSel > 0
         n := nFirst + nSel - 1
         aCtrl[nSel]:SetColor( ,CLR_LIGHT1,.T. )
      ENDIF
      nSel := oEdit:cargo
      n := nFirst + nSel - 1
      aCtrl[nSel]:SetColor( ,CLR_WHITE,.T. )
      hwg_Enablewindow( oBtnSele:handle, .T. )
      RETURN Nil
   }
   LOCAL bButtons := {|o,l|
      hwg_Enablewindow( oBtn1:handle, (nFirst > 1) )
      hwg_Enablewindow( oBtn2:handle, (Len(aData)-nFirst+1 > nControls) )
      hwg_Enablewindow( oBtnSele:handle, (nSel > 0) )
      RETURN Nil
   }
   LOCAL bCreate := {|i1|
      LOCAL j1 := nFirst + i1 -1
      @ 10,10 + (i1-1)*56 EDITBOX aCtrl[i1] CAPTION aData[j1] SIZE 580,52 STYLE ES_MULTILINE ;
         BACKCOLOR CLR_LIGHT1 FONT _oFont ON SIZE ANCHOR_LEFTABS + ANCHOR_RIGHTABS ON GETFOCUS bFocus
      aCtrl[i1]:cargo := i1
      RETURN Nil
   }
   LOCAL bSet := {|i1|
      LOCAL j1 := nFirst + i1 -1
      aCtrl[i1]:SetText( aData[j1] )
      RETURN Nil
   }
   LOCAL bResize := {|o,x,y|
      LOCAL nNew := Min( Len(aData)-nFirst+1, Int( (oLine:nTop-14)/56 ) )
      IF nNew != nControls
         IF nNew < nControls
            FOR i := Max( nNew+1,2 ) TO nControls
               aCtrl[i]:Hide()
            NEXT
         ELSEIF nNew > nControls
            IF nNew > Len( aCtrl )
               ASize( aCtrl, nNew )
            ENDIF
            FOR i := nControls+1 TO nNew
               IF Empty( aCtrl[i] )
                  Eval( bCreate, i )
               ELSE
                  aCtrl[i]:Show()
                  Eval( bSet, i )
               ENDIF
            NEXT
         ENDIF
         nControls := nNew
         Eval( bButtons, oDlg, .T. )
      ENDIF
      RETURN .T.
   }
   LOCAL bNext := {||
      LOCAL i1, j1
      nFirst += nControls
      FOR i1 := 1 TO nControls
         IF ( j1 := ( nFirst + i1 -1 ) ) <= Len(aData)
            Eval( bSet, i1 )
         ELSE
            aCtrl[i1]:Hide()
         ENDIF
      NEXT
      Eval( bButtons, oDlg, .T. )
      RETURN Nil
   }
   LOCAL bPrev := {||
      LOCAL i1
      nFirst -= nControls
      IF nFirst < 1
         nFirst := 1
      ENDIF
      FOR i1 := 1 TO nControls
         IF aCtrl[i1]:lHide
            aCtrl[i1]:Show()
         ENDIF
         Eval( bSet, i1 )
      NEXT
      IF Min( Len(aData)-nFirst+1, Int( (oLine:nTop-14)/56 ) ) < nControls
         Eval( bButtons, oDlg, .T. )
      ENDIF
      Eval( bResize, oDlg, 0, oDlg:nHeight )
      RETURN Nil
   }
   LOCAL bSele := {||
      oEditQ:SetText( aData[nFirst+nSel-1] )
      hwg_EndDialog()
      RETURN Nil
   }

   IF Empty( _aHistory )
      ReadHistory( cExePath )
   ENDIF
   aData := Iif( ( i := Ascan( _aHistory, {|a|a[1]==oDb:cdbName} ) ) == 0, {}, _aHistory[i,2] )

   INIT DIALOG oDlg TITLE "History" ;
      AT 0, 0 SIZE 600, 480 FONT HWindow():GetMain():oFont ;
      ON SIZE bResize

   @ 4, 440 LINE oLine LENGTH 582 ON SIZE ANCHOR_BOTTOMABS + ANCHOR_LEFTABS + ANCHOR_RIGHTABS

   @ 80,448 BUTTON oBtnSele CAPTION "Select" SIZE 80, 28 ON CLICK bSele
   @ 240,448 BUTTON oBtn1 CAPTION "<" SIZE 40, 28 TOOLTIP "Page Up" ON CLICK bPrev
   @ 320,448 BUTTON oBtn2 CAPTION ">" SIZE 40, 28 TOOLTIP "Page Down" ON CLICK bNext
   @ 440,448 BUTTON "Close" SIZE 80, 28 ON CLICK {||hwg_EndDialog()}

   nControls := Min( Len(aData), Int( (oLine:nTop-14)/56 ) )
   aCtrl := Array( nControls )

   FOR i := 1 TO nControls
      Eval( bCreate, i )
   NEXT

   ACTIVATE DIALOG oDlg ON ACTIVATE bButtons

   RETURN Nil

STATIC FUNCTION QueLoad( oEdit )

   LOCAL cFile := hwg_Selectfile( "( *.* )", "*.*", cCurrPath )

   IF !Empty( cFile )
      oEdit:SetText( MemoRead( cFile ) )
   ENDIF

   RETURN Nil

STATIC FUNCTION QueSave( oEdit )
   LOCAL cFile

#ifdef __PLATFORM__UNIX
   cFile := hwg_Selectfile( "( *.* )", "*.*", CurDir() )
#else
   cFile := hwg_Savefile( "*.*", "( *.* )", "*.*", CurDir() )
#endif

   IF !Empty( cFile )
      hb_MemoWrit( cFile, oEdit:GetText() )
   ENDIF

   RETURN Nil

STATIC FUNCTION tblNew()

   IF !oDb:lRdOnly .AND. StruMan( oDb, .T. )
      oBrw1:aArray := oDb:GetTables()
      oBrw1:Refresh()
   ENDIF

   RETURN Nil

STATIC FUNCTION tblUpd( nTable )

   IF StruMan( oDb, .F., nTable )
   ENDIF

   RETURN Nil

STATIC FUNCTION tblDrop( nTable )

   LOCAL nRes

   IF Empty( nTable ) .OR. oDb:lRdOnly .OR. !hwg_msgYesNo( "Really delete " + oDb:aTables[nTable,1] + "?" )
      RETURN Nil
   ENDIF

   sqlite3_exec( oDb:dbHandle, "DROP TABLE " + oDb:aTables[nTable,1] )
   IF ( nRes := sqlite3_errcode( oDb:dbHandle ) ) == SQLITE_OK .OR. nRes == SQLITE_DONE
      oBrw1:aArray := oDb:GetTables()
      oBrw1:Refresh()
      hwg_MsgInfo( "Done!" )
   ELSE
      hwg_MsgStop( sqlite3_errmsg(oDb:dbHandle), "Error " + Ltrim(Str(nRes)) )
   ENDIF

   RETURN Nil

STATIC FUNCTION tblInfo( nTable )

   LOCAL oDlg, oEdit, oBrw, oEditI, oBtn1, oBtn2
   LOCAL bPosChg := {||
      IF !Empty(oBrw:aArray)
         oEditI:SetText( oBrw:aArray[oBrw:nCurrent,3] )
         oEditI:lSetFocus := .F.
      ENDIF
      hwg_Enablewindow( oBtn1:handle, !oDb:lRdOnly )
      hwg_Enablewindow( oBtn2:handle, ( !oDb:lRdOnly.AND.!Empty(oBrw:aArray).AND.Left(oBrw:aArray[oBrw:nCurrent,1],7)!="sqlite_") )
      hwg_SetFocus( oBrw:handle )
      RETURN .T.
   }

   IF Empty( nTable )
      RETURN Nil
   ENDIF

   INIT DIALOG oDlg TITLE oDb:aTables[nTable,1] + ": table information" ;
      AT 0, 0 SIZE 400, 460 FONT HWindow():GetMain():oFont

   oEdit := HCEdit():New( ,,, 10, 10, 380, 110, _oFont,, { |o, x, y|o:Move( ,,x - 20 ) } )
   oEdit:SetWrap( .T. )
   oEdit:lReadOnly := .T.
   SetHili( oEdit )
   oEdit:SetText( oDb:aTables[nTable,2] )

   @ 4, 130 BROWSE oBrw ARRAY SIZE 392, 120 ;
      ON SIZE { |o, x, y|o:Move( , ,x-8 ) } FONT _oFont

   oBrw:aArray := oDb:GetObjects( 'index', oDb:aTables[nTable,1] )
   oBrw:tcolor := 0
   oBrw:bcolor := CLR_LIGHT1
   oBrw:bcolorSel := oBrw:htbcolor := CLR_DBLUE
   oBrw:bPosChanged := bPosChg
   oBrw:cargo := nTable

   oBrw:AddColumn( HColumn():New( "Indexes",{ |value,o|o:aArray[o:nCurrent,1] },"C",60 ) )

   oEditI := HCEdit():New( ,,, 10, 260, 380, 70, _oFont,, { |o, x, y|o:Move( ,,x - 20 ) } )
   oEditI:SetWrap( .T. )
   oEditI:lReadOnly := .T.
   SetHili( oEditI )

   @ 60, 350 BUTTON oBtn1 CAPTION "Add index" SIZE 110, 28 ON CLICK { ||indexNew(oBrw)}
   @ 230, 350 BUTTON oBtn2 CAPTION "Delete index" SIZE 110, 28 ON CLICK { ||indexDrop(oBrw)} ON SIZE ANCHOR_RIGHTABS

   @ 150, 410 BUTTON "Close" SIZE 100, 32 ON CLICK { ||oDlg:lResult:=.T.,hwg_EndDialog() } ON SIZE ANCHOR_RIGHTABS + ANCHOR_BOTTOMABS

   oDlg:Activate()

   RETURN Nil

STATIC FUNCTION indexNew( oBrw )

   LOCAL oDlg, oEdit, oGet0, oGet1
   LOCAL af := GetTblStru( oDb:aTables[oBrw:cargo,2] ), cIndName := ""
   LOCAL nField := 1, arr := {}, nRes
   LOCAL bAdd := {||
      IF Ascan( arr, af[nField,1] ) == 0
         Aadd( arr, af[nField,1] )
         oEdit:SetText( Query_CreateInd( cIndName, arr ) )
      ENDIF
      RETURN Nil
   }
   LOCAL bCreate := {||
      IF Empty( cIndName )
         hwg_MsgStop( "Index name is missed!" )
      ELSE
         sqlite3_exec( oDb:dbHandle, oEdit:GetText() )
         IF ( nRes := sqlite3_errcode( oDb:dbHandle ) ) == SQLITE_OK .OR. nRes == SQLITE_DONE
            hwg_MsgInfo( "Done!" )
            hwg_EndDialog()
         ELSE
            hwg_MsgStop( sqlite3_errmsg(oDb:dbHandle), "Error " + Ltrim(Str(nRes)) )
         ENDIF
      ENDIF
      RETURN Nil
   }

   INIT DIALOG oDlg TITLE "Add index for " + oDb:aTables[oBrw:cargo,1] ;
      AT 0, 0 SIZE 400, 290 FONT HWindow():GetMain():oFont

   @ 10,16 SAY "Index name:" SIZE 120, 24
   @ 130, 16 GET oGet0 VAR cIndName SIZE 260, 24

   @ 20, 50 BUTTON "Add" SIZE 60, 26 ON CLICK bAdd
   @ 90, 50 SAY "Field:" SIZE 60, 24
   @ 150,50 GET COMBOBOX oGet1 VAR nField ITEMS af SIZE 120, 24 DISPLAYCOUNT 5

   oEdit := HCEdit():New( ,,, 10, 90, 380, 110, _oFont,, { |o, x, y|o:Move( ,,x - 20 ) } )
   oEdit:SetWrap( .T. )
   oEdit:lReadOnly := .T.
   SetHili( oEdit )

   @ 60,240 BUTTON "Create" SIZE 100, 30 ON CLICK bCreate ON SIZE ANCHOR_BOTTOMABS + ANCHOR_LEFTABS
   @ 240, 240 BUTTON "Close" SIZE 100, 30 ON CLICK { ||hwg_EndDialog() } ON SIZE ANCHOR_BOTTOMABS + ANCHOR_RIGHTABS

   oDlg:Activate()

   RETURN Nil

STATIC FUNCTION indexDrop( oBrw )

   LOCAL nRes

   IF !hwg_msgYesNo( "Really delete an index " + oBrw:aArray[oBrw:nCurrent,1] + "?" )
      RETURN Nil
   ENDIF

   sqlite3_exec( oDb:dbHandle, "DROP INDEX " + oBrw:aArray[oBrw:nCurrent,1] )
   IF ( nRes := sqlite3_errcode( oDb:dbHandle ) ) == SQLITE_OK .OR. nRes == SQLITE_DONE
      oBrw:aArray := oDb:GetObjects( 'index', oDb:aTables[oBrw:cargo,1] )
      oBrw:Refresh()
      hwg_MsgInfo( "Done!" )
   ELSE
      hwg_MsgStop( sqlite3_errmsg(oDb:dbHandle), "Error " + Ltrim(Str(nRes)) )
   ENDIF

   RETURN Nil

STATIC FUNCTION Query_CreateInd( cIndName, arr )
   LOCAL cQ := "CREATE INDEX ON" + cIndName + "("
   LOCAL i

   FOR i := 1 TO Len(arr)
      cQ += arr[i]
      IF i < Len(arr)
         cQ += ","
      ENDIF
   NEXT
   cQ += ")"

   RETURN cQ

STATIC FUNCTION dbPragmas()
   LOCAL aPragmas := { "auto_vacuum", "automatic_index", "busy_timeout", "cache_size", ;
      "cache_spill", "case_sensitive_like", "checkpoint_fullfsync", "collation_list", "compile_options", ;
      "defer_foreign_keys", "encoding", "foreign_key_check", "foreign_key_list", ;
      "foreign_keys", "freelist_count", "fullfsync", "ignore_check_constraints", "incremental_vacuum", ;
      "integrity_check", "journal_mode", "journal_size_limit", "legacy_file_format", "locking_mode", ;
      "max_page_count", "mmap_size", "page_count", "page_size", "query_only", "quick_check", ;
      "read_uncommitted", "recursive_triggers", "reverse_unordered_selects", "schema_version", "secure_delete", ;
      "shrink_memory", "soft_heap_limit", "synchronous", "table_info", "temp_store", "threads", ;
      "user_version", "wal_autocheckpoint", "wal_checkpoint", "writable_schema" }
   LOCAL aValues := Array( Len(aPragmas) ), aBackup := Array( Len(aPragmas) ), aChanged
   LOCAL i, arr
   LOCAL oDlg, oBrw

   arr := sqlite3_get_table( oDb:dbHandle, "PRAGMA " + aPragmas[5] )

   FOR i := 1 TO Len( aPragmas )
      IF !Empty( arr := sqlite3_get_table( oDb:dbHandle, "PRAGMA " + aPragmas[i] ) ) .AND. ;
         Len( arr ) == 2 .AND. !Empty( arr[1] ) .AND. !Empty( arr[2] )
         aValues[i] := aBackup[i] := arr[2,1]
      ELSE
         aValues[i] := aBackup[i] := "Not set"
      ENDIF
   NEXT

   INIT DIALOG oDlg TITLE "Pragmas list" ;
      AT 0, 0 SIZE 400, 500 FONT HWindow():GetMain():oFont

   @ 4, 0 BROWSE oBrw ARRAY SIZE 392, 430 ;
      ON SIZE { |o, x, y|o:Move( , ,x-8 , y - 70 ) } FONT _oFont

   oBrw:aArray := aPragmas
   oBrw:tcolor := oBrw:tcolorSel := 0
   oBrw:bcolor := CLR_LIGHT1
   oBrw:bcolorSel := CLR_LIGHT1
   oBrw:htbcolor := CLR_DBLUE

   oBrw:AddColumn( HColumn():New( "",{ |value,o|o:aArray[o:nCurrent] },"C",30,0 ) )
   oBrw:AddColumn( HColumn():New( "",{ |value,o|aValues[o:nCurrent] },"C",20,0,.T. ) )

   @ 150, 450 BUTTON "CLose" SIZE 100, 32 ON CLICK { ||oDlg:lResult:=.T.,hwg_EndDialog() } ON SIZE ANCHOR_LEFTABS + ANCHOR_RIGHTABS + ANCHOR_BOTTOMABS

   oDlg:Activate()

   IF oDlg:lResult
      aChanged := {}
      FOR i := 1 TO Len( aValues )
         IF !( aValues[i] == aBackup[i] )
            Aadd( aChanged, { aPragmas[i],aBackup[i],aValues[i]  } )
         ENDIF
      NEXT
      IF Len( aChanged ) > 0

         INIT DIALOG oDlg TITLE "Following values are changed:" ;
            AT 0, 0 SIZE 500, 400  FONT HWindow():GetMain():oFont

         @ 4, 0 BROWSE oBrw ARRAY SIZE 492, 330 ;
            ON SIZE { |o, x, y|o:Move( , ,x-8 , y - 70 ) }

         oBrw:aArray := aChanged
         oBrw:tcolor := 0
         oBrw:bcolor := CLR_LIGHT1
         oBrw:bcolorSel := oBrw:htbcolor := CLR_MGREEN

         oBrw:AddColumn( HColumn():New( "",{ |value,o|o:aArray[o:nCurrent,1] },"C",30,0 ) )
         oBrw:AddColumn( HColumn():New( "Old value",{ |value,o|o:aArray[o:nCurrent,2] },"C",20,0, ) )
         oBrw:AddColumn( HColumn():New( "New value",{ |value,o|o:aArray[o:nCurrent,3] },"C",20,0, ) )

         @ 100, 350 BUTTON "Save" SIZE 100, 32 ON CLICK { ||oDlg:lResult:=.T.,hwg_EndDialog() } ON SIZE ANCHOR_BOTTOMABS
         @ 300, 350 BUTTON "Cancel" SIZE 100, 32 ON CLICK { ||hwg_EndDialog() } ON SIZE ANCHOR_BOTTOMABS

         oDlg:Activate()

         IF oDlg:lResult
            FOR i := 1 TO Len( aChanged )
               aChanged[i,3] := AllTrim( aChanged[i,3] )
               sqlite3_exec( oDb:dbHandle, "PRAGMA " + aChanged[i,1] + "=" + ;
                  Iif( isDigit(aChanged[i,3]), aChanged[i,3], '"'+aChanged[i,3]+'"' ) )
            NEXT
         ENDIF

      ENDIF
   ENDIF

   RETURN Nil

STATIC FUNCTION dbSchema()

   LOCAL arr := oDb:GetObjects(), aType := { "All", "Tables", "Indexes", "Triggers", "Views" }, nType := 1, nTypePrev := 1
   LOCAL oDlg, oBrowse
   LOCAL bType := {||
      LOCAL i, s
      IF nTypePrev != nType
         IF nType == 1
            oBrowse:aArray := arr
         ELSE
            oBrowse:aArray := {}
            s := Iif( nType==2, "table", Iif( nType==3, "index", Iif( nType==4, "trigger","view" ) ) )
            FOR i := 1 TO Len(arr)
               IF arr[i,1] == s
                  Aadd( oBrowse:aArray, arr[i] )
               ENDIF
            NEXT
         ENDIF
         nTypePrev := nType
         oBrowse:Top()
         oBrowse:Refresh()
      ENDIF
      RETURN .T.
   }

   ASort( arr,,, {|a1,a2|a1[3]<a2[3]} )
   INIT DIALOG oDlg TITLE "Schema" ;
      AT 0, 0 SIZE 500, 340 FONT HWindow():GetMain():oFont

   @ 20, 4 GET COMBOBOX nType ITEMS aType SIZE 120, 24 DISPLAYCOUNT 5 ON CHANGE bType
   
   @ 0, 36 BROWSE oBrowse ARRAY SIZE 500, 244 ON SIZE ANCHOR_LEFTABS + ANCHOR_RIGHTABS + ANCHOR_TOPABS + ANCHOR_BOTTOMABS
   oBrowse:tcolor := 0
   oBrowse:bcolor := CLR_LIGHT1
   oBrowse:bcolorSel := oBrowse:htbcolor := CLR_DBLUE

   oBrowse:aArray := arr
   oBrowse:AddColumn( HColumn():New( "Type",{ |v,o|o:aArray[o:nCurrent,1] },"C",20,0 ) )
   oBrowse:AddColumn( HColumn():New( "Name",{ |v,o|o:aArray[o:nCurrent,2] },"C",20,0 ) )
   oBrowse:AddColumn( HColumn():New( "Table",{ |v,o|o:aArray[o:nCurrent,3] },"C",20,0 ) )
   oBrowse:AddColumn( HColumn():New( "SQL",{ |v,o|o:aArray[o:nCurrent,4] },"C",64,0 ) )

   @ 200, 300 BUTTON "Close" SIZE 100, 30 ON CLICK { ||hwg_EndDialog() } ON SIZE ANCHOR_BOTTOMABS + ANCHOR_RIGHTABS + ANCHOR_LEFTABS

   ACTIVATE DIALOG oDlg

   RETURN Nil

STATIC FUNCTION SetOpt()

   LOCAL oFont := HFont():Select( _oFont )

   IF !Empty( oFont )
      _oFont := oFont
      _lOptChg := .T.

      oBrw1:oFont := oFont
      oBrw1:Refresh( .T. )
      IF !Empty( oBrw2 )
         oBrw2:oFont := oFont
         oBrw2:Refresh( .T. )
      ENDIF
      oEditQ:SetFont( oFont )
   ENDIF

   RETURN Nil

STATIC FUNCTION EditRow( lNew )

   LOCAL oDlg, oBtn1, oBtn2, oBtnNull, oBtnIT, oBtnIB, oBtnE, oBtnSave, oLine, oDlgPreview, oEditPreview
   LOCAL lSavePreview := .F., aCtrl, nControls, nSel := 0, nFirst := 1, cQ
   LOCAL i, af, nCCount, aData, nTable := oBrw2:cargo, stmt
   LOCAL at := { "integer", "real", "text", "blob", "null", "" }
   LOCAL bSetNull := {||
      LOCAL n
      IF nSel > 0
         n := nFirst + nSel -1
         aCtrl[n,3]:SetText( cNull )
         aData[n,2] := SQLITE_NULL
         aData[n,3] := .T.
         aCtrl[n,2]:SetText( "("+at[aData[n,2]]+")" )
      ENDIF
      RETURN Nil
   }
   LOCAL bGetText := {||
      LOCAL n, cFile
      IF !Empty( cFile := hwg_Selectfile( "( *.* )", "*.*", CurDir() ) )
         n := nFirst + nSel - 1
         aData[n,1] := hb_Memoread( cFile )
         aData[n,2] := SQLITE_TEXT
         aData[n,3] := .T.
         aCtrl[n,2]:SetText( "("+at[SQLITE_TEXT]+")" )
         aCtrl[n,3]:SetText( aData[n,1] )
      ENDIF
      RETURN Nil
   }
   LOCAL bGetBlob := {||
      LOCAL n, cFile
      IF !Empty( cFile := hwg_Selectfile( "( *.* )", "*.*", CurDir() ) )
         n := nFirst + nSel - 1
         aData[n,4] := hb_Memoread( cFile )
         aData[n,2] := SQLITE_BLOB
         aData[n,3] := .T.
         aCtrl[n,2]:SetText( aData[n,1] := "("+UPPER(at[SQLITE_BLOB])+")" )
      ENDIF
      RETURN Nil
   }
   LOCAL bPut := {||
      LOCAL cFile
#ifdef __PLATFORM__UNIX
      cFile := hwg_Selectfile( "( *.* )", "*.*", CurDir() )
#else
      cFile := hwg_Savefile( "*.*", "( *.* )", "*.*", CurDir() )
#endif
      IF !Empty( cFile )
         hb_Memowrit( cFile, aData[nFirst+nSel-1,1] )
      ENDIF
      RETURN Nil
   }
   LOCAL bFocus := {|o,id|
      LOCAL oEdit := o:FindControl(id), n, s
      IF nSel > 0
         n := nFirst + nSel -1
         aCtrl[nSel,1]:SetText( af[n,1]+"  " )
         aCtrl[nSel,1]:SetColor( 0,,.T. )
         aCtrl[nSel,2]:SetColor( 0,,.T. )
         aCtrl[nSel,3]:SetColor( ,CLR_LIGHT1,.T. )
         IF !( ( s := aCtrl[nSel,3]:GetText() ) == aData[n,1] )
            aData[n,1] := s
            aData[n,3] := .T.
         ENDIF
      ELSE
         hwg_Enablewindow( oBtnIT:handle, .T. )
         hwg_Enablewindow( oBtnIB:handle, .T. )
         hwg_Enablewindow( oBtnE:handle, .T. )
      ENDIF
      nSel := oEdit:cargo
      n := nFirst + nSel -1
      aCtrl[nSel,1]:SetText( af[n,1]+" >" )
      aCtrl[nSel,1]:SetColor( CLR_GREEN,,.T. )
      aCtrl[nSel,2]:SetColor( CLR_GREEN,,.T. )
      aCtrl[nSel,3]:SetColor( ,CLR_WHITE,.T. )
      hwg_Enablewindow( oBtnNull:handle, !af[n,4] .AND. aData[n,2] != SQLITE_NULL )
      RETURN Nil
   }
   LOCAL bButtons := {|o,l|
      hwg_Enablewindow( oBtn1:handle, (nFirst > 1) )
      hwg_Enablewindow( oBtn2:handle, (nCCount-nFirst+1 > nControls) )
      IF Empty( l ) 
         hwg_Enablewindow( oBtnNull:handle, .F. )
         hwg_Enablewindow( oBtnIT:handle, .F. )
         hwg_Enablewindow( oBtnIB:handle, .F. )
         hwg_Enablewindow( oBtnE:handle, .F. )
         IF oDb:lRdOnly .OR. oBrw2:cargo == 0
            hwg_Enablewindow( oBtnSave:handle, .F. )
         ENDIF
      ENDIF
      RETURN Nil
   }
   LOCAL bCreate := {|i1|
      LOCAL j1 := nFirst + i1 -1
      aCtrl[i1] := { Nil, Nil, Nil }
      @ 10, 40 + (i1-1)*56 SAY aCtrl[i1,1] CAPTION af[j1,1]+"  " SIZE 110,24 STYLE SS_RIGHT
      @ 10, 64 + (i1-1)*56 SAY aCtrl[i1,2] CAPTION "("+at[aData[j1,2]]+")" SIZE 110, 24 STYLE SS_RIGHT
      @ 120,40 + (i1-1)*56 EDITBOX aCtrl[i1,3] CAPTION aData[j1,1] SIZE 470,52 STYLE ES_MULTILINE ;
         BACKCOLOR CLR_LIGHT1 FONT _oFont ON SIZE ANCHOR_LEFTABS + ANCHOR_RIGHTABS ON GETFOCUS bFocus
      aCtrl[i1,3]:cargo := i1
      RETURN Nil
   }
   LOCAL bSet := {|i1|
      LOCAL j1 := nFirst + i1 -1
      aCtrl[i1,1]:SetText( af[j1,1]+"  " )
      aCtrl[i1,2]:SetText( "("+at[aData[j1,2]]+")" )
      aCtrl[i1,3]:SetText( aData[j1,1] )
      RETURN Nil
   }
   LOCAL bResize := {|o,x,y|
      LOCAL nNew := Min( nCCount-nFirst+1, Int( (oLine:nTop-44)/56 ) )
      IF nNew != nControls
         IF nNew < nControls
            FOR i := Max( nNew+1,2 ) TO nControls
               aCtrl[i,1]:Hide()
               aCtrl[i,2]:Hide()
               aCtrl[i,3]:Hide()
            NEXT
         ELSEIF nNew > nControls
            IF nNew > Len( aCtrl )
               ASize( aCtrl, nNew )
            ENDIF
            FOR i := nControls+1 TO nNew
               IF Empty( aCtrl[i] )
                  Eval( bCreate, i )
               ELSE
                  aCtrl[i,1]:Show()
                  aCtrl[i,2]:Show()
                  aCtrl[i,3]:Show()
                  Eval( bSet, i )
               ENDIF
            NEXT
         ENDIF
         nControls := nNew
         Eval( bButtons, oDlg, .T. )
      ENDIF
      RETURN .T.
   }
   LOCAL bNext := {||
      LOCAL i1, j1
      nFirst += nControls
      FOR i1 := 1 TO nControls
         IF ( j1 := ( nFirst + i1 -1 ) ) <= nCCount
            Eval( bSet, i1 )
         ELSE
            aCtrl[i1,1]:Hide()
            aCtrl[i1,2]:Hide()
            aCtrl[i1,3]:Hide()
         ENDIF
      NEXT
      Eval( bButtons, oDlg, .T. )
      RETURN Nil
   }
   LOCAL bPrev := {||
      LOCAL i1
      nFirst -= nControls
      IF nFirst < 1
         nFirst := 1
      ENDIF
      FOR i1 := 1 TO nControls
         IF aCtrl[i1,1]:lHide
            aCtrl[i1,1]:Show()
            aCtrl[i1,2]:Show()
            aCtrl[i1,3]:Show()
         ENDIF
         Eval( bSet, i1 )
      NEXT
      IF Min( nCCount-nFirst+1, Int( (oLine:nTop-44)/56 ) ) < nControls
         Eval( bButtons, oDlg, .T. )
      ENDIF
      Eval( bResize, oDlg, 0, oDlg:nHeight )
      RETURN Nil
   }
   LOCAL bSave := {||
      LOCAL i1, cv, cVal, nRes, n, s, l := .F.
      IF lNew
         cQ := "INSERT INTO " + oDb:aTables[nTable,1] + " ("
         cv := " VALUES ("
      ELSE
         cQ := "UPDATE "  + oDb:aTables[nTable,1] + " SET "
      ENDIF
      IF nSel > 0
         n := nFirst + nSel -1
         IF !( ( s := aCtrl[nSel,3]:GetText() ) == aData[n,1] )
            aData[n,1] := s
            aData[n,3] := .T.
         ENDIF
      ENDIF
      FOR i1 := 1 TO nCCount
         IF !Empty( aData[i1,3] )
            IF aData[i1,2] == SQLITE_INTEGER .OR. aData[i1,2] == SQLITE_FLOAT
               cVal := aData[i1,1]
            ELSEIF aData[i1,2] == SQLITE_TEXT .OR. aData[i1,2] == 6
               cVal := "'" + aData[i1,1] + "'"
            ELSEIF aData[i1,2] == SQLITE_BLOB
               cVal := "x'" + Blob2Hex( aData[i1,4] ) + "'"
            ELSEIF aData[i1,2] == SQLITE_NULL .AND. aData[i1,1] == cNull
               cVal := "NULL"
            ENDIF
            IF lNew
               cQ += Iif( l, ",", "" ) + af[i1,1]
               cv += Iif( l, ",", "" ) + cVal
            ELSE
               cQ += Iif( l, ",", "" ) + af[i1,1] + "=" + cVal
            ENDIF
            l := .T.
         ENDIF
      NEXT
      IF !l
         hwg_MsgStop( "Nothing to save!" )
         RETURN Nil
      ENDIF
      IF lNew
         cQ += " )" + cv + " )"
      ELSE
         cQ += oBq:KeyWhere( oBrw2:aArray[oBrw2:nCurrent] )
      ENDIF
      IF lSavePreview
         INIT DIALOG oDlgPreview TITLE "Save query" AT 100, 100 SIZE 400, 200 FONT HWindow():GetMain():oFont
         oEditPreview := HCEdit():New( ,,, 10, 10, 380, 120, _oFont,, ANCHOR_TOPABS + ANCHOR_BOTTOMABS + ANCHOR_LEFTABS + ANCHOR_RIGHTABS )
         oEditPreview:SetWrap( .T. )
         SetHili( oEditPreview )
         oEditPreview:SetText( cQ )

         @ 50, 150 BUTTON "Run" SIZE 100, 30 ON CLICK { ||oDlgPreview:lResult := .T., cQ := oEditPreview:GetText(), hwg_EndDialog() }
         @ 250, 150 BUTTON "Cancel" SIZE 100, 30 ON CLICK { ||hwg_EndDialog() }
         ACTIVATE DIALOG oDlgPreview
         IF !oDlgPreview:lResult
            cQ := ""
         ENDIF
      ENDIF
      IF !Empty( cQ )
         sqlite3_exec( oDb:dbHandle, cQ )
         IF ( nRes := sqlite3_errcode( oDb:dbHandle ) ) == SQLITE_OK .OR. nRes == SQLITE_DONE
            hwg_MsgInfo( hb_ntos( sqlite3_changes( oDb:dbHandle ) ), "The number of rows changed" )
            IF !lNew
               FOR i1 := 1 TO nCCount
                  IF !Empty( aData[i1,3] )
                     oBq:SetCell( i1, aData[i1,1], aData[i1,2] )
                  ENDIF
               NEXT
               oBrw2:Refresh()
            ENDIF
            hwg_EndDialog()
         ELSE
            hwg_MsgStop( sqlite3_errmsg(oDb:dbHandle), "Error " + Ltrim(Str(nRes)) )
         ENDIF
      ENDIF
      RETURN Nil
   }

   af := GetTblStru( oDb:aTables[nTable,2] )
   aData := Array( nCCount := Len( af ),4 )
   IF lNew
      FOR i := 1 TO nCCount
         aData[i,1] := ""
         aData[i,2] := Ascan( at, af[i,2] )
         IF aData[i,2] == 0
            aData[i,2] := 6
         ENDIF
      NEXT
   ELSEIF !Empty( stmt := sqlite3_prepare( oDb:dbHandle, ;
         "SELECT * FROM "+ oDb:aTables[nTable,1] + oBq:KeyWhere( oBrw2:aArray[oBrw2:nCurrent] ) ) )
      IF sqlite3_step( stmt ) == SQLITE_ROW
         FOR i := 1 TO nCCount
            aData[i,2] := sqlite3_column_type( stmt, i )
            IF aData[i,2] == SQLITE_BLOB
               aData[i,4] := sqlite3_column_text( stmt, i )
               aData[i,1] := "(BLOB)"
            ELSEIF aData[i,2] == SQLITE_INTEGER
               aData[i,1] := Ltrim( Str( sqlite3_column_int( stmt, i ) ) )
            ELSEIF aData[i,2] == SQLITE_FLOAT
               aData[i,1] := Ltrim( Str( sqlite3_column_double( stmt, i ) ) )
            ELSEIF aData[i,2] == SQLITE_NULL
               aData[i,1] := cNull
            ELSEIF aData[i,2] == SQLITE_TEXT
               aData[i,1] := sqlite3_column_text( stmt, i )
            ENDIF
         NEXT
      ENDIF
      sqlite3_finalize( stmt )
   ELSE
      hwg_MsgStop( "Read Error!" )
      RETURN Nil
   ENDIF

   INIT DIALOG oDlg TITLE "Edit row" ;
      AT 0, 0 SIZE 600, 480 FONT HWindow():GetMain():oFont ;
      ON SIZE bResize

   @ 4, 4 BUTTON oBtn1 CAPTION "<" SIZE 28, 28 TOOLTIP "Page Up" ON CLICK bPrev
   @ 32, 4 BUTTON oBtn2 CAPTION ">" SIZE 28, 28 TOOLTIP "Page Down" ON CLICK bNext
   @ 64, 2 LINE LENGTH 32 VERTICAL
   @ 68, 4 BUTTON oBtnNull CAPTION "U" SIZE 28, 28 TOOLTIP "Set NULL" ON CLICK bSetNull
   @ 100,2 LINE LENGTH 32 VERTICAL
   @ 104,4 BUTTON oBtnIT CAPTION "Get text" SIZE 100, 28 TOOLTIP "Import as text" ON CLICK bGetText
   @ 204,4 BUTTON oBtnIB CAPTION "Get blob" SIZE 100, 28 TOOLTIP "Import as blob" ON CLICK bGetBlob
   @ 308,2 LINE LENGTH 32 VERTICAL
   @ 312,4 BUTTON oBtnE CAPTION "Put" SIZE 50, 28 TOOLTIP "Import as text" ON CLICK bPut

   @ 4, 36 LINE LENGTH 582 ON SIZE ANCHOR_TOPABS + ANCHOR_LEFTABS + ANCHOR_RIGHTABS
   @ 4, 440 LINE oLine LENGTH 582 ON SIZE ANCHOR_BOTTOMABS + ANCHOR_LEFTABS + ANCHOR_RIGHTABS

   nControls := Min( nCCount, Int( (oLine:nTop-44)/56 ) )
   aCtrl := Array( nControls )

   FOR i := 1 TO nControls
      Eval( bCreate, i )
   NEXT

   @ 20,448 GET CHECKBOX lSavePreview CAPTION "" SIZE 16, 24 TOOLTIP "Preview SQL query"
   @ 40,448 BUTTON oBtnSave CAPTION "Save" SIZE 80, 28 TOOLTIP "Save changes" ON CLICK bSave ON SIZE ANCHOR_BOTTOMABS + ANCHOR_LEFTABS
   @ 210,448 BUTTON "< Row" SIZE 80, 28 TOOLTIP "Previous row" ON CLICK {||.t.} ON SIZE ANCHOR_BOTTOMABS + ANCHOR_LEFTABS
   @ 310,448 BUTTON "Row >" SIZE 80, 28 TOOLTIP "Next row" ON CLICK {||.t.} ON SIZE ANCHOR_BOTTOMABS + ANCHOR_RIGHTABS
   @ 480,448 BUTTON "Close" SIZE 80, 28 ON CLICK {||hwg_EndDialog()} ON SIZE ANCHOR_BOTTOMABS + ANCHOR_RIGHTABS

   ACTIVATE DIALOG oDlg ON ACTIVATE bButtons

   RETURN Nil

STATIC FUNCTION About()

   LOCAL oDlg

   INIT DIALOG oDlg TITLE "About" ;
      AT 0, 0 SIZE 400, 330 FONT HWindow():GetMain():oFont STYLE DS_CENTER

   @ 20, 40 SAY "SQLite database manager" SIZE 360,26 STYLE SS_CENTER COLOR CLR_VDBLUE
   @ 20, 64 SAY "Version "+APP_VERSION SIZE 360,26 STYLE SS_CENTER COLOR CLR_VDBLUE
   @ 20, 100 SAY "Copyright 2014 Alexander S.Kresin" SIZE 360,26 STYLE SS_CENTER COLOR CLR_VDBLUE
   @ 20, 124 SAY "http://www.kresin.ru" LINK "http://www.kresin.ru" SIZE 360,26 STYLE SS_CENTER
   @ 20, 160 LINE LENGTH 360
   @ 20, 180 SAY "SQLite library version: "+sqlite3_libversion() SIZE 360,26 STYLE SS_CENTER COLOR CLR_DBLUE

   @ 150, 250 BUTTON "Close" SIZE 100, 32 ON CLICK { ||hwg_EndDialog() } ON SIZE ANCHOR_BOTTOMABS + ANCHOR_RIGHTABS + ANCHOR_LEFTABS

   ACTIVATE DIALOG oDlg

   RETURN Nil


CLASS HSQLT

   DATA dbHandle
   DATA cdbName
   DATA aTables
   DATA lExcl, lRdOnly

   METHOD Open( cdbName, lExcl, lRdonly )
   METHOD New( cdbName )
   METHOD GetTables()
   METHOD GetObjects( cType )

ENDCLASS

METHOD Open( cdbName, lExclusive, lRdonly ) CLASS HSQLT

   LOCAL nMod := 0

   nMod += iif( lExclusive, SQLITE_OPEN_EXCLUSIVE, 0 )
   nMod += iif( lRdonly, SQLITE_OPEN_READONLY, SQLITE_OPEN_READWRITE )

   IF Empty( cdbName ) .OR. Empty( ::dbHandle := sqlite3_open_v2( cdbName, nMod ) )
      RETURN Nil
   ENDIF
   ::cdbName := cdbName
   ::lExcl := lExclusive
   ::lRdOnly := lRdonly

   RETURN Self

METHOD New( cdbName ) CLASS HSQLT

   IF Empty( cdbName ) .OR. Empty( ::dbHandle := sqlite3_open( cdbName, .T. ) )
      RETURN Nil
   ENDIF
   ::cdbName := cdbName
   ::aTables := {}
   ::lExcl := .T.
   ::lRdOnly := .F.

   RETURN Self

METHOD GetTables() CLASS HSQLT

   LOCAL arr, i, j

   arr := sqlite3_get_table( ::dbHandle, "SELECT name,sql FROM sqlite_master WHERE type='table'" )
   ::aTables := {}
   FOR i := 2 TO Len( arr )
      IF Left( arr[i,1], 7 ) != "sqlite_"
         AAdd( ::aTables, { arr[i,1], arr[i,2] } )
      ENDIF
   NEXT
   ASort( ::aTables,,, {|a1,a2|a1[1]<a2[1]} )

   Return ::aTables

METHOD GetObjects( cType, cTblName ) CLASS HSQLT

   LOCAL arr, cWhere := ""

   IF !Empty( cTblName )
      IF Empty( ::aTables )
         ::GetTables()
      ENDIF
      IF Ascan( ::aTables,{ |a|a[1] == cTblName } ) == 0
         RETURN {}
      ENDIF
   ENDIF

   IF !Empty( cType ) .OR. !Empty( cTblName )
      cWhere := " WHERE "
      cWhere += Iif( Empty(cType), "", " type='" + cType +"'" )
      cWhere += Iif( Empty(cTblName), "", Iif( Empty(cType), "", " AND" ) + " tbl_name='" + cTblName +"'" )
   ENDIF
   arr := sqlite3_get_table( ::dbHandle, "SELECT " + Iif( Empty(cType),"type,","" ) + ;
         "name,tbl_name,sql FROM sqlite_master" + cWhere )

   ADel( arr, 1 )
   ASize( arr, Len(arr)-1 )

   Return arr

STATIC FUNCTION FontFromXML( oXmlNode )

   LOCAL width  := oXmlNode:GetAttribute( "width" )
   LOCAL height := oXmlNode:GetAttribute( "height" )
   LOCAL weight := oXmlNode:GetAttribute( "weight" )
   LOCAL charset := oXmlNode:GetAttribute( "charset" )
   LOCAL ita   := oXmlNode:GetAttribute( "italic" )
   LOCAL under := oXmlNode:GetAttribute( "underline" )

   IF width != Nil
      width := Val( width )
   ENDIF
   IF height != Nil
      height := Val( height )
   ENDIF
   IF weight != Nil
      weight := Val( weight )
   ENDIF
   IF charset != Nil
      charset := Val( charset )
   ENDIF
   IF ita != Nil
      ita := Val( ita )
   ENDIF
   IF under != Nil
      under := Val( under )
   ENDIF

   RETURN HFont():Add( oXmlNode:GetAttribute( "name" ),  ;
      width, height, weight, charset, ita, under,,,.T. )

STATIC FUNCTION FontToXML( oFont )

   LOCAL aAttr := {}

   AAdd( aAttr, { "name", oFont:name } )
   AAdd( aAttr, { "width", LTrim( Str(oFont:width,5 ) ) } )
   AAdd( aAttr, { "height", LTrim( Str(oFont:height,5 ) ) } )
   IF oFont:weight != 0
      AAdd( aAttr, { "weight", LTrim( Str(oFont:weight,5 ) ) } )
   ENDIF
   IF oFont:charset != 0
      AAdd( aAttr, { "charset", LTrim( Str(oFont:charset,5 ) ) } )
   ENDIF
   IF oFont:Italic != 0
      AAdd( aAttr, { "italic", LTrim( Str(oFont:Italic,5 ) ) } )
   ENDIF
   IF oFont:Underline != 0
      AAdd( aAttr, { "underline", LTrim( Str(oFont:Underline,5 ) ) } )
   ENDIF

   RETURN HXMLNode():New( "font", HBXML_TYPE_SINGLE, aAttr )

STATIC FUNCTION BtnEnable( lEnable, arr )

   LOCAL i, j := 0

   FOR i := 1 TO Len( oPanel:aControls )
      IF oPanel:aControls[i]:winclass == "BUTTON"
         j ++
         IF Empty( arr ) .OR. Ascan( arr, j ) != 0
            hwg_Enablewindow( oPanel:aControls[i]:handle, lEnable )
         ENDIF
      ENDIF
   NEXT

   RETURN Nil

STATIC FUNCTION MenuEnable( arr, lEnable )

   LOCAL i

   FOR i := 1 TO Len( arr )
      hwg_Enablemenuitem( , arr[i], lEnable, .T. )
   NEXT
   hwg_Drawmenubar( HWindow():GetMain():handle )

   RETURN Nil

FUNCTION FSayNum( cText )

   oSayNum:SetText( PAdr( cText, 16 ) )
   hwg_Redrawwindow( oPanel:handle, RDW_ERASE + RDW_INVALIDATE + RDW_INTERNALPAINT + RDW_UPDATENOW )

   RETURN Nil

FUNCTION SetHili( oEdit )

   LOCAL oHiliMod

   oHiliMod := HXMLNode():New( "module" )
   oHiliMod:Add( HXMLNode():New( "keywords",,,"select distinct all from where group having values order by desc limit offset insert set update alter create drop index table trigger view virtual delete begin end transaction commit rollback pragma reindex release savepoint vacuum with explain temp temporary on if not exists and or null integer text real blob without rowid primary key" ) )
   oHiliMod:Add( HXMLNode():New( "functions",,,"avg count max min sum total date time datetime" ) )
   oEdit:HighLighter( Hilight():New( oHiliMod ) )
   oEdit:SetHili( HILIGHT_KEYW, oEdit:oFont:SetFontStyle( .T. ), 8388608, oEdit:bColor )
   oEdit:SetHili( HILIGHT_FUNC, - 1, 8388608, 16777215 )
   oEdit:SetHili( HILIGHT_QUOTE, - 1, 16711680, 16777215 )

   RETURN Nil

STATIC FUNCTION Add2Recent( cFile )

   LOCAL i, j

   IF ( i := Ascan( _aRecent, cFile ) ) == 0
      IF Len( _aRecent ) < MAX_RECENT_FILES
         Aadd( _aRecent, Nil )
      ENDIF
      AIns( _aRecent, 1 )
      _aRecent[1] := cFile
      _lOptChg := .T.
   ELSEIF i > 1
      FOR j := i TO 2 STEP -1
         _aRecent[j] := _aRecent[j-1]
      NEXT
      _aRecent[1] := cFile
      _lOptChg := .T.
   ENDIF

   RETURN Nil

STATIC FUNCTION Add2His( cFile, cQ )

   LOCAL i, j, j1, arr

   IF Empty( _aHistory )
      ReadHistory( cExePath )
   ENDIF
      
   IF ( i := Ascan( _aHistory, {|a|a[1]==cFile} ) ) == 0
      IF Len( _aHistory ) < MAX_RECENT_FILES
         Aadd( _aHistory, Nil )
      ENDIF
      AIns( _aHistory, 1 )
      _aHistory[1] := { cFile, { cQ } }
      _lHisChg := .T.
   ELSE
      arr := _aHistory[i,2]
      IF ( j := Ascan( arr, cQ ) ) == 0
         IF Len( arr ) < MAX_RECENT_QUERIES
            Aadd( arr, Nil )
         ENDIF
         AIns( arr, 1 )
         arr[1] := cQ
         _lHisChg := .T.
      ELSEIF j > 1
         FOR j1 := j TO 2 STEP -1
            arr[j1] := arr[j1-1]
         NEXT
         arr[1] := cQ
         _lHisChg := .T.
      ENDIF
   ENDIF

   RETURN Nil

FUNCTION sqlGetField( stmt, i )

   LOCAL nCType := sqlite3_column_type( stmt, i ), value

   SWITCH nCType
   CASE SQLITE_BLOB
      value := "(BLOB)"
      EXIT
   CASE SQLITE_INTEGER
      value := Ltrim( Str( sqlite3_column_int( stmt, i ) ) )
      EXIT
   CASE SQLITE_FLOAT
      value := Ltrim( Str( sqlite3_column_double( stmt, i ) ) )
      EXIT
   CASE SQLITE_NULL
      value := cNull
      EXIT
   CASE SQLITE_TEXT
      value := sqlite3_column_text( stmt, i )
      IF Len( value ) > QUE_TEXT_MAX
         IF nLimitText == Nil
            IF hwg_MsgYesNo( "The text length in a field exceeds " + Ltrim(Str(QUE_TEXT_MAX)) + " bytes." + Chr(13)+Chr(10) + "Truncate it ?" )
               nLimitText := 1
            ELSE
               nLimitText := 2
            ENDIF
         ENDIF
         IF nLimitText == 1
            value := Left( value, QUE_TEXT_MAX )
         ENDIF
      ENDIF
      EXIT
   ENDSWITCH

   RETURN value
