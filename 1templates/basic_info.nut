class MyAiTest extends AIInfo
{
	function GetAuthor()   		{ return "Jiri Lysek"; }
	function GetName()      	{ return "MyAiTest";}
	function GetDescription()	{ return "Testovaci Ai pro OpenTTD"; }
	function GetVersion()		{ return 1; }
	function GetDate() 			{ return "2014-10-20"; }
	function CreateInstance()	{ return "MyAiTest"; }
	function GetShortName() 	{ return "MYAT"; }
	function GetAPIVersion() 	{ return "1.1"; }
	function GetSettings() 	{}
}
RegisterAI(MyAiTest());