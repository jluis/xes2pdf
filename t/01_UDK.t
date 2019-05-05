use strict;
use Test::More 0.98;
use xes2pdf;
is(xes2pdf::escape("1234","\x{1b}"),"1234");
is(xes2pdf::escape("1234","2"),"1\x{1b}34");
is(xes2pdf::limpia("=UDK=&&1\n"),"\x{1b}1\n");

done_testing;

