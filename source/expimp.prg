/*  $Id: $
 *
 * dbc_SQLite - SQLite database manager
 * Export / import
 *
 * Copyright 2014 Alexander S.Kresin <alex@kresin.ru>
 * www - http://www.kresin.ru
*/

#include "hbsqlit3.ch"
#include "hwgui.ch"

FUNCTION tblImport( oDb, nTable )

   LOCAL oDlg

   INIT DIALOG oDlg TITLE "Import to " + oDb:aTables[nTable,1]  ;
      AT 0, 0 SIZE 600, 480 FONT HWindow():GetMain():oFont

   ACTIVATE DIALOG oDlg

   RETURN Nil

FUNCTION tblExport( oDb, nTable )

   LOCAL oDlg

   INIT DIALOG oDlg TITLE "Export from " + oDb:aTables[nTable,1]  ;
      AT 0, 0 SIZE 600, 480 FONT HWindow():GetMain():oFont

   ACTIVATE DIALOG oDlg

   RETURN Nil

FUNCTION dbDump( oDb )

   LOCAL i, j, cLine
   LOCAL cFile, han, stmt, nCCount, nCType

#ifdef __PLATFORM__UNIX
   cFile := hwg_Selectfile( "( *.* )", "*.*", CurDir() )
#else
   cFile := hwg_Savefile( "*.*", "( *.* )", "*.*", CurDir() )
#endif

   IF Empty( cFile )
      RETURN Nil
   ENDIF
   IF ( han := FCreate( cFile ) ) == -1
      hwg_MsgStop( "Can't create " + cFile )
      RETURN Nil
   ENDIF

   FWrite( han, "PRAGMA foreign_keys=OFF;" + Chr(13) + Chr(10) )
   FWrite( han, "BEGIN TRANSACTION;" + Chr(13) + Chr(10) )
   FOR i := 1 TO Len( oDb:aTables )
      FWrite( han, oDb:aTables[i,2] + ";" + Chr(13) + Chr(10) )

      IF !Empty( stmt := sqlite3_prepare( oDb:dbHandle, "SELECT * FROM "+oDb:aTables[i,1] ) )
         DO WHILE sqlite3_step( stmt ) == SQLITE_ROW
            nCCount := sqlite3_column_count( stmt )
            cLine := "INSERT INTO " + oDb:aTables[i,1] + " VALUES ( "
            FOR j := 1 TO nCCount

               IF j > 1
                  cLine += ","
               ENDIF
               nCType := sqlite3_column_type( stmt, j )

               SWITCH nCType
               CASE SQLITE_BLOB
                  cLine += "x'" + sqlite3_column_text( stmt, j ) + "'"
                  EXIT
               CASE SQLITE_INTEGER
                  cLine += Ltrim( Str( sqlite3_column_int( stmt, j ) ) )
                  EXIT
               CASE SQLITE_FLOAT
                  cLine += Ltrim( Str( sqlite3_column_double( stmt, j ) ) )
                  EXIT
               CASE SQLITE_NULL
                  cLine += "NULL"
                  EXIT
               CASE SQLITE_TEXT
                  cLine += "'" + sqlite3_column_text( stmt, j ) + "'"
                  EXIT
               ENDSWITCH

            NEXT
            cLine += ");" + Chr(13) + Chr(10)
            FWrite( han, cLine )
         ENDDO
         sqlite3_finalize( stmt )
      ENDIF     
   NEXT
   FWrite( han, "COMMIT TRANSACTION;" + Chr(13) + Chr(10) )

   FClose( han )

   RETURN Nil
