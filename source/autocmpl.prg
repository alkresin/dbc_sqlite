/*  $Id: $
/*
 * dbc_SQLite - SQLite database manager
 * Autocompletition routines
 *
 * Copyright 2014 Alexander S.Kresin <alex@kresin.ru>
 * www - http://www.kresin.ru
*/

#include "hwgui.ch"

FUNCTION AutoDop( oEdit, nKey, nCtrl, oDb )

   LOCAL nLine, nPos, cQ, cTemp, cCurr, i, arr, nLen, aRes := {}
   LOCAL aCmd := { "alter", "analyze", "attach", "begin transaction", ;
      "commit transaction", "create", "delete", "detach", "drop", ;
      "end transaction", "insert into", "pragma", "reindex", "replace into", ;
      "rollback transaction", "select", "update", "vacuum" }
   LOCAL aCreate := { "index", "table", "trigger", "view", "virtual table" }
   LOCAL aDrop := { "index", "table", "trigger", "view" }

   IF nKey != VK_TAB
      RETURN -1
   ENDIF

   nLine := oEdit:aPointC[2]
   nPos  := oEdit:aPointC[1]

   cQ := oEdit:aText[nLine]
   FOR i := nLine-1 TO 1 STEP -1
      IF Right( cTemp := AllTrim( oEdit:aText[i] ) ) != ";"
         cQ := cTemp + cQ
         nPos += Len( cTemp )
      ENDIF
   NEXT

   IF !Empty( Substr(cQ,nPos,1) ) .OR. Empty( Substr(cQ,nPos-1,1) )
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
            Aadd( aRes, "VALUES ( " )
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
               Aadd( aRes, "IF EXISTS " )
            ENDIF
         ELSEIF Len( arr ) == 4
            IF arr[Len(arr)-1] == "if" .AND. "exists" = cCurr
               Aadd( aRes, "EXISTS " )
            ENDIF
         ELSEIF ( Len( arr ) == 5 .AND. arr[3] == "if" )
            aRes := Auto_table( oDb,cCurr )
         ENDIF
      ENDIF
   ENDIF

   IF Empty( aRes )
      RETURN 0
   ELSEIF Len( aRes ) == 1
      nPos := oEdit:aPointC[1]
      oEdit:InsText( { nPos-nLen,nLine }, Left( aRes[1], nLen ), .T. )
      oEdit:InsText( oEdit:aPointC, Substr( aRes[1], nLen+1 ) )
   ENDIF
   
   RETURN 0

STATIC FUNCTION Auto_keyw( arr, cCurr )

   LOCAL i := 1, aRes := {}

   DO WHILE ( i := Ascan( arr, cCurr, i ) ) != 0
      Aadd( aRes, Upper(arr[i])+' ' )
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
