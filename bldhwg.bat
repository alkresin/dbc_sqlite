@set HRB_DIR=c:\harbour
@set HWGUI_DIR=c:\papps\hwgui_uni

   if not exist bin md bin
   %HRB_DIR%\bin\harbour source\dbc_sqlite.prg -n -w -q -i%HRB_DIR%\include;%HWGUI_DIR%\include;%HRB_DIR%\contrib\hbsqlit3 %1 >harbour.log 2>harberr.log
   %HRB_DIR%\bin\harbour source\modistru.prg -n -w -q -i%HRB_DIR%\include;%HWGUI_DIR%\include;%HRB_DIR%\contrib\hbsqlit3 %1 >>harbour.log 2>>harberr.log
   %HRB_DIR%\bin\harbour source\hbrwtbl.prg -n -w -q -i%HRB_DIR%\include;%HWGUI_DIR%\include;%HRB_DIR%\contrib\hbsqlit3 %1 >>harbour.log 2>>harberr.log
   %HRB_DIR%\bin\harbour source\expimp.prg -n -w -q -i%HRB_DIR%\include;%HWGUI_DIR%\include;%HRB_DIR%\contrib\hbsqlit3 %1 >>harbour.log 2>>harberr.log
   %HRB_DIR%\bin\harbour source\autocmpl.prg -n -w -q -i%HRB_DIR%\include;%HWGUI_DIR%\include;\%HRB_DIR%\contrib\hbsqlit3 %1 >>harbour.log 2>>harberr.log

   bcc32  -c -O2 -tW -M -I%HRB_DIR%\include;%HWGUI_DIR%\include dbc_sqlite.c modistru.c hbrwtbl.c expimp.c autocmpl.c
   echo 1 24 "%HWGUI_DIR%\image\WindowsXP.Manifest" > dbc_sqlite.rc
   brc32 -r dbc_sqlite

   ilink32 -Gn -Tpe -aa -L%HRB_DIR%\lib;%HWGUI_DIR%\lib c0w32.obj dbc_sqlite.obj modistru.obj hbrwtbl.obj expimp.obj autocmpl.obj, bin\dbc_sqlite.exe, dbc_sqlite.map, hwgui.lib procmisc.lib hbxml.lib hwgdebug.lib hbdebug.lib hbvm.lib hbrtl.lib gtgui.lib gtwin.lib hblang.lib hbrdd.lib hbmacro.lib hbpp.lib rddntx.lib rddcdx.lib rddfpt.lib hbsix.lib hbcommon.lib hbcpage.lib hbct.lib hbpcre.lib hbcplr.lib sqlite3.lib hbsqlit3.lib ws2_32.lib cw32.lib import32.lib,, dbc_sqlite.res

   @del *.c
   @del *.obj
   @del dbc_sqlite.rc
   @del dbc_sqlite.res
   @del dbc_sqlite.map
   @del bin\dbc_sqlite.tds