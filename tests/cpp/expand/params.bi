#pragma once

extern "C"

'' @fbfrog -whitespace -nonamefixup -removedefine m

declare sub f()
declare function f(byval as long, byval as long) as long

declare sub bar()
declare sub baz()

declare sub bar()
declare sub baz()

declare sub bar()
declare sub baz()

declare sub f()

declare sub f()

declare sub f()
declare sub f()
declare sub f(byval as long)
declare sub f(byval as long)
declare sub f(byval as long, byval as long)
declare sub f(byval as long, byval as long)
declare sub f(byval as single, byval as double, byval as long, byval as long)
declare sub f(byval as single, byval as double, byval as long, byval as long)

declare sub f(byval p as sub())
declare sub f(byval p as sub())
declare sub f(byval p as sub(byval as long))
declare sub f(byval p as sub(byval as long))
declare sub f(byval p as sub(byval as long, byval as long))
declare sub f(byval p as sub(byval as long, byval as long))

declare sub f()
declare sub f()
declare sub f(byval as long)
declare sub f(byval as long)

declare sub f()
declare sub f()
declare sub f(byval as long)
declare sub f(byval as long)

declare sub x(byval as long)
declare sub x()
declare sub x(byval as long, byval as long)
declare sub x(byval as long)
declare sub x()

end extern
