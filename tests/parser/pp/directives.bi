#include "1"
#include "2"
#include "3"
#include "4"
#include "5"
#include "6"
#include "7"
#include "8"

#define A01 0
#define A02 1
#define A03 11
#define A04 01
#define A05 0123
#define A06 0x
#define A07 0x0
#define A08 0x1
#define A09 0xFF
#define A10 1.0
#define A11 1.0f
#define A12 1.0d
#define A13 0.1
#define A14 0.0
#define A15 1.123
#define A16 1e+1
#define A17 1.0e+1
#define A18 1u
#define A19 1l
#define A20 1ul
#define A21 1ll
#define A22 1ull

#define B01 1+1
#define B02 ((1))

#define X01 
#define X02 
#define X03 11
#define X04 foo
#define X05 1foo
#define X06 foo1
#define X07 1+
#define X08 (
#define X09 )
#define X10 -
#define X11 

#define m( a ) 
#define m( a ) 
#define m( a, b ) 
#define m( a, b ) 
#define m( a, b ) 
#define m( foo, abcdefg, something, bar, buzzzz ) 
#define m( a ) foo
#define m( a ) foo

#define m( a ) a
#define m( a ) afoo
#define m( a ) fooa
#define m( a ) fooafoo

#define m( a, b ) ab
#define m( a, b ) abfoo
#define m( a, b ) afoob
#define m( a, b ) afoobfoo
#define m( a, b ) fooab
#define m( a, b ) fooabfoo
#define m( a, b ) fooafoob
#define m( a, b ) fooafoobfoo

#define m( a ) a##foo
#define m( a ) foo##a
#define m( a ) foo##a##foo

#define m( a, b ) a##b
#define m( a, b ) a##b##foo
#define m( a, b ) a##foo##b
#define m( a, b ) a##foo##b##foo
#define m( a, b ) foo##a##b
#define m( a, b ) foo##a##b##foo
#define m( a, b ) foo##a##foo##b
#define m( a, b ) foo##a##foo##b##foo

#define m( a ) #a
#define m( a, b ) #a#b

#define no_parameters_here (a)
#define no_parameters_here (a,b,c)
