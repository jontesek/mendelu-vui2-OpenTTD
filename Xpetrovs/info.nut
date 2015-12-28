class Xpetrovs extends AIInfo {
	  function GetAuthor()    { return "Jonas Petrovsky"; }
	  function GetName()      { return "Xpetrovs";}
	  function GetDescription()	{ return "Moje AI do UI2"; }
	  function GetVersion()	{ return 1; }
	  function GetDate()	{ return "2015-12-27"; }
	  function CreateInstance()	{ return "Xpetrovs"; }
	  function GetShortName() { return "XPET"; }
	  function GetAPIVersion() { return "1.1"; }
}
RegisterAI(Xpetrovs());
