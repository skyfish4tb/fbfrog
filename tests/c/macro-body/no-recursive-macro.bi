#pragma once

extern "C"

declare sub A(byval x as long)
#define A(x) A(x)
const b = 1
const B = 2
#define C B

end extern
