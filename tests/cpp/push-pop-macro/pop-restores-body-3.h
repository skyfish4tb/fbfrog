#define A

#pragma push_macro("A")

// Temporarily redefined with non-empty body
#define A 123
static int x = A;

#pragma pop_macro("A")
A static int y;
