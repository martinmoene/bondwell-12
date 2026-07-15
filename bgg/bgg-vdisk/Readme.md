<h2 id="vdisk">Bondwell 12 Virtual-disk</h2>

<p>door M.J. Moene</p>

<h2>Inleiding</h2>

<p> Bij het gebruik van programma's die veel of frequent disk-I/O doen, zoals vertalers (compilers en assemblers) en programma's die gebruik maken van overlay-files (bv. WordStar), wordt de relatief langzame disk-I/O van de floppy- diskdrives dikwijls als storend ervaren. Ook de beschikbare opslagcapaciteit van beide drives (166 kbyte elk) is soms te klein. Deze nadelen van floppy-diskdrives met betrekking tot snelheid en (tijdelijk) beschikbare capaciteit kunnen worden ondervangen door een in het geheugen gesimuleerde disk te gebruiken: een virtuele disk. </p>

<p>In dit artikel beschrijf ik hoe een virtuele disk ge&iuml;mplementeerd kan worden in het Bondwell 12-CP/M 2.2 operating system. De geheugenruimte die nodig is voor de virtuele disk kan verkregen worden door het geheugen met acht 64 kbyte dynamische RAM's uit te breiden. De hardware van de Bondwell 12 voorziet in de mogelijkheid om deze twee extra geheugenbanken van 32 kbyte toe te voegen. Door een kleine hardware-uitbreiding is het mogelijk in plaats van twee, acht extra geheugenbanken van 32 kbyte (= 256 kbyte) toe te voegen.</p>

<h3>Inhoud</h3>

<div class="floater">This article was published in Bondwell/ELCI-gg mededelingen, nummer 2, februari 1988 and nummer 3, mei 1988</a>.<br /> <br />

Download:
<a href="vdisk18.mac">source</a>,
<a href="vdisk18.prn">listing</a>,
<a href="vdisk18.com">program</a>.
</div>

<p>H 1. Het CP/M-besturingssysteem<br />
H 2. Uitbreiden van het BIOS met een virtuele disk<br />
H 3. Geheugenbank-selectie<br />
H 4. 256 kbyte geheugenuitbreiding<br /></p>

<h3>1. Het CP/M-besturingssysteem</h3>

<h4>1.1. Inleiding</h4>

<p>Een besturingssysteem (operating system) is bedoeld om programma's controle te geven over de randapparatuur, zoals bijvoorbeeld terminal, diskdrives en printer, op een manier die onafhankelijk is van de hardware-opbouw van die randapparatuur. CP/M is zo'n besturingssysteem.</p>

<p>CP/M is opgebouwd uit vijf delen:</p>
<ul>
<li>BIOS: Basic Input Output System,</li>
<li>BDOS: Basic Disk Operating System,</li>
<li>CCP : Console Command Processor,</li>
<li>TPA : Transient Program Area,</li>
<li>MWA : Monitor Work Area.</li>
</ul>

<p>Het BIOS verzorgt de elementaire handelingen die nodig zijn om de disk drives en de gebruikelijke randapparatuur, zoals terminal en printer, te kunnen besturen. Het BDOS verzorgt het diskbeheer en de besturing van de randapparatuur, daarbij gebruik makend van het BIOS. CCP voert de commando's uit die afkomstig zijn van het toetsenbord. De TPA is het deel van het geheugen dat beschikbaar is voor de gebruikersprogramma's (eventueel uitgebreid met de ruimte van CCP en BDOS).  De MWA bevat een aantal systeemconstanten en -buffers. Van deze vijf delen is alleen het BIOS afhankelijk van het gebruikte hardware-systeem. Het toevoegen van een geheugendisk vereist dus dat het BIOS wordt aangepast.</p>

<h4>1.2. Het Basic Input/Output System</h4>

<p>Wat moet er in het BIOS aangepast worden? Om dit te onderzoeken volgt hier een beschrijving van de belangrijkste eigenschappen van het BIOS.</p>

<p>Het BIOS van de Bondwell 12 is opgebouwd uit de volgende delen:</p>
<ol>
<li>jump-table,</li>
<li>BIOS-routines,</li>
<li>diskparameter-tabellen,</li>
<li>functietoets-tabel.</li>
</ol>

<dl>
<dt>ad 1.</dt><dd>De jump-table dient om de BIOS-routines aan te kunnen roepen. Op adres $0001 en $0002 in de MWA staat het adres van de tweede jump- instructie van de BIOS jump-table. Hierdoor is dus de ligging van de gehele BIOS jump-table bekend.</dd>

<dt>ad 2.</dt><dd>De BIOS-routines zijn te verdelen in drie groepen:
<ul>
<li>systeem initialisatie,</li>
<li>ASCII in- en uitvoerroutines,</li>
<li>disk in- en uitvoerroutines.</li>
</ul>
Voor het toevoegen van de geheugendisk zijn alleen de disk in- en uitvoerroutines van belang.</dd>

<dt>ad 3.</dt><dd>De fysische eigenschappen van de gebruikte diskdrives zijn vastgelegd in drie disk-parameter tabellen:
<ul>
<li>Disk Parameter Header table (DPH),</li>
<li>Disk Parameter Block table (DPB),</li>
<li>sector translate table (XLT).</li>
</ul></dd>

<dt>ad 4.</dt><dd>De functietoets-tabel bestaat uit 16 x 16 byte voor de zestien functietoetsen. De tabel beslaat het adresgebied $F6BF..$F7BF. Deze tabel beschrijf ik verder niet.</dd>
<dl>

<h5>De BIOS-routines</h5>

<p>De gegevens op de floppy-disk zijn georganiseerd in tracks en sectoren. (zie figuur 1.2.1.)</p>

<pre>
               \---+---/
               |\--+--/|
               ||\-+-/|o---- track (cirkel)
               |||\|/|||
              -+++-O-+++-
               |||/|\|||\
               ||/-+-\|| )-- sector (cirkelsegment)
               |/--+--\|/
               /---+---\

          figuur 1.2.1.  tracks en sectoren op een disk
</pre>

<p>De data-overdracht van en naar naar disk gebeurt via een zogenaamd DMA- buffer (Direct Memory Access-buffer). De gegevens worden per record van 128 byte uitgewisseld tussen het DMA-buffer en de disk.  De records worden aangeduid met een track- en sectornummer.</p>

<p>Het BIOS bevat de volgende disk in- en uitvoerroutines:</p>
<pre>
   home   : Breng  de leeskop naar track nul van de geselecteerde drive:
            normaal  is  op de eerste tracks het  CP/M-operating  system
            opgeslagen.
   seldsk : Selecteer   de  disk-drive,   aangegeven  door  register   c
            (0=A:,1=B:); als de drive bestaat, dan bevat registerpaar hl
            het  adres  van  de  Disk  Parameter  Header,  anders  bevat
            registerpaar hl nul.
   settrk : Selecteer  de track van de geselecteerde disk-drive,  aange-
            geven door het nummer in registerpaar bc.
   setsec : Selecteer de sector van de geselecteerde disk-drive,  aange-
            geven door het nummer in registerpaar bc.
   setdma : Gebruik  voor  volgende disk  read- en  write-operaties  het
            adres van de DMA-buffer als aangegeven door registerpaar bc.
   read   : Lees  de geselecteerde sector van de disk en plaats de  data
            in  de aangegeven DMA-buffer;  als de operatie geslaagd  is,
            bevat  register a de waarde nul,  anders een waarde ongelijk
            aan nul.
   write  : Beschrijf  de geselecteerde sector van de disk met  de  data
            uit  de aangegeven DMA-buffer;  als de operatie geslaagd is,
            bevat register a de waarde nul,  anders een waarde  ongelijk
            aan nul.
   sectran: Vertaal een logisch sectornummer in registerpaar bc naar het
            fysische  sectornummer in registerpaar hl;  registerpaar  de
            bevat  het adres van de sector vertaal-tabel;   het verschil
            tussen  het  logische- en het  fysische  sectornummer  wordt
            gebruikt om de tijd  die nodig is om  opeenvolgende sectoren
            te lezen of te beschrijven te verkorten (skewing).
</pre>

<p>Voor bovenstaande routines, home uitgezonderd, geldt,dat de lees/schrijfkop pas  werkelijk naar de geselecteerde sector gebracht hoeft te worden bij de read- en write-operaties.</p>

<h5>De disk-parameter tabellen</h5>

<p>De fysische eigenschappen van de gebruikte disk-drives worden vastgelegd in drie disk-parameter tabellen in het BIOS:</p>

<ul>
   <li>Disk Parameter Header table (DPH),</li>
   <li>Disk Parameter Block table  (DPB),</li>
   <li>sector translate table      (XLT).</li>
</ul>

<p>De DPH is de schakel tussen het BDOS en het BIOS voor het gebruik van  disk in- en uitvoer.   De DPH bevat een kladgebied en de adressen van een aantal buffers die door het BDOS gebruikt worden.  Verder bevat de DPH de adressen van de DPB en de XLT tabellen.  De DPB beschrijft de fysische eigenschappen van  de drive en de XLT-tabel geeft de vertaling van logische sectoren naar fysische sectoren.</p>

<p>Per aangesloten drive is er e'e'n DPH.   DPBASE geeft het begin van de  lijst van DPH's aan.  In figuur 1.2.2. is het formaat van de DPH's weergegeven.</p>

<pre>
            Disk Parameter Header
           +--------------------------------------------+
    DPBASE | XLT | 0 | 0 | 0 | DIRBUF | DPB | CSV | ALV |   Drive 0 (A:)
           +--------------------------------------------+
           |                     :                      |
           +--------------------------------------------+
           | XLT | 0 | 0 | 0 | DIRBUF | DPB | CSV | ALV |   Drive n
           +--------------------------------------------+
             16b  16b 16b 16b   16b     16b   16b   16b

           figuur 1.2.2. lijst van Disk Parameter Headers
</pre>

<p>De DPH bevat de volgende gegevens:</p>

<pre>
   XLT   : Adres van de sector vertaal tabel;  als er geen skewing wordt
           toegepast heeft XLT de waarde nul.
   000   : Kladgebied  voor  het BDOS;  de initi&euml;le waarde is  niet  van
           belang.
   DIRBUF: Adres  van  een  128 byte groot  kladbuffer  voor  directory-
           operaties  die  door het BDOS worden uitgevoerd;  alle  DPH's
           kunnen verwijzen naar dezelfde buffer,
   DPB   : Adres  van het Disk Parameter Block voor deze  drive;  drives
           met dezelfde karakteristieken kunnen verwijzen naar  dezelfde
           DPB,
   CSV   : Adres  van  een kladgebied dat gebruikt wordt voor  het  uit-
           voeren  van  een software-controle op het verwisselen van  de
           disk;  elke DPH verwijst naar een eigen kladgebied; indien er
           niet gecontroleerd hoeft te worden, heeft CSV de waarde nul.
   ALV   : Adres van een kladgebied dat door het BDOS gebruikt wordt  om
           de  bezetting van de disk,  uitgedrukt in  allocation-blocks,
           bij  te houden;  elk bit van de buffer stelt een  allocation-
           block  voor;  een bit dat de waarde een heeft,  geeft aan dat
           het  corresponderende  allocation-block bezet  is;  elke  DPH
           verwijst naar een eigen kladgebied.
</pre>

<p>Het formaat van het Disk Parameter Block is weergeven in figuur 1.2.3..

<pre>
        Disk Parameter Block
       +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
A:, B: | SPT | BSH | BLM | EXM | DSM | DRM | AL0 | AL1 | CKS | OFF |
       +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+

       +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
Vdisk  | SPT | BSH | BLM | EXM | DSM | DRM | AL0 | AL1 | CKS | OFF |
       +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
         16b    8b    8b    8b   16b   16b    8b    8b   16b   16b

                 figuur 1.2.3. twee Disk Parameter Blocks
</pre>

<p>Het Disk Parameter Block bevat de volgende gegevens:</p>

<pre>
   SPT : Sectors Per Track.
         Het aantal sectoren per track.
   BSH : Data allocation Block SHift factor.
         Dit  is  een getal dat afhankelijk is van de  grootte  van  het
         allocation-block (BLS: allocation BLock Size).
   BLM : Data allocation BLock Mask.
         De waarde hiervan is: 2^(BSH-1).
   EXM : EXtent Mask.
         De  waarde  van  EXM  is afhankelijk van  de  grootte  van  het
         allocation-block  op zich en van het totaal aantal  allocation-
         blocks van deze disk.
   DSM : Maximum Data block number.
         DSM geeft de capaciteit van de disk in allocation-blocks:
         DSM= alloc-blocks -1.
   DRM : Maximum number of DiRectory entries -1.
         DRM geeft het aantal directory-plaatsen -1 van deze disk.
   AL0,AL1 : ALlocated blocks for directory.
         AL0  en  AL1 geven de beginwaarde voor de  ALV:  hiermee  wordt
         aangegeven welke blocks zijn gereserveerd voor de directory.
   CKS : Number of directory sectors ChecK Summed.
         CKS  geeft  de grootte van de buffer voor de  controle  op  het
         verwisselen van de disk,  uitgedrukt in sectoren; wordt er geen
         controle toegepast, dan heeft CKS de waarde nul.
   OFF : Number of reserved system tracks (track OFFset).
         OFF  geeft het aantal gereserveerde tracks aan het begin van de
         disk; deze tracks kunnen bv. gebruikt worden voor de opslag van
         het CP/M-besturingssysteem.
</pre>

<p>De  waarde  van BSH en BLM bepalen indirect de grootte van een  allocation- block (BLS).   De waarde van BLS is niet vermeld in de DPB.  De grootte van een allocation-block is: 128 x 2^(BSH), of 128 x (BLM+1) [byte]. BSH en BLM zijn als volgt afhankelijk van BLS:</p>

<pre>
  BLS        BSH    BLM
 1024 byte    3       7
 2048 byte    4      15
 4096 byte    5      31
 8192 byte    6      63
16384 byte    7     127
</pre>

<p>BSH  wordt  gebruikt  om te bepalen in welk  allocation-block  een  bepaald record valt: allocation-block nr = record nummer >> BSH. (j >> k: schuif getal j k-maal naar rechts)</p>

<p>BLM  wordt  gebruikt  voor het bepalen van  het  record-nummer  binnen  het allocation-block: plaats = record-nummer & BLM. (j & k : bitsgewijs AND van j met k)</p>

<p>DSM geeft de capaciteit van de disk gemeten in allocation-blocks.   Hierbij worden  de  gereserveerde  tracks  aan het begin van  de  disk  (OFF)  niet meegeteld.  De capaciteit van de disk is: BLS x (DSM +1) [bytes].</p>

<p>De  waarde  van EXM is als volgt afhankelijk van BLS en van DSM:</p>

<pre>
  BLS        DSM < 256    DSM >= 256
 1024 byte       0            --
 2048 byte       1             0
 4096 byte       3             1
 8192 byte       7             3
16384 byte      15             7
</pre>

<p>Voor  de  keuze  van de grootte van het allocation-block  (BLS)  gelden  de volgende afwegingen:  voor de opslag van omvangrijke files geeft een  groot allocation-block  een  effici&euml;nt gebruik van de directory-ruimte;  voor  de opslag van veel kleine files geeft een klein allocation-block een effici&euml;nt gebruik  van de beschikbare diskcapaciteit:  een file die slechts een  paar byte groot is, gebruikt toch een heel allocation-block.</p>

<p>DRM  geeft  het aantal directory-plaatsen minus e'e'n.   Al0  en  Al1  worden gebruikt  als  beginwaarde  voor de allocation-buffer (ALV)  om  ruimte  te reserveren voor de directory.  De waarde van DRM is bepalend voor de waarde AL0  en AL1.   De aaneenschakeling van AL0 en AL1 kan worden beschouwd  als een lijst van 16 bits (zie figuur 1.2.4.).</p>

<pre>
  +---------------------------------------------------------------------+
  |              AL0              |                AL1                  |
  +-------------------------------+-------------------------------------+
  | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |
  +-------------------------------+-------------------------------------+

                figuur 1.2.4.  directory allocation-blocks
</pre>


<p>Positie  0 correspondeert met het high-order bit van byte AL0,  positie  15 correspondeert met het low-order bit van byte AL1.   Elk bit in deze  lijst reserveert  een allocation-block voor een aantal directory-plaatsen,  zodat totaal zestien allocation-blocks gebruikt kunnen worden voor de  directory. Elke  directory-plaats beslaat 32 bytes.   Het aantal allocation-blocks dat nodig  is  voor  de directory is dus afhankelijk van  de  grootte  van  het allocation-block.  Deze afhankelijkheid kan als volgt worden uitgedrukt: aantal directory allocation-blocks = (DRM+1)/(BLS/32).</p>

<p>Zoveel allocation-blocks als de directory nodig heeft, zoveel bits van AL0 en AL1 moeten '1' zijn, te beginnen bij Al0 positie 0.</p>

<p>De  waarde van OFF bepaalt het aantal tracks dat wordt overgeslagen aan het begin van de fysische disk.   Deze waarde wordt automatisch toegevoegd  aan het  track-nummer bij het aanroepen van de routine settrk.   Dit mechanisme kan  gebruikt worden om de tracks die gereserveerd zijn voor het  operating system over te slaan, of om een grote disk te verdelen in kleinere delen.</p>

<p>De uitleg van de Disk Parameter Header eindigt met de CSV- en  ALV-buffers. De  grootte van de buffer voor de controle op het verwisselen van  de  disk (CSV)  is gelijk aan de waarde van CKS.   De waarde van CKS wordt als volgt bepaald:  in  het  geval  van een verwijderbare disk heeft  CKS  de  waarde (DRM+1)/4: er zijn namelijk vier directory-plaatsen per record. Betreft het een vaste disk dan heeft CKS de waarde nul (geen controle op verwisselen).</p>

<p>De  grootte  van de allocation-buffer (ALV) wordt bepaald door het  maximum aantal allocation-blocks van de betreffende disk.   De grootte van ALV  is: (DSM/8)+1 [bytes], namelijk e'e'n bit per allocation-block.</p>

<h3>2. Uitbreiden van het BIOS met een virtuele disk</h3>

<h4>2.1. Inleiding</h4>

<p>De werking van het BIOS is nu voldoende bekend om een virtuele disk aan het BIOS toe te voegen.  Het toevoegen vereist de volgende acties:</p>

<ul>
   <li>ken een vrije letter tussen A en P toe aan de virtuele disk,</li>
   <li>programmeer de BIOS disk-I/O routines voor de virtuele disk,</li>
   <li>maak de virtuele disk DPH-, DPB- en eventueel de XLT-tabel.</li>
</ul>

<p>Het vervolg beschrijft de manier waarop de virtuele disk ge&iuml;mplementeerd is in het bestaande Bondwell 12 CP/M 2.2 besturingssysteem.</p>

<h4>2.2. Het vdisk programma (versie 1.5)</h4>

<h5>2.2.1. Uitgangspunten</h5>

<p>Bij  het  maken van programma voor de virtuele disk zijn de  volgende  uitgangspunten aangehouden:</p>

<ul>
   <li>Het  CP/M-besturingssysteem op de systeemdisk dient ongewijzigd  te blijven:  de  installatie van de geheugendisk dient door een  apart programma te gebeuren.</li>
   <li>Voor  de geheugenruimte die nodig is voor de virtuele disk,  worden de geheugenbanken e'e'n en twee gebruikt; deze komen beschikbaar door de standaard 64 kbyte geheugenuitbreiding van de Bondwell 12;  door de  extra geheugenuitbreiding van 256 kbyte zijn de  geheugenbanken &eacute;&eacute;n tot en met acht beschikbaar voor de virtuele disk.</li>
   <li>Het  programma  dient  zowel  voor de 64  als  voor  de  256  kbyte geheugenruimte geschikt te zijn.</li>
</ul>

<h5>2.2.2. Globale werking</h5>

<p>De werking van het geheugendisk programma kan als volgt worden samengevat. De  aanroepen van de BIOS disk-I/O routines seldsk tot en met write  worden omgeleid naar de daarmee corresponderende geheugendisk BIOS-routines, zodat gecontroleerd  kan  worden of het de geheugendisk betreft.   Indien het  de geheugendisk  betreft,   wordt  de  geheugendiskroutine  verder  afgewerkt; betreft  het echter een andere drive,  dan gaat het programma verder in  de originele BIOS-routine.</p>

<p>Voor  de geheugendisk BIOS-routines en de disk-parameter tabellen,  die aan het standaard Bondwell 12 BIOS moeten worden toegevoegd, is enige geheugen ruimte  nodig die niet door andere programma's gebruikt kan  (zal)  worden. Het  is  vereist dat deze geheugenruimte zich bevindt in de  gemeenschappe lijke  geheugenbank  (common bank:  adres $8000..$FFFF),  omdat  de  andere geheugenbanken  alleen  vanuit deze geheugenbank te  bereiken  zijn.   Deze ruimte voor de geheugendisk BIOS-routines is beschikbaar in het BIOS  vanaf adres $F500 tot adres $F6BF, waar de functietoets-tabel begint.</p>

<p>Het installeren van de geheugendisk omvat de volgende handelingen:</p>

<ul>
   <li>Formatteer, indien gewenst, de geheugendisk directory-ruimte.</li>
   <li>Overschrijf  de   bestaande  BIOS jump-tabel met de  virtuele  disk jump-tabel  voor zover het de van belang zijnde  disk-I/O  routines betreft.</li>
   <li>Kopi&euml;er  de  virtuele disk parameter tabellen en -routines naar  de vrije ruimte in het BIOS.</li>
   <li>Vervang  de jump CCP aan het einde van de originele  BIOS  warmboot- routine  door  jump virtual-disk-warmboot,  zodat gecontroleerd  kan worden  of de default-drive de (inmiddels) legale virtuele disk  is; wordt  dit laatste niet gedaan,  dan wordt de virtuele disk door  de originele  warmboot-routine niet als legaal beschouwd  en  vervangen door drive A:.</li>
</ul>

<p>Figuur 2.2.2.1. geeft een indruk van het geheugengebruik van de virtuele disk.</p>

<pre>
   $FFFF  +--------------+ 64 kbyte
          |    video     |
   $F800  |--------------|
          |--------------|
          | vdisk-buffer |
          | vdisk-program|
   $F500  |--------------|
          |--------------|
          |     BIOS     |
          |     BDOS     |
          |     CCP      |
          |--------------|
          |     TPA      |
    $8000 +--------------+ 32 kbyte
            common bank

    $7FFF +--------------+ 32 kbyte        $7FFF +--------------+ 32 kbyte
          |              |                       |              |
          |              |                       |              |
          |              |                       |              |
          |              |                       |    Vdisk     |
          |     TPA      |                       |    track     |
          |              |                       |              |
          |              |                       |     n-1      |
          |              |                       |              |
          |              |                       |              |
    $0100 |--------------|                       |              |
          |     MWA      |                       |              |
    $0000 +--------------+  0              $0000 +--------------+  0
              bank 0                ...              bank n


        figuur 2.2.2.1.  geheugengebruik van de virtuele disk
</pre>

<h5>2.2.3. Realisatie</h5>

<p>Deze  paragraaf beschrijft de opbouw van het virtuele  disk  programma,  de werking van de BIOS-routines en de invulling van de disk parameter tabellen.</p>

<h6>Opbouw</h6>

<p>Het geheugendisk-programma bestaat uit de volgende delen:</p>

</ul>
   <li>installatie,</li>
   <li>formattering,</li>
   <li>jump-table,</li>
   <li>parameter-tabellen,</li>
   <li>BIOS-routines.</li>
</ul>

<p>Hieronder worden deze delen nader toegelicht.</p>

<h6>Installatie</h6>

<p>De geheugendisk-installatie verloopt als volgt.

<p>De  installatieroutine  bepaalt of de geheugendisk geformatteerd  dient  te worden ('-f' optie).  Indien dit het geval is, dan kopi&euml;ert de installatie- routine  de  format-routine naar de beschikbare ruimte in het  Bondwell  12 BIOS (adres $F500..$F6BF) en roept deze vervolgens aan.  Is het formatteren niet vereist,  dan wordt dit gedeelte achterwege gelaten.   Verder kopi&euml;ert de installatieroutine de geheugendisk parameter-tabellen en  -BIOS-routines naar  de beschikbare ruimte in het originele BIOS.   De sprong naar de  CCP aan  het einde van de BIOS warmboot-routine wordt vervangen door een sprong naar de geheugendisk warmboot-routine.   Ten slotte overschrijft de installatieroutine  een  gedeelte  van  de  originele  BIOS  jump-table  met   de geheugendisk jump-table.</p>

<h6>Formattering</h6>

<p>De format-routine initialiseert alle locaties in de geheugenbank(en) waarin de geheugendisk-directory zich bevindt met de waarde $E5,  hetgeen  corres- pondeert met een lege directory.</p>

<h6>Jump-table</h6>

<p>De  jump-table  zorgt  ervoor dat bij het aanroepen  van  de  BIOS-routines seldsk tot en met write,  eerst naar de ermee corresponderende geheugendisk BIOS-routine wordt gesprongen. Daarna wordt, indien dat nodig is, de origi- nele BIOS-routine doorlopen.</p>

<h6>Disk parameter tabellen</h6>

<p>In de disk parameter-tabellen zijn de disk-eigenschappen vastgelegd. De geheugendisk heeft de volgende eigenschappen:</p>

<h6>Disk Parameter Header</h6>

<pre>
   XLT   =    0: Er wordt geen sector-translation toegepast.
   DIRBUF=$F2CD: Adres van de directory-buffer van drive A: en B:.
   DPB   = ....: Disk Parameter Block, zie verder.
   CSV   =    0: Geen controle op verwisselen van de disk.
   ALV   = ....: Dit is het adres van de geheugendisk allocation-buffer.
</pre>

<h6>Disk Parameter Block</h6>

<pre>
   SPT = 256: Er  is precies e'e'n track per geheugenbank;  dit geeft  een eenvoudige  berekening van het geheugenbank-nummer en  het adres van de sector in die bank.
   BSH =   4: De allocation-block grootte is 2048 byte.
   BLM =  15: De allocation-block grootte is 2048 byte.
   EXM =   1: De allocation-block grootte is 2048 byte en DSM &lt; 256.
   DSM =  31: Maximum allocation-block nummer voor de 64 kbyte disk. (127 voor de 256 kbyte geheugendisk.)
   DRM =  63: Er zijn 64 directory-plaatsen.
   AL0 = $80: Er is e'e'n block gereserveerd voor de directory.
   AL1 =   0: Idem.
   CKS =   0: Geen controle op het verwisselen van de disk.
   OFF =   0: Er zijn geen gereserveerde tracks op de disk.
</pre>

<h6>BIOS-routines</h6>

<p>Het CP/M-besturingssysteem hoeft niet aanwezig te zijn op de geheugendisk. Verder  zal het toepassen van skewing voor de geheugendisk geen  snelheidswinst  geven.  Hieruit  volgt  dat  de  home- en  sectran-routine  voor  de geheugendisk niet van belang zijn.   Hieronder volgen de geheugendisk BIOS- routines.</p>

<pre>
   seldsk: Het  drive-nummer  in  register c wordt  gekopi&euml;erd  naar  de
           variabele 'drive';  indien het de geheugendisk  betreft,  dan
           krijgt  registerpaar  hl het adres van de  geheugendisk  Disk
           Parameter  Header en de subroutine wordt  be&euml;indigd;  betreft
           het een andere disk, dan springt de routine naar de originele
           seldsk-routine.
   settrk: Het  track-nummer in registerpaar bc wordt gekopi&euml;erd naar de
           variabele  'track'  en de routine springt naar  de  originele
           settrk-routine.
   setsec: Het sector-nummer in registerpaar bc wordt gekopi&euml;erd naar de
           variabele  'sector' en de routine springt naar  de  originele
           setsec-routine.
   setdma: Het  dma-adres  in registerpaar bc wordt gekopi&euml;erd  naar  de
           variabele  'dma'  en  de  routine spring  naar  de  originele
           setdma-routine.
   read  : Met behulp van de subroutine 'checkd' wordt gecontroleerd  of
           er  een sector gelezen moet worden van de geheugendisk of van
           een  van de floppy-disks;  betreft het niet de  geheugendisk,
           dan springt de routine naar de orignele read-routine;  indien
           het de geheugendisk betreft, dan wordt de subroutine 'getadr'
           aangeroepen;  deze routine selecteert de juiste  geheugenbank
           (track  van  de geheugendisk) en geeft het beginadres van  de
           gevraagde sector in die geheugenbank in registerpaar  hl;  de
           sector   wordt   gekopi&euml;erd  naar  de  locale   geheugendisk-
           databuffer in de 'common bank';  met de routine 'bank'  wordt
           geheugenbank  nul  weer  geselecteerd;  vervolgens  wordt  de
           geheugendisk-databuffer  gekopi&euml;erd  naar het  dma-adres;  de
           read-routine  eindigt met een nul in register a om  het  BDOS
           aan te geven dat de lees-operatie goed is verlopen.
   write : De  werking van de write-routine is vergelijkbaar met die van
           de read-routine;  de richting van de gegevensstroom is echter
           omgekeerd.
</pre>

<h6>Overige routines</h6>

<pre>
   vdwbt : Deze routine wordt vlak na de originele BIOS warmboot-routine
           doorlopen;  de vdwbt-routine controleert of het nummer van de
           default  drive  in de MWA overeenkomt met het nummer  van  de
           geheugendisk.  Als de nummers overeenkomen, wordt in register
           c het nummer van de geheugendisk meegegeven naar de CCP.
   checkd: Deze routine geeft aan of de geheugendisk is geselecteerd.
   getadr: De  routine  'getadr'  selecteert de geheugenbank  waarin  de
           gevraagde sector zich bevindt en geeft in registerpaar hl het
           beginadres van de sector in die geheugenbank.   De berekening
           van geheugenbank-nummer en sector-beginadres gaat als volgt:
           - de sector-grootte is 128 byte,
           - er  zijn 256 sectoren per track:  256 x 128 byte= 32 kbyte,
             zodat elke track e'e'n geheugenbank beslaat;
             het nummer  van de geheugenbank is:  bank= track + 1:
             de geheugendisk begin bij geheugenbank een;
           - de  eerste sector van elke track begint op adres $0 van  de
             met die track corresponderende geheugenbank:  de berekening
             van  het beginadres van een sector is dus niet  afhankelijk
             van het tracknummer; het beginadres van een sector is:
             adres=  sector x 128, of (sector x 256) / 2:
           - laad register h met het sector-nummer (sector x 256),
             laad register l met 0,
           - schuif  de  inhoud  van registerpaar hl  e'e'n  positie  naar
             rechts (hl / 2),
   bank  : De routine 'bank' selecteert de geheugenbank op grond van het
           nummer in register a.  Deze routine is zowel geschikt voor de
           standaard 64 kbyte geheugenuitbreiding van de Bondwell 12 als
           voor de geheugenuitbreiding van 256 kbyte.  De werking van de
           geheugenbank selectie wordt beschreven in hoofdstuk  3..   De
           nummering van de geheugenbanken in de routine 'bank' wijkt af
           van  de nummering in de Bondwell 12/14 manual:  in de routine
           'bank' is de nummering als volgt:
           - 0   : Boot-ROM,
           - 1..9: RAM-bank 0..8.
</pre>

<h3>3. Geheugenbank selectie</h3>

<h4>3.1. Inleiding</h4>

<p>In dit hoofdstuk beschrijf ik de werking van het circuit dat zorgt voor het omschakelen  van de geheugenbanken.   Kennis hiervan is noodzakelijk om  de werking  van  de  geheugenbank selectieroutine  en van de  extra  geheugen- uitbreiding te kunnen doorgronden.</p>

<h4>3.2. Werking</h4>

<p>In  figuur  3.2.1.  is  het  schema van  het  Bondwell  12/14  geheugenbank selectie-circuit  weergegeven.   Met  dit  circuit  kan  een  van  de  drie geheugenbanken of de boot-ROM worden geselecteerd.   Bank nul is de normaal geselecteerde bank, banken een en twee worden gebruikt voor de geheugendisk.</p>

<pre>
Address-bus
___________________________
     \                     \   addressable
     |     decoder         |      latch              decoder
     |                     |
     |      LS138          |      LS259               LS138
     |  +-----------+      |  +-----------+       +-----------+
     |  |           |      |  |           |       |           |
  A7 |\_| /E1   /Q7 |-     |  |        Q7 |-      |       /Q7 |
     |  |       /Q6 |-  A3 |\_|  A2    Q6 |-      |       /Q6 |
     |  |       /Q5 |-  A2 |\_|  A1    Q5 |-      |       /Q5 |
     |  |       /Q4 |-  A1 |\_|  A0    Q4 |-      |       /Q4 |
     |  |       /Q3 |-     |  |        Q3 |-    0 |       /Q3 |--o /bank2
  A6 |\_|  A2   /Q2 |-  A0 \_|  D      Q2 |-o   o-|  A2   /Q2 |--o /bank1
  A5 |\_|  A1   /Q1 |-        |        Q1 |-------|  A1   /Q1 |--o /bank0
  A4  \_|  A0   /Q0 |---------| /E     Q0 |-------|  A0   /Q0 |--o /boot-ROM
        |    /E2    |         |           |       |           |
        +-----------+         +-----------+       +-----------+
___________   |
I/O-request   |
______________/
                   figuur 3.2.1.  geheugenbank selectie circuit
</pre>

<p>In  de  figuur zijn ge&iuml;nverteerde signalen aangegeven door een '/' voor  de signaalnaam te zetten. Signalen die voor het beschrijven van de werking van het circuit niet van belang zijn, staan niet in de figuur vermeld.</p>

<p>De werking van het circuit is als volgt.<br /> Door het aanbieden van een bepaald I/O-adres kan met behulp van de  decoder LS138, links in het schema, een van de 'latches' van de  LS259 geadresseerd worden.  De  waarde  van de 'latches' nul en een van de LS259 bepalen  welk geheugenbank  select-signaal  actief  gemaakt wordt via  de  decoder  LS138 rechts in het schema (/boot-ROM, /bank0..2).</p>

<p>Hieronder wordt de werking meer gedetailleerd beschreven.<br /> Wanneer er een I/O-adres aangesproken wordt waarbij A7 gelijk nul  is,  dan wordt  de decoder LS138 links in het schema 'enabled':  dit is in het  I/O- adresgebied  $00..$7F.  I/O-adreslijnen A4 tot en met A6 bepalen dan  welke uitgang van de decoder geactiveerd wordt.  Indien uitgang /Q0 actief wordt, dan  wordt  de adresseerbare 'latch' LS259 'enabled':  dit is in  het  I/O- adresgebied  $00..$0F.  I/O-adreslijnen A1..A3 bepalen welke 'latch' van de LS259  geadresseerd wordt,  I/O-adreslijn A0 bepaalt of in die 'latch'  een '1' of een '0' geschreven wordt.  Tezamen vormen de uitgangen Q0 en Q1  van de  adresseerbare  'latch' het ingangsignaal (0..3) voor de decoder  LS138, rechts in het schema,  die een van de geheugenbank selectie-signalen actief maakt.</p>

<h3>4. 256 kbyte  geheugenuitbreiding</h3>

<h4>4.1. Inleiding</h4>

<p>In  dit  hoofdstuk  beschrijf ik de 256 kbyte geheugenuitbreiding  voor  de Bondwell 12.  Voor deze uitbreiding is het nodig om enige veranderingen aan te  brengen  op het Bondwell 12 computerboard.   Verder is  er  een  kleine schakeling nodig voor het genereren van enkele niet beschikbare signalen. In  bijlage  1 is het complete schema van  het  geheugenuitbreidingscircuit weergegeven.   Bijlage  2 geeft de componentenopstelling en printlayout van de voor de uitbreiding gemaakte print.</p>

<h4>4.2. Dynamische RAM</h4>

<p>Wat moet er veranderd worden om voor IC 53..60 in plaats van 64 kbyte,  256 kbyte  dynamische RAM te gebruiken?   Om dit te kunnen bepalen,  kijken  we eerst naar de werking van dynamische RAM (zie figuur 4.2.1.).</p>

<pre>
                                 +-------+
                       address   |       |   data
               A7/A15 ---------\ |       | /------\  D7
                      |         \|dynamic|/        \
                      |         /|  RAM  |\        /
               A0/A8  ---------/ |       | \------/  D0
                                 |       |
                                 +-------+
               ___                 |  |
               RAS ----------------+  |
               ___                    |
               CAS -------------------+

                     figuur 4.2.1.  dynamische RAM
</pre>

<p>Het gebruik van dynamische RAM heeft twee opvallende aspecten,  namelijk de adressering en de 'refresh' van de geheugenlocaties.</p>

<h5>Adressering</h5>

<p>De  toegang tot een geheugenplaats in een dynamische RAM is te  vergelijken met het selecteren van een element uit een tweedimensionale array:  er moet een rij-adres en een kolom-adres worden aangeboden om de gewenste geheugenlocatie aan te wijzen.   Het adresseren van een geheugenlocatie gebeurt bij een  dynamische  RAM door het na elkaar aanbieden van het rij-adres en  het kolom-adres,  over dezelfde adreslijnen.   Het onderscheid tussen het  rij- adres  en het kolom-adres wordt aangegeven door de RAS (Row Address Select) en CAS (Column Address Select) signalen.</p>

<h5>Refresh</h5>

<p>De waarde van een bit in een dynamische RAM wordt bepaald door de lading op een  kleine condensator.   Om 'geheugenverlies' door het weglekken van deze lading  te voorkomen,  wordt de lading periodiek hersteld  ('gerefreshed').</p>

<p>Dit 'refreshen' gebeurt automatisch voor alle geheugenlocaties van een rij, wanneer  die rij geadresseerd wordt.   Om er nu voor te zorgen dat elke rij binnen  een  bepaalde  vereiste tijd geadresseerd wordt,  verzorgt  de  Z80 microprocessor  speciale  refresh-adresseringen van  de  rij-adressen.   De refresh-counter van de Z80 verzorgt het 'refreshen' van 128 rijen (A0..A6).</p>

<p>De eisen voor de memory-refresh van 64 en 256 kbyte geheugens zijn:</p>

<ul>
   <li>xx64 : 128 refresh cycles / 2 ms (7 bit refresh-counter: A0..A6),</li>
   <li>xx256: 256 refresh cycles / 4 ms (8 bit refresh-counter: A0..A7).</li>
</ul>

<p>Hieruit  volgt  dat de Z80 microprocessor niet in staat is  de  refresh  te verzorgen voor 256 kbyte dynamische RAM.</p>

<h4>4.3. Bankselect- & refresh-circuit</h4>

<p>Om de bestaande hardware van de Bondwell 12 aan te passen aan de 256  kbyte dynamische geheugens,  is het 'bankselect- & refresh-circuit' gemaakt.  Het heeft de volgende functies:</p>

<ul>
   <li>generatie van A7 met refresh-signaal/A15,</li>
   <li>generatie van A8/A16,</li>
   <li>leveren  van een stuursignaal voor een LED om de activiteit van  de geheugendisk aan te geven.</li>
</ul>

<h5>A7 met refresh/A15</h5>

<p>Om 256 kbyte dynamische RAM geheel te kunnen 'refreshen' dient adreslijn A7 ook deel uit te maken van de refresh-cyclus (zie figuur 4.3.1.).</p>

<p>Met  behulp van het row/column- (R/Cn) en het refresh-signaal (/RFR) van de Z80  microprocessor,  wordt  het aantal refresh-cycles,  dat  de  processor genereert,  bijgehouden  door de teller HEF 4040.   Telkens wanneer er  128 refresh-cycles  geteld  zijn,  wordt de uitgang Q7 van de teller  HEF  4040 ge&iuml;nverteerd.  De switch LS151 bepaalt op grond van het /RFR-signaal of het op  uitgang  Y  aan  te  bieden  A7-signaal  een  normale  of  een  refresh adressering  betreft.   Hierdoor  is nu ook A7 onderdeel  geworden  van  de refresh-cyclus.</p>

<p>Verder  bepaalt  het  row/column-signaal of het uitgangssignaal  Y  van  de switch  LS151  een  rij-adres (normale of refresh adressering  A7)  of  een kolom-adres (originele A15) bevat.</p>

<pre>
              NOR-gate         counter

               LS02           HEF 4040
     _       +-----+     +---------------+
   R/C o-----|     |     |               |
   ___       | >=1 |o----| CLK           |
   RFR o-----|     |     |  Q7           |
             +-----+     +---------------+
                            |
                            |     switch
                            |      LS151
                            |    +-------+
                            |    |       |
   A7 org o-----------------|----| D3    |
                            +----| D2    |
   A15    o-----------------+----| D1  Y |-----o A7 + refresh
                            +----| D0    |
     _                           |       |        (xx256 RAM)
   R/C    o----------------------| B     |
   ___                           |       |
   RFR    o----------------------| A     |
                                 +-------+

         figuur 4.3.1.  generatie van A7 + refresh / A15
</pre>

<h5>Adreslijn A8/A16</h5>

<p>Door  het toepassen van 256 kbyte geheugens zijn er acht in plaats van twee extra geheugenbanken van 32 kbyte.  Om deze geheugenruimte te kunnen adresseren zijn twee nieuwe adres-signalen nodig: A8 en A16 (zie figuur 4.2.2.). De andere adres-signalen zijn reeds beschikbaar in de bestaande schakeling.</p>

<pre>
                  8 bit-register         switch

                      LS174               LS158
                  +-----------+       +-----------+
                  |           |       |           |
                  | D7     Q7 |-      |           |
                  | D6     Q6 |-      |           |
                  | D5     Q5 |-      |           |
                  | D4     Q4 |-      |         Y |----o A8/A16
                  | D3     Q3 |-      |           |
                  | D2     Q2 |-      |           |    (xx256 RAM)
   LS259 Q1   o---| D1     Q1 |-------| B         |
   LS259 Q0   o---| D0     Q0 |-------| A         |
                  |    CLK    |       |     S     |
                  +-----------+       +-----------+
                        |                   |
   LS259 Q2   o---------+                   |
       ______                               |
   Row/Column o-----------------------------+

               figuur 4.3.2.  generatie van A8/A16
</pre>

<p>De  adres-signalen A8 en A16 worden gemaakt met behulp van de  'addressable latch' LS259 van het originele bankselect-circuit (zie figuur 3.2.1.).  Via de uitgangen Q0,  Q1 en Q2 van deze 'addressable latch' worden de A8 en A16 signalen in het 8-bit register LS174 geplaatst.  De Q2-uitgang van de LS259 voert het klok-signaal voor het 8-bit register LS174.</p>

<p>Het row/column-signaal bepaalt of het uitgangssignaal Y van de switch LS158 het rij-adres (A8) of het kolom-adres (A16) bevat.</p>

<h5>Indicatie van de geheugendisk activiteit</h5>

<p>Figuur 4.3.3.  geeft de schakeling weer voor het aangeven van de  geheugendisk activiteit.</p>

<pre>
                    NOR-gate         one-shot

                      LS02             555
                                +---------------+
                    +-----+     |               |   R
     LS259 Q2 ------| >=1 |o----| /T            |--===--o
                    +-----+     |    D THR      |         LED
                                +---------------+       o
                                  R   ||   C            |
                            <----===--++---||---|      ---

        figuur 4.3.3.  geheugendisk activiteit indicatie
</pre>

<p>Het signaal dat de geheugendisk activiteit aangeeft, wordt afgeleid van het uitgangssignaal  Q2  van  de 'addressable latch' LS259  van  het  originele bankselect-circuit (zie figuur 3.2.1.).  De uitgang Q2 wordt korte tijd '1' wanneer  een van de virtuele disk geheugenbanken geadresseerd wordt.   Deze korte  puls  wordt door de 'one-shot' 555 verlengt tot  circa  10  ms.   De uitgang van de 'one-shot' is geschikt voor het aansturen van een LED.</p>

<h4>4.4. Installeren van de geheugenuitbreiding</h4>

<p>Het  toevoegen  van  de 256 kbyte geheugenuitbreiding aan  de  Bondwell  12 hardware brengt de volgende handelingen met zich mee:</p>

<ul>
   <li>verwijderen van vier verbindingen op het computerboard,</li>
   <li>aanbrengen van twee nieuwe verbindingen op het computerboard,</li>
   <li>aansluiten van van het uitbreidings-board op het computerboard.</li>
</ul>

<p>De hieronder vermelde I.C.-nummers zijn op het computerboard aangegeven.</p>

<h5>Te verwijderen verbindingen</h5>

<pre>
Printzijde     Signaal    Onderbreken tussen
Componenten    A8         IC52, pin 8  (74LS32)  --  IC53, pin 1  (xx256)
Componenten    A8         IC60, pin 1  (xx256)   --  IC61, pin 15 (xx256)
Componenten    A7         IC60, pin 9  (xx256)   --  IC61, pin 9  (xx256)
Soldeer        A7         IC59, pin 9  (xx256)   --  IC44, pin 9  (74LS157)
</pre>

<h5>Nieuwe verbindingen</h5>

<pre>
Printzijde     Signaal    Verbinding tussen
Soldeer        A7         IC44, pin 9  (74LS157) --  IC61, pin 9  (4164)
Soldeer        CAS        IC52, pin 9  (74LS32)  --  IC61, pin15  (4164)
</pre>

<h5>Aansluiten van het uitbreidings-board</h5>

<p>Op  het  uitbreidings-board bevinden zich een tien-pins en  twee  twee-pins Molex-connectors  om  de verbindingen met het computerboard te  maken  (zie bijlage 2).   Een geschikte plaats om het uitbreidings-board te monteren is linksvoor op het plastic frame in de Bondwell 12. Onderstaande  lijst beschrijft de verbindingen die gelegd moeten worden van de tien-pins Molex-connector naar het Bondwell 12 computerboard.

<pre>
 pin    draadkleur   signaal   I.C.  type  pin
-------------------------------------------------
  1.	brown	     R/Cn     (IC44, LS157, p1 )
  2.    red	     O0	      (IC18, LS259, p4 )
  3.    orange	     O1	      (IC18, LS259, p5 )
  4.    yellow	     O2	      (IC18, LS259, p6 )
  5.    green	     A7mem    (IC53, xx256, p9 )
  6.    blue	     A7org    (IC35,   Z80, p37)
  7.    violet	     A8       (IC53, xx256, p1 )
  8.    grey	     A15      (IC44, LS157, p11)
  9.    white	     RFRn     (IC35,   Z80, p28)
 1.     black	     MRQn     (Molex pin 1=R/Cn)
</pre>

<p>Verder  dient nog de 5V voedingsspanning aangesloten te worden op de  daarvoor  bestemde  twee-pins  Molex-connector.   Indien gewenst  kan  een  LED aangesloten worden op de overblijvende twee-pins Molex-connector.</p>

<p>M.J. Moene<br />
Linnaeusparkweg 46-3<br />
1098 EC Amsterdam<br />
Tel.:020-936378 (bij voorkeur tussen 19:00 en 20:00 uur)</p>

<p class="center">                             o-------o-------o</p>

<dl>
<dt>Opmerking 1:</dt><dd>VDISK.COM t/m versie 1.5 Programma's  die direct de geheugendisk BIOS-routines read  of write aanroepen,  e'n waarvan de stackpointer een waarde  heeft die kleiner is dan $8000,  zullen vastlopen.  Dit komt doordat de routine "bank" na het omschakelen van geheugenbank nul naar e'e'n van de geheugendiskbanken, het return-adres van de aanroepende routine (read,  write of getadr) uit de verkeerde geheugenbank haalt. In VDISK versie 1.6 is dit probleem opgelost.</dd>

<dt>Opmerking 2:</dt><dd>De geheugenruimte waarin de routines voor de virtual disk worden geplaatst, is tevens in gebruik voor: - routine die de eerste 'cold-boot' verzorgt, - disk-buffer  bij  het  gebruik  van  Kaypro  II  en  Osborne configuratie voor drive B:;  tegelijkertijd toepassen van de geheugendisk en het gebruik van drive B:  voor Kaypro II  of Osborne formaat is derhalve niet mogelijk.</dd> <dl>

<p>Lijst van gebruikte afkortingen:</p>

<pre>
AL0,AL1: beginwaarde voor ALV (DPH-tabel)
ALV    : adres van een buffer om de bezetting van disk bij te houden (DPH)
AND    : logische 'en'-functie
ASCII  : American Standard Code for Information Interchange
BDOS   : Basic Disk Operating System (CP/M)
BIOS   : Basic Input/Output System (CP/M)
BLM    : BLock Mask (DPB-tabel)
BSH    : Block SHift factor (DPB-tabel)
CAS    : Column Address Select (Dynamische RAM)
CCP    : Console Command Processor (CP/M)
CKS    : aantal directory-plaatsen dat gecontroleerd moet worden (DPB-tabel)
CPM    : Control Program for Microcomputers
CSV    : adres van een buffer voor controle op het verwisselen van de disk
DIRBUF : Directory Buffer (DPH-tabel)
DMA    : Direct Memory Access
DPB    : Disk Parameter Block
DRM    : maximum directory-plaats nummer (0..DRM) (DPB-tabel)
DSM    : maximum data-block nummer van een drive (0..DSM) (DPB-tabel)
EXM    : EXtent Mask (DPB-tabel)
HEF    : type cmos logica (Philips)
LED    : Light Emitting Diode (geheugendisk activiteit indicatie)
MRQ    : Memory ReQuest (microprocessor)
MWA    : Monitor Work Area (CP/M systeem parameters)
NOR    : ge&iuml;nverteerde logische 'of'-functie
OFF    : aantal gereserveerde (systeem) tracks (DPB-tabel)
RAM    : Random Access Memory
RAS    : Row Address Select (dynamische RAM)
RFR    : ReFResh (memory-refresh, microprocessor)
ROM    : Read Only Memory
SPT    : Sectors Per Track (DPB-tabel)
TPA    : Transient Program Area (CP/M)
THR    : THReshold (one-shot 555)
XLT    : sector vertaal tabel (DPH-tabel)
</pre>

<p>Geraadpleegde literatuur:</p>
<dl>
<dt>[1]</dt>
   <dd>CP/M Operating System Manual<br />
       California, Digital Research.</dd>

<dt>[2]</dt>
   <dd>Hoff, E.L. van 't:<br />
       "Meer performance met uitbreiding opslageenheden".<br />
       In: Databus. februari 1985, pp. 12-21.</dd>

<dt>[3]</dt>
   <dd>Moene, M.J.:<br />
       VDISK.MAC<br />
       Version 1.5, Amsterdam, februari 1987.</dd>

<dt>[4]</dt>
   <dd>Wilmink, Jan:<br />
        CP/M Operating System, gebruik, programmeren, opbouw.<br />
        3e oplage, Deventer: Kluwer Technische Boeken B.V., 1984.</dd>
</dl>

<p class="center">o-------o-------o</p>

<pre>
                                S C H E M A


                            P R I N T - L A Y O U T


                C O M P O N E N T E N - O P S T E L L I N G
</pre>
