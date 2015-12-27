
class XpetrovsAi extends AIController {
	constructor() {
	}
}

function XpetrovsAi::Start()
{
	while (true) {
		AILog.Info("Ahoj vsichni! Provedl jsem " + "instrukci: " + this.GetTick());
		this.Sleep(500);
	}
}
