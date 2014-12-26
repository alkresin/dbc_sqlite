/*
 * dbc_SQLite - SQLite database manager
 * Table structure handling, based on dbchw ( Hwgui utility for dbf management )
 *
 * Copyright 2001-2014 Alexander S.Kresin <alex@kresin.ru>
 * www - http://www.kresin.ru
*/

#include "hbsqlit3.ch"
#include "hwgui.ch"

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

STATIC oBrowse, oGet0, oGet1, oGet2, oGet3, oGet4, oGet5, oEdit, lRes
STATIC aTypes := { "", "integer", "real", "text", "blob" }
MEMVAR oBrw, currentCP, currFname
Memvar _oFont

FUNCTION StruMan( oDb, lNew, nTable )

   LOCAL oDlg
   LOCAL af, af0, cName := "", nType := 1, lPK := .F., lNotNull := .F., cDef := "", i, cTblName := ""
   LOCAL bChgPos := { |o|
      oGet1:SetGet( o:aArray[o:nCurrent,1] )
      oGet2:SetItem( Ascan( aTypes,o:aArray[o:nCurrent,2] ) )
      Eval( oGet3:bSetGet, o:aArray[o:nCurrent,3], oGet3 )
      Eval( oGet4:bSetGet, o:aArray[o:nCurrent,4], oGet4 )
      oGet5:SetGet( o:aArray[o:nCurrent,5] )
      hwg_RefreshAllGets( oDlg )
      RETURN Nil
   }
   LOCAL bOnAct := {||
      IF !lNew
         hwg_Enablewindow( oGet0:handle, .F. )
         oEdit:SetText( oDb:aTables[nTable,2] )
      ENDIF
      RETURN Nil
   }

   lRes := .F.
   IF lNew
      af := { { "","",.F.,.F.,"" } }
   ELSE
      af := GetTblStru( oDb:aTables[nTable,2] )
      cTblName := oDb:aTables[nTable,1]
   ENDIF

   INIT DIALOG oDlg TITLE Iif( oDb:lRdOnly, "View structure", Iif( lNew, "Create", "Modify" ) + " table" ) ;
      AT 0, 0 SIZE 600, 480 FONT HWindow():GetMain():oFont

   @ 10,16 SAY "Table name:" SIZE 120, 24
   @ 130, 16 GET oGet0 VAR cTblName SIZE 260, 24
   @ 10, 50 BROWSE oBrowse ARRAY SIZE 580, 190 ON POSCHANGE bChgPos ON SIZE ANCHOR_LEFTABS + ANCHOR_RIGHTABS

   oBrowse:tcolor := 0
   oBrowse:bcolor := CLR_LIGHT1
   oBrowse:bcolorSel := oBrowse:htbcolor := CLR_DBLUE

   oBrowse:aArray := af
   oBrowse:AddColumn( HColumn():New( "",{ |v,o|o:nCurrent },"N",4,0 ) )
   oBrowse:AddColumn( HColumn():New( "Name",{ |v,o|o:aArray[o:nCurrent,1] },"C",32,0 ) )
   oBrowse:AddColumn( HColumn():New( "Type",{ |v,o|o:aArray[o:nCurrent,2] },"C",8,0 ) )
   oBrowse:AddColumn( HColumn():New( "PK",{ |v,o|Iif(o:aArray[o:nCurrent,3],"Yes","") },"C",4,0 ) )
   oBrowse:AddColumn( HColumn():New( "Not NULL",{ |v,o|Iif(o:aArray[o:nCurrent,4],"Yes","") },"C",4,0 ) )
   oBrowse:AddColumn( HColumn():New( "Default",{ |v,o|o:aArray[o:nCurrent,5] },"C",32,0 ) )

   @ 20,260 SAY "Name:" SIZE 60, 24
   @ 80, 260 GET oGet1 VAR cName SIZE 100, 24
   @ 210, 260 GET COMBOBOX oGet2 VAR nType ITEMS aTypes SIZE 100, 24 DISPLAYCOUNT 5
   @ 320, 260 GET CHECKBOX oGet3 VAR lPK CAPTION "Primary" SIZE 110, 24
   @ 430, 260 GET CHECKBOX oGet4 VAR lNotNull CAPTION "Not NULL" SIZE 110, 24
   @ 20,290 SAY "Default value:" SIZE 120, 24
   @ 140, 290 GET oGet5 VAR cDef SIZE 200, 24

   IF !oDb:lRdOnly .AND. oDb:lExcl

      @ 28, 330 BUTTON "Add"     SIZE 80, 30 ON CLICK { ||UpdStru( 1 ) }
      @ 136,330 BUTTON "Insert"  SIZE 80, 30 ON CLICK { ||UpdStru( 2 ) }
      @ 246,330 BUTTON "Replace" SIZE 80, 30 ON CLICK { ||UpdStru( 3 ) }
      @ 356,330 BUTTON "Remove"  SIZE 80, 30 ON CLICK { ||UpdStru( 4 ) }

      @ 100,430 BUTTON Iif( lNew, "Create", "Modify" ) SIZE 100, 30 ON CLICK {||DoSave(oDb,lNew)} ON SIZE ANCHOR_BOTTOMABS + ANCHOR_LEFTABS
   ENDIF

   oEdit := HCEdit():New( ,,, 10, 370, 580, 50, _oFont,, ANCHOR_TOPABS + ANCHOR_BOTTOMABS + ANCHOR_LEFTABS + ANCHOR_RIGHTABS )
   oEdit:SetWrap( .T. )
   SetHili( oEdit )

   @ 400, 430 BUTTON "Close" SIZE 100, 30 ON CLICK { ||hwg_EndDialog() } ON SIZE ANCHOR_BOTTOMABS + ANCHOR_RIGHTABS

   ACTIVATE DIALOG oDlg ON ACTIVATE bOnAct

   RETURN lRes

STATIC FUNCTION UpdStru( nOperation )

   LOCAL cName, cType, lPK, lNotNull, cDef

   IF nOperation == 4
      IF oBrowse:nRecords > 1
         ADel( oBrowse:aArray, oBrowse:nCurrent )
         oBrowse:aArray := ASize( oBrowse:aArray, Len( oBrowse:aArray ) - 1 )
         IF oBrowse:nCurrent < Len( oBrowse:aArray ) .AND. oBrowse:nCurrent > 1
            oBrowse:nCurrent --
            oBrowse:RowPos --
         ENDIF
         oBrowse:nRecords --
      ENDIF
   ELSE
      IF Empty( cName := oGet1:SetGet() )
         RETURN Nil
      ENDIF
      cType := aTypes[ Eval(oGet2:bSetGet,,oGet2) ]
      lPk := Eval( oGet3:bSetGet,,oGet3 )
      lNotNull := Eval( oGet4:bSetGet,,oGet4 )
      cDef := oGet5:SetGet()
      IF oBrowse:nRecords == 1 .AND. Empty( oBrowse:aArray[oBrowse:nCurrent,1] )
         nOperation := 3
      ENDIF
      IF nOperation == 1
         AAdd( oBrowse:aArray, { cName, cType, lPk, lNotNull, cDef } )
      ELSE
         IF nOperation == 2
            AAdd( oBrowse:aArray, Nil )
            AIns( oBrowse:aArray, oBrowse:nCurrent )
            oBrowse:aArray[oBrowse:nCurrent] := { "","",.F.,.F.,"" }
         ENDIF
         oBrowse:aArray[oBrowse:nCurrent,1] := cName
         oBrowse:aArray[oBrowse:nCurrent,2] := cType
         oBrowse:aArray[oBrowse:nCurrent,3] := lPk
         oBrowse:aArray[oBrowse:nCurrent,4] := lNotNull
         oBrowse:aArray[oBrowse:nCurrent,5] := cDef
      ENDIF
   ENDIF
   oBrowse:Refresh()

   oEdit:SetText( Query_CreateTbl() )

   RETURN Nil

STATIC FUNCTION DoSave( oDb, lNew )

   LOCAL cTblName := oGet0:SetGet(), nRes

   IF lNew
      IF Empty( cTblName )
         hwg_MsgStop( "Table name is missed!" )
      ELSEIF Ascan( oDb:aTables,{ |a|a[1] == cTblName } ) != 0
         hwg_MsgStop( "Table " + cTblName + "  already exist" )
      ELSE
         sqlite3_exec( oDb:dbHandle, oEdit:GetText() )
         IF ( nRes := sqlite3_errcode( oDb:dbHandle ) ) == SQLITE_OK .OR. nRes == SQLITE_DONE
            hwg_MsgInfo( "Done!" )
            hwg_EndDialog()
            lRes := .T.
         ELSE
            hwg_MsgStop( sqlite3_errmsg(oDb:dbHandle), "Error " + Ltrim(Str(nRes)) )
         ENDIF
      ENDIF
   ELSE
   ENDIF

   RETURN Nil

STATIC FUNCTION Query_CreateTbl()
   LOCAL cQ := "CREATE TABLE " + oGet0:SetGet() + "("
   LOCAL i

   FOR i := 1 TO oBrowse:nRecords
      cQ += Trim( oBrowse:aArray[i,1] )
      IF !Empty( oBrowse:aArray[i,2] )
         cQ += " " + Upper( Trim( oBrowse:aArray[i,2] ) )
         IF oBrowse:aArray[i,3]
            cQ += " PRIMARY KEY"
         ENDIF
      ENDIF
      IF oBrowse:aArray[i,4]
         cQ += " NOT NULL"
      ENDIF
      IF !Empty( oBrowse:aArray[i,4] )
      ENDIF
      IF i != oBrowse:nRecords
         cQ += ","
      ENDIF
   NEXT

   cQ += ")"

   RETURN cQ

FUNCTION GetTblStru( cQ )

   LOCAL af := {}, nPos1, nPos2, nPos3, arr, i, cField, cType, lPK, lNotNull, cDef, cQuo

   IF Empty( cQ )
      RETURN af
   ENDIF
   IF Chr(13) $ cQ
      cQ := StrTran( cQ, Chr(13), " " )
   ENDIF
   IF Chr(10) $ cQ
      cQ := StrTran( cQ, Chr(10), " " )
   ENDIF

   IF ( nPos1 := At( '(', cQ ) ) > 0 .AND. ( nPos2 := find_z( Substr( cQ, nPos1 + 1 ),')' ) ) > 0
      arr := DivByComma( Substr( cQ, nPos1 + 1, nPos2 - 1 ) )
      FOR i := 1 TO Len( arr )
         arr[i] := Lower( AllTrim(arr[i]) )
         cType := cDef := ""
         lPK := lNotNull := .F.

         IF ( nPos1 := At( '(', arr[i] ) ) != 0 .AND. !( ' ' $ Left(arr[i],nPos1) )
            LOOP
         ENDIF
         IF ( nPos1 := At( ' ', arr[i] ) ) != 0
            cField := Left( arr[i], nPos1-1 )
            IF cField == "primary" .OR. cField == "check" .OR. cField == "unique" .OR. cField == "foreign"
               LOOP
            ENDIF
            arr[i] := Trim( Substr( arr[i], nPos1+1 ) )

            IF ( nPos1 := At( 'not ', arr[i] ) ) != 0 .AND. ;
                  ( nPos2 := At( 'null', arr[i] ) ) != 0 .AND. nPos2>nPos1
               lNotNull := .T.
               arr[i] := Left( arr[i],nPos1-1 ) + Substr( arr[i],nPos2+5 )
            ENDIF
            IF ( nPos1 := At( 'default ', arr[i] ) ) != 0
               nPos2 := nPos1 + 8
               DO WHILE nPos2<Len(arr[i]).AND.Substr( arr[i],nPos2,1 ) == " "; nPos2++; ENDDO
               IF ( cQuo := Substr( arr[i],nPos2,1 ) ) == "'" .OR. cQuo == '"'
                  nPos2 ++
                  IF ( nPos3 := hb_At( cQuo, arr[i], nPos2 ) ) != 0
                     cDef := Substr( arr[i], nPos2, nPos3-nPos2 )
                     arr[i] := Left( arr[i],nPos1-1 ) + Substr( arr[i],nPos3+1 )
                  ENDIF
               ELSE
                  nPos3 := nPos2+1
                  DO WHILE nPos3<Len(arr[i]).AND.Substr( arr[i],nPos3,1 ) != " "; nPos3++; ENDDO
                  cDef := Substr( arr[i], nPos2, nPos3-nPos2 )
                  arr[i] := Left( arr[i],nPos1-1 ) + Substr( arr[i],nPos3+1 )
               ENDIF
            ENDIF

            IF ( nPos1 := At( ' ', arr[i] ) ) != 0
               cType := Left( arr[i], nPos1-1 )
               arr[i] := Trim( Substr( arr[i], nPos1+1 ) )
               IF Left( arr[i],7 ) == "primary"
                  lPK := .T.
               ENDIF
            ELSE
               cType := arr[i]
            ENDIF
         ELSE
            cField := arr[i]
         ENDIF
         Aadd( af, { cField, Lower(cType), lPK, lNotNull, cDef } )
      NEXT
   ENDIF

   RETURN af

FUNCTION GetTblPK( cQ )

   LOCAL cPK := "", nPos1, nPos2, arr, i, cField

   IF Empty( cQ )
      RETURN ""
   ENDIF
   IF Chr(13) $ cQ
      cQ := StrTran( cQ, Chr(13), " " )
   ENDIF
   IF Chr(10) $ cQ
      cQ := StrTran( cQ, Chr(10), " " )
   ENDIF

   IF ( nPos1 := At( '(', cQ ) ) > 0 .AND. ( nPos2 := find_z( Substr( cQ, nPos1 + 1 ),')' ) ) > 0
      arr := DivByComma( Substr( cQ, nPos1 + 1, nPos2 - 1 ) )
      FOR i := 1 TO Len( arr )
         arr[i] := Lower( AllTrim(arr[i]) )
         IF ( nPos1 := At( ' ', arr[i] ) ) != 0
            cField := Left( arr[i], nPos1-1 )
            IF cField == "primary"
               IF ( nPos1 := At( '(', arr[i] ) ) > 0 .AND. ( nPos2 := find_z( Substr( arr[i], nPos1 + 1 ),')' ) ) > 0
                  arr := DivByComma( Substr( arr[i], nPos1 + 1, nPos2 - 1 ) )
                  FOR i := 1 TO Len( arr )
                     arr[i] := AllTrim(arr[i])
                     IF ( nPos1 := At( ' ', arr[i] ) ) != 0
                        arr[i] := Lower( AllTrim(arr[i]) )
                        cField := Left( arr[i], nPos1-1 )
                     ELSE
                        cField := arr[i]
                     ENDIF
                     cPK += Iif( Empty(cPK),"","," ) + cField
                  NEXT
               ENDIF
               EXIT
            ELSEIF "primary" $ arr[i]
               cPK := cField
               EXIT
            ENDIF
         ENDIF
      NEXT
      IF Empty( cPK )
         cPK := "rowid"
      ENDIF
   ENDIF

   RETURN cPK

STATIC FUNCTION DivByComma( s )
   LOCAL arr := {}, nPos

   DO WHILE ( nPos := find_z( s, ',' ) ) > 0
      Aadd( arr, Left( s, nPos-1 ) )
      s := Substr( s, nPos+1 )
   ENDDO
   Aadd( arr, s )

   RETURN arr
