package xes2pdf;
use 5.020;
use strict;
use warnings;
use English;
use feature qw(signatures);
no warnings qw(experimental::signatures);


our $VERSION = "0.01";

sub escapetext {
    my $text = shift;
    $text =~ s/([\x{0}-\x{1F}])/sprintf('x{%02x}',ord($1))/ge;
    return $text;
}

sub escape($block,$escape){
    return $block if $escape eq "\x{1b}";
    return $block =~ s/$escape/\x{1b}/gr;
}

sub limpia($tira,$escape = "\x{1b}",$done = '') {
 return $done.escape($tira,$escape) unless $tira =~ /(:?$escape\+X[^\n]*\n)|(:?=UDK=(?!=|U|D|K|,|¨U|¨D|¨K]).)/;
 my $do = $PREMATCH;
 $tira  = $POSTMATCH;
 if ('=' eq substr($MATCH,0,1)) {
     my $esc = substr($MATCH,-1);
     $done .= escape($do,$escape);
     $escape = $esc;
  } else {
     my $ending = "\x{1b}".substr($MATCH,1);; 
     $done .= escape($do,$escape).$ending;
     $escape = "\x{1b}"
  }  
  return limpia($tira,$escape,$done);
}

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

