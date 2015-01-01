#!/bin/bash
export HRB_DIR=../../../../
export HWGUI_DIR=../../..
export SYSTEM_LIBS="-lsqlite3"
export HARBOUR_LIBS="-lhbdebug -lhbvm -lhbrtl -lgtcgi -lhblang -lhbrdd -lhbmacro -lhbpp -lrddntx -lrddcdx -lrddfpt -lhbsix -lhbcommon -lhbcpage -lhbsqlit3"
export HWGUI_LIBS="-lhwgui -lprocmisc -lhbxml"

if ! [ -e bin ]; then
   mkdir bin
   chmod a+w+r+x bin
fi

$HRB_DIR/bin/linux/gcc/harbour source/dbc_sqlite source/modistru source/hbrwtbl source/expimp source/autocmpl -n -i$HRB_DIR/include -i$HRB_DIR/contrib/hbsqlit3 include -i$HWGUI_DIR/include -w2
gcc dbc_sqlite.c modistru.c hbrwtbl.c expimp.c autocmpl.c -obin/dbc_sqlite  -I $HRB_DIR/include -L $HRB_DIR/lib/linux/gcc -L $HWGUI_DIR/lib -Wl,--start-group $HWGUI_LIBS $HARBOUR_LIBS -Wl,--end-group `pkg-config gtk+-2.0 --libs` $SYSTEM_LIBS >bld.log 2>bld.log
