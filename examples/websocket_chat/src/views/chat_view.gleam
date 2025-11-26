import templates/components/chat_header
import templates/components/input_area
import templates/components/messages_container
import templates/components/welcome_screen
import templates/elements/button
import templates/elements/input
import templates/layouts/page
import templates/pages/chat

/// Render the chat page
///
/// Composes elements → components → page → layout following Dream patterns.
/// CSS and JS are served as static assets, not embedded.
pub fn render_page() -> String {
  // Welcome screen elements
  let name_input =
    input.render(
      id: "nameInput",
      placeholder: "Enter your name",
      value: "",
      attributes: "",
    )
  let join_button =
    button.render(id: "joinButton", text: "Join Chat", attributes: "")

  // Chat screen elements
  let message_input =
    input.render(
      id: "messageInput",
      placeholder: "Type a message...",
      value: "",
      attributes: "disabled",
    )
  let send_button =
    button.render(id: "sendButton", text: "Send", attributes: "disabled")
  let leave_button =
    button.render(id: "leaveButton", text: "Leave", attributes: "")

  // Components
  let welcome =
    welcome_screen.render(name_input: name_input, join_button: join_button)
  let header =
    chat_header.render(status: "Disconnected", leave_button: leave_button)
  let messages = messages_container.render()
  let input_area_component =
    input_area.render(message_input: message_input, send_button: send_button)

  // Page
  let page_content =
    chat.render(
      welcome_screen: welcome,
      header: header,
      messages: messages,
      input_area: input_area_component,
    )

  // Layout (references static CSS and JS files)
  page.render(title: "Dream WebSocket Chat", content: page_content)
}
