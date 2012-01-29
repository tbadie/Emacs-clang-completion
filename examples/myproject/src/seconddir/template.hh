#ifndef SECONDDIR_TEMPLATE_HH_
# define SECONDDIR_TEMPLATE_HH_

template <typename T, typename U>
class AnyThing
{
  public:
    AnyThing()
    {
    }

    int genericAttribute;
};

template <typename T>
class AnyThing<T, T>
{
  public:
    AnyThing()
    {
    }

    int specializedAttribute;
};



#endif // !SECONDDIR_TEMPLATE_HH_
