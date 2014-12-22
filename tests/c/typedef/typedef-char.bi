#pragma once

#include once "crt/wchar.bi"

extern "C"

type CHAR as zstring
type WCHAR as wstring
type CCHAR as const zstring
type CWCHAR as const wstring

extern p1 as zstring ptr
extern p2 as wstring ptr
extern p3 as zstring const ptr
extern p4 as wstring const ptr
extern p5 as const zstring ptr
extern p6 as const wstring ptr
extern p7 as const zstring ptr
extern p8 as const wstring ptr
extern p10 as const zstring ptr
extern p20 as const wstring ptr
extern p30 as const zstring const ptr
extern p40 as const wstring const ptr
extern p50 as const zstring ptr
extern p60 as const wstring ptr
extern p70 as const zstring ptr
extern p80 as const wstring ptr
extern c1 as byte
extern c2 as wchar_t
extern c3 as const byte
extern c4 as const wchar_t
extern c10 as const byte
extern c20 as const wchar_t
extern c30 as const byte
extern c40 as const wchar_t
extern array1 as zstring * 10
extern array2 as wstring * 10
extern array3 as const zstring * 10
extern array4 as const wstring * 10
extern array10 as const zstring * 10
extern array20 as const wstring * 10
extern array30 as const zstring * 10
extern array40 as const wstring * 10

end extern
