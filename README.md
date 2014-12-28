## dbc_SQLite - SQLite database manager

Development tools used: Harbour + hbSQLit3 + HwGUI.
  Unicode version of HwGUI is needed to be possible to view and edit non-latin symbols.

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