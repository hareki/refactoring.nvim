const foo = "foo";
function bar() {
  console.log(foo);
}

console.log(foo);

while (false) {
  console.log(foo);
}

do {
  console.log(foo);
} while (false);

if (true) {
  console.log(foo);
} else {
  console.log(foo);
}

for (let i = 0; i < 5; i++) {
  console.log(foo);
}
const baz = () => {
  console.log(foo);
};
