��    E      D  a   l      �  o   �  ?   a  �   �  .   8  #   g     �  '   �     �     �     �       (        C  K   Z     �     �  -   �     �     �     �     	  8   	  M   V	  k   �	  8   
  (   I
     r
     w
  u   �
            X     @   o     �     �  ;   �  6     7   V  �   �  /     4   G  =   |  Y   �  �    )   �  7        :  1   Y  '   �  .   �  C   �     &  �   ?     �     �  n   �     V  @   o     �  &   �     �     �  '   	     1  !   J     l  a   �     �  s  �  s   b  A   �  �     6   �  1        L  .   j     �  #   �     �     �  /   �     .  T   K     �     �  P   �                    )  >   @  |     t   �  <   q  &   �     �  #   �  �   �     �     �  g   �  H   �     H     b  F   �  O   �  6     �   O  K   �  A   9  B   {  n   �  �  -  (   !  <   1!  #   n!  9   �!  ,   �!  ,   �!  B   &"     i"  �   �"     #       #  �   A#  $   �#  K   �#     5$  2   O$     �$     �$  '   �$      �$  !   �$     %  z   $%     �%        3      &       @                    <                       /                          =       )                  '       2   ;   +   9                 6   .   :   E      ?         ,      C   -   A           7       0                            *   1   "          B             8      $      5                  #   !   (   
      D      	   4   >   %    
        --outdated		Merge in even outdated translations.
	--drop-old-templates	Drop entire outdated templates. 
  -o,  --owner=package		Set the package that owns the command.   -f,  --frontend		Specify debconf frontend to use.
  -p,  --priority		Specify minimum priority question to show.
       --terse			Enable terse mode.
 %s failed to preconfigure, with exit status %s %s is broken or not fully installed %s is fuzzy at byte %s: %s %s is fuzzy at byte %s: %s; dropping it %s is missing %s is missing; dropping %s %s is not installed %s is outdated %s is outdated; dropping whole template! %s must be run as root (Enter zero or more items separated by a comma followed by a space (', ').) Back Choices Config database not specified in config file. Configuring %s Debconf Debconf on %s Debconf, running at %s Dialog frontend is incompatible with emacs shell buffers Dialog frontend requires a screen at least 13 lines tall and 31 columns wide. Dialog frontend will not work on a dumb terminal, an emacs shell buffer, or without a controlling terminal. Enter the items you want to select, separated by spaces. Extracting templates from packages: %d%% Help Ignoring invalid priority "%s" Input value, "%s" not found in C choices! This should never happen. Perhaps the templates were incorrectly localized. More Next No usable dialog-like program is installed, so the dialog based frontend cannot be used. Note: Debconf is running in web mode. Go to http://localhost:%i/ Package configuration Preconfiguring packages ...
 Problem setting up the database defined by stanza %s of %s. TERM is not set, so the dialog frontend is not usable. Template #%s in %s does not contain a 'Template:' line
 Template #%s in %s has a duplicate field "%s" with new value "%s". Probably two templates are not properly separated by a lone newline.
 Template database not specified in config file. Template parse error near `%s', in stanza #%s of %s
 Term::ReadLine::GNU is incompatable with emacs shell buffers. The Sigils and Smileys options in the config file are no longer used. Please remove them. The editor-based debconf frontend presents you with one or more text files to edit. This is one such text file. If you are familiar with standard unix configuration files, this file will look familiar to you -- it contains comments interspersed with configuration items. Edit the file, changing any items as necessary, and then save it and exit. At that point, debconf will read the edited file, and use the values you entered to configure the system. This frontend requires a controlling tty. Unable to load Debconf::Element::%s. Failed because: %s Unable to start a frontend: %s Unknown template field '%s', in stanza #%s of %s
 Usage: debconf [options] command [args] Usage: debconf-communicate [options] [package] Usage: debconf-mergetemplate [options] [templates.ll ...] templates Valid priorities are: %s You are using the editor-based debconf frontend to configure your system. See the end of this document for detailed instructions. _Help apt-extracttemplates failed: %s debconf-mergetemplate: This utility is deprecated. You should switch to using po-debconf's po2debconf program. debconf: can't chmod: %s delaying package configuration, since apt-utils is not installed falling back to frontend: %s must specify some debs to preconfigure no none of the above please specify a package to reconfigure template parse error: %s unable to initialize frontend: %s unable to re-open stdin: %s warning: possible database corruption. Will attempt to repair by adding back missing question %s. yes Project-Id-Version: debconf
Report-Msgid-Bugs-To: 
POT-Creation-Date: 2014-04-22 20:04-0400
PO-Revision-Date: 2006-10-05 21:07-0300
Last-Translator: André Luís Lopes <andrelop@debian.org>
Language-Team: Debian-BR Project <debian-l10n-portuguese@lists.debian.org>
Language: pt_BR
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit
 
        --outdated		Une traduções desatualizadas.
	--drop-old-templates	Remove inteiramente traduções antigas. 
  -o   --owner=pacote		Define o pacote proprietário do comando.   -f   --frontend		Especifica o frontend a ser utilizado.
  -p   --priority		Especifica a prioridade mínima das questões                      a serem exibidas.
       --terse		Habilita modo resumido.
 %s falhou na preconfiguração com estado de saída %s %s está quebrado ou não completamente instalado %s está fuzzy no byte %s: %s %s está fuzzy no byte %s: %s; desistindo dela %s está faltando %s está faltando; desistindo de %s %s não está instalado %s está desatualizado %s está desatualizado; desistindo do template! %s deve ser rodado como root (Digite zero ou mais itens separados por uma vírgula seguida de um espaço (', ').) Anterior Escolhas Banco de dados de configuração não especificado no arquivo de configuração. Configurando %s Debconf Debconf em %s Debconf, rodando em %s O frontend Dialog é incompatível com buffers shell do emacs. Caso você seja iniciante no sistema Debian GNU/Linux escolhe 'crítica' agora e veja somente as questões mais importantes. O frontend Dialog não vai funcionar em um terminal burro, num buffer shell do emacs ou sem um terminal controlador. Digite os itens que quer selecionar, separados por espaços. Extraíndo templates de pacotes : %d%% Ajuda Ignorando prioridade "%s" inválida Valor de entrada, "%s" não encontrado nas escolhas C! Isso nunca deveria acontecer. Talvez os templates foram traduzidos incorretamente. Mais Próximo Nenhum programa estilo-dialog está instalado, então o frontend baseado em dialog não pode ser usado. Nota: O Debconf está rodando em modo web. Vá para http://localhost:%i/ Configuração de Pacotes Pré-configurando pacotes ...
 Problemas configurando o banco de dados definido pela stanza %s de %s. A variável TERM não está definida, então o frontend Dialog não é usável. Template #%s em %s não contém uma linha 'Template:'
 Template #%s em %s tem um campo duplicado "%s" com novo valor "%s". Provavelmente dois templates não estão separados apropriadamente por uma única linha.
 Banco de dados de templates não especificado no arquivo de configuração. Erro na análise do template perto de `%s', instãncie #%s de %s
 A Term::ReadLine::GNU é incompatível com buffers shell do Emacs. As opções Sigils e Smileys no arquivo de configuração não são mais usadas. Por favor, removas as mesmas. O frontend baseado em editor do debconf apresenta um ou mais arquivos para serem editas. Esse é um deles. Se você é familiar com os arquivos de configuração padrão do unix, esse arquivo será familiar para você -- ele contém comentários
entre itens de configuração. Edite o arquivo mudando os itens que forem necessessários e então salve-no e saia. Nesse ponto o debconf irá ler o arquivo
editado e usar os valores que você digitou para configurar o sistema.  Esse frontend requer um tty controlador. Impossível carregar Debconf::Element::%s. Falhou porque: %s Impossível iniciar um frontend: %s Campo de template desconhecido '%s', na stanza #%s de %s
 Uso: debconf [opções] comando [argumentos] Uso: debconf-communicate [opções] [pacote] Uso: debconf-mergetemplate [opções] [templates.ll ...] templates Prioridades válidas são : %s Você está usando o frontend baseado em editor do debconf para configurar seu sistema. Veja o fim desse documento para instruções detalhadas. Aj_uda apt-extracttemplates falhou : %s debconf-mergetemplate: Este utilitátio é obsoleto. Você deveria migrar para a utilização do program po2debconf do po-debconf. debconf: impossível fazer chmod: %s adiando configuração de pacotes, já que o apt-utils não está instalado tentando com frontend: %s é necessário especificar debs para preconfigurar não nenhuma das acima especifique um pacote para reconfigurar erro na análise de template: %s falha ao inicializar frontend: %s Impossível reabrir o stdin: %s aviso: possível corrupção da base de dados. Vou tentar consertar adicionando a questão %s que está faltando de volta. sim 