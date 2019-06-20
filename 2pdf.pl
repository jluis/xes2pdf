#!/usr/bin/env perl
use v5.024;
use strict;
use warnings;
use Marpa::R2;
use PDF::API2::Simple;
use Image::Size;
use feature qw(signatures);
no warnings qw(experimental::signatures);
use Marpa::R2;
use Encode;

BEGIN{ push @INC ,'./lib'}

use grammar;
my $name = $ARGV[0];

sub escapetext {
    my $text = shift;
    return $text =~ s/([\x{0}-\x{1f}])/sprintf('\x{%02x}',ord($1))/ger;
}

sub escape($block,$escape){
    return $block if $escape eq "\x{1b}";
    return $block =~ s/$escape(?=[\d\+a-z])/\x{1b}/gr;
}

sub limpia($tira) {
   my ($done,$escape,$loop) = ('',"\x{1b}",0) ;
   while ($tira) {
      if ($tira =~ /(:?$escape\+X[^\n]*\n)|(:?=UDK=(?!=|U|D|K|,|¨U|Ü|¨D|¨K).)/) {
         my $do    = $PREMATCH;
         $tira  = $POSTMATCH;
         my $found = $MATCH;
         $done .= escape($do,$escape);
         if ('=' eq substr($found,0,1)) {
            $escape = substr( $found,-1);
         } else {
            $done .= "\x{1b}".substr($found,1);
            $escape = "\x{1b}";
         }  
      }else{
          $done .= escape($tira,$escape);
          last
      }
   }
   return $done;
}

grammar::xesfont(\&xesfont);

binmode STDOUT, ':encoding(UTF-8)';
binmode STDIN,':encoding(UTF-8)';

my $g = Marpa::R2::Scanless::G->new({
    action_object => 'grammar',
    default_action => 'do_first_arg',
    source         => grammar::gramar()});

my $string = limpia do{local $/;<STDIN>};

# my $r  = Marpa::R2::Scanless::R->new({ grammar => $g });
# my @doc;
# $r->read(\$string);
my $tree = $g->parse(\$string);
my @doc = (${$tree});
my $pdf =PDF::API2::Simple->new(
                file=>$name,
                line_height => 12,
                height => 842,
                width => 595,
                margin_top => 0
);

sub camina {
        my $docs = shift;
        my $callback = shift;
        my $flag;
        my @init = qw(bold dirty underline overstrike baseline);
        state $efect = {bold=>0,dirty=>0,underline=>0,overstrike=>0,baseline=> 0,landscape=>0};
        my ($x,$y);
        my @sufix=('','-Bold');
        for my $tree (@{$docs}) { 
            if (ref($tree) eq 'HASH'){
                if(defined($tree->{job})){
                    say Dumper $tree->{job};
                    $pdf->add_page() if $efect->{dirty};
                    $efect->{dirty}  = 0;
                    camina([$tree->{job}],$callback);
                    next
                } 
                elsif (defined($tree->{draw})) {
                    $x= $pdf->x();
                    $y= $pdf->y();
                    $callback->( $tree->{draw} );
                    $pdf->x($x);$pdf->y($y);
                    next
                }
                elsif (defined($tree->{move})) {
                    $pdf->x(XesU($tree->{move}->{x}));
                    $pdf->y(XesU($tree->{move}->{y}));
                    #$flag = 1;
                    next
                }
                elsif (defined($tree->{fontName})) { 
                    fontload($tree->{font},
                    $tree->{fontName});
                    next
                }
                elsif (defined($tree->{font})) {
                     $efect->{$_} = 0 for @init;
                     my $font = fontload($tree->{font});
                     next if $font->{image};
                     $pdf->set_font($font->{name},$font->{size});
                     if (not $font->{origen} and not $efect->{landscape}) {
                        $efect->{landscape} = 1;
                        $pdf -> height(595);
                        $pdf -> width(842);
                        $pdf -> margin_top(0);
                        $pdf -> margin_right(0);
                    }elsif ($font->{origen} and $efect->{landscape}){
                        $efect->{landscape} = 0;
                        $pdf -> height(842);
                        $pdf -> width(595);
                        $pdf -> margin_top(0);
                        $pdf -> margin_right(0);
                    }
                    next
                }
                elsif (defined($tree->{bold})) {
#                   estat
                    $efect->{bold} = $tree->{bold};
                    next
                }
                elsif (defined($tree->{NuevaLinea})) {
                    die"NuevaLinea";
                    $pdf->next_line();
                    $pdf->x(0);
                    next
                }
                elsif (defined $tree->{datos} ) {
                    for ( @{$tree->{datos}} ) {
                        $efect->{dirty} = 1 if /\s/;
                        text($pdf,$_,$efect);
                    }
                    next
                }
                elsif (defined $tree->{margin}){
                    next #ignore it
                }
                elsif (defined $tree->{underline}){
                    my $font = xesfont(fontload());
                    $efect->{underline} = $tree->{underline}*($efect->{baseline}-$font->{size}*.2);
                    next
                }
                elsif (defined $tree->{tray}){
                    next #ignore it
                }
                elsif (defined $tree->{overstrike}){
                    $efect->{overstrike}=$tree->{overstrike};
                    next
                }
                elsif (defined $tree->{reset}){
                   $pdf->add_page() if $efect->{dirty};
                   $efect = {bold=>0,dirty=>0,underline=>0,overstrike=>0,baseline=> 0,landscape=>0};
                   next;
                }
                elsif (defined $tree->{"sub"}){
                   say Dumper $tree;
                   NonBase($pdf,-1/6,$tree->{"sub"},$efect);
		   next;
                }
                elsif (defined $tree->{sup}){
                   say Dumper $tree;
                   NonBase($pdf,1/3,$tree->{sup},$efect);
                   next;
                }
                elsif (defined $tree->{baseline}){
                   my @baseline = (-1/3,0,1/3);
                   my $font = xesfont(fontload());
                   $efect->{baseline} = $baseline[1+$tree->{baseline}]*$font->{size};
                   next;
                }
                else {
                    say join('|',keys(%{$tree}));
                    die Dumper $tree;
                    next
                }
            }
            elsif (ref($tree) eq 'ARRAY') {
                camina($tree,$callback);
                next;
            } 
            else { 
                next; #ignore
            }
            die "Que Mierda es esta"
        }
        
}

sub xesfont($name = undef) {
    state %fonts;
    if (not defined  $name) { #return the PDF fonts used for loged xes fonts names
        return ("Courier") unless %fonts;
        my %list;
        for my $key (keys(%fonts)){
            unless (ref $fonts{$key} ) {
                $fonts{$key} = {};
                if ($key =~ /^([A-Za-z]+)(\d+\.?\d*)(.*)-([PL])$/) {
                    $fonts{$key}->{name} = 'Courier' if $1 eq 'Titan' or $1 eq 'XCP';
                    $fonts{$key}->{origen} = $4 eq 'P';
                    if (defined $fonts{$key}->{name}) { #Titan or XCPC fixed pitch font
            # $2 chars/inch 120 inch*size/chars (scale factor for courier)
                        $fonts{$key}->{size} = (120/$2);
                    } else {
            #Proporcionales Helvetia or Univers  
                        $fonts{$key}->{name} = 'Helvetica';
                        $fonts{$key}->{size} = $2 * .95;
                        local $_ = $3;
                        $fonts{$key}->{name} .= '-' if /n|i/i;
                        $fonts{$key}->{name} .= 'Bold' if /b/i;
                        $fonts{$key}->{name} .= 'Oblique' if /i/i;
                    }
                    $fonts{$key}->{image} = 0;
                } elsif (-e "resources/$key.jpg")  {
                    my ($delta_x,$delta_y) = imgsize("resources/$key.jpg");
                    say "[*$key*]"unless $delta_x and $delta_y;
                    $fonts{$key} = {image=>1,name=>"resources/$key.jpg",delta_y=>($delta_y*6)/25, delta_x=>($delta_x*6)/25};
                }else{
                    say "[$key]";
                    my ($delta_x,$delta_y) = imgsize('camelia.png');
                    $fonts{$key} = {image=>1,name=>'camelia.png',delta_y=>($delta_y*6)/25,delta_x=>($delta_x*6)/25};
                }
            }
            $list{$fonts{$key}->{name}}++ unless $fonts{$key}->{image}
        }
        return (keys %list);
    }
    return $fonts{$name} if defined $fonts{$name};
    return $fonts{$name} = 0;
}


sub fontload {
    state (%font,$last);
    $last //= 'Titan12iso-P';
    return $last unless @_; 
    my ($id,$name) = @_;# say Dumper(\@_,\%font);
    if (1 == @_) {
        my $hash = xesfont($last=$font{$id});
        return $hash;
    }
    $font{$id}=$name;
}

sub text($pdf,$text,$efect) {
    my $font = xesfont(fontload());
    my ($x,$y) = ($pdf->x,$pdf->y);
    if ($font->{image}) {
        $pdf->image($font->{name} , y=>$y - $font->{delta_y},width=>$font->{delta_x},height=>$font->{delta_y}) if $text =~ /A/;
        $pdf->x($x);$pdf->y($y);
    } elsif ($text =~ /\n/) {
        $pdf->y($pdf->y - $font->{size}*1.1);
        $pdf->x(0);
    }elsif ($text =~ /\f/) {
#         say "<",escapetext( $text),">(",$efect->{dirty},")";
        return unless $efect->{dirty};
        $pdf->add_page();
        $efect->{dirty}  = 0;
    }else {
        my $baseline = $y + $efect->{baseline};
        my $width = $pdf->text($text,y=>$baseline);
        if ($efect->{bold}) {
            my $offset = $font->{size}*.015;
            $pdf->text($text,y=>$baseline-$offset);
            $pdf->text($text,y=>$baseline+$offset);
            $pdf->text($text,y=>$baseline,x=>$x+$offset);
            $pdf->text($text,y=>$baseline,x=>$x-$offset);
        }
        if ($efect->{underline}) {
            my ($offset,$thikness) = ($efect->{underline},$font->{size}*.05);
            $pdf->rect( x=>$x,y=>$y+$offset,to_x=>$x+$width,to_y=>$y+$offset-$thikness);
        }
        if ($efect->{overstrike}) {
            $pdf->text($text =~ s|\S|$efect->{overstrike}|gr);
        }
        $pdf->x($x+$width);
        $pdf->y($y);
    }
}
         		  	


sub XesU($units){
    return $units * 6 / 25 # 1/300 to points
} 

for my $font (xesfont()){
    $pdf->add_font($font);#,-encode=>'utf8');
}

$pdf->add_page();
 
$pdf->set_font('Courier',10);

my $rutina = sub {
    my $box= shift;
    my $shade = (defined $box->{shade})? '#'.sprintf('%X',15-$box->{shade})x3 :'#000';
    $pdf->rect( x=>XesU($box->{x}),y=>XesU($box->{y}),
                to_x=>XesU($box->{x}+$box->{dx}),to_y=>XesU($box->{y}+$box->{dy}),
                fill_color => $shade ,
              );
};

camina(\@doc,$rutina);
					
$pdf->save();
#say Dumper(@doc);
################################################################# Grammar callbacks #############################


# 
