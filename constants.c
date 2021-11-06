// constants.c

#include <sys/select.h>
#include <stdio.h>

int main() {

  // determine FD_SETSIZE for the host operating system.
  // This would be needed for a runtime test, to avoid 
  // calling select(2) on any file descriptor not less 
  // than this value.
  //
  // TBD : availability of any poll interface in
  // Ruby that does not call select(2) internally
  printf("FD_SETSIZE=%d\n", FD_SETSIZE);

  return(0);
}
