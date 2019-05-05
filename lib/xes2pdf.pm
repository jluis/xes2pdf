package xes2pdf;
use 5.020;
use strict;
use warnings;
use English;
use feature qw(signatures);
no warnings qw(experimental::signatures);
use Marpa::R2;


our $VERSION = "0.01";

my $gramar = <<'SOURCE';

:start          ::= spec

spec            ::= <spec decl>+ action => do_list
<spec decl>     ::= <jobless decl> | <job decl>
<jobless decl>  ::= <command> #action => fixed_Command
<jobless decl>  ::= <data list> action => do_list
<jobless seq>   ::= <jobless decl>* action => do_list
<job decl>      ::= <job command> <jobless seq> action => do_job

<anyChar>       ~ [\x{0}-\x{ffff}]

<data>          ~ <anyChar>

<data list>     ::= <data>+ action => misdatos
                    
                    

<job command>   ::= <reset> action=>do_job
<job command>   ::= <PrintJob> action=>do_job
<job command>   ::= <font> action => font
<command>       ::= <font use> action => font
                    |<efects> action => efect
                    |<offset>|<unit6>|<unit3>|<eraseTabs>
                    |<eraseVtabs>|<start_justify>
                    |<stop_justify>|<center>|<start_merge>
                    |<stop_merge>|<startsust>
                    |<line> action => draw
                    |<curposabs> action => move
                    |<margins> action => margin
                    |<Intray> action => tray

<efects>        ::= <start_bold>|<stop_bold>|
                    <stop_over>|<start_over>|
                    <start_line>|<stop_line>|
                    <subindex>|<baseline>|<superindex>
                    

#:lexeme        ~ <UDK>   pause => before priority=>20
#:lexeme        ~ <reset> priority=>10 pause => after
#:lexeme        ~ <data> pause => before priority=>-1

<reset>         ~ <escape>'+X'<lineEnd>
<reset>         ~ <escape>'+X'<comment><lineEnd>
<PrintJob>	    ~ <escape>'+P'<lineEnd>
<PrintJob>      ~ <escape>'+P'<comment><lineEnd>
<font>          ~ <escape>'+'[\d] <value><lineEnd>
<font use>      ~ <escape>[\d]
<start_bold>    ~ <escape>'b'
<stop_bold>     ~ <escape>'p'
<stop_over>     ~ <escape>'zp'
<start_over>    ~ <escape>'zo'<anyChar>
<start_line>    ~ <escape>'u'
<stop_line>     ~ <escape>'w'
<subindex>      ~ <escape>'l'
<baseline>      ~ <escape>'s'
<superindex>    ~ <escape>'h'
<offset>        ~ <escape>'o'
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
<margins>       ~ <escape>'m'<digits><coma> <digits> <coma> <digits> <coma> <digits> <coma> <digits> <lineEnd>
<notEOL>        ~ [^\n]*
<coma>          ~ ','
<value>         ~ <notEOL>
<comment>       ~ <coma> <notEOL>
<Intray>        ~ <escape>'c'[\d]

escape          ~ [\x{1b}]
digits          ~ [\d]+
X               ~ digits
Y               ~ digits
length          ~ digits
thick           ~ digits
#shade          ~ digits
lineEnd         ~ [\n]
SOURCE

sub escapetext {
    my $text = shift;
    $text =~ s/([\x{0}-\x{1F}])/sprintf('x{%02x}',ord($1))/ge;
    return $text;
}

sub escape($block,$escape){
    return $block if $escape eq "\x{1b}";
    return $block =~ s/$escape(?=[\d\+a-z])/\x{1b}/gr;
}

sub limpia($tira,$escape = "\x{1b}",$done = '') {
 return $done.escape($tira,$escape) unless $tira =~ /(:?$escape\+X[^\n]*\n)|(:?=UDK=(?!=|U|D|K|,|¨U|Ü|¨D|¨K).)/;
 my $do = $PREMATCH;
 $tira  = $POSTMATCH;
 if ('=' eq substr($MATCH,0,1)) {
     my $esc = substr($MATCH,-1);
     $done .= escape($do,$escape);
     $escape = $esc;
  } else {
     my $ending = "\x{1b}".substr($MATCH,1);
     $done .= escape($do,$escape).$ending;
     $escape = "\x{1b}"
  }  
  return limpia($tira,$escape,$done);
}

my $g = Marpa::R2::Scanless::G->new({
    action_object => 'main',
    default_action => 'do_first_arg',
    source         => \$gramar});

1;
__END__

=encoding utf-8

=head1 NAME

xes2pdf - It's new $module

=head1 SYNOPSIS

    use xes2pdf;

=head1 DESCRIPTION

xes2pdf is ...

=head1 LICENSE

Copyright (C) Jose Luis Perez Diez.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Jose Luis Perez Diez E<lt>jluis@escomposlinux.orgE<gt>

=cut

