//// Templates guide: calling a module that Matcha generated
////
//// templates_guide_hello.gleam is generated from templates_guide_hello.matcha.

import snippets/templates_guide_hello as hello

pub fn greet(name: String) -> String {
  hello.render(name: name)
}
