
This is a [SciTE](http://www.scintilla.org) script lexer for the [HLA programming language.](
http://en.wikipedia.org/wiki/High_Level_Assembly)

####Usage


Place the properties file(*script_hla.properties*) in **$(SciteDefaultHome)** which usually points  
to **C:\ProgramData\SciTE** in Windows.

You can run this command in the output pane to confirm.  

    > echo $(SciteDefaultHome)

Then place the *Lua* script(**script_hla.lua**) in the same directory and add this line to your  
**SciTEStartup.lua** file:

    dofile(props["SciteDefaultHome"] .. "\\script_hla.lua")

The script can be placed in a different directory as long as you update the path accordingly.

You'll have to change the settings in the properties file to suite your needs. I imagine that  
anybody who has used *SciTE* for quite some time has moved away from the default theme.

Here's how a *hla* script looks like in my case(a little too much color):

![A screenshot of the lexer in action](http://i.imgur.com/LxvwepB.png?1)


####Shortcomings

+ The *.properties* files is only loaded at startup meaning all changes made to it will take effect  
  after a restart of the editor.


