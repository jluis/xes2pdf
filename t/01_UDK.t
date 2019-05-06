use strict;
use Test::More 0.98;
use xes2pdf;
is(xes2pdf::escape("1234","\x{1b}"),"1234","unchanged if \$escape=\\x{1b}" );
is(xes2pdf::escape("1234","2"),"1\x{1b}34","changed all \$escape for \\x{1b}");
is(xes2pdf::limpia("=UDK=&&1\n"),"\x{1b}1\n","=UDK= defines \$escape char");
is(xes2pdf::limpia("=UDK=&&+Xoo=UDK=l&&&1\n&&&"),"\x{1b}+Xoo=UDK=l&&&1\n&&&","\$escape+X undefines  \$escape char");
is(xes2pdf::limpia("=UDK=&&+Xoo=UDK=l&&&1\n=UDK=&&1"),"\x{1b}+Xoo=UDK=l&&&1\n\x{1b}1","second =UDK= defines  \$escape char");
is(xes2pdf::limpia("=UDK=$_"),"=UDK=$_","forbiden \"$_\"")for ("=","\n","U","D","K","Ü","¨U","¨D","¨K",",");
is(xes2pdf::limpia("=UDK=&=UDK=UDK=b=&=UDK=&"),"=UDK=&","test =UDK=# print");
is(xes2pdf::Limpia(" =UDK=& &+X\n=UDK=&\n&c1\n&+2XCP12.5iso-L\n&m490,10,10,30,690\n&2","  \x{1b}+X\n\n\x{1b}c1\n\x{1b}+2XCP12.5iso-L\n\x{1b}m490,10,10,30,690\n\x{1b}2","texto");


done_testing;

