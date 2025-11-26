import services/chat_service.{type ChatPubSub, init_chat_pubsub}

/// Application services
///
/// Holds all application-level dependencies shared across requests.
pub type Services {
  Services(pubsub: ChatPubSub)
}

/// Initialize all application services
///
/// Creates and returns a Services instance with all initialized dependencies.
///
/// ## Example
///
/// ```gleam
/// let app_services = services.initialize()
/// ```
pub fn initialize() -> Services {
  let pubsub = init_chat_pubsub()
  Services(pubsub: pubsub)
}
