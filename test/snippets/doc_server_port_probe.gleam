//// Doc comment example: dream/servers/mist/port_probe.is_in_use

import dream/servers/mist/port_probe
import gleam/option.{None}

pub fn check_port(port: Int) -> Bool {
  let in_use = port_probe.is_in_use(None, port)
  in_use
}
