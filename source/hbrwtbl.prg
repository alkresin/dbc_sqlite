/*  $Id: $
 *
 * dbc_SQLite - SQLite database manager
 * HBrwTable class - browse of a table
 *
 * Copyright 2001-2014 Alexander S.Kresin <alex@kresin.ru>
 * www - http://www.kresin.ru
*/

#include "hbclass.ch"
#include "hbsqlit3.ch"
#include "hwgui.ch"

#define QUE_TEXT_MAX       72

Memvar nLimitText

CLASS HBrwTable

   DATA oBrw
   DATA DbHandle
   DATA nQueLimit  INIT 192
   DATA nQueStep   INIT 64
   DATA cTblName
   DATA cTblSQL
   DATA cTblPK, aTblPK, cTblPKDesc
   DATA lRowid
   DATA aFlds
   DATA cBaseQ
   DATA lFirst     INIT .T.
   DATA lLast      INIT .F.
   DATA nIdMaxR, nIdMinR
   DATA nRows      INIT 0

   METHOD New( dbHandle, cTblName, oBrw )

   METHOD ReadFirst()
   METHOD ReadLast()
   METHOD ReadNext()
   METHOD ReadPrev()

   METHOD Skip( n )
   METHOD Top()
   METHOD Bottom()
   METHOD Eof()
   METHOD Bof()
   METHOD RCou()
   METHOD RecNo()

   METHOD KeyCompare( xKey1, xKey2 )
   METHOD KeyVal( aRow )
   METHOD KeyWhere( aRow )

   METHOD SetCell( nCell, cValue, nType )

ENDCLASS

METHOD New( dbHandle, cTblName, oBrw ) CLASS HBrwTable

   LOCAL stmt, cQ, i, aFlds, nCCount, arr

   ::DbHandle := DbHandle
   ::cTblName := cTblName

   arr := sqlite3_get_table( ::DbHandle, "SELECT sql FROM sqlite_master WHERE type='table' AND name='" + cTblName +"'" )
   IF Empty( arr ) .OR. Len(arr) < 2
      RETURN Nil
   ENDIF
   ::cTblSQL := Lower( arr[2,1] )
   ::lRowid  := !( "without" $ ::cTblSQL )
   ::cTblPK  := GetTblPK( ::cTblSQL )

   ::oBrw := oBrw
   oBrw:bSkip   := { | o, n | ::Skip( n ) }
   oBrw:bGoTop  := { | o | ::Top() }
   oBrw:bGoBot  := { | o | ::Bottom() }
   oBrw:bEof    := { | o | ::Eof() }
   oBrw:bBof    := { | o | ::Bof() }
   oBrw:bRcou   := { | o | ::RCou() }
   oBrw:bRecno  := { | o | ::RecNo() }

   stmt := sqlite3_prepare( ::DbHandle, 'SELECT * FROM ' + cTblName + ' LIMIT 1' )
   sqlite3_step( stmt )
   nCCount := sqlite3_column_count( stmt )
   cQ := 'SELECT ' + Iif( ::lRowid, 'rowid,', '' )
   aFlds := Array( nCCount, 2 )
   FOR i := 1 TO nCCount
      aFlds[i,1] := Lower( sqlite3_column_name( stmt, i ) )
      aFlds[i,2] := 1
      cQ += aFlds[i,1] + iif( i == nCCount, ' ', ',' )
   NEXT
   sqlite3_finalize( stmt )

   ::cBaseQ := cQ + 'FROM ' + cTblName
   ::aFlds := aFlds

   IF !::lRowid
      ::aTblPK := hb_ATokens( ::cTblPK, ',' )
      ::cTblPKDesc := ""
      FOR i := 1 TO Len( ::aTblPK )
         ::cTblPKDesc += Iif( i>1,",","" ) + ::aTblPK[i] + " DESC"
         ::aTblPK[i] := Ascan( aFlds, {|a|a[1]==::aTblPK[i]} )
      NEXT
   ENDIF
   nLimitText := Nil

   RETURN Self

METHOD ReadFirst() CLASS HBrwTable

   LOCAL stmt, nCCount, arr := {}, nArr := 0, i, n := Iif( ::lRowid, 1, 0 )

   stmt := sqlite3_prepare( ::dbHandle, ::cBaseQ + ;
         ' ORDER BY ' + Iif( ::lRowid, 'rowid', ::cTblPK ) + ' LIMIT ' + ;
         LTrim( Str(::nQueLimit ) ) )

   DO WHILE sqlite3_step( stmt ) == SQLITE_ROW
      nArr ++
      nCCount := sqlite3_column_count( stmt )
      AAdd( arr, Array( nCCount ) )
      FOR i := 1 TO nCCount
         arr[nArr,i] := sqlGetField( stmt, i )
         IF i > n
            ::aFlds[i-n,2] := Max( ::aFlds[i-n,2], Len( arr[nArr,i] ) )
         ENDIF
      NEXT
   ENDDO

   sqlite3_finalize( stmt )

   ::lFirst := .T.
   ::lLast := ( Len( arr ) < ::nQueLimit )
   IF !Empty( arr ) .AND. Empty( ::nIdMaxR )
      ::nIdMaxR := ::KeyVal( ATail( arr ) )
      ::nRows := iif( ::lLast, - Len( arr ), Len( arr ) )
   ENDIF

   ::oBrw:aArray := arr
   FSayNum( iif( ::nRows > 0, "Rows > " + LTrim(Str(::nRows ) ), "Rows: " + LTrim(Str( - ::nRows ) ) ) )

   RETURN Len( arr )

METHOD ReadLast() CLASS HBrwTable

   LOCAL stmt, nCCount, arr := {}, nArr := 0, i

   stmt := sqlite3_prepare( ::dbHandle, ::cBaseQ + ;
         ' ORDER BY ' + Iif( ::lRowid, 'rowid DESC', ::cTblPKDesc ) + ;
         ' LIMIT ' + LTrim( Str(::nQueLimit ) ) )
   DO WHILE sqlite3_step( stmt ) == SQLITE_ROW
      nArr ++
      nCCount := sqlite3_column_count( stmt )
      AAdd( arr, Array( nCCount ) )
      FOR i := 1 TO nCCount
         arr[nArr,i] := sqlGetField( stmt, i )
      NEXT
   ENDDO
   sqlite3_finalize( stmt )

   IF !Empty( arr )
      AReverse( arr )
      IF Empty( ::nIdMinR )
         ::nIdMinR := ::KeyVal( arr[1] )
         IF ::nRows > 0
            ::nRows += nArr
            IF ::KeyCompare( ::nIdMaxR, ::nIdMinR ) == 1
               FOR i := 1 TO nArr
                  IF ::KeyCompare( ::KeyVal( arr[1] ), ::nIdMaxR ) == 0
                     ::nRows -= i
                     ::nRows := - ::nRows
                     EXIT
                  ENDIF
               NEXT
            ENDIF
         ENDIF
      ENDIF
   ENDIF
   ::lFirst := .F.
   ::lLast := .T.

   ::oBrw:aArray := arr
   FSayNum( iif( ::nRows > 0, "Rows > " + LTrim(Str(::nRows ) ), "Rows: " + LTrim(Str( - ::nRows ) ) ) )

   RETURN Len( arr )

METHOD ReadNext() CLASS HBrwTable

   LOCAL stmt, nCCount, arr := {}, nArr := 0, i, nShift, cWhere

   IF ::lRowid
      stmt := sqlite3_prepare( ::dbHandle, ::cBaseQ + ' WHERE rowid > ' + ;
            LTrim( ::oBrw:aArray[Len(::oBrw:aArray),1] ) + ' ORDER BY rowid LIMIT ' + LTrim( Str(::nQueStep ) ) )
   ELSE
      cWhere := BldWhereNext( ::aTblPK, ::aFlds, ATail( ::oBrw:aArray ) )
      stmt := sqlite3_prepare( ::dbHandle, ::cBaseQ + ' WHERE ' + cWhere + ;
            ' ORDER BY ' + ::cTblPK + ' LIMIT ' + LTrim( Str(::nQueStep ) ) )
   ENDIF
   DO WHILE sqlite3_step( stmt ) == SQLITE_ROW
      nArr ++
      nCCount := sqlite3_column_count( stmt )
      AAdd( arr, Array( nCCount ) )
      FOR i := 1 TO nCCount
         arr[nArr,i] := sqlGetField( stmt, i )
      NEXT
   ENDDO
   sqlite3_finalize( stmt )

   IF !Empty( arr )
      IF ::KeyCompare( i := ::KeyVal( ATAil(arr) ), ::nIdMaxR ) == 1
         ::nIdMaxR := i
         IF ::nRows > 0
            ::nRows += nArr
            IF !Empty( ::nIdMinR ) .AND. ::KeyCompare( ::nIdMaxR, ::nIdMinR ) == 1
               FOR i := nArr TO 1 STEP - 1
                  IF ::KeyCompare( ::KeyVal( arr[i] ), ::nIdMinR ) == 0
                     ::nRows -= ( nArr - i + 1 )
                     ::nRows := - ::nRows
                     EXIT
                  ENDIF
               NEXT
            ENDIF
         ENDIF
      ENDIF
      ::lFirst := .F.

      nShift := Len( arr )
      nArr := Len( ::oBrw:aArray ) - nShift
      FOR i := 1 TO nArr
         ::oBrw:aArray[i] := ::oBrw:aArray[i+nShift]
      NEXT
      FOR i := 1 TO nShift
         ::oBrw:aArray[i+nArr] := arr[i]
      NEXT
      ::oBrw:nCurrent -= nShift
   ENDIF

   IF ( ::lLast := ( Len( arr ) < ::nQueStep ) ) .AND. ::nRows > 0
      ::nRows := - ::nRows
   ENDIF
   FSayNum( iif( ::nRows > 0, "Rows > " + LTrim(Str(::nRows ) ), "Rows: " + LTrim(Str( - ::nRows ) ) ) )

   RETURN Len( arr )

METHOD ReadPrev() CLASS HBrwTable

   LOCAL stmt, nCCount, arr := {}, nArr := 0, i, nShift, cWhere

   IF ::lRowid
      stmt := sqlite3_prepare( ::dbHandle, ::cBaseQ + ' WHERE rowid < ' + LTrim( ::oBrw:aArray[1,1] ) + ' ORDER BY rowid DESC LIMIT ' + LTrim( Str(::nQueStep ) ) )
   ELSE
      cWhere := BldWherePrev( ::aTblPK, ::aFlds, ::oBrw:aArray[1] )
      stmt := sqlite3_prepare( ::dbHandle, ::cBaseQ + ' WHERE ' + cWhere + ;
            ' ORDER BY ' + ::cTblPKDesc + ' LIMIT ' + LTrim( Str(::nQueStep ) ) )
   ENDIF
   DO WHILE sqlite3_step( stmt ) == SQLITE_ROW
      nArr ++
      nCCount := sqlite3_column_count( stmt )
      AAdd( arr, Array( nCCount ) )
      FOR i := 1 TO nCCount
         arr[nArr,i] := sqlGetField( stmt, i )
      NEXT
   ENDDO
   sqlite3_finalize( stmt )

   IF !Empty( arr )
      ::lLast := .F.
      IF !Empty( ::nIdMinR ) .AND. ::KeyCompare( ::nIdMinR, i := ::KeyVal( ATail(arr) ) ) == 1
         ::nIdMinR := i
         IF ::nRows > 0
            ::nRows += nArr
            IF ::KeyCompare( ::nIdMaxR, ::nIdMinR ) == 1
               FOR i := 1 TO nArr
                  IF ::KeyCompare( ::KeyVal( arr[i] ), ::nIdMaxR ) == 0
                     ::nRows -= ( nArr-i+1 )
                     ::nRows := - ::nRows
                     EXIT
                  ENDIF
               NEXT
            ENDIF
         ENDIF
      ENDIF

      nShift := Len( arr )
      nArr := Len( ::oBrw:aArray ) - nShift
      FOR i := Len( ::oBrw:aArray ) TO nShift STEP - 1
         ::oBrw:aArray[i] := ::oBrw:aArray[i-nShift+1]
      NEXT
      FOR i := 1 TO nShift
         ::oBrw:aArray[i] := arr[nShift-i+1]
      NEXT
      ::oBrw:nCurrent += nShift
   ENDIF
   ::lFirst := ( Len( arr ) < ::nQueStep )
   FSayNum( iif( ::nRows > 0, "Rows > " + LTrim(Str(::nRows ) ), "Rows: " + LTrim(Str( - ::nRows ) ) ) )

   RETURN Len( arr )

METHOD Skip( n ) CLASS HBrwTable

   LOCAL cTmp := ":PAINT"

   IF n < 0 .AND. !::lFirst .AND. ::RecNo() < ::nQueStep
      IF !( cTmp $ ProcName( 2 ) ) .AND. !( cTmp $ ProcName( 3 ) )
         ::ReadPrev()
      ENDIF
   ELSEIF n > 0 .AND. !::lLast .AND. ( ::RCou() - ::RecNo() ) < ::nQueStep
      IF !( cTmp $ ProcName( 2 ) ) .AND. !( cTmp $ ProcName( 3 ) )
         ::ReadNext()
      ENDIF
   ENDIF

   RETURN ArSkip( ::oBrw, n )

METHOD Top() CLASS HBrwTable

   IF !::lFirst
      ::ReadFirst()
   ENDIF

   RETURN ( ::oBrw:nCurrent := 1 )

METHOD Bottom() CLASS HBrwTable

   IF !::lLast
      ::ReadLast()
   ENDIF

   RETURN ( ::oBrw:nCurrent := ::oBrw:nRecords )

METHOD Eof() CLASS HBrwTable

   IF !::lLast
      RETURN .F.
   ENDIF

   RETURN ( ::oBrw:nCurrent > ::oBrw:nRecords )

METHOD Bof() CLASS HBrwTable

   IF !::lFirst
      RETURN .F.
   ENDIF

   RETURN ( ::oBrw:nCurrent == 0 )

METHOD RCou() CLASS HBrwTable

   RETURN ( Len( ::oBrw:aArray ) )

METHOD RecNo() CLASS HBrwTable

   RETURN ( ::oBrw:nCurrent )

METHOD KeyCompare( xKey1, xKey2 ) CLASS HBrwTable

   LOCAL nRes, i

   IF ::lRowid
      nRes := Iif( xKey1 == xKey2, 0, Iif( xKey1 > xKey2, 1, -1 ) )
   ELSEIF Len( ::aTblPK ) == 1
      nRes := Iif( xKey1 == xKey2, 0, Iif( xKey1 > xKey2, 1, -1 ) )
   ELSE
      nRes := 0
      FOR i := 1 TO Len( ::aTblPK )
         IF xKey1[i] > xKey2[i]
            RETURN 1
         ELSEIF xKey1[i] < xKey2[i]
            RETURN -1
         ENDIF
      NEXT
   ENDIF

   RETURN nRes

METHOD KeyVal( aRow ) CLASS HBrwTable

   LOCAL xRes, i

   IF ::lRowid
      xRes := Val( aRow[1] )
   ELSEIF Len( ::aTblPK ) == 1
      xRes := aRow[ ::aTblPK[1] ]
   ELSE
      xRes := {}
      FOR i := 1 TO Len( ::aTblPK )
         Aadd( xRes, aRow[ ::aTblPK[i] ] )
      NEXT
   ENDIF

   RETURN xRes

METHOD KeyWhere( aRow ) CLASS HBrwTable

   LOCAL cRes := " WHERE ", i, arr

   IF ::lRowid
      cRes += "rowid=" + aRow[1]
   ELSEIF Len( ::aTblPK ) == 1
      cRes += ::cTblPK + "='" + aRow[ ::aTblPK[1] ] + "'"
   ELSE
      arr := hb_ATokens( ::cTblPK, ',' )
      FOR i := 1 TO Len( ::aTblPK )
         cRes += Iif( i>1," AND ","" ) + arr[i] + "='" + aRow[ ::aTblPK[i] ] + "'"
      NEXT
   ENDIF

   RETURN cRes

METHOD SetCell( nCell, cValue, nType ) CLASS HBrwTable

   IF nType == 3
      IF Len( cValue ) > QUE_TEXT_MAX
         cValue := Left( cValue, QUE_TEXT_MAX )
      ENDIF
   ELSEIF nType == 4
      cValue := "(BLOB)"
   ELSEIF nType == 5
      cValue := "(NULL)"
   ENDIF
   ::oBrw:aArray[::oBrw:nCurrent,nCell+Iif(::lRowid,1,0)] := cValue

   RETURN Nil


STATIC FUNCTION AReverse( arr )

   LOCAL nLen := Len( arr ), nMid, i, xTemp

   nMid := iif( nLen % 2 == 0, nLen / 2, ( nLen - 1 ) / 2 )
   FOR i := 1 TO nMid
      xTemp := arr[i]
      arr[i] := arr[nLen+1-i]
      arr[nLen+1-i] := xTemp
   NEXT

   RETURN Nil

STATIC FUNCTION BldWhereNext( aPK, aFlds, aValues )

   LOCAL cWhere := "", i

   FOR i := 1 TO Len( aPK )
      IF i > 1
         cWhere += " OR (" + aFlds[aPK[i-1],1] + "='" + aValues[aPK[i-1]] + "' AND "
      ENDIF
      cWhere += aFlds[aPK[i],1] + ">'" + aValues[aPK[i]] + "'" + Iif( i>1, ")", "" )
   NEXT

   RETURN cWhere

STATIC FUNCTION BldWherePrev( aPK, aFlds, aValues )

   LOCAL cWhere := "", i

   FOR i := 1 TO Len( aPK )
      IF i > 1
         cWhere += " OR (" + aFlds[aPK[i-1],1] + "='" + aValues[aPK[i-1]] + "' AND "
      ENDIF
      cWhere += aFlds[aPK[i],1] + "<'" + aValues[aPK[i]] + "'" + Iif( i>1, ")", "" )
   NEXT

   RETURN cWhere
