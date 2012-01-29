#include <myheader.hh>

int main()
{
  Foo f;

  f.myGreatAttribute++;

//  To check if clang-complete works, try to uncomment the next
//  line, and then, M-x clang-complete just after the 'f.'.
//  f.

// You can also check if your clang version is fair enough to detect
// error: try to delete some letters in "myGreatAttribute" and try to
// complete again.



  return 0;
}

