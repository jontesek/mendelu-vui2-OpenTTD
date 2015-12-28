
class Xpetrovs extends AIController {
	constructor() {
	}
}

function Xpetrovs::Start()
{
	while (true) {
		AILog.Info("Ahoj vsichni! Provedl jsem " + "instrukci: " + this.GetTick());
		this.Sleep(500);
	}
}
