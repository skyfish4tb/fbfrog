#pragma once

extern "C"

extern string1 as zstring * 10
extern string2 as zstring * 10
extern string3 as zstring * 10
extern byteArray1(0 to 9) as byte
extern byteArray2(0 to 9) as byte
extern byteArray3(0 to 9) as byte

type UDT1
	name as zstring * 10
	forComparison(0 to 9) as byte
	myPath as zstring * 10
end type

type UDT2
	name(0 to 9) as byte
	myFullPath as zstring * 10
end type

extern myPartialPath(0 to 9) as byte
declare sub f1(byval param1 as zstring ptr)
declare sub f2(byval param1 as ubyte ptr)

end extern
