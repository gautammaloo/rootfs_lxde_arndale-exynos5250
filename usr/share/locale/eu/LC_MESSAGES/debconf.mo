��    F      L  a   |         o     ?   q  �   �  .   H  #   w     �  '   �     �     �            (   *     S  K   j     �     �  -   �     �      	  R   	     [	     i	  8   �	  M   �	  k   
  8   s
  (   �
     �
     �
  u   �
     o     t  X   y  @   �          )  ;   F  6   �  7   �  �   �  /   z  4   �  =   �  Y     �  w  )   ;  7   e     �  1   �  '   �  .     C   E     �  �   �     $     *  n   J     �  @   �       &   0     W     Z  '   l     �  !   �     �  a   �     M  �  Q  ~   �  =   x  �   �  <   `  +   �  !   �  6   �     "  #   .     R     i  8   }     �  J   �     !     (  H   0     y     �  T   �     �     �  U     n   h  �   �  <   Y  )   �     �  -   �  }   �     u  	   }  y   �  Q        S      j  M   �  N   �  2   (  �   [  E   �  ;   5  >   q  _   �  �     =   "  E   A"     �"  6   �"  3   �"  2   #  K   D#     �#  �   �#  	   C$  /   M$  m   }$      �$  M   %      Z%  3   {%     �%     �%  $   �%  #   �%  "   &     6&  `   R&     �&        4      '       A                    =                       0                           >       *                  (       3   <   ,   :                 7   /   ;   F      @         -      D   .   B          8       1                            +   2   #          C             9      %      6          !       $   "   )   
      E      	   5   ?   &    
        --outdated		Merge in even outdated translations.
	--drop-old-templates	Drop entire outdated templates. 
  -o,  --owner=package		Set the package that owns the command.   -f,  --frontend		Specify debconf frontend to use.
  -p,  --priority		Specify minimum priority question to show.
       --terse			Enable terse mode.
 %s failed to preconfigure, with exit status %s %s is broken or not fully installed %s is fuzzy at byte %s: %s %s is fuzzy at byte %s: %s; dropping it %s is missing %s is missing; dropping %s %s is not installed %s is outdated %s is outdated; dropping whole template! %s must be run as root (Enter zero or more items separated by a comma followed by a space (', ').) Back Choices Config database not specified in config file. Configuring %s Debconf Debconf is not confident this error message was displayed, so it mailed it to you. Debconf on %s Debconf, running at %s Dialog frontend is incompatible with emacs shell buffers Dialog frontend requires a screen at least 13 lines tall and 31 columns wide. Dialog frontend will not work on a dumb terminal, an emacs shell buffer, or without a controlling terminal. Enter the items you want to select, separated by spaces. Extracting templates from packages: %d%% Help Ignoring invalid priority "%s" Input value, "%s" not found in C choices! This should never happen. Perhaps the templates were incorrectly localized. More Next No usable dialog-like program is installed, so the dialog based frontend cannot be used. Note: Debconf is running in web mode. Go to http://localhost:%i/ Package configuration Preconfiguring packages ...
 Problem setting up the database defined by stanza %s of %s. TERM is not set, so the dialog frontend is not usable. Template #%s in %s does not contain a 'Template:' line
 Template #%s in %s has a duplicate field "%s" with new value "%s". Probably two templates are not properly separated by a lone newline.
 Template database not specified in config file. Template parse error near `%s', in stanza #%s of %s
 Term::ReadLine::GNU is incompatable with emacs shell buffers. The Sigils and Smileys options in the config file are no longer used. Please remove them. The editor-based debconf frontend presents you with one or more text files to edit. This is one such text file. If you are familiar with standard unix configuration files, this file will look familiar to you -- it contains comments interspersed with configuration items. Edit the file, changing any items as necessary, and then save it and exit. At that point, debconf will read the edited file, and use the values you entered to configure the system. This frontend requires a controlling tty. Unable to load Debconf::Element::%s. Failed because: %s Unable to start a frontend: %s Unknown template field '%s', in stanza #%s of %s
 Usage: debconf [options] command [args] Usage: debconf-communicate [options] [package] Usage: debconf-mergetemplate [options] [templates.ll ...] templates Valid priorities are: %s You are using the editor-based debconf frontend to configure your system. See the end of this document for detailed instructions. _Help apt-extracttemplates failed: %s debconf-mergetemplate: This utility is deprecated. You should switch to using po-debconf's po2debconf program. debconf: can't chmod: %s delaying package configuration, since apt-utils is not installed falling back to frontend: %s must specify some debs to preconfigure no none of the above please specify a package to reconfigure template parse error: %s unable to initialize frontend: %s unable to re-open stdin: %s warning: possible database corruption. Will attempt to repair by adding back missing question %s. yes Project-Id-Version: eu
Report-Msgid-Bugs-To: 
POT-Creation-Date: 2014-04-22 20:04-0400
PO-Revision-Date: 2012-08-01 15:11+0200
Last-Translator: Iñaki Larrañaga Murgoitio <dooteo@zundan.com>
Language-Team: Basque <debian-l10n-basque@lists.debian.org>
Language: eu
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit
X-Generator: Lokalize 1.0
Plural-Forms: nplurals=2; plural=(n != 1)
 
        --outdated		Batu nahiz eta itzulpenak zaharkituta egon.
	--drop-old-templates	Baztertu zaharkitutako txantiloi osoak. 
  -o,  --owner=paketea		Ezarri komandoaren jabe den paketea.   -f,  --frontend		Erabiliko den debconf interfazea ezarri.
  -p,  --priority		Erakutsiko diren galderen lehentasun baxuena ezarri.
       --terse			Modu laburra gaitu.
 %s(e)k huts egin du aurrekonfiguratzean, Irteerako kodea: %s %s hondatuta edo erabat instalatu gabe dago %s zalantzazkoa da %s byte-an: %s %s zalantzazkoa da %s byte-an: %s; alde batetara uzten %s falta da %s falta da; %s alde batetara uzten %s ez dago instalatuta %s zaharkituta dago %s zaharkituta dago, txantiloi osoa alde batetara uzten. %s root gisa exekutatu behar da (sar 0 edo elementu gehiago gako bat eta hutsune batez bereizirik (', ').) Atzera Aukerak Ez dago konfigurazioko datu-baserik ezarrita konfigurazioko fitxategian. %s konfiguratzen Debconf Debconf ez dago ziur errore mezu hau erakus daitekeenik, beraz postaz bidaliko dizu. Debconf %s(e)n Debconf, %s(e)n exekutatzen Elkarrizketa-koadroaren interfazea ez da emacs-en shell-eko bufferrekin bateragarria. Elkarrizketa-koadroaren interfazeak gutxienez 13 lerro altuerako eta 31 zutabe zabalerako pantaila beharko du. Elkarrizketa-koadroaren interfazeak ez du terminal tonto, emacs shell buffer edo kontrolik gabeko terminal  batean funtzionatuko. Sartu hautatu nahi dituzun elementuak, bereiztu zuriuneekin. Txantiloiak paketeetatik ateratzen: %% %d Laguntza Baliogabeko "%s" lehentasunari ezikusi egiten Emandako "%s" balioa ez da C aukeretan aurkitu! Hau ez zen inoiz gertatu beharko. Agian txantiloia gaizki lokalizaturik dago. Gehiago Hurrengoa Ez dago elkarrizketa-koadro bezalako programarik instalatuta, ezingo da beraz elkarrizketa-koadroaren interfazea erabili. Oharra: Debconf web moduan funtzionatzen ari da. Joan hona:  http://localhost:%i/ Paketeen konfigurazioa Paketeak aurrekonfiguratzen ...
 Arazoa gertatu da %s / %s paragrafoak definitutako datu-basea konfiguratzean. TERM ez dago ezarrita, eta ezin da elkarrizketa-koadroaren interfazea erabili. %s txantiloiak ez du 'Template:' lerro bat %s(e)n
 %s txantiloiak %s(e)n bikoiztutako "%s" eremu bat du "%s" balio berriarekin. Baliteke bi txantiloiak lerro berri bakar batez bereiztuta ez egotea.
 Ez dago txantiloien datu-baserik ezarrita konfigurazioko fitxategian. Txantiloiaren errorea '%s'(e)tik gertu, %s/%s paragrafoan.
 Term::ReadLine::GNU ez da emacs shell buferrekin bateragarria. Zeinu eta aurpegieren aukerak ez dira gehiago erabiliko konfigurazioko fitxategian. Ken itzazu. Editorean oinarritutako debconf interfazeak testu-fitxategi bat edo gehiago erakutsiko dizkizu editatzeko. Hau testu-fitxategi horietako bat da. Zu Unix-en konfigurazioko fitxategi arruntekin ohituta bazaude, fitxategi hau ezaguna egingo zaizu -- honek iruzkinak ditu konfigurazioko elementuen artean. Editatu fitxategia, aldatu behar diren elementuak, gero gorde eta itxi. Momentu horretan debconf-ek editatutako fitxategia irakurri eta zuk sartutako balioak erabiliko ditu sistema konfiguratzeko. Interfaze honek kontrolatzen den terminal (tty) bat behar du. Ezin izan da Debconf::Element::%s kargatu. Hutsegitearen zergatia: %s Ezin da interfaze hau hasi: %s Txantiloiaren '%s' eremu ezezaguna %s/%s paragrafoan.
 Erabilera: debconf [aukerak] komandoa [argumentuak] Erabilera: debconf-communicate [aukerak] [paketea] Erabilera: debconf-mergetemplate [aukerak] [txantiloiak.ll ...] txantiloiak Lehentasun erabilgarriak: %s Editorean oinarritutako debconf interfazea erabiltzen ari zara sistema konfiguratzeko. Dokumentu honen amaieran argibide zehatzagoak aurki ditzakezu. _Laguntza apt-extracttemplates komandoak huts egin du: %s debconf-mergetemplate: Tresna hau zaharkituta dago. po-debconf-en po2debconf programa erabili beharko zenuke. debconf: ezin da chmod landu: %s paketearen konfigurazioa atzeratu egingo da apt-utils ez baitago instalatuta. interfaze honetara itzultzen: %s deb batzuk zehaztu behar dituzu aurrekonfiguratzeko ez aurrekoetako bat ere ez zehaztu pakete bat birkonfiguratzeko errorea txantiloia analizatzean: %s ezin da interfaze hau abiarazi: %s ezin da stdin berrireki: %s abisua: datu-basea hondatuta egon daiteke. Konpontzen saiatuko da galdutako %s galdera gehitzen. bai 