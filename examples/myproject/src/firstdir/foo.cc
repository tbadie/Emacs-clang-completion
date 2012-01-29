#include <myheader.hh>
#include "foo.hh"

void    nearlyEmpty()
{
  // Global and Foo refers to the ns.
  Foo fGlobal;
  foo::Foo fFoo;

  // You can test yourself, It works.
  // You just have to set the clang-flags to
  // the correct absolute-path.
  fGlobal.myGreatAttribute++;
  fFoo.myStupidAttribute++;
}
