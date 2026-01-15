#include <stdio.h>
#include <stdbool.h>

int main() {
  P foo = "foo";
  printf(foo);

  while (false) {
    printf(foo);
  }

  do {
    printf(foo);
  } while (false);

  if (true) {
    int a;
    printf(foo);
  } else {
    printf(foo);
  }

  for (int i = 0; i < 5; i++) {
    printf(foo);
  }
}
