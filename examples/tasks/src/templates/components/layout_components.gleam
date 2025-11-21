//// Layout composition - calls layout templates

import templates/layouts/footer
import templates/layouts/main_wrapper
import templates/layouts/nav
import templates/layouts/page
import templates/layouts/scripts

pub fn build_page(title: String, content: String) -> String {
  let nav_html = nav.render()
  let main_html = main_wrapper.render(main_content: content)
  let footer_html = footer.render()
  let scripts_html = scripts.render()

  let body_content = nav_html <> main_html <> footer_html <> scripts_html

  page.render(page_title: title, page_content: body_content)
}
