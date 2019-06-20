#!/usr/bin/env perl
#sello Retirado en documentos que sabemos que son notificacions
use 5.010;
use strict;
use warnings;
use DateTime;
use Data::Dumper;
use File::Copy qw(copy);
use Encode qw(decode encode);
#use Carp::Always;

#########################################################################################################
#  Export to a module 
{
#   $_[0] => Contenido del documento actual
#   $_[1] => identificador y tipo del documento
#   $_[2] => Identificacion del lote
#   $_[3] => Hash docuemtos
   sub addDoc {
       $_[1] .= "#" if defined $_[3]->{$_[1]};
       $_[3]->{$_[1]} =$_[0];
       $_[1];
   }
   sub carta_pago {
       return 0 unless $_[0]  =~ /&a160,3100[^&]*&5Carta de (?:pago|pagament)/; 
    
       if ( $_[0] =~ /&a510,3030[^&]*&8(MB|FB|RR|TR|08|17|25|43)-?(\d{5})-?(\d{2})\b/) {
           $_[1] = "$1-$2-$3_CP";
           if ($_[2]) {
               if ($_[2]  =~ /^Aco/) {
                 $_[1] .='AI';
               }
               elsif ($_[2]  =~ /^Res/){
                 $_[1] .='R';
               }
            }
       }
       else{
          die "No trobo el expedient d'aquesta carta de pagament $_[0]"
       }
       addDoc(@_);
   }

   sub carta_rara {
       return 0 unless $_[0] =~ /^&&\?{2}. ..\n1B'/; 
       #carta pago muy rara
       die "$_[0]\n!!!!\nAlert" unless $_[0] =~ /\n1B'8(MB|FB|RR|TR|08|17|25|43)(\d{5})(\d{2})'0D0A/;
       $_[1] = "$1-$2-$3_CP";
       #die "carta $_[1]";
       $_[0]  .= $_ while <>;
       warn "carta_rara";
       addDoc(@_);
   } 

   sub Acusaments {
       return 0 unless $_[0] =~ / {6}(Acord inici|Informes|Resoluci.)(?:\x0a){2}/;
       $_[1] = $1;
       #die "$_[0]\nAcusaments $1";
       $_[0] .= $_ while <>;
       warn "Acusaments";
       addDoc(@_);
   }

   sub Certificats {
       if ($_[0] =~ m|\( #left parentesis
                      (\d{2}([BGLT])\d{3})
                      \) #right parentesis 
                      \s+es\s+troben\s+pendents\s+de\s+pagament|x ){ 
           $_[1] = letra($2)."-$1";
           #die "Certificats $_[1]";
       }
       elsif ($_[0] =~ m|mero (GT\d{8}) de certificacions|) {
           $_[1] = "08-cert-$1";
       } 
       else {
           return 0;
       }
       $_[0] .= $_ while <>;
       warn "Certificats";
       addDoc(@_);
   }

   sub Caucionista {
       return 0 unless $_[0] =~ /&bAsunto:&p +Notificaci.n? +(resoluci.n?|a +empresa +caucionista) +[Ee]xpediente +n.mero: +((?:08|17|25|43)-\d{5}-\d{2})/; 
       $_[0] = "$1_NRC";
       addDoc(@_);
   }

   sub Transferencia {
       return 0 unless $_[0] =~ /#\$3\$b #escape es $ en estos documentos
                                 #So(?:l\.l|l)citud #Solicitud 
                                 #.+ # mucho texto
                                 \n\$7((?:08|17|25|43)-\d{5}-\d{2})\n # Expedient
                                /sx;# Solicitut transferencia Bancaria
       $_[1] = "$1_STB";
       addDoc(@_);
   }

   sub Carta {
       return 0 unless $_[0]  =~ /&3(?:[^&])+&x,\d+,\d+,\d+,\d+,1(?:(?:[^&])+&){10,12}(?:[^-])+-{41}&p/;
       # "Carta Registrada $name";
       $_[2] = "Cartes" unless $_[2];
       $_[1] = "$1_CARTA" if $_[0] =~/\b((?:08|17|25|43)-?\d{5}-?\d{2})\b/;
       addDoc(@_);
   }
   
   sub Recarrec {
       return 0  unless (defined($_[3]->{$_[1]}) and $_[1] =~ /_CP/ and $_[0] =~ /BOE 302, 18\/12\/2003/);
       # "Carta pagament amb recarec executiu";
       $_[3]->{$_[1]} .= $_[0];
       $_[3]->{$_[1]} =~ s/&c1\n&\+X\n\f  =UDK=& &\+X\n=UDK=&\n&c1/\f/ || die "reg";
       $_[3]->{$_[1]} =~ s/&\+P\n&c1\n&\+X\n\f/\f/s || die "|$_[3]->{$_[1]}|Mucho texto";
   }

   sub Devolucio {
       return 0 unless $_[0] =~ /assumpte.*:.*devoluci.*Exp.*((?:08|17|25|43)-\d{5}-\d{2})/is;
       $_[1] = "$1_DEVOLUCIO";
       addDoc(@_)
   }

   sub Referencia {
       return 0 unless $_[0] =~ /\n\s{20,}Ref\. (.*)/;
        $_[1] = $1;
        $_[1] = "$1_$_[1]" if $_[0] =~ /((?:MB|FB|RR|TR|08|17|25|43)-\d{5}-\d{2})/;
        addDoc(@_);
     }

   sub ingresos {
       return 0 unless $_[0] =~ /\n.\+1ESCUT-P\n/;
       if ($_[0] =~ /31 DGTM/) {
          $_[1] =  "08-oingres_".DateTime->now->ymd('');
       } 
       elsif ($_[0] =~ /sancionador/) {
           $_[1] = "08NoSe".DateTime->now->ymd('');
           $_[1] = "$1_$_[1]" if $_[0] =~ /((?:08|17|25|43)-\d{5}-\d{2})/;
       } 
       else {  
            $_[1] = '08-DESCONEGUT_'.DateTime->now->ymd('');
            $_[1] = "$1_$_[1]" if $_[0] =~ /((?:08|17|25|43)-\d{5}-\d{2})/;
       }
       #die "ingresos $_[1] ($_[0])";
       $_[0] .= $_ while <>;
       warn " ingresos";
       addDoc(@_);
   }
   
   sub llistat {
      return 0 unless $_[0] =~ /\n.+(\d)XCP12\.5iso-L\n/ or $_[0] !~ /=UDK=/;
      my $backup = $_[0];
      if ($_[2]) {
          warn  "Lot $_[2] last $_[1] Roto\n****\n$_[0]\n******";
      }
      $_[1] = "llistat";
      if ($_[0] =~ /======(TSAPRL14|TSAPRl07)/) {
          my ($id,$di)  =('','');
          if ($1 eq 'TSAPRL14') {
             warn "llistat ESTAT $_[0]"  unless $_[0] =~ /L'ESTAT: '(.{4})'.+S. TERRIT.:   (\w+)/s;
             ($id,$di) = ("estat_$1",$2);
          }
          else { #TSAPRl07
             warn  "llistat BAREM $_[0]"  unless $_[0] =~ /BAREM:\s+(\w+).+RIAL:\s+(\w+)/s;
             ($id,$di) = ("barem_$1",$2);
          }
               
          if ($di eq 'BARCELONA') {
              $_[1] ="08-$_[1]_$id";
          }
          elsif ($di eq 'GIRONA') {
              $_[1] ="17-$_[1]_$id";
          }
          elsif ($di eq 'LLEIDA') {
              $_[1] ="25-$_[1]_ESTAT_$id";
          }
	  elsif( $di eq 'TARRAGONA') {
    	      $_[1] ="43-$_[1]_ESTAT_$id";
          }
          else {
            warn "estat ${id}_$di"
          }
          #die "llistat $_[1]";
      } 
      elsif  ($_[0] =~ /======TSAPRL55/) {
          die "inerval"  unless $_[0] =~ /SELECCI. : (\w*).+LLISTAT: (\w+)/s;
          if ($2 eq 'BARCELONA') {
              $_[1] ="08$_[1]_interval_$1";
          }
          elsif ($2 eq 'GIRONA') {
              $_[1] ="17$_[1]_inteval_$1";
          }
          elsif ($2 eq 'LLEIDA') {
              $_[1] ="25$_[1]_interval_$1";
          }elsif( $2 eq 'TARRAGONA') {
              $_[1] ="43$_[1]_interval_$1";
          }else {
               $_[1] ="08Catalunya$_[1]_interval_$1";
          }
          #die "llistat interval  $_[1]";
      }
      elsif ($_[0] =~ /======TSAPRM36/) {
          warn "Iniciar descoverts ($_[0])" unless $_[0] =~ /SANCI. = (\w+(?: \w*)?)\n\n.*RIAL:  (\w+)/;
          if ($2 eq 'BARCELONA') {
              $_[1] ="08$_[1]_iniciar_$1";
          }
          elsif ($2 eq 'GIRONA') {
              $_[1] ="17$_[1]_iniciar_$1";
          }
          elsif ($2 eq 'LLEIDA') {
              $_[1] ="25$_[1]_iniciar_$1";
          }elsif( $2 eq 'TARRAGONA') {
              $_[1] ="43$_[1]_iniciar_$1";
          }else {
              #die "iniciar $1_$2"
          }
          $_[1] =~ s/ /_/g;
      }
      elsif ($_[0] =~ / ={4,6}(\w+)/) {
         $_[1] = "08$_[1]_no_se_$1"
      }
  
      $_[1] = letra($1)."-$_[1]-$1$2" if $_[0] =~ /\s+:\s+(\d{2}[BGLT]\d)\/(\d{2})\b/;
      $_[1] = "$1-Signar_R".DateTime->now->ymd("") if $_[0] =~ /======TSAPRL90.*(08|17|25|43)-\d{5}-\d{2}/s;
      $_[1] = "Signar_R" if $_[0] =~ /======TSAPRL90/ and $_[1] eq "llistat" ;
      $_[1] = "08-ingresos_".DateTime->now->ymd("") if $_[0] =~ /\f.+1\n/;
      #if ($_[1] eq "llistat") {
      #   $_[0] .= <> for (1..20);
      #   
      #}
      #die "****$_[0]****\nllistat($_[1])";
      $_[0] .= $_ while <>;
      if ($_[0] =~ /====(\w{9})/) {
         if ($1 eq "SHAPR347") {
            die "no trobo el certificat" unless $_[0] =~ /TRAMESA: (\w+)/;
         } 
         elsif ($1 eq "TSAPRAC3"){
            die "tipor raro " unless $_[0] =~ /CERTIFICATS (\w+)/
         }
	 elsif ($1 eq "TSAPRL16"){
            die "tipor raro " unless $_[0] =~ /RESOLTS (\w+)/
         }

         $_[1] .= $1;
         die "Falta demarcacio" unless $_[0] =~ /\n(\d{2})-\d{5}-\d{2}\s/;
         $_[1] = "$1-Sobresegudes".DateTime->now->ymd("");
         say "procesando $_[1]";
      }
      addDoc(@_);
   }

   sub llistatP {
      return 0 unless $_[0] =~ /\n.+1Titan12iso-P\n/ or $_[0] !~ /=UDK=/;
      if ($_[2]) {
          warn  "Lot $_[2] last $_[1] Roto\n***\n$_[0]\n***";
      }
      $_[1] = "llistatp";
      $_[1] = "08$_[1]TramesesST".DateTime->now->ymd("") if $_[0] =~ /======TSAPR022/;
      $_[1] = "08$_[1]RebutsST".DateTime->now->ymd("") if $_[0] =~ /======TSAPR020/;
      #die "llistaP $_[1]";
      $_[0] .= $_ while <>;
      addDoc(@_);
   }

   sub RevisioMG {
       return 0 unless $_[0] =~ /Vista\s+la\s+proposta\s+de\s+la\s+Direc.+HE\sRESOLT.+recurs\s+de\s+revisi/s;
       $_[1] .= '_RRRMG';
       $_[2] = 'RevisonsMG' unless defined $_[2];
       addDoc(@_);  
   }
   sub Acord {
       return 0 unless $_[0] =~ /Assumpte: *[Aa]cord d'iniciaci.|Asunto: *[Aa]cuerdo de inicio/ ; 
       $_[1] .=  "_AI";
       $_[2] = "Acords" unless $_[2];
       addDoc(@_);
   }

   sub NAcord {
      return 0 unless $_[0] =~ /Assumpte:\s*notificaci.\s+d'acord\s+d'iniciaci.|Asunto:\s?notificaci.n\s+(?:de\s+)?acuerdo\s+de\s+inicio/;
      $_[2] = "Acords" unless $_[2];
      $_[1] .= "_NAI";
      if ($_[0] =~ /85\s+de\s+la\s+(?:ley|llei)\s+39\/2015/i ) {
          $_[1] .= 'c' if $_[0] =~ s/&a1700,1872\n[ \d\.\-,EUROS]+\n//;
          #Treu l'import amb el 30% de descompte;
      }
      addDoc(@_);
   }

   sub NCaucio {
      return 0 unless $_[0] =~ #Notificacion cauciniste
          /&bAss?u(?:mpte|nto):&p +Notificaci.n? +(:?resoluci.n?|a +empresa +caucionista\.) +[Ee]xpediente? +n.m(?:ero|.): +$_[1]e/;
      $_[1] .= "_NRC";
      addDoc(@_);
   }

   sub Resolucio {
      return 0 unless $_[0] =~ /(?:&b)?Assumpte:(?:&p)? +Resoluci. +(?:sancionadora|de +sob|de +cad)|Ass?unto ?: ?Resoluci.n/;
      if ($_[0] =~ /$_[1]-00/){
          $_[1] .=  "_R";
          director(); #must be changed 
          $_[2] = "PropostesMG" unless $_[2];
      }
      else{
          if ($_[0] =~ /el\s+
                        [Dd]irector\s+
                        [Gg]eneral\s
                        de\s
                        Transporte?s\s+
                        .*
                        dicta(:?t|do)/sx) {
              $_[1] .= "_NRMG";
              $_[2]  = "ResolucionsMG" unless $_[2];
          }
          else {
              $_[1] .= "_R"; #Resolucio Cap del servei
              $_[2]  = "Resolucions" unless $_[2]
          }
      }
      addDoc(@_);
   }

   sub Alcades {
      return 0 unless $_[0] =~ /\bASS?U[MN]P?T[EO]:\s*&bRECURSO?\s+D.\s*AL.ADA&p/; # Alçades (Proposta / Notificacio/ Resolucio
      $_[2] = "Alcades" unless $_[2];
      if ($_[0] =~ /\s{10}Barcelona[^\n]*\n\s+Expedien/) {
         say "NRRA";
         $_[1] .= "_NRRA";
         die "NRRA" unless Segell($_[0]);
      }
      elsif (Segell($_[0])){
         say "NRRA";
         $_[1] .= "_NRRA";
      } else {
         say "PRRA";
         $_[1] .= "_PRRA"
      }
      addDoc(@_);
   }

   sub Revisio {
      return 0 unless $_[0] =~ /\bASS?U[MN]P?T[EO]:\s*&bRECURSO?\s+EXTRAORDINARIO?\s+DE\s+REVISI.N?\s*&p/; # Alçades (Proposta / Notificacio/ Resolucio
      say " $_[1]  Estraordinari de reviso( P R N)";
      $_[2] = "Revisio" unless $_[2];
      if ($_[0] =~ /\s{10}Barcelona[^\n]*\n\s+Expedien/) {
         say "NRRER";
         $_[1] .= "_NRRR";
         warn  "$_[1] Sense Segell Registre" unless Segell($_[0]);
      }
      else {
             say "PRRER";
             $_[1] .= "_PRRR"
      }
      addDoc(@_);
   }
   
   sub AlcadaMG {
      return 0 unless $_[0] =~ /\s&bHE RES(?:OLT|UELTO):&p/; # resolicion rara
      say "Adios";
      $_[1] .= "_RRAMG"; #molt greu
      $_[2] = "AlcadesMG" unless $_[2];
      addDoc @_
   }

   sub Informes {
      return 0 unless $_[0] =~ /(?i:assumpte|ass?unto) ?: ?(?i:sol|rem|requ|esm|corr|env|tra)/;
      $_[2] = "Informes" unless $_[2];
      $_[1] .= "_SI";
      addDoc @_;
   }

   sub InformeR {
      return 0 unless $_[0] =~ /(?i:assumpte|ass?unto) ?: ?(?i:informe recur)/;
      $_[2]  = "Informes_recurs" unless $_[2];
      $_[1] .= "_IRA";
      addDoc @_;
   }

   sub Proposta {
      return 0 unless $_[0] =~ /Assumpte:\s*[Pp]rop|Ass?unto:\s*[Pp]rop/; # proposta de resolució
      $_[1] .= "_PR";
      if (Segell($_[0])) {
          $_[1] .= "A";
          $_[2]  = "Audiencies" unless $_[2];
      }
      addDoc @_;
   }

   sub Arxiu {
      return 0 unless $_[0] =~ /DILIG.NCIA D'ARXIU/;
      $_[1] .= "_DA";
      if ($_[0] =~ /^08-/) {
	  my $head = 'El cap de Servei Territorial de Transports, e.f';
          $_[0] =~ s/L'INSTRUCTOR|El.La Cap de la Secci. d'Inspecci. i R.gim Sancionador/$head/s;
	  $_[0] =~ s/\n&\+X/&a1800,800\n&7Vist\n&\+X/s;
      }
      addDoc @_;
   }

   sub InformesP {
      return 0 unless $_[0] =~ /Assumpte: *[Ee]xpedient +[Ss]ancionador|Asunto: *[Ee]xpediente *[Ss]ancionador/;
      $_[2] = "InformesP" unless $_[2];
      $_[1] .= "_SP";
      addDoc @_;
   }

   sub revocacio {
      return 0 unless $_[0] =~ /\bASS?U[MN]P?T[EO]\s*:\s*&bREVOCACI.M?/; 
      $_[2] = "Revocacions" unless $_[2];
      $_[1] .=   Segell($_[0])? "_NRRV":"_PRRV";
      addDoc @_
   }

   sub caducitat {
      return 0 unless $_[0]  =~ /\bASS?U[MN]P?T[EO]\s*:\s*&bDECLARACI.N? +DE +CADUCIM?/;
      $_[2]  =  "Caducitat" unless $_[2];
      $_[1] .=  Segell($_[0])?"_NDC":"_DC";
      addDoc @_
   }

   sub AlcadesC {
      return 0 unless $_[0] =~ /&bASS?U[MN]P?T[EO]\s*:&p\s*Notificaci/i; # Alçades ( Notificacio/ Resolucio
      $_[2]  = "Alcades" unless $_[2];
      $_[1] .= "_NRRAC";
      addDoc @_
   }#    die "sin registro" unless Segell($current);

   sub ResolCad {
      return 0 unless $_[0] =~ /&bAss?u[mn]p?t[oe]:&p Resoluci.n? de caduc/i;
      $_[2]  = "Caducitat" unless $_[0];
      $_[1] .= "_R";
      addDoc @_;
   }

   
}
#########################################################################################################
sub Barcelona {
  return;
  warn "no he canviat capçalera [$_[0]]" unless $_[0] =~ s/( *)EL\s+CAP\s+DEL\s+SERVEI\s*\(\s*E\.\s*F.\s*\)(:?[\s]*\n){4,8}/$1El cap del Servei Territorial de Transports de Barcelona\n$1p.s. Resoluci\xf3 4 de maig de 2018 de la directora dels\n$1Serveis Territorials a Barcelona\n$1El cap de la Secci\xf3 d'Inspecci\xf3 i R\xe8gim Sancionador, e.f.\n/ or #fitxer grafic de la singatura a host;
  $_[0] =~ s/( *)EL\s+JEFE\s+DEL\s+SERVICIO\s*\(\s*E\.\s*F\.\s*\)(:?[\s]*\n){4,8}/$1El jefe del Servei Territorial de Transports de Barcelona\n$1p.s. Resoluci\xf3n del 4 de Mayo del 2018 de la directora de los\n$1Serveis Territorials a Barcelona\n$1El jefe de la Secci\xf3 d'Inspecci\xf3 i R\xe8gim Sancionador, e.f.\n/; #fitxer grafic de la singatura a host;
  warn "no he canviat signatura" unless $_[0] =~ s/0dgtsvba3/0xmas/g;
  $_[0] =~ s/(&3\n)\n*(\n\s+X)/$1$2/;
} 

sub Tarragona {
  return;
  warn "no he canviat capçalera [$_[0]]" unless $_[0] =~ s/( *)EL\s+CAP\s+DEL\s+SERVEI(:?[\s]*\n){3}/$1El cap del Servei Territorial de Transports, e.f.\n$1Jordi Follia i Alsina\n$1p.s. Resoluci\xf3 de la directora dels Serveis Territorials a Tarragon de 4.6.18\n$1El cap de la Secci\xf3 de Concessions i Autoritzacions\n/is or #fitxer grafic de la singatura a host;
  $_[0] =~ s/( *)EL\s+JEFE\s+DEL\s+SERVICIO(:?[\s]*\n){4,6}/$1El jefe del Servicio Territorial de Transportes, e.f.\n$1Jordi Follia i Alsina\n$1p.s. Resoluci\xf3n de la directora de los Servicios Territoriales\n$1en Tarragona del 4.6.18\n$1El jefe de la Secci\xf3n de Concesiones y Autorizaciones\n/s; #fitxer grafic de la singatura a host
  warn "no he canviat signatura" unless $_[0] =~ s/0dgtsvba3/0CarlesT/g;
#   $_[0] =~ s/&0ABC//
} 

sub delegacio {

#  return unless   #? es la paginia amb la signatura
#  $_[0] =~ /&0ABC/; #Signatura
                    #Si fem el grafic  hauriem de mirar si es paper
  Barcelona(@_) if $_[1] eq "08" and $_[0] =~ /0dgtsvba3/; #? firma follia
      
  
                                      # substituir al final 
# 20180629 Fin delegacio de signatura
#  Tarragona(@_) if $_[1] eq "43" and $_[0] =~ /0dgtsvba3/;
###########
}


my %documents = (
    SP    => 'Requeriments prèvies (per exemple, requeriment contracte arrendament...)',
    SPJ   => 'Justificant recepció requeriment prèvies',
    AI    => 'acord d’inici.',
    NAI   => 'notificació acord d’inici.',
    NAIJ  => 'justificant notificació acord d’inici.',
    SI    => 'requeriment informe.',
    STB   => 'Solicitut dades bancaries',
    SIJ   => 'evidència de la notificació del requeriment d’informe.',
    PR    => 'proposta de resolució (sense audiència).',
    PRA   => 'proposta de resolució i audiència.',
    PRAJ  => 'evidència de la notificació de la proposta de resolució i audiència.',
    R     => 'resolució.',
    NHR   => 'Resouci Notificacio amb Registrada TSA (Delegació)',
    RJ    => 'evidència de la notificació de la resolució',
    NRMG  => 'notificació resolució molt greus (és un document diferent a la pròpia resolució que signa el director dels Serveis Territorials).',
    NHRMG => 'Notificacío resolució registre Host (delegacio)',
    NRMGJ => 'evidència de la notificació de la resolució molt greus',
    IRA   => 'Informe Recurs',
    CPAI  => 'Carta de pagament amb reducció (AI)',
    CPR   => 'Carta de pagament pel total (amb resolució)',
    SIRA  => 'requeriment documentació recurs d’alçada (en algun cas en què es consideri necessari fer un requeriment previ a l’informe del recurs d’alçada).',
    SIRAJ => 'evidència de la notificació del requeriment recurs d’alçada',
    RRA   => 'resolució recurs d’alçada',
    NRRA  => 'notificacio resolució recurs d’alçada',
    NRRAC => 'Notificacio caucioniste Recurs d´alçada',
    RRAJ  => 'evidència de la notificació de la resolució recurs d’alçada',
    SIRR  => 'requeriment documentació recurs de revisió (en algun cas en què es consideri necessari fer un requeriment previ a l’informe del recurs de revisió).',
    SIRRJ => 'evidència de la notificació del requeriment recurs de revisió',
    PRRR  => 'Proposta recurs de revisió',
    RRR   => 'resolució RR',
    RRR   => 'Resolucio Recurs de Revisio Molt greu', 
    RRRJ  => 'evidència de la notificació del RR',
    );

my %signatura = (R=>3,AI=>3,NRC=>3,NAI=>1,NAIc=>1,SI=>1,SP=>1,PR=>1,PRA=>1,NRMG=>3,NRRA=>5,NRRAC=>5,NRRR=>5,NRRV=>5,RRR=>6);
my @signatura = ('','01_Instructor','02_Cap_Seccio','03_Cap_Servei','04_Director_General','05_Cap_Recursos','06_S_Infraestuctures');
sub director { $signatura{R} = 4;}

my $lot ='';
 
my $tempfname = shift @ARGV ;
$tempfname = '' unless defined $tempfname;
{
    my $HOME = "$ENV{HOME}/";	
    my $destino = $HOME.( $0 =~ /test/ ?'test/':'test/');
    #say $destino;
#   my $ghostpcl = $HOME =~ /jpddb/?'~/ghostpcl-9.07-linux-x86/pcl6-907-linux_x86 ':'gpcl6 ';
    #Must dismiss on  refactoring
    $ENV{REDMON_PRINTER} //= "IO246C";
    $ENV{REDMON_JOB} //= 1 + int rand 600;
    $ENV{XES2PCL_CONFIG} //="./xes.cfg";
    my  $PDF= './2pdf.pl ';
#   my  $PDF='~/xes2pcl/xes | '. 
    #RH         '~/ghostpcl-9.20-linux-x86_64/gpcl6-920-linux_x86_64 -sDEVICE=pdfwrite '. #rh
#        $ghostpcl.'-sDEVICE=pdfwrite '.#debian
#        '-dBATCH -dNOPAUSE -dSAFER -sPAPERSIZE=a4 '.
#        '-dProcessColorModel=/DeviceGray -sOutputFile="';

    sub genpdf {
        my ($filename,$doc) = @_;
#        die "($filename,$doc)";
        my $handle;
        my $alida = $PDF.$filename.'.pdf' ;
        print '.';say $alida;
        open $handle,"|-", $alida or die "no puedo con el pipe;";
        binmode $handle,"utf8";
        print $handle $doc;
        close($handle) or die "programa $0";
        $ENV{REDMON_JOB}++
    }

		  
    my %prefix = ('08'=>'Barcelona',
	          'RR'=>'Barcelona',
		  'FB'=>'Barcelona',
		  'TR'=>'Barcelona',
                  'MB'=>'Barcelona',
                  '17'=>'Girona',
                  '25'=>'Lleida',
                  '43'=>'Tarragona',
                 );

    if ($tempfname =~ /IO238W/) {
       $prefix{$_}= "Juridic" for keys(%prefix);
    }
    
    sub telefon {
        $HOME.($0 =~ /test/ ?'test/':'test/')."IO238W/$_[0]"
    }

    sub original{
        my $entrada =shift; 
        return 0 unless $entrada;
        my $newname =shift;
        say "original(1)=> $entrada, $newname" unless $0 =~ /Dil/;
        if (defined($newname)) {
           $newname = "$destino$prefix{$1}/$2_".DateTime->now->ymd("") if $newname =~ /^(\d{2})(\w*)$/;
           say "original(2)=> $entrada, $newname" unless $0 =~ /Dil/;
           mkdir $newname;
           $destino = $newname;
        } else {
           $newname = $entrada;
        }
 
	#my $command = "iconv -ct ISO-8859-15//TRANSLIT $entrada|".$PDF.$newname.'.pdf" -' ;
	#system("$command &");
	#$ENV{REDMON_JOB}++;
	#printlog("$newname.csv") unless $0 =~ /Dil/;
    } 


    sub prefix {
        my $key = shift;
        my $infix = '';
        if ('/' eq substr($destino,-1) and $key =~ /^(MB|FB|TR|RR|08|17|25|43)-/ )  { #single
             $infix = "$destino$prefix{$1}/";
	} else {        
             $infix = "$destino/";
        }
        if ( $key =~ /^((FB|TR|RR|08|17|25|43)-(\d{5})-(\d{2}))_(.*)$/) {
           if ('/' ne substr($destino,-1)) { #lote
              mkdir "$infix$1" unless -e "$infix$1";
              if ($signatura{$5}) {
                  $infix .= $signatura[$signatura{$5}];
                  mkdir $infix unless -e $infix;
                  $infix .= '/';
              }else{ 
               $infix .= "$1/";
              }
           } 
           "$infix$2$3$4_$5"

        } elsif ( $key =~ /^(08|17|25|43)-(\d{2}[BGLT]\d{3})(_.*)$/) {
             "$infix$2$3"
        } elsif ( $key =~ /^(?:MB|FB|TR|RR|08|17|25|43)-(.+)$/) {
             "$infix$1"
        } else {
             $key
        }
    }
}

sub letra{
   return '08' if $_[0] =~ /B/;
   return '17' if $_[0] =~ /G/;
   return '25' if $_[0] =~ /L/;
   return '43' if $_[0] =~ /T/;
     'Error'
}

binmode STDIN,":utf8";

{
#    my $carry = '';
    sub pagina {
        my $page = '';#$carry;
        while (<>) {
#          print;
#           if (s/(.*\x0C)(.*)/$1/s) {
#               $carry = $2;
#               $page .= $_;
#               last;
#           }
           $page .= $_;
           last if /\x0C/;         
        }
        $page
    }
}

sub seguent {
    local $_ = substr($_[0],-2);
    substr($_[0],-2) = ++$_ unless /00/;
    $_;
}

{
   my $registro;
 
 #open $loghandle,">", "$tempfname.csv" or die "Puedo registrar Documentos";
   my %logreg;
 
   sub getSegell {
      die "No tinc on cercar " unless @_;
      return 0 unless $_[0] =~ s/
                          &3 #tipo de letra del sello
                          ((?:[^&])+ #caracteres que no sean &
                          &x,\d+,\d+,\d+,\d+,1 # ubicacion del sello
                          (?:(?:[^&])+&){10,12} #numero de sequencia de escape que evitamos
                          (?:[^-])+)-{41}&p//xs; #ultima linea del sello
      my $tira = $1;
      if ($tira =~ /N.mero:([^\n]*)/) {
         $logreg{$1} = [@_[1..$#_]] unless defined  $logreg{$1} ;
      } else {    
         die " Registre sense número??? ";
      }
   }
   
   sub Segell {
       local $_ = shift;
       /&3 #tipo de letra del sello
        (?:[^&])+ #caracteres que no sean &
        &x,\d+,\d+,\d+,\d+,1 # ubicacion del sello
        (?:(?:[^&])+&){10,12} #numero de sequencia de escape que evitamos
        (?:[^-])+-{41}&p/xs
   }

   sub printlog {
      open my $handle,">", $_[0] or die "Puedo listar los Registros";
      say $handle join("\t",$_,@{$logreg{$_}}) for sort keys %logreg;
   }
}

my $current = '';

my %lot;
my ($name,$pagina) =('','');
my $pass = 0;

while (($current = pagina)) {
   last if carta_rara($current,$name,'',\%lot);

   #say $ARGV[0];
   say "($pagina)Pasada #",++$pass, "#($name,$lot)";

   if ($pagina) {
      if ($current =~ /$pagina/) {
         say "**$pagina**";
         #hay documentos multipagina no paginados contienen "00"
         #todas ellas como numero de pagina
         seguent($pagina);
         $lot{$name} .= $current;
         say ">>$pagina";
         next
      }   
      $name = $pagina = '';
   }

   my $back = $current; # canary
   
   if ($current =~ /((?:FB|RR|TR|08|17|25|43)-\d{5}-\d{2}-)(\d{2})/) { #multipage document 
       $pagina = $1.($2 eq "00"?$2:"02"); #hi-ha documents que totes les pagines son 00 i sabem que si no la seguent sera la 02
   }

   die "($back) ne ($current)" unless $current eq $back; #canary la pagina no ha canviat

   if ($pagina or $current =~ /expediente?:((?:FB|RR|TR|08|17|25|43)-\d{5}-\d{2})/i){ #document multipagina o que hem de idtentificar
      $name = $pagina?substr($pagina,0,11): $1;
      say "$name($pagina)"; #estem al expedient $name

       next if NAcord($current,$name,$lot,\%lot); say "NAI";
       next if NCaucio($current,$name,$lot,\%lot);say "caucio";

       next if Acord($current,$name,$lot,\%lot);say "AI";

       next if Resolucio($current,$name,$lot,\%lot);say "R";

       next if Alcades($current,$name,$lot,\%lot);say "RRA";
      
       next if Revisio($current,$name,$lot,\%lot);say "RRRV";
      
       next if AlcadaMG($current,$name,$lot,\%lot);say "RRAMG";
  
       next if Informes($current,$name,$lot,\%lot);say "SI";
   
       next if InformeR($current,$name,$lot,\%lot);say "IR";

       next if Proposta ($current,$name,$lot,\%lot);say "PR";
 
       next if Arxiu ($current,$name,$lot,\%lot);say "DA";

       next if InformesP ($current,$name,$lot,\%lot);say "SP";
   
       next if revocacio($current,$name,$lot,\%lot);say "Revocas";

       next if caducitat($current,$name,$lot,\%lot);say "caducitat";
  
       next if AlcadesC ($current,$name,$lot,\%lot);say "AlcadesCau";

       next if ResolCad ($current,$name,$lot,\%lot);say "ResolCad";    

       next if RevisioMG($current,$name,$lot,\%lot);say "RevisioMG";
       $name .="_ERR$pass";
       warn "$current>>>>>>>>>$tempfname $name";
       addDoc($current,$name,$lot,\%lot);
       next
   } 
   die "($back) ne ($current)" unless $current eq $back;

   next if carta_pago($current,$name,$lot,\%lot);
   die "($back) ne ($current)" unless $current eq $back;

   say "$tempfname acussaments $name" and last if Acusaments($current,$name,'',\%lot);
   die "($back) ne ($current)" unless $current eq $back;

   last if Certificats($current,$name,$lot,\%lot);
   die "($back) ne ($current)" unless $current eq $back;

   next if Caucionista($current,$name,$lot,\%lot);
   die "($back) ne ($current)" unless $current eq $back;

   next if Transferencia($current,$name,$lot,\%lot);
   die "($back) ne ($current)" unless $current eq $back;

   next if Carta($current,$name,$lot,\%lot);
   die "($back) ne ($current)" unless $current eq $back;

   next if Recarrec($current,$name,$lot,\%lot);
   die "($back) ne ($current)" unless $current eq $back;

   next if Devolucio($current,$name,$lot,\%lot);
   say "hola"; 
   if ($name =~ /_SI|_NAI/ ) {
          # Document partit
          $lot{$name} .= $current;
          next
   }
   
   next if Referencia($current,$name,$lot,\%lot);
   die "($back) ne ($current)" unless $current eq $back;

   next if ingresos ($current,$name,$lot,\%lot);
   die "($back) ne ($current)" unless $current eq $back;
   last if llistat ($current,$name,$lot,\%lot);
   die "($back) ne ($current)***********" unless $current eq $back;
   warn "llistatP ($name,$lot)" and next if  llistatP ($current,$name,$lot,\%lot);
   die "($back) ne ($current)" unless $current eq $back;
   next if $current =~ /^\s*=UDK=&\s*\&+X\s*/s;
   next if $current =~ /^\x00$/;
   $name = $pagina?"$pagina($pass)":"ERROR($pass)";
   $lot{$name} = $current unless defined $lot{$name};
   say "($tempfname) AQUI PASA ALGOO RARO RARO";
   die "Aqui($current)";
}

#exit (`./acuses.sh $tempfname` || 0) if $name =~ /acusaments/;
#rename($tempfname,$name.'_'.$tempfname) and original($name.'_'.$tempfname) if $name =~ /listat/;


say "$lot";
#die "$name es un lote de $lot" if $lot; 

if (3 < keys(%lot) or $lot eq "Caducitat") {
   ($name) = keys %lot unless $name;# =~ /^(FB|MB|TR|RR|\d{2})-\d{5}-\d{2}/;
   $lot = 'Altres' unless $lot;
   my $newname = $lot;
   substr($newname,0,0) = $1 if $name  =~ /^(FB|MB|TR|RR|\d{2})-\d{5}-\d{2}/;
#   rename($tempfname,"lot_$tempfname") or warn "($name) renaming $tempfname to $newname";
   original("lot_$tempfname",$newname);
   say "AQUI ESTOY***********************";
}
elsif (0 == keys(%lot)) {
   say "warn $tempfname Buida trobo document ?????";
   original($tempfname)
}
elsif (1 == keys(%lot)) {
   my $tipo = join('',keys(%lot));
   say "lote de uno ($tipo)";
   if ($tipo =~ /_[CNDSRP]|\d{2}[BGLT]\d{3}/) {
      say "$tipo --> $tempfname";
      if ($tipo =~ /listat/){
          say "tipo llistat";
          #rename($tempfname,$tipo.'_'.$tempfname) and original($tipo.'_'.$tempfname);
          exit;
      }
      elsif ($tipo =~ /_CP$/ and $tempfname =~ /IO238W/) {
          if ($lot{$tipo} =~ /&8&b([^,]*),? ?(.*)&p/) {
              my $apellidos = $1;
              if ($2) { 
                 $name = $2 =~ s/ *$//r ;
                 $name = "${name}_$apellidos" =~ s/ /_/gr;
              }
              else{
                 $name = ($apellidos =~ s/ *$//r) =~ s/ /_/gr;
              }
              $name = decode("iso-8859-15",$name);
              $name =~ s/[\/\\<>:"\.\|\?\*]/#/g;
          }
          if ( $lot{$tipo} =~ /&a510,3030[^&]*&8(FB|RR|TR|08|17|25|43)(\d{5})(\d{2})\b/) {
              $name = "$1-$2-$3_CP_$name"
          }
          elsif ( $lot{$tipo} =~ /&a510,3030[^&]*&8(\d{11})\b/){
              $name = "$1_CP_$name"
          }
          else {
              warn " expedient d'aquesta carta de pagament?????"
          }
          genpdf(telefon($name),$lot{$tipo});
          say "Carta pago atencio telefonica";
	  exit;
      }
      say "Saliendo lote de uno";
   }
}

for (sort(grep(!/COPIAS$/,keys(%lot)))) {
#   next if /COPIA$/;
#   next unless /No/;
#   next if /_CP/ and $lot{$_} =~ /\n&83[1234]12\d{7}\n/;
#   $lot{$_} =~ s/Josep Andreu Clariana i Selva// if /^08-\d{2}B\d{3}/;
#   if (/^(08)-/) {# Sols Barcelona 29-06-18 (/^(08|43)-/) {
#      delegacio $lot{$_},$1 unless /H/ ;
#   }
   genpdf(prefix($_),$lot{$_});
#  say "($lot{$_})";
}
say "($0)";

__END__

=head1 Classificador de documents en fitxers de CMSPOOL

=head2 Codis de documents Generats o derivats del host

=over 6

=item SP

Requeriments prèvies (per exemple, requeriment contracte arrendament...) 

=item SPJ

Justificant recepció requeriment prèvies

=item AI

acord d’inici.  

=item NAI

notificació acord d’inici.

=item NAIJ

justificant notificació acord d’inici.

=item SI

requeriment informe.

=item SIJ

evidència de la notificació del requeriment d’informe.

=item PR

proposta de resolució (sense audiència).

=item PRA

proposta de resolució i audiència.

=item PRAJ

evidència de la notificació de la proposta de resolució i audiència.

=item R

resolució.

=item RJ

O238W_evidència de la notificació de la resolució

=item NRMG

notificació resolució molt greus (és un document diferent a la pròpia resolució que signa el director dels Serveis Territorials).

=item NRMGJ

evidència de la notificació de la resolució molt greus

=item CPAI

Carta de pagament amb reducció (AI)

=item CPR

Carta de pagament pel total (amb resolució)
 
=item SIRA

requeriment documentació recurs d’alçada (en algun cas en què es consideri necessari fer un requeriment previ a l’informe del recurs d’alçada).

=item SIRAJ

evidència de la notificació del requeriment recurs d’alçada

=item RRA

resolució recurs d’alçada

=item RRAJ

evidència de la notificació de la resolució recurs d’alçada

=item SIRR

requeriment documentació recurs de revisió (en algun cas en què es consideri necessari fer un requeriment previ a l’informe del recurs de revisió).

=item SIRRJ

evidència de la notificació del requeriment recurs de revisió

=item RRR

resolució RR

=item RRRJ

evidència de la notificació del  RR

=back

=head2 Altres documents

=over 

=item DEN: 	denúncia

=item AC:	Acta d’inspecció

=over 

=item DENTB: 	justificant bàscula (tiquet bàscula tipus super) 

=item DENCV: 	Certificat verificació bàscula

=item DENDOCON: document de control (document annex a denúncia)

=item DENDISC: discos de tacògraf analògic que es retiren en carretera i s’adjunten a la denúncia.

=item DENALT: Altra documentació adjunta a la denúncia

=item DENTI: tiquets impresos de tacògraf digital (document annex a denúncia)

=item DENCA: certificat d'activitats adjunt a la denúncia

=item DENDIL: diligències agents denunciants (quan les denúncies van acompanyades de diligències, declaracions etc.)

=back

=item CONSSIT:	Consulta SITRAN (en el cas que es consideri que s’ha d’incorporar a l’exp.). 

=item CONSDGT:	Consulta DGT	

=item PD: 	plec de descàrrecs (al·legacions acord d’inici i plec de càrrecs).

=item JPD: Justificant de tramesa d’entrada del plec de descàrrecs ?

=item RSI: Resposta sol.licitud informe

=item RSIJ: Justificant entrega resposta sol.licitud informe

=item ALPRA: al·legacions a la proposta de resolució i audiència.

=item JALPRA: Justificant al·legacions a la proposta de resolució i audiència.

=item RCA: resolució (còpia autèntica).

=item JP: justificant del pagament (en aquells casos que es presenta un justificant de l’ingrés de la sanció)

=item RA: recurs d’alçada.

=item RAJ: justificant recurs d’alçada

=item IRA: informe recurs d’alçada.

=item RR: recurs de revisió.

=item RRJ: justificant recurs de revisió

=item IRR: informe recurs de revisió.

=item SF: sol·licitud fraccionament.

=item SFJ: justificant sol·licitud fraccionament

=item OFIF: ofici resposta sol.licitud fraccionament.

=item OFIFJ: evidència de la notificació del requeriment fraccionament.

=item ROFIF: resposta requeriment fraccionament.

=item ROFIFJ: justificant entrada requeriment fraccionament

=item OTF: ofici de tramesa fraccionament a GE

=item SIATC: Sol·licitud informe ATC

=item RRC Recurs reposició constrenyiment

=item IATC Informe ATC

=item CRCA Comunicació de recurs contenciós-administratiu

=item SRCA Sentència de recurs contenciós-administratiu

=back

=cut
