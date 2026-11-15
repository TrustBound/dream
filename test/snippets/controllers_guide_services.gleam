//// The services that the controllers-and-models guide's controllers use.
////
//// The guide's models use dream_postgres. To keep these tests free of a
//// database, the connection here holds the tasks in memory.

import snippets/controllers_guide_task.{type Task}

pub type Services {
  Services(database: Database)
}

pub type Database {
  Database(connection: Connection)
}

pub type Connection {
  Connection(tasks: List(Task))
}
