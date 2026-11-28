//// Templates guide: a layout wraps page content

import snippets/templates_guide_footer as footer
import snippets/templates_guide_main_wrapper as main_wrapper
import snippets/templates_guide_nav as nav
import snippets/templates_guide_page as page
import snippets/templates_guide_scripts as scripts

pub fn build_page(title: String, content: String) -> String {
  // Compose layout pieces
  let nav_html = nav.render()
  let main_html = main_wrapper.render(main_content: content)
  let footer_html = footer.render()
  let scripts_html = scripts.render()

  let body_content = nav_html <> main_html <> footer_html <> scripts_html

  // Wrap everything in page structure
  page.render(page_title: title, page_content: body_content)
}
