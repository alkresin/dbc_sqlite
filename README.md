## dbc_SQLite - SQLite database manager

<b> Attention! Since October 6, 2023 we are forced to use two-factor authentication to be able to
   update the repository. Because it's not suitable for me, I will probably use another place for projects.
   Maybe, https://gitflic.ru/, maybe, Sourceforge... Follow the news on my website, http://www.kresin.ru/

   Внимание! С 6 октября 2023 года нас вынуждают использовать двухфакторную идентификацию для того, чтобы 
   продолжать работать над проектами. Поскольку для меня это крайне неудобно, я, возможно, переведу проекты
   на другое место. Это может быть https://gitflic.ru/, Sourceforge, или что-то еще. Следите за новостями
   на моем сайте http://www.kresin.ru/ </b>

Development tools used: Harbour + hbSQLit3 + HwGUI.

### Preface

There is a number of a tools to manage SQLite databases, so the first question is:
  Why to develop yet another ?

   First of all, I want to learn SQLite features more, and writing a database manager is
a good method, I think.

   Secondly, I'm not satisfied with an interface of most existing tools. When I open some
database, the main thing that interests me, is a data in it. What tables it contains and
what data are contained in these tables. The indexes, views and triggers are a secondary
type of a database contents and I don't want to see them immedeately after the database
is opened for they do not distract attention from the main. I need only to have the
possibility to look at them separately, if this will be necessary.

   Thirdly, at the moment I begin to develop it (December 2014), most of existing tools didn't include
support of some new sqlite features. For example, they didn't open databases, which had tables
"WITHOUT ROWID" at all!

   And, at least, I want to have a possibility to add any feature when I will need it.

### Installation notes
#### Windows:

Bldhwg.bat is provided to build dbc_sqlite.exe with Borland C compiler.
You will need to change HRB_DIR and HWGUI_DIR - they should point to your Harbour and HwGUI directories, appropriately.

Unicode version of HwGUI is needed to be possible to view and edit non-latin symbols.

#### Linux:

Use the build.sh to compile dbc_sqlite.
You will need to change HRB_DIR and HWGUI_DIR - they should point to your Harbour and HwGUI directories, appropriately.

### Download

Binaries are available for download on my site: http://www.kresin.ru/en/dbc_sqlite.html
