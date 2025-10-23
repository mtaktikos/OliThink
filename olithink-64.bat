del *.o
cls
gcc.exe -o olithink.exe olithink.c -w -s -pipe -O3 -m64 -march=nocona -std=c99 -flto -DNDEBUG -fwhole-program -fprofile-generate







