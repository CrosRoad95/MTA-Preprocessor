# MTA-Preprocessor
C++ macros inside mta.

# instructions
1. `include "scriptName"` - load specified file with macro support
2. `ignore [n]` - ignore next line, or N next lines, `ignore 10` will ignore next 10 lines
3. `define name value` - set value under name.
4. `precompile name value` - same as above but value become executed and result is stores under name.
5. `undef name` - remove variable.
6. `ifdef name` - check if variables is in use.
7. `ifndef name` - check if variables isn't used yet.
8. `if condition` - skip chunk of code if result of condition equal false.
9. `else` - if condition was false.
10. `endif` - end of if.

I recommend to set uppercase name.

Macros starting with `#` char at start.

# Examples
1.
```lua
#define A 1
#define B 1
#precompile C A+B
print(C)
```
final code will be: `print(2)`

2.
```lua
#define ADD1(A,B) A+B
#precompile ADD2(A,B) A+B

print(ADD1(1,2)) -- print(1+2)
print(ADD2(1,2)) -- print(3)
```
