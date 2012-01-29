#include "template.hh"

void doit()
{
  AnyThing<int, int> same;
  AnyThing<int, float> different;

  // Try it. Clang make the completion as wanted.
  same.specializedAttribute;
  different.genericAttribute;



}
