AI pro OpenTTD

Stručný popis schopností AI:
- Umí stavět vlakové tratě na jakémkoliv terénu - umí stavět mosty (přes řeky i tratě) a tunely.
- Dokáže převážet libovolný typ zboží resp. souběžně převážet více typů zboží. 
- Můžu hrát více AI zároveň (s občasnými chybami ohledně umístění depa a zastávek).

Hlavní vlastnosti:
- Na začátku jsou zvýrazněny všechny přítomné zdroje a spotřební místa a vytvořeny jejich dvojice.
- V programu jsou stanoveny preference zboží - uhlí, železná ruda, ropa, ...
- Program v cyklu prochází zboží a pro každé najde nejkratší cestu (Manhattanská) mezi zdrojem a cílem. Na této cestě následně postaví vlakovou trať.
--> Vyloučí se dvojice, jejichž zdroj je odtransportován z více než 70 % (za poslední měsíc).
--> Pokud daná trať nejde postavit, vybere se 2. nejkratší cesta (atd. dokola).
--> Do logu se vypisuje průběh stavby.
- Lokomotiva je vybrána dle aktuálního stavu konta firmy (defaultně 2. nejdražší).
- Počet vagónů je určen na základě velikosti přebytku produkce daného zdroje a kapacity vagonu (opět se kontroluje stav konta).
--> Min. počet je 2 a max. 10.
- Po postavění tratí je do logu periodicky zobrazován stav konta.

Upozornění: 
- AI funguje jen na mapě, která je vytvořena z testovacího scénáře dr. Popelky - netuším proč. 
- Pokud dám New game a vygeneruje se mapa, nebo vytvořím novou mapu v Scenario Editor, nikdy to nenajde cestu.
- V příloze přikládám ukázkovou mapu, na které vše funguje bez problémů.
- Pokud má hrát více AI zároveň, je lepší (jistější) počkat až první AI postaví tratě a potom teprve zapnout druhou AI.

Poznámka k autorství:
- V AI jsou využity některé funkce od dr. Popelky - především pro stavění zastávky a depa.

Problémy:
- Nalezení již vybrané trati trvá dlouhou dobu, to je nicméně daní za její krátkost a co nejoptimálnější poměr délka/cena.
- Ve výjimečných případech se vlak chová bláznivě a vrací se pořád do depa (stalo se jednou u převozu dřeva).
- Při hře více AI zároveň se občas vyskytují chyby. 
--> Např. pokud je topologie vytvořených tratí komplikovaná, může být depo někdy postaveno tak nešikovně, že vlak nemůže vyjet ven na trať.
