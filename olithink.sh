rm *.o
gcc -o olithink olithink.c -w -s -pipe -Ofast -flto -DNDEBUG -fprofile-generate 
 
