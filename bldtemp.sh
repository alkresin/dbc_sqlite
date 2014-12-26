#!/bin/bash
export HB_INS=../../../../
export HWGUI_INC=../../../include
export HWGUI_LIB=../../../lib
export SYSTEM_LIBS="-lsqlite3"
export HARBOUR_LIBS="-lhbdebug -lhbvm -lhbrtl -lgtcgi -lhblang -lhbrdd -lhbmacro -lhbpp -lrddntx -lrddcdx -lrddfpt -lhbsix -lhbcommon -lhbcpage -lhbsqlit3"
export HWGUI_LIBS="-lhwgui -lprocmisc -lhbxml"

if ! [ -e bin ]; then
   mkdir bin
   chmod a+w+r+x bin
fi

$HB_INS/bin/linux/gcc/harbour source/dbc_sqlite source/modistru source/hbrwtbl source/expimp source/autocmpl -n -d__GTK__ -i$HB_INS/include -i$HB_INS/contrib/hbsqlit3 include -i$HWGUI_INC -w2 -d__LINUX__
gcc dbc_sqlite.c modistru.c hbrwtbl.c expimp.c autocmpl.c -obin/dbc_sqlite -D__GTK__ -I $HB_INS/include -L $HB_INS/lib/linux/gcc -L $HWGUI_LIB -Wl,--start-group $HWGUI_LIBS $HARBOUR_LIBS -Wl,--end-group `pkg-config gtk+-2.0 --libs` $SYSTEM_LIBS >bld.log 2>bld.log
