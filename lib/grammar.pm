use v5.024;
use strict;
use warnings;
use feature qw(signatures);no warnings qw(experimental::signatures);
use English;
package grammar;

sub gramar {
my  $exp =<<'SOURCE';

:start          ::= spec

spec            ::= <spec decl>+ action => do_list
<spec decl>     ::= <jobless decl>
<spec decl>     ::= <job decl> 
<spec decl>     ::= <fontpush>
<jobless decl>  ::= <command> 
<jobless decl>  ::= <data list>
<jobless seq>   ::= <jobless decl>+
<job decl>      ::= <Reset> 
<data list>     ::= <data> action => misdatos
# <data list>     ::= newLine action => misdatos
# <data list>     ::= formFeed action => misdatos
<Reset>         ::= <EndJob> 
<command>       ::= <fontpush> action=> ignore
<fontpush>      ::= <LoadFont> <font Data> <Reset> action => ignore
<font Data>     ::= <data list> <font Data2> action =>ignore
<font Data2>    ::= <font AddData>* action =>ignore
<font AddData>  ::= <AddFont> <data list> action => ignore
<command>       ::= <DelFont> action => ignore
<command>       ::= <PrintJob>
                #P Portait or Landscape
                #Q Portait and Landscape
                #[CE]\d{1..3} copies Collated 999 E(uncolated) max 99
                #
<command>       ::= <font> action => fontName
<command>       ::= <font use> action => font
                    |<efects> action => efect
                    |<offset> action => ignore
                    |<unit6> action => ignore
                    |<unit3> action => ignore
                    |<eraseTabs> action => ignore
                    |<eraseVtabs> action => ignore
                    |<start_justify> action => ignore
                    |<stop_justify> action => ignore
                    |<center> action => ignore
                    |<start_merge> action => ignore
                    |<stop_merge>  action => ignore
                    |<startsust>  action => ignore
                    |<line> action => draw
                    |<curposabs> action => move
                    |<curposrel> action => ignore
                    |<margins> action => ignore #margin
                    |<Intray> action => tray
                    |<bypass> action => ignore
                    |<2side> action => ignore
                    |<commentary> action => ignore
                    |<margin> action => ignore
                    |<tabs> action => ignore
                    |<spacing> action => ignore
                    |<Merge><jobless seq><formFeed> action => ignore
                    |<Merge><jobless seq><Reset> action => ignore
                    |<Merge><jobless seq><PrintJob> action => ignore
                    
<efects>        ::= <start_bold>|<stop_bold>|
                    <stop_over>|<start_over>|
                    <start_line>|<stop_line>|
                    <subindex>|<baseline>|<superindex>

<anyChar>       ~ [^\x{1b}]+
<data>          ~ <anyChar>
<EndJob>        ~ <escape>'+'[X]<comment><lineEnd>
<PrintJob>      ~ <escape>'+'[^\dXFABUM]<comment><lineEnd>
<LoadFont>      ~ <escape>'+'[F]<comment><lineEnd>
<AddFont>       ~ <escape>'+'[A]<comment><lineEnd>
<DelFont>       ~ <escape>'+'[B]<comment><lineEnd><notEOL><lineEnd>
<DelFont>       ~ <escape>'+'[U]<comment><lineEnd>#all loaded fonts
<Merge>         ~ <escape>'+'[M]<comment><lineEnd>#Merge page data
<font>          ~ <escape>'+'[\d]<value><lineEnd>
<font use>      ~ <escape>[\d]
<start_bold>    ~ <escape>'b'
<stop_bold>     ~ <escape>'p'
<stop_over>     ~ <escape>'zp'
<start_over>    ~ <escape>'zo'[\S]
<start_line>    ~ <escape>'u'
<stop_line>     ~ <escape>'w'
<subindex>      ~ <escape>'l'
<baseline>      ~ <escape>'s'
<superindex>    ~ <escape>'h'
<offset>        ~ <escape>'o'#offset
<unit6>         ~ <escape>'zg'
<unit3>         ~ <escape>'zf'
<eraseTabs>     ~ <escape>'d'
<eraseVtabs>    ~ <escape>'e'
<start_justify> ~ <escape>'j'
<stop_justify>  ~ <escape>'k'
<center>        ~ <escape>'q'
<start_merge>   ~ <escape>'ze'
<stop_merge>    ~ <escape>'zd'
<startsust>     ~ <escape>'zt'
<line>          ~ <escape>[xy] <X> <coma> <Y> <coma> <length> <coma> <thick> <value> <lineEnd>
<line>          ~ <escape>[xy]<coma> <X> <coma> <Y> <coma> <length> <coma> <thick> <value> <lineEnd>
<curposabs>     ~ <escape>'a'<X> <coma> <Y> <lineEnd>
<curposrel>     ~ <escape>'r'[udlr] <Y> [^\d] #Up Down Left Right 
<margins>       ~ <escape>'m'<digits><coma> <digits> <coma> <digits> <coma> <digits> <coma> <digits> <lineEnd>
<margin>        ~ <escape>'z'[nqkm]<digits><lineEnd>#set n top q botom k left  m right Margins.
<tabs>          ~ <escape>'t'<notEOL><lineEnd> #horitzontal tabs stops diguits(,digits)
<tabs>          ~ <escape>'v'<notEOL><lineEnd> #vertical tabs stops diguits(,digits)
<spacing>       ~ <escape>'i'<digit>#0 >single 1>3/2 2>2 3>3 4>1/2 
<spacing>       ~ <escape>'ip'<digits><lineEnd># spacing in 1/300 inch 
<notEOL>        ~ [^\n]*
<coma>          ~ ','
<value>         ~ <notEOL>
<comment>       ~ <notEOL>
<Intray>        ~ <escape>'c'<digit># used for paper source
<commentary>    ~ <escape>'zya'<comment><lineEnd># Commentary
<2side>         ~ <escape>'zyd'<X><lineEnd># 2 sided printing head to head
<2side>         ~ <escape>'zyf'<X><lineEnd># 2 sided printing head to toe
<2side>         ~ <escape>'zye'<lineEnd># 1 sided printing
<2side>         ~ <escape>'zyi'<digit># 2 sided formfeed
<bypass>        ~ <escape>'zyb'<hexdigit># use bypass paper size
                    #0  Letter (216 x 279 mm)
                    #1  Legal (216 x 279 mm)
                    #2  Ledger (279 x 432 mm)
                    #3  A3 (297 x 420 mm)
                    #4  A4 (210 x 297 mm)
                    #5  A5 (148 x 210 mm)
                    #6  A6 (105 x 148 mm)
                    #7  C5 envelope (162 x 229 mm)
                    #8  DL envelope (110 x 220 mm)
                    #9  ISO B5 (176 X 250 mm)
                    #A  Executive/Monarch (184 x 267 mm)
                    #B  Statement (140 x 216 mm)
                    #C  Postcard (88.9 x 142 mm)
                    #D  Eurolegal (8.5 x 13”)
                    #E  Monarch envelope (98 x 191 mm)
                    #F  #10 envelope (4.125 x 9.5”)
escape          ~ [\x{1b}]
digit           ~ [\d]
hexdigit        ~ [\dA-F]
digits          ~ [\d]+
X               ~ digits
Y               ~ digits
length          ~ digits
thick           ~ digits
#shade          ~ digits
lineEnd         ~ [\n]
formFeed        ~ [\f]
#newLine         ~ [\n]
SOURCE
return \$exp;
}

sub efect ($self,$text){
        local $_ = substr($text,1);
        return{bold=>1} if /^b/;
        return{bold=>0} if /^p/;
        return{underline=>1} if /^u/;
        return{underline=>0} if /^w/;
        return{baseline=>-1} if /^l/;
        return{baseline=>0} if /^s/;
        return{baseline=>1} if /^h/;
        return{overstrike=>''} if /^zp/;
        return{overstrike=>substr($_,2)} if /^zo/;
}

sub font ($self,$text){
    if (2 == length($text)){ # font use
       return {font => substr($text,1)};
    } else {
        die "error en font use"
    }
}

sub fontName($self,$text){
    if (4 > length($text)){ # mimun ^[+\dFontName\n 5 chars font use
       die "Empty font Name " ;
    } else { #font definition
#  spoiler:
#     useng a functio with side efect (state var)
#     that logs the name of fonts to help initialitzing the pdf;       
#       {
#           font => substr($text,2,1). #id
#           fontName=>substr($text,3,-1),#xerox name 
#       };
       xesfont(substr($text,3,-1));
       return {font=>substr($text,2,1),fontName=>substr($text,3,-1)}
    }
}

sub xesfont($name = undef){
    state $calback;
    $calback = $name if 'CODE' eq ref $name;
    $calback->($name) unless ref $name;
}

sub draw($self,$text) {
    my $draw = substr($text,1,-1);
    my $len  = substr($draw,0,1);
    my @numbers = split ",",substr($draw,1);
    shift @numbers if '' eq $numbers[0];
    my %result;
    $result{x} =$numbers[0];
    $result{y} =$numbers[1];
    $result{shade} = $numbers[4] if defined $numbers[4];
    if ('x' eq $len) {
        $result{dx} = $numbers[2];
        $result{dy} = $numbers[3];
    }elsif ('y' eq $len ){
        $result{dx} = $numbers[3];
        $result{dy} = $numbers[2];
    }else {return {draw => $draw}}
    return {draw =>\%result}
}  
sub move($self,$text){
    my $move =substr($text,1,-1);
    my @numbers = split ",",substr($move,1); 
    my %result = (x=>$numbers[0],y=>$numbers[1]);
    if ('a' eq substr($move,0,1) ){
        return {move =>\%result}
    }else {return {move => $move}}
}

sub margin($self,$text) {
#     Ingnored we dont need it to process our files
#     my $self = shift;
#     my $margin =substr(shift,1,-1);
#     my @numbers = split ",",substr($margin,1); 
#     my %result = (h=>$numbers[0],
#                   t=>$numbers[1],b=>$numbers[2],
#                   l=>$numbers[3],r=>$numbers[4]);
#     if ('m' eq substr($margin,0,1) ){
#         return {margin =>\%result}
#     }else {return {margin => "$margin"}}
    return; #ignore margins
}

sub tray($self,$text) {
    my $tray =substr($text,2);
    return {tray => $tray}
}

sub new($self) {
#    say "==new==>",Dumper \@_;
    return bless {}, $self
}

sub ignore($self,@rest) {
    return #do nothing;
}

sub do_first_arg($self,$text) {
    return  $text;
}

sub do_list($self,@rest) {
    return $rest[0] if 1 == scalar(@rest) ;
    return \@rest;
}

sub reset($self,$text) {
    {reset => 0}
}

sub toArray($do) {
    my @done ;
    while ($do =~ /[\n\f]/p) {
        push @done,${^PREMATCH} if ${^PREMATCH};
        push @done,${^MATCH};
        $do = ${^POSTMATCH};
    }
    push @done,$do if $do; 
    return \@done if @done;
    die;
} 

sub misdatos($self,$text) {
    my $list = toArray($text) if defined($text);
    return {datos=> $list} if ref $list;
    
}

1;
