import dream/services/broadcaster

pub type TickMessage {
  Tick
}

pub type Services {
  Services(ticker: broadcaster.Broadcaster(TickMessage))
}

pub fn initialize() -> Services {
  let assert Ok(ticker) = broadcaster.start_broadcaster()
  Services(ticker: ticker)
}
