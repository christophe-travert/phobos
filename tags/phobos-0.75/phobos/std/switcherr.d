
import object;
import std.c.stdio;

class SwitchError : Object
{
  private:

    uint linnum;
    char[] filename;

    this(char[] filename, uint linnum)
    {
	this.linnum = linnum;
	this.filename = filename;
    }

  public:

    /***************************************
     * If nobody catches the Assert, this winds up
     * getting called by the startup code.
     */

    void print()
    {
	printf("Switch Default %s(%u)\n", (char *)filename, linnum);
    }
}

/********************************************
 * Called by the compiler generated module assert function.
 * Builds an Assert exception and throws it.
 */

extern (C) static void _d_switch_error(char[] filename, uint line)
{
    //printf("_d_switch_error(%s, %d)\n", (char *)filename, line);
    SwitchError a = new SwitchError(filename, line);
    //printf("assertion %p created\n", a);
    throw a;
}
